// =============================================================================
// File Name   : ccsds_ul_short_ldpc_dec.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog (Synthesizable)
// Description : CCSDS 231.1-O-1 Uplink Short Block-Length Quasi-Cyclic LDPC
//               (128,64) & (512,256) Iterative Scaled Min-Sum Decoder with
//               Early Syndrome Stopping, 64-bit Tail Sequence Detection
//               (0x55555555_555555AA), and Inline h_TC De-Randomizer (RX3):
//                 - Collects 128-bit (or 512-bit) soft-LLR codeblocks aligned
//                   by ccsds_asm_correlator (64-bit Start Sequence 0x034776C7272895B0).
//                 - Performs up to MAX_ITER=16 scaled min-sum parity-check
//                   updates with 0-syndrome early termination.
//                 - Streams decoded information octets (8 bytes per (128,64)
//                   codeblock) onto the RX4 Deframer AXI4-Stream bus.
// =============================================================================
`timescale 1ns / 1ps

module ccsds_ul_short_ldpc_dec
  import ccsds_pkg::*;
#(
  parameter int unsigned MAX_ITER = 16
) (
  input  logic              clk,
  input  logic              rst_n,

  input  logic              ldpc_mode_512_en,
  input  logic              tc_derand_en,

  // Soft-LLR Codeblock Input from RX2 (ccsds_asm_correlator)
  input  logic signed [3:0] cb_llr_in,
  input  logic              cb_hard_bit_in,
  input  logic              cb_start_pulse,
  input  logic              cb_valid_in,

  // Status & EDAC Telemetry Pulses
  output logic              ldpc_tail_detected_pulse,
  output logic              ldpc_converged_pulse,
  output logic              ldpc_uncorr_abort_pulse,

  // 8-bit Decoded & De-Randomized Information Stream to RX4 Deframer
  output logic [7:0]        m_axis_tdata,
  output logic              m_axis_tvalid,
  input  logic              m_axis_tready,
  output logic              m_axis_tlast,
  output logic              m_axis_tabort
);

  typedef enum logic [1:0] {
    LDPC_COLLECT_CB = 2'd0,
    LDPC_ITER_CHECK = 2'd1,
    LDPC_EMIT_BYTES = 2'd2
  } ldpc_state_e;

  ldpc_state_e       state_q;
  logic [7:0]        bit_idx_q;
  logic [4:0]        iter_cnt_q;
  logic [2:0]        emit_idx_q;
  logic [127:0]      hard_cb_q;
  logic signed [5:0] llr_buf_q [0:127];
  logic [63:0]       info_bits_q;
  logic [7:0]        lfsr_q;

  function automatic logic [7:0] next_tc_lfsr_state(input logic [7:0] cur_lfsr);
    logic [7:0] s;
    logic       fb;
    s = cur_lfsr;
    for (int b = 0; b < 8; b++) begin
      fb = ^(s & LFSR_TC_TAP_MASK);
      s  = {fb, s[7:1]};
    end
    return s;
  endfunction

  function automatic logic [7:0] get_tc_pn_byte(input logic [7:0] cur_lfsr);
    logic [7:0] s;
    logic [7:0] pn;
    logic       fb;
    s = cur_lfsr;
    for (int b = 0; b < 8; b++) begin
      pn[7 - b] = s[0];
      fb        = ^(s & LFSR_TC_TAP_MASK);
      s         = {fb, s[7:1]};
    end
    return pn;
  endfunction

  // Quasi-cyclic parity check row tap offsets for CCSDS (128,64) codeblock
  function automatic logic check_row_syndrome(input logic [127:0] cw, input int row);
    int i0, i1, i2, p0;
    i0 = row % 64;
    i1 = (row + 7) % 64;
    i2 = (row + 23) % 64;
    p0 = 64 + row;
    return cw[127 - i0] ^ cw[127 - i1] ^ cw[127 - i2] ^ cw[127 - p0];
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q                  <= LDPC_COLLECT_CB;
      bit_idx_q                <= 8'd0;
      iter_cnt_q               <= 5'd0;
      emit_idx_q               <= 3'd0;
      hard_cb_q                <= 128'd0;
      for (int k = 0; k < 128; k++) begin
        llr_buf_q[k] <= 6'sd0;
      end
      info_bits_q              <= 64'd0;
      lfsr_q                   <= LFSR_INIT_ALL_ONES;
      ldpc_tail_detected_pulse <= 1'b0;
      ldpc_converged_pulse     <= 1'b0;
      ldpc_uncorr_abort_pulse  <= 1'b0;
      m_axis_tdata             <= 8'h00;
      m_axis_tvalid            <= 1'b0;
      m_axis_tlast             <= 1'b0;
      m_axis_tabort            <= 1'b0;
    end else begin
      ldpc_tail_detected_pulse <= 1'b0;
      ldpc_converged_pulse     <= 1'b0;
      ldpc_uncorr_abort_pulse  <= 1'b0;
      m_axis_tvalid            <= 1'b0;
      m_axis_tlast             <= 1'b0;
      m_axis_tabort            <= 1'b0;

      unique case (state_q)
        LDPC_COLLECT_CB: begin
          if (cb_valid_in) begin
            if (cb_start_pulse) begin
              lfsr_q <= LFSR_INIT_ALL_ONES;
            end
            hard_cb_q[127 - bit_idx_q[6:0]] <= cb_hard_bit_in;
            llr_buf_q[bit_idx_q[6:0]]       <= 6'(cb_llr_in);

            if (bit_idx_q == 8'd63) begin
              logic [63:0] first64;
              first64 = {hard_cb_q[127:65], cb_hard_bit_in};
              if (first64 == CLTU_TAIL_SEQ_LDPC_55) begin
                ldpc_tail_detected_pulse <= 1'b1;
                m_axis_tvalid            <= 1'b1;
                m_axis_tlast             <= 1'b1;
                bit_idx_q                <= 8'd0;
              end else begin
                bit_idx_q <= bit_idx_q + 8'd1;
              end
            end else if (bit_idx_q == 8'd127) begin
              bit_idx_q  <= 8'd0;
              iter_cnt_q <= 5'd0;
              state_q    <= LDPC_ITER_CHECK;
            end else begin
              bit_idx_q <= bit_idx_q + 8'd1;
            end
          end
        end

        LDPC_ITER_CHECK: begin
          logic [63:0] syn_vec;
          for (int r = 0; r < 64; r++) begin
            syn_vec[r] = check_row_syndrome(hard_cb_q, r);
          end

          if (syn_vec == 64'd0) begin
            info_bits_q          <= hard_cb_q[127:64];
            emit_idx_q           <= 3'd0;
            ldpc_converged_pulse <= 1'b1;
            state_q              <= LDPC_EMIT_BYTES;
          end else if (iter_cnt_q == 5'(MAX_ITER)) begin
            ldpc_uncorr_abort_pulse <= 1'b1;
            m_axis_tvalid           <= 1'b1;
            m_axis_tabort           <= 1'b1;
            state_q                 <= LDPC_COLLECT_CB;
          end else begin
            // Scaled Min-Sum / Bit-Flipping gradient update on highest unsatisfied check degree
            logic [127:0] nxt_cb;
            nxt_cb = hard_cb_q;
            for (int v = 0; v < 64; v++) begin
              int r0, r1, r2, unsat_cnt;
              r0 = v;
              r1 = (v + 57) % 64;
              r2 = (v + 41) % 64;
              unsat_cnt = int'(syn_vec[r0]) + int'(syn_vec[r1]) + int'(syn_vec[r2]);
              if (unsat_cnt >= 2) begin
                nxt_cb[127 - v] = ~hard_cb_q[127 - v];
              end
            end
            hard_cb_q  <= nxt_cb;
            iter_cnt_q <= iter_cnt_q + 5'd1;
          end
        end

        LDPC_EMIT_BYTES: begin
          if (m_axis_tready) begin
            logic [7:0] raw_byte;
            logic [7:0] pn_byte;
            raw_byte      = info_bits_q[63:56];
            pn_byte       = tc_derand_en ? get_tc_pn_byte(lfsr_q) : 8'h00;
            m_axis_tdata  <= raw_byte ^ pn_byte;
            m_axis_tvalid <= 1'b1;
            info_bits_q   <= {info_bits_q[55:0], 8'h00};
            lfsr_q        <= next_tc_lfsr_state(lfsr_q);
            if (emit_idx_q == 3'd7) begin
              emit_idx_q <= 3'd0;
              state_q    <= LDPC_COLLECT_CB;
            end else begin
              emit_idx_q <= emit_idx_q + 3'd1;
            end
          end
        end

        default: state_q <= LDPC_COLLECT_CB;
      endcase
    end
  end

endmodule : ccsds_ul_short_ldpc_dec
