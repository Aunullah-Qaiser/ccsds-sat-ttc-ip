// =============================================================================
// File Name   : ccsds_bch6356_dec.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog (Synthesizable)
// Description : Uplink Expurgated BCH(63,56) SEC-DED Syndrome Decoder, CLTU
//               Tail Detector, and TC De-Randomizer (RX3 in signal flow chain,
//               CCSDS 231.0-B-4):
//                 - Incremental 1-bit-per-cycle registered syndrome LFSR
//                   (syn_running_q) and parity accumulator (odd_wt_running_q)
//                   across bits 0..62 so bit 63 decodes directly from flip-
//                   flops in 2 LUT levels (Fix CR-13: cuts 10-level 9.297 ns
//                   path down to <2.5 ns / >350 MHz on Kintex UltraScale).
// =============================================================================
`timescale 1ns / 1ps

module ccsds_bch6356_dec
  import ccsds_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  input  logic        tc_derand_en,         // 1 = De-randomize 56-bit info blocks via h_TC(x)

  // Input from ccsds_asm_correlator (RX2)
  input  logic        cb_hard_bit_in,
  input  logic        cb_start_pulse,
  input  logic        cb_valid_in,

  // Feedback to ccsds_asm_correlator to return to SEARCH on tail or abort
  output logic        cltu_ended_pulse,
  output logic        bch_single_err_pulse,
  output logic        bch_double_abort_pulse,

  // 8-bit AXI4-Stream De-Randomized Information Octet Output to RX4 Deframer
  output logic [7:0]  m_axis_tdata,
  output logic        m_axis_tvalid,
  input  logic        m_axis_tready,
  output logic        m_axis_tlast,
  output logic        m_axis_tabort
);

  // Precomputed 7-bit BCH(63,56) Single-Bit Error Syndromes for bpos = 0..62
  localparam logic [6:0] BCH_SYN_LUT [0:62] = '{
    7'h40, 7'h20, 7'h10, 7'h08, 7'h04, 7'h02, 7'h01, 7'h62,
    7'h31, 7'h7A, 7'h3D, 7'h7C, 7'h3E, 7'h1F, 7'h6D, 7'h54,
    7'h2A, 7'h15, 7'h68, 7'h34, 7'h1A, 7'h0D, 7'h64, 7'h32,
    7'h19, 7'h6E, 7'h37, 7'h79, 7'h5E, 7'h2F, 7'h75, 7'h58,
    7'h2C, 7'h16, 7'h0B, 7'h67, 7'h51, 7'h4A, 7'h25, 7'h70,
    7'h38, 7'h1C, 7'h0E, 7'h07, 7'h61, 7'h52, 7'h29, 7'h76,
    7'h3B, 7'h7F, 7'h5D, 7'h4C, 7'h26, 7'h13, 7'h6B, 7'h57,
    7'h49, 7'h46, 7'h23, 7'h73, 7'h5B, 7'h4F, 7'h45
  };

  function automatic logic is_valid_bch_syn(input logic [6:0] syn);
    logic hit;
    begin
      hit = 1'b0;
      for (int i = 0; i < 63; i++) begin
        if (syn == BCH_SYN_LUT[i]) hit = 1'b1;
      end
      return hit;
    end
  endfunction

  // Step 8 bits of right-shifting TC LFSR (8'h5F)
  function automatic void step_tc_lfsr_byte(
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
      fb    = ^(sr & LFSR_TC_TAP_MASK);
      sr    = {fb, sr[7:1]};
    end
    sr_out  = sr;
    pn_byte = b_val;
  endfunction

  logic [63:0] cb_shift_q;
  logic [5:0]  bit_cnt_q;
  logic [6:0]  syn_running_q;
  logic        odd_wt_running_q;
  logic [55:0] tx_info_buf_q;
  logic [2:0]  out_byte_idx_q;
  logic        streaming_bytes_q;
  logic [7:0]  tc_lfsr_q;

  logic [63:0] cb_candidate;
  logic        is_tail_seq;
  logic        bit_uninv;
  logic        syn_fb;
  logic [55:0] corrected_info56;
  logic        dec_single_err;
  logic        dec_uncorr_abort;

  assign cb_candidate = {cb_shift_q[62:0], cb_hard_bit_in};

  always_comb begin
    is_tail_seq = (cb_candidate == CLTU_TAIL_SEQ_BCH_C5) ||
                  (cb_candidate == CLTU_TAIL_SEQ_LDPC_55);

    bit_uninv = (bit_cnt_q >= 6'd56) ? ~cb_hard_bit_in : cb_hard_bit_in;
    syn_fb    = syn_running_q[6] ^ bit_uninv;

    // On bit_cnt_q == 63, syn_running_q and odd_wt_running_q are already
    // registered in flip-flops (0 logic levels from cb_shift_q!)
    for (int bpos = 0; bpos < 56; bpos++) begin
      corrected_info56[55 - bpos] = cb_shift_q[62 - bpos] ^
                                    (odd_wt_running_q && (syn_running_q == BCH_SYN_LUT[bpos]));
    end

    dec_single_err   = 1'b0;
    dec_uncorr_abort = 1'b0;
    if (!is_tail_seq) begin
      if (syn_running_q == 7'd0) begin
        dec_single_err   = 1'b0;
        dec_uncorr_abort = 1'b0;
      end else if (odd_wt_running_q && is_valid_bch_syn(syn_running_q)) begin
        dec_single_err   = 1'b1;
      end else begin
        dec_uncorr_abort = 1'b1;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cb_shift_q             <= 64'd0;
      bit_cnt_q              <= 6'd0;
      syn_running_q          <= 7'd0;
      odd_wt_running_q       <= 1'b0;
      tx_info_buf_q          <= 56'd0;
      out_byte_idx_q         <= 3'd0;
      streaming_bytes_q      <= 1'b0;
      tc_lfsr_q              <= LFSR_INIT_ALL_ONES;
      cltu_ended_pulse       <= 1'b0;
      bch_single_err_pulse   <= 1'b0;
      bch_double_abort_pulse <= 1'b0;
      m_axis_tdata           <= 8'h00;
      m_axis_tvalid          <= 1'b0;
      m_axis_tlast           <= 1'b0;
      m_axis_tabort          <= 1'b0;
    end else begin
      cltu_ended_pulse       <= 1'b0;
      bch_single_err_pulse   <= 1'b0;
      bch_double_abort_pulse <= 1'b0;

      if (cb_start_pulse) begin
        bit_cnt_q        <= 6'd1;
        cb_shift_q       <= {63'd0, cb_hard_bit_in};
        syn_running_q    <= cb_hard_bit_in ? POLY_BCH6356 : 7'h00;
        odd_wt_running_q <= cb_hard_bit_in;
        tc_lfsr_q        <= LFSR_INIT_ALL_ONES;
      end else if (cb_valid_in) begin
        cb_shift_q <= cb_candidate;
        if (bit_cnt_q == 6'd63) begin
          bit_cnt_q        <= 6'd0;
          syn_running_q    <= 7'd0;
          odd_wt_running_q <= 1'b0;
          if (is_tail_seq) begin
            cltu_ended_pulse <= 1'b1;
            m_axis_tvalid    <= 1'b1;
            m_axis_tlast     <= 1'b1;
            m_axis_tabort    <= 1'b0;
            m_axis_tdata     <= CLTU_IDLE_FILL_OCTET;
          end else if (dec_uncorr_abort) begin
            cltu_ended_pulse       <= 1'b1;
            bch_double_abort_pulse <= 1'b1;
            m_axis_tvalid          <= 1'b1;
            m_axis_tlast           <= 1'b1;
            m_axis_tabort          <= 1'b1;
            m_axis_tdata           <= 8'h00;
          end else begin
            logic [7:0] nxt_sr, pn_b;
            bch_single_err_pulse <= dec_single_err;
            step_tc_lfsr_byte(tc_lfsr_q, nxt_sr, pn_b);
            m_axis_tdata      <= tc_derand_en ? (corrected_info56[55:48] ^ pn_b) : corrected_info56[55:48];
            m_axis_tvalid     <= 1'b1;
            m_axis_tlast      <= 1'b0;
            m_axis_tabort     <= 1'b0;
            tc_lfsr_q         <= tc_derand_en ? nxt_sr : tc_lfsr_q;
            tx_info_buf_q     <= {corrected_info56[47:0], 8'h00};
            out_byte_idx_q    <= 3'd1;
            streaming_bytes_q <= 1'b1;
          end
        end else begin
          bit_cnt_q        <= bit_cnt_q + 6'd1;
          syn_running_q    <= {syn_running_q[5:0], 1'b0} ^ (syn_fb ? POLY_BCH6356 : 7'h00);
          odd_wt_running_q <= odd_wt_running_q ^ bit_uninv;
        end
      end

      // Stream the remaining 6 octets of the 7-octet decoded BCH information block
      if (streaming_bytes_q && m_axis_tready) begin
        logic [7:0] nxt_sr, pn_b;
        step_tc_lfsr_byte(tc_lfsr_q, nxt_sr, pn_b);
        m_axis_tdata  <= tc_derand_en ? (tx_info_buf_q[55:48] ^ pn_b) : tx_info_buf_q[55:48];
        m_axis_tvalid <= 1'b1;
        m_axis_tlast  <= 1'b0;
        m_axis_tabort <= 1'b0;
        tc_lfsr_q     <= tc_derand_en ? nxt_sr : tc_lfsr_q;
        tx_info_buf_q <= {tx_info_buf_q[47:0], 8'h00};
        if (out_byte_idx_q == 3'd6) begin
          streaming_bytes_q <= 1'b0;
        end else begin
          out_byte_idx_q <= out_byte_idx_q + 3'd1;
        end
      end else if (m_axis_tvalid && m_axis_tready && !streaming_bytes_q) begin
        m_axis_tvalid <= 1'b0;
        m_axis_tlast  <= 1'b0;
        m_axis_tabort <= 1'b0;
      end
    end
  end

endmodule : ccsds_bch6356_dec
