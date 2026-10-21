// =============================================================================
// File Name   : ccsds_asm_correlator.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog (Synthesizable)
// Description : Uplink & Crosslink Soft-LLR / Hard-Bit Synchronization
//               Correlator (RX2 in signal flow chain, Audit R1-2):
//                 - Correlates against 16-bit CLTU Start (16'hEB90), 64-bit
//                   Short-LDPC Start (64'h0347_76C7_2728_95B0), 24-bit Prox-1
//                   ASM (24'hFAF320), or 32-bit TM ASM (32'h1ACFFC1D).
//                 - Resolves 0/180 deg BPSK phase inversion ambiguity by
//                   checking Hamming distance against both pattern P and ~P.
//                 - Establishes exact codeblock boundary BEFORE BCH(63,56) or
//                   Short-Block LDPC decoding.
// =============================================================================
`timescale 1ns / 1ps

module ccsds_asm_correlator
  import ccsds_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // Configuration & Frame Termination Feedback
  input  logic [1:0]  sync_mode,            // 0=CLTU 16b (0xEB90), 1=LDPC 64b, 2=Prox1 24b, 3=TM 32b
  input  logic [2:0]  hamming_thresh,       // Allowed bit errors in sync marker (0..4)
  input  logic        tail_or_abort_pulse,  // Returns correlator to SEARCH state

  // Incoming Symbol Stream from Demodulator / Viterbi (clk_tc_safe)
  input  logic signed [3:0] sym_llr_in,     // +7 = strong '0', -7 = strong '1'
  input  logic              sym_valid_in,

  // Codeblock-Aligned Output Stream to BCH / Short-LDPC Decoder
  output logic signed [3:0] cb_llr_out,
  output logic              cb_hard_bit_out,
  output logic              cb_start_pulse, // Asserts on first bit following sync marker
  output logic              cb_valid_out,
  output logic              sync_locked,
  output logic              phase_inverted
);

  logic [63:0] shift_reg_q;
  logic [6:0]  bit_fill_cnt_q;
  logic        locked_q;
  logic        inverted_q;
  logic        start_pending_q;

  logic        hard_bit_in;
  logic [63:0] next_shift;
  logic        match_norm;
  logic        match_inv;

  // Hard bit slice: negative LLR (< 0) represents logic '1', non-negative represents logic '0'
  assign hard_bit_in = sym_llr_in[3];
  assign next_shift  = {shift_reg_q[62:0], hard_bit_in};

  function automatic logic [6:0] popcount64(input logic [63:0] v);
    logic [6:0] cnt;
    cnt = 7'd0;
    for (int i = 0; i < 64; i++) begin
      cnt = cnt + {6'd0, v[i]};
    end
    return cnt;
  endfunction

  always_comb begin
    logic [63:0] diff_norm;
    logic [63:0] diff_inv;
    logic [6:0]  dist_norm;
    logic [6:0]  dist_inv;
    logic [6:0]  req_bits;

    diff_norm = 64'd0;
    diff_inv  = 64'd0;
    req_bits  = 7'd16;

    unique case (sync_mode)
      2'd0: begin // 16-bit CLTU Start Sequence (16'hEB90)
        req_bits  = 7'd16;
        diff_norm = {48'd0, next_shift[15:0] ^ CLTU_START_SEQ_16B};
        diff_inv  = {48'd0, next_shift[15:0] ^ (~CLTU_START_SEQ_16B)};
      end
      2'd1: begin // 64-bit Short Uplink LDPC Start Sequence
        req_bits  = 7'd64;
        diff_norm = next_shift ^ UL_LDPC_START_SEQ_64B;
        diff_inv  = next_shift ^ (~UL_LDPC_START_SEQ_64B);
      end
      2'd2: begin // 24-bit Proximity-1 ASM (24'hFAF320)
        req_bits  = 7'd24;
        diff_norm = {40'd0, next_shift[23:0] ^ PROX1_ASM_24B};
        diff_inv  = {40'd0, next_shift[23:0] ^ (~PROX1_ASM_24B)};
      end
      default: begin // 32-bit TM/AOS/USLP ASM (32'h1ACFFC1D)
        req_bits  = 7'd32;
        diff_norm = {32'd0, next_shift[31:0] ^ DL_ASM_TM_RS_CONV_32B};
        diff_inv  = {32'd0, next_shift[31:0] ^ (~DL_ASM_TM_RS_CONV_32B)};
      end
    endcase

    dist_norm  = popcount64(diff_norm);
    dist_inv   = popcount64(diff_inv);
    match_norm = ((bit_fill_cnt_q + 7'd1) >= req_bits) && (dist_norm <= {4'd0, hamming_thresh});
    match_inv  = ((bit_fill_cnt_q + 7'd1) >= req_bits) && (dist_inv  <= {4'd0, hamming_thresh});
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      shift_reg_q     <= 64'd0;
      bit_fill_cnt_q  <= 7'd0;
      locked_q        <= 1'b0;
      inverted_q      <= 1'b0;
      start_pending_q <= 1'b0;
    end else if (tail_or_abort_pulse) begin
      shift_reg_q     <= 64'd0;
      bit_fill_cnt_q  <= 7'd0;
      locked_q        <= 1'b0;
      inverted_q      <= 1'b0;
      start_pending_q <= 1'b0;
    end else if (sym_valid_in) begin
      shift_reg_q <= next_shift;
      if (bit_fill_cnt_q < 7'd64) begin
        bit_fill_cnt_q <= bit_fill_cnt_q + 7'd1;
      end

      if (!locked_q) begin
        if (match_norm || match_inv) begin
          locked_q        <= 1'b1;
          inverted_q      <= match_inv && !match_norm;
          start_pending_q <= 1'b1;
        end
      end else begin
        start_pending_q <= 1'b0;
      end
    end
  end

  assign cb_llr_out      = inverted_q ? (-sym_llr_in) : sym_llr_in;
  assign cb_hard_bit_out = inverted_q ? (~hard_bit_in) : hard_bit_in;
  assign cb_start_pulse  = locked_q && sym_valid_in && start_pending_q;
  assign cb_valid_out    = locked_q && sym_valid_in;
  assign sync_locked     = locked_q;
  assign phase_inverted  = inverted_q;

endmodule : ccsds_asm_correlator
