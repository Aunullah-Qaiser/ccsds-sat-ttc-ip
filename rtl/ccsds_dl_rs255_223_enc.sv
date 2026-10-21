// =============================================================================
// File Name   : ccsds_dl_rs255_223_enc.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog (Synthesizable)
// Description : Spacecraft Downlink Interleaved Dual-Basis Reed-Solomon
//               RS(255,223) Encoder (I in {1..5,8}, Implicit 0-Cycle Virtual
//               Fill Q per Audit R1-6 & R2-6), TM Pseudo-Randomizer (0xA9),
//               32-bit ASM Prepender (32'h1ACFFC1D), and Rate 1/2 K=7
//               Convolutional Encoder (CCSDS 131.0-B-5):
//                 - Zero-initializes all I x 32 parity registers so virtual
//                   fill Q takes 0 clock cycles and never shifts the TM LFSR.
//                 - Converts incoming dual-basis symbols to standard basis,
//                   updates branch c = idx mod I via RS_GEN_POLY_STD[1:32],
//                   and converts the 32 x I parity bytes back to dual basis.
// =============================================================================
`timescale 1ns / 1ps

module ccsds_dl_rs255_223_enc
  import ccsds_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  input  logic [3:0]  interleave_depth_i, // 1, 2, 3, 4, 5, or 8
  input  logic        tm_rand_en,         // 1 = Scramble CADU bytes after ASM with h_TM(x)
  input  logic        conv_enc_en,        // 1 = Enable Rate 1/2 K=7 Convolutional Encoder

  // Transfer Frame Input from TX5 Framer (length K = (223 - Q) * I bytes)
  input  logic [7:0]  s_axis_tdata,
  input  logic        s_axis_tvalid,
  output logic        s_axis_tready,
  input  logic        s_axis_tlast,

  // Encoded CADU Byte Output (ASM + Randomized Message + Randomized RS Parity)
  output logic [7:0]  m_axis_cadu_tdata,
  output logic        m_axis_cadu_tvalid,
  input  logic        m_axis_cadu_tready,
  output logic        m_axis_cadu_tlast,

  // Optional Rate 1/2 K=7 Convolutional Encoded 16-bit Symbol Pair Output
  output logic [15:0] conv_symbols_out,
  output logic        conv_symbols_valid
);

  typedef enum logic [1:0] {
    RS_SEND_ASM    = 2'd0,
    RS_STREAM_DATA = 2'd1,
    RS_SEND_PARITY = 2'd2
  } rs_state_e;

  rs_state_e   state_q;
  logic [1:0]  asm_idx_q;
  logic [2:0]  branch_idx_q;
  logic [4:0]  par_stage_q;
  logic [7:0]  parity_q [0:7][0:31];
  logic [7:0]  tm_lfsr_q;
  logic [5:0]  conv_sr_q;

  // GF(2^8) standard-basis multiplier modulo 9'h187
  function automatic logic [7:0] gf_mul_std(input logic [7:0] a, input logic [7:0] b);
    logic [7:0] p;
    logic [7:0] cur;
    logic       hi;
    p   = 8'h00;
    cur = a;
    for (int i = 0; i < 8; i++) begin
      if (b[i]) begin
        p = p ^ cur;
      end
      hi  = cur[7];
      cur = {cur[6:0], 1'b0};
      if (hi) begin
        cur = cur ^ 8'h87;
      end
    end
    return p;
  endfunction

  // Step 1 octet of TM Pseudo-Randomizer (8'hA9)
  function automatic void step_tm_lfsr_byte(
    input  logic [7:0] sr_in,
    output logic [7:0] sr_out,
    output logic [7:0] pn_byte
  );
    logic [7:0] sr;
    logic [7:0] b_val;
    logic       fb;
    sr    = sr_in;
    b_val = 8'h00;
    for (int b = 0; b < 8; b++) begin
      b_val = {b_val[6:0], sr[0]};
      fb    = ^(sr & LFSR_TM_TAP_MASK);
      sr    = {fb, sr[7:1]};
    end
    sr_out  = sr;
    pn_byte = b_val;
  endfunction

  // Rate 1/2, K=7 Convolutional Encoder for 1 octet (8 input bits -> 16 output symbols)
  function automatic void encode_conv_byte(
    input  logic [5:0]  sr_in,
    input  logic [7:0]  data_in,
    output logic [5:0]  sr_out,
    output logic [15:0] sym16_out
  );
    logic [5:0]  sr;
    logic [15:0] out16;
    logic [6:0]  win;
    logic        c1, c2;
    sr    = sr_in;
    out16 = 16'h0000;
    for (int b = 7; b >= 0; b--) begin
      win   = {data_in[b], sr};
      c1    = ^(win & POLY_CONV_G1);
      c2    = ~(^ (win & POLY_CONV_G2)); // G2 inverted per CCSDS 131.0-B-5 Sec 3.3
      out16 = {out16[13:0], c1, c2};
      sr    = {data_in[b], sr[5:1]};
    end
    sr_out    = sr;
    sym16_out = out16;
  endfunction

  assign s_axis_tready = (state_q == RS_STREAM_DATA) && m_axis_cadu_tready;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q            <= RS_SEND_ASM;
      asm_idx_q          <= 2'd0;
      branch_idx_q       <= 3'd0;
      par_stage_q        <= 5'd0;
      for (int c = 0; c < 8; c++) begin
        for (int k = 0; k < 32; k++) begin
          parity_q[c][k] <= 8'h00;
        end
      end
      tm_lfsr_q          <= LFSR_INIT_ALL_ONES;
      conv_sr_q          <= 6'd0;
      m_axis_cadu_tdata  <= 8'h00;
      m_axis_cadu_tvalid <= 1'b0;
      m_axis_cadu_tlast  <= 1'b0;
      conv_symbols_out   <= 16'h0000;
      conv_symbols_valid <= 1'b0;
    end else if (m_axis_cadu_tready) begin
      m_axis_cadu_tvalid <= 1'b0;
      m_axis_cadu_tlast  <= 1'b0;
      conv_symbols_valid <= 1'b0;

      unique case (state_q)
        RS_SEND_ASM: begin
          // Prepend unscrambled 32-bit Attached Sync Marker (32'h1ACFFC1D) when frame starts
          if ((asm_idx_q != 2'd0) || s_axis_tvalid) begin
            logic [7:0]  asm_byte;
            logic [5:0]  nxt_csr;
            logic [15:0] c_sym;
            asm_byte = DL_ASM_TM_RS_CONV_32B[(3 - asm_idx_q)*8 +: 8];
            m_axis_cadu_tdata  <= asm_byte;
            m_axis_cadu_tvalid <= 1'b1;
            encode_conv_byte(conv_sr_q, asm_byte, nxt_csr, c_sym);
            conv_sr_q          <= nxt_csr;
            conv_symbols_out   <= c_sym;
            conv_symbols_valid <= conv_enc_en;

            if (asm_idx_q == 2'd3) begin
              asm_idx_q    <= 2'd0;
              branch_idx_q <= 3'd0;
              tm_lfsr_q    <= LFSR_INIT_ALL_ONES;
              for (int c = 0; c < 8; c++) begin
                for (int k = 0; k < 32; k++) begin
                  parity_q[c][k] <= 8'h00; // Implicit 0-cycle virtual fill Q (Audit R2-6)
                end
              end
              state_q <= RS_STREAM_DATA;
            end else begin
              asm_idx_q <= asm_idx_q + 2'd1;
            end
          end
        end

        RS_STREAM_DATA: begin
          if (s_axis_tvalid) begin
            logic [7:0]  sym_std, fb;
            logic [7:0]  nxt_sr, pn_b, out_byte;
            logic [5:0]  nxt_csr;
            logic [15:0] c_sym;

            sym_std = gf256_dual_to_std(s_axis_tdata);
            fb      = sym_std ^ parity_q[branch_idx_q][0];

            for (int k = 0; k < 31; k++) begin
              parity_q[branch_idx_q][k] <= parity_q[branch_idx_q][k + 1] ^
                                           gf_mul_std(fb, RS_GEN_POLY_STD[k + 1]);
            end
            parity_q[branch_idx_q][31] <= gf_mul_std(fb, RS_GEN_POLY_STD[32]);

            step_tm_lfsr_byte(tm_lfsr_q, nxt_sr, pn_b);
            out_byte           = tm_rand_en ? (s_axis_tdata ^ pn_b) : s_axis_tdata;
            tm_lfsr_q          <= tm_rand_en ? nxt_sr : tm_lfsr_q;
            m_axis_cadu_tdata  <= out_byte;
            m_axis_cadu_tvalid <= 1'b1;

            encode_conv_byte(conv_sr_q, out_byte, nxt_csr, c_sym);
            conv_sr_q          <= nxt_csr;
            conv_symbols_out   <= c_sym;
            conv_symbols_valid <= conv_enc_en;

            if (s_axis_tlast) begin
              branch_idx_q <= 3'd0;
              par_stage_q  <= 5'd0;
              state_q      <= RS_SEND_PARITY;
            end else if (({1'b0, branch_idx_q} + 4'd1) >= interleave_depth_i) begin
              branch_idx_q <= 3'd0;
            end else begin
              branch_idx_q <= branch_idx_q + 3'd1;
            end
          end
        end

        RS_SEND_PARITY: begin
          logic [7:0]  par_dual, nxt_sr, pn_b, out_byte;
          logic [5:0]  nxt_csr;
          logic [15:0] c_sym;
          logic        last_par;

          par_dual = gf256_std_to_dual(parity_q[branch_idx_q][par_stage_q]);
          step_tm_lfsr_byte(tm_lfsr_q, nxt_sr, pn_b);
          out_byte = tm_rand_en ? (par_dual ^ pn_b) : par_dual;
          tm_lfsr_q <= tm_rand_en ? nxt_sr : tm_lfsr_q;

          last_par = (par_stage_q == 5'd31) &&
                     (({1'b0, branch_idx_q} + 4'd1) >= interleave_depth_i);

          m_axis_cadu_tdata  <= out_byte;
          m_axis_cadu_tvalid <= 1'b1;
          m_axis_cadu_tlast  <= last_par;

          encode_conv_byte(conv_sr_q, out_byte, nxt_csr, c_sym);
          conv_sr_q          <= nxt_csr;
          conv_symbols_out   <= c_sym;
          conv_symbols_valid <= conv_enc_en;

          if (last_par) begin
            branch_idx_q <= 3'd0;
            par_stage_q  <= 5'd0;
            state_q      <= RS_SEND_ASM;
          end else if (({1'b0, branch_idx_q} + 4'd1) >= interleave_depth_i) begin
            branch_idx_q <= 3'd0;
            par_stage_q  <= par_stage_q + 5'd1;
          end else begin
            branch_idx_q <= branch_idx_q + 3'd1;
          end
        end

        default: state_q <= RS_SEND_ASM;
      endcase
    end
  end

endmodule : ccsds_dl_rs255_223_enc
