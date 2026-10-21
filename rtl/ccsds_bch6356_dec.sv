// =============================================================================
// File Name   : ccsds_bch6356_dec.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog (Synthesizable)
// Description : Uplink Expurgated BCH(63,56) SEC-DED Syndrome Decoder, CLTU
//               Tail Detector, and TC De-Randomizer (RX3 in signal flow chain,
//               CCSDS 231.0-B-4):
//                 - Accumulates 64-bit codeblocks after 0xEB90 sync lock.
//                 - Detects 64-bit CLTU Tail (0xC5..79 or 0x55..AA).
//                 - Corrects any single-bit error across all 63 BCH bits,
//                   rejects double-bit errors with fec_abort, and de-randomizes
//                   the 7 information octets per codeblock via h_TC(x) (8'h5F).
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

  logic [63:0] cb_shift_q;
  logic [5:0]  bit_cnt_q;
  logic [55:0] tx_info_buf_q;
  logic [2:0]  out_byte_idx_q;
  logic        streaming_bytes_q;
  logic [7:0]  tc_lfsr_q;

  logic [63:0] cb_candidate;

  assign cb_candidate = {cb_shift_q[62:0], cb_hard_bit_in};

  // Compute 7-bit BCH(63,56) syndrome modulo g(x) = x^7 + x^6 + x^2 + 1 (7'h45)
  function automatic logic [6:0] calc_bch_syndrome(input logic [62:0] cw63);
    logic [6:0] rem;
    logic       fb;
    rem = 7'd0;
    for (int i = 62; i >= 0; i--) begin
      fb  = rem[6] ^ cw63[i];
      rem = {rem[5:0], 1'b0};
      if (fb) begin
        rem = rem ^ POLY_BCH6356;
      end
    end
    return rem;
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

  // Combinational decode of a completed 64-bit codeblock
  logic        is_tail_seq;
  logic [62:0] cw63_uninv;
  logic [6:0]  syndrome;
  logic        odd_wt;
  logic [55:0] corrected_info56;
  logic        dec_single_err;
  logic        dec_uncorr_abort;

  always_comb begin
    is_tail_seq      = (cb_candidate == CLTU_TAIL_SEQ_BCH_C5) ||
                       (cb_candidate == CLTU_TAIL_SEQ_LDPC_55);
    cw63_uninv       = {cb_candidate[63:8], cb_candidate[7:1] ^ 7'h7F};
    syndrome         = calc_bch_syndrome(cw63_uninv);
    odd_wt           = ^cw63_uninv;
    corrected_info56 = cw63_uninv[62:7];
    dec_single_err   = 1'b0;
    dec_uncorr_abort = 1'b0;

    if (!is_tail_seq) begin
      if (syndrome == 7'd0) begin
        dec_single_err   = 1'b0;
        dec_uncorr_abort = 1'b0;
      end else if (odd_wt) begin
        // Single-bit error: find matching single-bit syndrome across positions 0..62
        logic found_pos;
        found_pos = 1'b0;
        for (int bpos = 0; bpos < 63; bpos++) begin
          logic [62:0] unit_vec;
          unit_vec = 63'd1 << (62 - bpos);
          if (calc_bch_syndrome(unit_vec) == syndrome) begin
            found_pos = 1'b1;
            if (bpos < 56) begin
              corrected_info56[55 - bpos] = ~cw63_uninv[62 - bpos];
            end
          end
        end
        if (found_pos) begin
          dec_single_err = 1'b1;
        end else begin
          dec_uncorr_abort = 1'b1;
        end
      end else begin
        // Non-zero syndrome with even weight -> double-bit uncorrectable error
        dec_uncorr_abort = 1'b1;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cb_shift_q             <= 64'd0;
      bit_cnt_q              <= 6'd0;
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
        bit_cnt_q  <= 6'd1;
        cb_shift_q <= {63'd0, cb_hard_bit_in};
        tc_lfsr_q  <= LFSR_INIT_ALL_ONES;
      end else if (cb_valid_in) begin
        cb_shift_q <= cb_candidate;
        if (bit_cnt_q == 6'd63) begin
          bit_cnt_q <= 6'd0;
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
          bit_cnt_q <= bit_cnt_q + 6'd1;
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
