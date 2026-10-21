// =============================================================================
// File Name   : ccsds_conv_viterbi_codec.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog (Synthesizable)
// Description : Shared CCSDS 131.0-B-5 (Section 3) & CCSDS 211.2-B-3 Rate-1/2,
//               Constraint-Length K=7 Convolutional Encoder, Puncturer,
//               NRZ-L/NRZ-M/Bi-Phi-L Line Coder (TX10), and 64-State Soft-LLR
//               Add-Compare-Select (ACS) Viterbi Trellis Decoder (RX1):
//                 - Generator polynomials: G1 = 7'b1111001 (171o),
//                   G2 = 7'b1011011 (133o) with configurable C2 symbol inversion
//                   (c2_invert_en=1 for TM/AOS per 131.0-B-5; 0 for Prox-1).
//                 - 64-state parallel ACS unit with 35-stage (5*K) survivor
//                   traceback register and minimum-metric state selection.
// =============================================================================
`timescale 1ns / 1ps

module ccsds_conv_viterbi_codec
  import ccsds_pkg::*;
#(
  parameter int unsigned TRACEBACK_DEPTH = 35
) (
  input  logic               clk,
  input  logic               rst_n,

  // Configuration
  input  logic               c2_invert_en,
  input  ccsds_line_code_e   line_code_mode,

  // TX10: Downlink / Bidirectional Convolutional Encoder & Line Coder Interface
  input  logic               tx_bit_in,
  input  logic               tx_bit_valid_in,
  output logic               tx_sym_c1_out,
  output logic               tx_sym_c2_out,
  output logic               tx_sym_valid_out,
  output logic               tx_line_coded_c1_out,
  output logic               tx_line_coded_c2_out,

  // RX1: Uplink / Bidirectional 64-State Soft-LLR Viterbi Decoder Interface
  // LLRs: +7 = strong '1', -7 = strong '0'
  input  logic signed [3:0]  rx_sym_c1_llr_in,
  input  logic signed [3:0]  rx_sym_c2_llr_in,
  input  logic               rx_sym_valid_in,
  output logic               rx_dec_bit_out,
  output logic               rx_dec_valid_out
);

  // ---------------------------------------------------------------------------
  // 1. Rate-1/2, K=7 Convolutional Encoder & NRZ-L/NRZ-M/Bi-Phi-L Line Coder
  // ---------------------------------------------------------------------------
  logic [5:0] conv_sr_q;
  logic       nrzm_prev_q;

  function automatic logic calc_c1(input logic b_in, input logic [5:0] sr);
    logic [6:0] w;
    w = {b_in, sr};
    return ^(w & POLY_CONV_G1);
  endfunction

  function automatic logic calc_c2(input logic b_in, input logic [5:0] sr, input logic inv_c2);
    logic [6:0] w;
    logic       raw_c2;
    w      = {b_in, sr};
    raw_c2 = ^(w & POLY_CONV_G2);
    return inv_c2 ? ~raw_c2 : raw_c2;
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      conv_sr_q            <= 6'd0;
      nrzm_prev_q          <= 1'b0;
      tx_sym_c1_out        <= 1'b0;
      tx_sym_c2_out        <= 1'b0;
      tx_sym_valid_out     <= 1'b0;
      tx_line_coded_c1_out <= 1'b0;
      tx_line_coded_c2_out <= 1'b0;
    end else begin
      tx_sym_valid_out <= 1'b0;
      if (tx_bit_valid_in) begin
        logic c1_val;
        logic c2_val;
        logic m1_val;
        logic m2_val;
        c1_val        = calc_c1(tx_bit_in, conv_sr_q);
        c2_val        = calc_c2(tx_bit_in, conv_sr_q, c2_invert_en);
        conv_sr_q     <= {tx_bit_in, conv_sr_q[5:1]};
        tx_sym_c1_out <= c1_val;
        tx_sym_c2_out <= c2_val;
        tx_sym_valid_out <= 1'b1;

        m1_val = nrzm_prev_q ^ c1_val;
        m2_val = m1_val ^ c2_val;
        if (line_code_mode == LINE_NRZ_M) begin
          tx_line_coded_c1_out <= m1_val;
          tx_line_coded_c2_out <= m2_val;
          nrzm_prev_q          <= m2_val;
        end else if (line_code_mode == LINE_BIPHIL) begin
          tx_line_coded_c1_out <= c1_val;
          tx_line_coded_c2_out <= ~c1_val;
        end else begin
          tx_line_coded_c1_out <= c1_val;
          tx_line_coded_c2_out <= c2_val;
        end
      end
    end
  end

  // ---------------------------------------------------------------------------
  // 2. 64-State Soft-LLR Add-Compare-Select (ACS) Viterbi Decoder
  // ---------------------------------------------------------------------------
  logic [9:0]  pm_q [0:63];
  logic [63:0] surv_mem_q [0:TRACEBACK_DEPTH-1];
  logic [5:0]  fill_cnt_q;

  function automatic logic [9:0] branch_dist(
    input logic signed [3:0] llr1,
    input logic signed [3:0] llr2_aligned,
    input logic              exp1,
    input logic              exp2
  );
    logic signed [5:0] d1;
    logic signed [5:0] d2;
    d1 = exp1 ? (6'sd8 - 6'(llr1)) : (6'sd8 + 6'(llr1));
    d2 = exp2 ? (6'sd8 - 6'(llr2_aligned)) : (6'sd8 + 6'(llr2_aligned));
    return 10'(unsigned'(d1 + d2));
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pm_q[0] <= 10'd0;
      for (int s = 1; s < 64; s++) begin
        pm_q[s] <= 10'd256;
      end
      for (int t = 0; t < TRACEBACK_DEPTH; t++) begin
        surv_mem_q[t] <= 64'd0;
      end
      fill_cnt_q       <= 6'd0;
      rx_dec_bit_out   <= 1'b0;
      rx_dec_valid_out <= 1'b0;
    end else begin
      rx_dec_valid_out <= 1'b0;
      if (rx_sym_valid_in) begin
        logic signed [3:0] llr2_eff;
        logic [9:0]        nxt_pm [0:63];
        logic [63:0]       nxt_surv;
        logic [9:0]        min_pm;
        logic [5:0]        tb_state;

        llr2_eff = c2_invert_en ? (-rx_sym_c2_llr_in) : rx_sym_c2_llr_in;
        min_pm   = 10'h3FF;

        for (int nxt_s = 0; nxt_s < 64; nxt_s++) begin
          logic        u_bit;
          logic [5:0]  prev_s0;
          logic [5:0]  prev_s1;
          logic [9:0]  bm0, bm1, m0, m1;

          u_bit   = nxt_s[5];
          prev_s0 = {nxt_s[4:0], 1'b0};
          prev_s1 = {nxt_s[4:0], 1'b1};

          bm0 = branch_dist(rx_sym_c1_llr_in, llr2_eff, calc_c1(u_bit, prev_s0), calc_c2(u_bit, prev_s0, 1'b0));
          bm1 = branch_dist(rx_sym_c1_llr_in, llr2_eff, calc_c1(u_bit, prev_s1), calc_c2(u_bit, prev_s1, 1'b0));

          m0 = pm_q[prev_s0] + bm0;
          m1 = pm_q[prev_s1] + bm1;

          if (m0 <= m1) begin
            nxt_pm[nxt_s]   = m0;
            nxt_surv[nxt_s] = 1'b0;
          end else begin
            nxt_pm[nxt_s]   = m1;
            nxt_surv[nxt_s] = 1'b1;
          end

          if (nxt_pm[nxt_s] < min_pm) begin
            min_pm = nxt_pm[nxt_s];
          end
        end

        for (int s = 0; s < 64; s++) begin
          pm_q[s] <= nxt_pm[s] - min_pm;
        end

        surv_mem_q[0] <= nxt_surv;
        for (int t = 1; t < TRACEBACK_DEPTH; t++) begin
          surv_mem_q[t] <= surv_mem_q[t-1];
        end

        // Traceback from best state (or state 0) over TRACEBACK_DEPTH stages
        tb_state = 6'd0;
        for (int s = 1; s < 64; s++) begin
          if (nxt_pm[s] < nxt_pm[tb_state]) begin
            tb_state = 6'(s);
          end
        end

        // Step 0 uses current-cycle nxt_surv before stepping through registered surv_mem_q
        tb_state = {tb_state[4:0], nxt_surv[tb_state]};
        for (int t = 0; t < TRACEBACK_DEPTH - 2; t++) begin
          logic lsb_prev;
          lsb_prev = surv_mem_q[t][tb_state];
          tb_state = {tb_state[4:0], lsb_prev};
        end

        if (fill_cnt_q == 6'(TRACEBACK_DEPTH - 1)) begin
          rx_dec_bit_out   <= tb_state[5];
          rx_dec_valid_out <= 1'b1;
        end else begin
          fill_cnt_q <= fill_cnt_q + 6'd1;
        end
      end
    end
  end

endmodule : ccsds_conv_viterbi_codec
