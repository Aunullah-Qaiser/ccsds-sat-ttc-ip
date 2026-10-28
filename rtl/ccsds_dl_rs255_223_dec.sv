//=============================================================================
// File Name   : ccsds_dl_rs255_223_dec.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : CCSDS 131.0-B-5 (TM Synchronization and Channel Coding)
// Description : Synthesizable Ground EGSE Dual-Basis RS(255,223) De-Interleaver
//               & Full t=16 Berlekamp-Massey / Chien / Forney Error-Correcting
//               Decoder (Fix P1-2):
//                 - Converts incoming dual-basis symbols to standard basis via
//                   T_alpha^-1 (RS_T_DUAL_TO_STD) and stores information bytes
//                   in a single-write-port distributed LUTRAM (`info_buf`)
//                 - Accumulates all 32 consecutive generator roots S_0..S_31
//                   (alpha^(11*j mod 255) for j = 112..143) across shortened
//                   codewords (virtual fill Q in [0..200])
//                 - Solves degree-16 error-locator polynomial Lambda(z) via
//                   32-step iterative Berlekamp-Massey (`RS_DEC_SOLVE_BM`, 4
//                   steps/clock = 8 clocks) and degree-15 Forney evaluator
//                   polynomial Omega(z) = S(z)*Lambda(z) mod z^16
//                   (`RS_DEC_SOLVE_OMEGA`, 1 clock)
//                 - Evaluates Chien roots and Forney error magnitudes on-the-fly
//                   during `RS_DEC_EMIT`, correcting up to t = 16 arbitrary
//                   symbol errors per codeword in dual basis
//=============================================================================
`timescale 1ns / 1ps

module ccsds_dl_rs255_223_dec
  import ccsds_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // Configuration
  input  logic [3:0]  interleave_depth_i_cfg,
  input  logic [7:0]  virtual_fill_q_cfg,

  // Input RS-Coded Block Stream ((255 - Q) * I bytes)
  input  logic        s_axis_tvalid,
  output logic        s_axis_tready,
  input  logic [7:0]  s_axis_tdata,
  input  logic        s_axis_tlast,

  // Output Decoded Information Block Stream ((223 - Q) * I bytes)
  output logic        m_axis_tvalid,
  input  logic        m_axis_tready,
  output logic [7:0]  m_axis_tdata,
  output logic        m_axis_tlast,

  // Status Pulses
  output logic        rs_cw_done_pulse,
  output logic        rs_syndrome_clean_out,
  output logic [15:0] rs_corrected_sym_cnt_out
);

  function automatic logic [7:0] dual_to_std(input logic [7:0] d);
    logic [7:0] s;
    begin
      for (int i = 0; i < 8; i++) begin
        s[7 - i] = ^(d & RS_T_DUAL_TO_STD[i]);
      end
      return s;
    end
  endfunction

  function automatic logic [7:0] std_to_dual(input logic [7:0] s);
    logic [7:0] d;
    begin
      for (int i = 0; i < 8; i++) begin
        d[7 - i] = ^(s & RS_T_STD_TO_DUAL[i]);
      end
      return d;
    end
  endfunction

  function automatic logic [7:0] gf_mul(input logic [7:0] a, input logic [7:0] b);
    logic [7:0] p;
    logic [7:0] cur;
    begin
      p   = 8'd0;
      cur = a;
      for (int i = 0; i < 8; i++) begin
        if (b[i]) p = p ^ cur;
        if (cur[7]) cur = (cur << 1) ^ 8'h87;
        else        cur = (cur << 1);
      end
      return p;
    end
  endfunction

  // All 32 consecutive generator roots alpha^(11*j mod 255) for j = 112..143 (CCSDS 131.0-B-5 Sec 4.3.4)
  localparam logic [7:0] RS_ROOTS_32 [0:31] = '{
    8'h15, 8'h64, 8'h8C, 8'h7C, 8'h02, 8'hDD, 8'hFB, 8'h74,
    8'h78, 8'h3F, 8'hAC, 8'h13, 8'h84, 8'h06, 8'hE0, 8'h8A,
    8'h9C, 8'h88, 8'h41, 8'h73, 8'h35, 8'h0B, 8'h0A, 8'hA7,
    8'h19, 8'h23, 8'h1F, 8'hC3, 8'h95, 8'h5F, 8'h1D, 8'h1E
  };

  localparam logic [7:0] GF_INV_LUT [0:255] = '{
    8'h00, 8'h01, 8'hC3, 8'h82, 8'hA2, 8'h7E, 8'h41, 8'h5A, 8'h51, 8'h36, 8'h3F, 8'hAC, 8'hE3, 8'h68, 8'h2D, 8'h2A,
    8'hEB, 8'h9B, 8'h1B, 8'h35, 8'hDC, 8'h1E, 8'h56, 8'hA5, 8'hB2, 8'h74, 8'h34, 8'h12, 8'hD5, 8'h64, 8'h15, 8'hDD,
    8'hB6, 8'h4B, 8'h8E, 8'hFB, 8'hCE, 8'hE9, 8'hD9, 8'hA1, 8'h6E, 8'hDB, 8'h0F, 8'h2C, 8'h2B, 8'h0E, 8'h91, 8'hF1,
    8'h59, 8'hD7, 8'h3A, 8'hF4, 8'h1A, 8'h13, 8'h09, 8'h50, 8'hA9, 8'h63, 8'h32, 8'hF5, 8'hC9, 8'hCC, 8'hAD, 8'h0A,
    8'h5B, 8'h06, 8'hE6, 8'hF7, 8'h47, 8'hBF, 8'hBE, 8'h44, 8'h67, 8'h7B, 8'hB7, 8'h21, 8'hAF, 8'h53, 8'h93, 8'hFF,
    8'h37, 8'h08, 8'hAE, 8'h4D, 8'hC4, 8'hD1, 8'h16, 8'hA4, 8'hD6, 8'h30, 8'h07, 8'h40, 8'h8B, 8'h9D, 8'hBB, 8'h8C,
    8'hEF, 8'h81, 8'hA8, 8'h39, 8'h1D, 8'hD4, 8'h7A, 8'h48, 8'h0D, 8'hE2, 8'hCA, 8'hB0, 8'hC7, 8'hDE, 8'h28, 8'hDA,
    8'h97, 8'hD2, 8'hF2, 8'h84, 8'h19, 8'hB3, 8'hB9, 8'h87, 8'hA7, 8'hE4, 8'h66, 8'h49, 8'h95, 8'h99, 8'h05, 8'hA3,
    8'hEE, 8'h61, 8'h03, 8'hC2, 8'h73, 8'hF3, 8'hB8, 8'h77, 8'hE0, 8'hF8, 8'h9C, 8'h5C, 8'h5F, 8'hBA, 8'h22, 8'hFA,
    8'hF0, 8'h2E, 8'hFE, 8'h4E, 8'h98, 8'h7C, 8'hD3, 8'h70, 8'h94, 8'h7D, 8'hEA, 8'h11, 8'h8A, 8'h5D, 8'hBC, 8'hEC,
    8'hD8, 8'h27, 8'h04, 8'h7F, 8'h57, 8'h17, 8'hE5, 8'h78, 8'h62, 8'h38, 8'hAB, 8'hAA, 8'h0B, 8'h3E, 8'h52, 8'h4C,
    8'h6B, 8'hCB, 8'h18, 8'h75, 8'hC0, 8'hFD, 8'h20, 8'h4A, 8'h86, 8'h76, 8'h8D, 8'h5E, 8'h9E, 8'hED, 8'h46, 8'h45,
    8'hB4, 8'hFC, 8'h83, 8'h02, 8'h54, 8'hD0, 8'hDF, 8'h6C, 8'hCD, 8'h3C, 8'h6A, 8'hB1, 8'h3D, 8'hC8, 8'h24, 8'hE8,
    8'hC5, 8'h55, 8'h71, 8'h96, 8'h65, 8'h1C, 8'h58, 8'h31, 8'hA0, 8'h26, 8'h6F, 8'h29, 8'h14, 8'h1F, 8'h6D, 8'hC6,
    8'h88, 8'hF9, 8'h69, 8'h0C, 8'h79, 8'hA6, 8'h42, 8'hF6, 8'hCF, 8'h25, 8'h9A, 8'h10, 8'h9F, 8'hBD, 8'h80, 8'h60,
    8'h90, 8'h2F, 8'h72, 8'h85, 8'h33, 8'h3B, 8'hE7, 8'h43, 8'h89, 8'hE1, 8'h8F, 8'h23, 8'hC1, 8'hB5, 8'h92, 8'h4F
  };

  localparam logic [7:0] Z_INV_POW_LUT [0:255] = '{
    8'h01, 8'h3E, 8'h46, 8'h32, 8'hC9, 8'h14, 8'h16, 8'h6A, 8'hE6, 8'h82, 8'h97, 8'hBF, 8'h93, 8'h47, 8'h0C, 8'h8F,
    8'h26, 8'hDF, 8'h7E, 8'hF0, 8'hE8, 8'h71, 8'h3D, 8'h04, 8'hF8, 8'h9F, 8'hC8, 8'h2A, 8'h50, 8'h58, 8'h2F, 8'h96,
    8'h81, 8'hD5, 8'h75, 8'hC5, 8'h9B, 8'h30, 8'hB5, 8'h98, 8'h72, 8'h7F, 8'hCE, 8'hAE, 8'h43, 8'hF4, 8'h10, 8'hEE,
    8'hF5, 8'h2E, 8'hA8, 8'hC7, 8'hE7, 8'hBC, 8'hD1, 8'h8D, 8'h5A, 8'h53, 8'h1A, 8'hE5, 8'hC0, 8'h5D, 8'hE9, 8'h4F,
    8'h7B, 8'h36, 8'h31, 8'h8B, 8'hDE, 8'h40, 8'hB6, 8'hDA, 8'hB8, 8'h29, 8'h12, 8'h92, 8'h79, 8'h4A, 8'hBD, 8'hEF,
    8'hCB, 8'h68, 8'h9A, 8'h0E, 8'hF3, 8'hAA, 8'hBB, 8'h6B, 8'hD8, 8'hC4, 8'hA5, 8'h76, 8'h87, 8'h51, 8'h66, 8'h69,
    8'hA4, 8'h48, 8'hC1, 8'h63, 8'hAF, 8'h7D, 8'hB2, 8'h22, 8'h27, 8'hE1, 8'h38, 8'hC2, 8'h21, 8'h65, 8'h2B, 8'h6E,
    8'h1E, 8'h1D, 8'h5F, 8'h95, 8'hC3, 8'h1F, 8'h23, 8'h19, 8'hA7, 8'h0A, 8'h0B, 8'h35, 8'h73, 8'h41, 8'h88, 8'h9C,
    8'h8A, 8'hE0, 8'h06, 8'h84, 8'h13, 8'hAC, 8'h3F, 8'h78, 8'h74, 8'hFB, 8'hDD, 8'h02, 8'h7C, 8'h8C, 8'h64, 8'h15,
    8'h28, 8'h2C, 8'hD4, 8'h4B, 8'h83, 8'hA9, 8'hF9, 8'hA1, 8'h8E, 8'h18, 8'h99, 8'h4C, 8'h39, 8'hFC, 8'h67, 8'h57,
    8'hE2, 8'h7A, 8'h08, 8'h77, 8'hB9, 8'h17, 8'h54, 8'hA0, 8'hB0, 8'h5E, 8'hAB, 8'h85, 8'h2D, 8'hEA, 8'h0D, 8'hB1,
    8'h60, 8'hED, 8'hB7, 8'hE4, 8'hFE, 8'h1B, 8'hDB, 8'h86, 8'h6F, 8'h20, 8'h5B, 8'h6D, 8'h5C, 8'hD7, 8'h09, 8'h49,
    8'hFF, 8'h25, 8'h9D, 8'hB4, 8'hA6, 8'h34, 8'h4D, 8'h07, 8'hBA, 8'h55, 8'h9E, 8'hF6, 8'h6C, 8'h62, 8'h91, 8'h3B,
    8'h80, 8'hEB, 8'h33, 8'hF7, 8'h52, 8'h24, 8'hA3, 8'hF2, 8'h94, 8'hFD, 8'h59, 8'h11, 8'hD0, 8'hB3, 8'h1C, 8'h61,
    8'hD3, 8'hF1, 8'hD6, 8'h37, 8'h0F, 8'hCD, 8'hEC, 8'h89, 8'hA2, 8'hCC, 8'hD2, 8'hCF, 8'h90, 8'h05, 8'hC6, 8'hD9,
    8'hFA, 8'hE3, 8'h44, 8'h4E, 8'h45, 8'h70, 8'h03, 8'h42, 8'hCA, 8'h56, 8'hDC, 8'h3C, 8'h3A, 8'hBE, 8'hAD, 8'h01
  };

  localparam logic [7:0] R0_INV_POW_LUT [0:255] = '{
    8'h01, 8'h1E, 8'hD3, 8'h68, 8'h25, 8'hA8, 8'h08, 8'hF0, 8'h84, 8'h4E, 8'hAF, 8'h52, 8'h40, 8'h1B, 8'hB5, 8'hF9,
    8'h6A, 8'h19, 8'h89, 8'hD8, 8'hBA, 8'h53, 8'h5E, 8'hC8, 8'hDD, 8'hDC, 8'hC2, 8'h11, 8'h79, 8'h5C, 8'hF4, 8'hFC,
    8'h0C, 8'h88, 8'hC6, 8'h69, 8'h3B, 8'h7B, 8'h60, 8'hD5, 8'h2C, 8'h46, 8'h5F, 8'hD6, 8'h0E, 8'hB4, 8'hE7, 8'hB9,
    8'h71, 8'hAC, 8'h70, 8'hB2, 8'hA3, 8'hDA, 8'h86, 8'h72, 8'h8E, 8'h82, 8'h0A, 8'hCC, 8'hA5, 8'h9E, 8'hE5, 8'h85,
    8'h50, 8'h7C, 8'h3A, 8'h65, 8'hB3, 8'hBD, 8'h09, 8'hEE, 8'h57, 8'h26, 8'h8A, 8'hFA, 8'h48, 8'hEB, 8'h31, 8'hB7,
    8'hC5, 8'h4B, 8'hC9, 8'hC3, 8'h0F, 8'hAA, 8'h34, 8'hD1, 8'h54, 8'h04, 8'h78, 8'h42, 8'h27, 8'h94, 8'h29, 8'h20,
    8'hCE, 8'h99, 8'hBF, 8'h35, 8'hCF, 8'h87, 8'h6C, 8'h5D, 8'hEA, 8'h2F, 8'h64, 8'hAD, 8'h6E, 8'h61, 8'hCB, 8'hFF,
    8'h2E, 8'h7A, 8'h7E, 8'h06, 8'h44, 8'h63, 8'hF7, 8'hDE, 8'hFE, 8'h30, 8'hA9, 8'h16, 8'h23, 8'hEC, 8'h6B, 8'h07,
    8'h5A, 8'hB0, 8'h9F, 8'hFB, 8'h56, 8'h38, 8'h59, 8'h92, 8'h6D, 8'h43, 8'h39, 8'h47, 8'h41, 8'h05, 8'h66, 8'h91,
    8'h4F, 8'hB1, 8'h81, 8'h28, 8'h3E, 8'h1D, 8'hF1, 8'h9A, 8'h9D, 8'hC7, 8'h77, 8'hE8, 8'h13, 8'h45, 8'h7D, 8'h24,
    8'hB6, 8'hDB, 8'h98, 8'hA1, 8'hE6, 8'hA7, 8'hA2, 8'hC4, 8'h55, 8'h1A, 8'hAB, 8'h2A, 8'h02, 8'h3C, 8'h21, 8'hD0,
    8'h4A, 8'hD7, 8'h10, 8'h67, 8'h8F, 8'h9C, 8'hD9, 8'hA4, 8'h80, 8'h36, 8'hED, 8'h75, 8'hD4, 8'h32, 8'h95, 8'h37,
    8'hF3, 8'hA6, 8'hBC, 8'h17, 8'h3D, 8'h3F, 8'h03, 8'h22, 8'hF2, 8'hB8, 8'h6F, 8'h7F, 8'h18, 8'h97, 8'h0B, 8'hD2,
    8'h76, 8'hF6, 8'hC0, 8'h2D, 8'h58, 8'h8C, 8'hBE, 8'h2B, 8'h1C, 8'hEF, 8'h49, 8'hF5, 8'hE2, 8'hDF, 8'hE0, 8'hE3,
    8'hC1, 8'h33, 8'h8B, 8'hE4, 8'h9B, 8'h83, 8'h14, 8'h1F, 8'hCD, 8'hBB, 8'h4D, 8'h8D, 8'hA0, 8'hF8, 8'h74, 8'hCA,
    8'hE1, 8'hFD, 8'h12, 8'h5B, 8'hAE, 8'h4C, 8'h93, 8'h73, 8'h90, 8'h51, 8'h62, 8'hE9, 8'h0D, 8'h96, 8'h15, 8'h01
  };

  typedef enum logic [1:0] {
    RS_DEC_RECV        = 2'd0,
    RS_DEC_SOLVE_BM    = 2'd1,
    RS_DEC_SOLVE_OMEGA = 2'd2,
    RS_DEC_EMIT        = 2'd3
  } rs_dec_state_e;

  (* ram_style = "distributed" *) logic [7:0] info_buf [0:255];

  rs_dec_state_e state_q;
  logic [15:0]   byte_cnt_q;
  logic [15:0]   total_cw_len_q;
  logic [15:0]   info_len_q;
  logic [15:0]   out_idx_q;
  logic [7:0]    syn_q   [0:31];
  logic          syn_clean_q;

  // Berlekamp-Massey & Forney Solver Registers (t = 16)
  logic [2:0]    bm_grp_q;
  logic [7:0]    bm_c_q  [0:16];
  logic [7:0]    bm_b_q  [0:16];
  logic [5:0]    bm_l_q;
  logic [5:0]    bm_m_q;
  logic [7:0]    bm_bval_q;
  logic [7:0]    omg_q   [0:15];
  logic [15:0]   corr_cnt_q;

  logic [15:0]   info_limit_comb;
  logic          wr_buf_en;

  assign info_limit_comb          = (16'd223 - {8'd0, virtual_fill_q_cfg}) * {12'd0, interleave_depth_i_cfg};
  assign s_axis_tready            = (state_q == RS_DEC_RECV);
  assign rs_corrected_sym_cnt_out = corr_cnt_q;
  assign wr_buf_en                = (state_q == RS_DEC_RECV) && s_axis_tvalid && (byte_cnt_q < info_limit_comb);

  // Dedicated Single-Write-Port Distributed LUTRAM Inference Block
  always_ff @(posedge clk) begin
    if (wr_buf_en) begin
      info_buf[byte_cnt_q[7:0]] <= s_axis_tdata;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q               <= RS_DEC_RECV;
      byte_cnt_q            <= 16'd0;
      total_cw_len_q        <= 16'd0;
      info_len_q            <= 16'd0;
      out_idx_q             <= 16'd0;
      for (int k = 0; k < 32; k++) begin
        syn_q[k] <= 8'd0;
      end
      syn_clean_q           <= 1'b1;
      bm_grp_q              <= 3'd0;
      bm_c_q[0]             <= 8'h01;
      bm_b_q[0]             <= 8'h01;
      for (int k = 1; k <= 16; k++) begin
        bm_c_q[k] <= 8'd0;
        bm_b_q[k] <= 8'd0;
      end
      bm_l_q                <= 6'd0;
      bm_m_q                <= 6'd1;
      bm_bval_q             <= 8'h01;
      for (int k = 0; k < 16; k++) begin
        omg_q[k] <= 8'd0;
      end
      corr_cnt_q            <= 16'd0;
      m_axis_tvalid         <= 1'b0;
      m_axis_tdata          <= 8'd0;
      m_axis_tlast          <= 1'b0;
      rs_cw_done_pulse      <= 1'b0;
      rs_syndrome_clean_out <= 1'b1;
    end else begin
      rs_cw_done_pulse <= 1'b0;
      if (m_axis_tready) begin
        m_axis_tvalid <= 1'b0;
        m_axis_tlast  <= 1'b0;
      end

      unique case (state_q)
        RS_DEC_RECV: begin
          if (s_axis_tvalid) begin
            logic [7:0] std_sym;
            logic [7:0] nxt_s [0:31];
            logic       clean;
            std_sym = dual_to_std(s_axis_tdata);
            clean   = 1'b1;
            for (int k = 0; k < 32; k++) begin
              nxt_s[k] = gf_mul((byte_cnt_q == 16'd0) ? 8'd0 : syn_q[k], RS_ROOTS_32[k]) ^ std_sym;
              syn_q[k] <= nxt_s[k];
              if (nxt_s[k] != 8'd0) begin
                clean = 1'b0;
              end
            end

            if (s_axis_tlast) begin
              syn_clean_q           <= clean;
              rs_syndrome_clean_out <= clean;
              total_cw_len_q        <= byte_cnt_q + 16'd1;
              info_len_q            <= info_limit_comb;
              byte_cnt_q            <= 16'd0;
              bm_grp_q              <= 3'd0;
              bm_c_q[0]             <= 8'h01;
              bm_b_q[0]             <= 8'h01;
              for (int k = 1; k <= 16; k++) begin
                bm_c_q[k] <= 8'd0;
                bm_b_q[k] <= 8'd0;
              end
              bm_l_q                <= 6'd0;
              bm_m_q                <= 6'd1;
              bm_bval_q             <= 8'h01;
              state_q               <= RS_DEC_SOLVE_BM;
            end else begin
              byte_cnt_q <= byte_cnt_q + 16'd1;
            end
          end
        end

        RS_DEC_SOLVE_BM: begin
          // 32-Step Berlekamp-Massey Solver (4 syndrome steps per clock = 8 clocks total)
          logic [7:0] c_tmp [0:16];
          logic [7:0] b_tmp [0:16];
          logic [7:0] t_tmp [0:16];
          logic [5:0] l_tmp;
          logic [5:0] m_tmp;
          logic [7:0] bval_tmp;

          for (int i = 0; i <= 16; i++) begin
            c_tmp[i] = bm_c_q[i];
            b_tmp[i] = bm_b_q[i];
          end
          l_tmp    = bm_l_q;
          m_tmp    = bm_m_q;
          bval_tmp = bm_bval_q;

          for (int sub = 0; sub < 4; sub++) begin
            int         n_idx;
            logic [7:0] disc;
            n_idx = int'(bm_grp_q) * 4 + sub;
            disc  = syn_q[n_idx];
            for (int i = 1; i <= 16; i++) begin
              if ((6'(i) <= l_tmp) && (n_idx >= i)) begin
                disc = disc ^ gf_mul(c_tmp[i], syn_q[n_idx - i]);
              end
            end

            if (disc == 8'd0) begin
              m_tmp = m_tmp + 6'd1;
            end else begin
              logic [7:0] coef;
              for (int i = 0; i <= 16; i++) begin
                t_tmp[i] = c_tmp[i];
              end
              coef = gf_mul(disc, GF_INV_LUT[bval_tmp]);
              for (int i = 0; i <= 16; i++) begin
                if ((6'(i) + m_tmp) <= 6'd16) begin
                  c_tmp[6'(i) + m_tmp] = c_tmp[6'(i) + m_tmp] ^ gf_mul(coef, b_tmp[i]);
                end
              end
              if ((l_tmp << 1) <= 6'(n_idx)) begin
                l_tmp    = 6'(n_idx + 1) - l_tmp;
                for (int i = 0; i <= 16; i++) begin
                  b_tmp[i] = t_tmp[i];
                end
                bval_tmp = disc;
                m_tmp    = 6'd1;
              end else begin
                m_tmp = m_tmp + 6'd1;
              end
            end
          end

          for (int i = 0; i <= 16; i++) begin
            bm_c_q[i] <= c_tmp[i];
            bm_b_q[i] <= b_tmp[i];
          end
          bm_l_q    <= l_tmp;
          bm_m_q    <= m_tmp;
          bm_bval_q <= bval_tmp;

          if (bm_grp_q == 3'd7) begin
            bm_grp_q <= 3'd0;
            state_q  <= RS_DEC_SOLVE_OMEGA;
          end else begin
            bm_grp_q <= bm_grp_q + 3'd1;
          end
        end

        RS_DEC_SOLVE_OMEGA: begin
          // Compute Forney Error Evaluator Polynomial Omega(z) = S(z) * Lambda(z) mod z^16
          for (int i = 0; i < 16; i++) begin
            logic [7:0] acc;
            acc = 8'd0;
            for (int j = 0; j < 16; j++) begin
              if (j <= i) begin
                acc = acc ^ gf_mul(syn_q[i - j], bm_c_q[j]);
              end
            end
            omg_q[i] <= acc;
          end
          out_idx_q <= 16'd0;
          state_q   <= RS_DEC_EMIT;
        end

        RS_DEC_EMIT: begin
          if (!m_axis_tvalid || m_axis_tready) begin
            if (out_idx_q == info_len_q) begin
              rs_cw_done_pulse <= 1'b1;
              state_q          <= RS_DEC_RECV;
            end else begin
              logic [15:0] d16;
              logic [7:0]  d8;
              logic [7:0]  z_val;
              logic [7:0]  eval_lam;
              logic [7:0]  eval_omg;
              logic [7:0]  z_lam_deriv;
              logic [7:0]  raw_b, corr_b;

              d16   = (total_cw_len_q - 16'd1) - out_idx_q;
              d8    = d16[7:0];
              raw_b = info_buf[out_idx_q[7:0]];
              z_val = Z_INV_POW_LUT[d8];

              // Horner evaluation of Lambda(z_val), Omega(z_val), and z_val * Lambda'(z_val)
              eval_lam = 8'd0;
              for (int i = 16; i >= 0; i--) begin
                eval_lam = gf_mul(eval_lam, z_val) ^ bm_c_q[i];
              end

              eval_omg = 8'd0;
              for (int i = 15; i >= 0; i--) begin
                eval_omg = gf_mul(eval_omg, z_val) ^ omg_q[i];
              end

              z_lam_deriv = 8'd0;
              for (int i = 15; i >= 1; i -= 2) begin
                z_lam_deriv = gf_mul(gf_mul(z_lam_deriv, z_val), z_val) ^ bm_c_q[i];
              end
              z_lam_deriv = gf_mul(z_lam_deriv, z_val);

              if (!syn_clean_q && (eval_lam == 8'h00) && (z_lam_deriv != 8'h00)) begin
                logic [7:0] y_val;
                logic [7:0] err_std;
                y_val      = gf_mul(eval_omg, GF_INV_LUT[z_lam_deriv]);
                err_std    = gf_mul(y_val, R0_INV_POW_LUT[d8]);
                corr_b     = raw_b ^ std_to_dual(err_std);
                corr_cnt_q <= corr_cnt_q + 16'd1;
              end else begin
                corr_b = raw_b;
              end

              m_axis_tvalid <= 1'b1;
              m_axis_tdata  <= corr_b;
              m_axis_tlast  <= ((out_idx_q + 16'd1) == info_len_q);
              out_idx_q     <= out_idx_q + 16'd1;
            end
          end
        end

        default: state_q <= RS_DEC_RECV;
      endcase
    end
  end

endmodule : ccsds_dl_rs255_223_dec
