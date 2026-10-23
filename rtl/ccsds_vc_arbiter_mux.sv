// =============================================================================
// File Name   : ccsds_vc_arbiter_mux.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog (Synthesizable)
// Description : Downlink Telemetry Non-Mutating Space Packet Length Validator,
//               Virtual Channel Arbiter, Closed-Form Cycle-0 First Header
//               Pointer (FHP) Segmenter, and Only-Idle-Data (OID) Frame
//               Generator (TX1 & TX2, CCSDS 133.0-B-2 & 132.0-B-3, Audit R1-6,
//               R2-5, R3-3).
// =============================================================================
`timescale 1ns / 1ps

module ccsds_vc_arbiter_mux
  import ccsds_pkg::*;
#(
  parameter int unsigned NUM_VC = DEFAULT_NUM_VC
) (
  input  logic         clk,
  input  logic         rst_n,

  input  logic [10:0]  tfdf_byte_len_cfg,
  input  logic         request_next_frame,

  input  logic [7:0]   s_axis_pkt_tdata,
  input  logic [2:0]   s_axis_pkt_vcid,
  input  logic         s_axis_pkt_tvalid,
  output logic         s_axis_pkt_tready,
  input  logic         s_axis_pkt_tlast,

  output logic [7:0]   m_axis_tfdf_tdata,
  output logic         m_axis_tfdf_tvalid,
  input  logic         m_axis_tfdf_tready,
  output logic         m_axis_tfdf_tlast,
  output logic [2:0]   m_axis_tfdf_vcid,
  output logic [10:0]  m_axis_tfdf_fhp,
  output logic         m_axis_tfdf_is_oid,

  output logic         irq_obc_pkt_len_err
);

  logic [7:0]  pkt_buf [0:2047];
  logic [10:0] wr_spec_ptr_q;
  logic [10:0] wr_commit_ptr_q;
  logic [10:0] rd_ptr_q;

  logic [15:0] cur_pkt_byte_cnt_q;
  logic [15:0] hdr_expected_len_q;
  logic [2:0]  active_vcid_q;

  logic        emitting_frame_q;
  logic [10:0] tfdf_idx_q;
  logic [10:0] rem_in_cur_pkt_q;
  logic [10:0] latched_fhp_q;
  logic        emitting_oid_q;

  logic [10:0] committed_bytes;
  assign committed_bytes   = wr_commit_ptr_q - rd_ptr_q;
  assign s_axis_pkt_tready = ((wr_spec_ptr_q - rd_ptr_q) < 11'd2040);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_spec_ptr_q       <= 11'd0;
      wr_commit_ptr_q     <= 11'd0;
      rd_ptr_q            <= 11'd0;
      cur_pkt_byte_cnt_q  <= 16'd0;
      hdr_expected_len_q  <= 16'd0;
      active_vcid_q       <= 3'd0;
      emitting_frame_q    <= 1'b0;
      tfdf_idx_q          <= 11'd0;
      rem_in_cur_pkt_q    <= 11'd0;
      latched_fhp_q       <= TM_FHP_OID_IDLE_FRAME;
      emitting_oid_q      <= 1'b0;
      m_axis_tfdf_tdata   <= 8'h00;
      m_axis_tfdf_tvalid  <= 1'b0;
      m_axis_tfdf_tlast   <= 1'b0;
      m_axis_tfdf_vcid    <= 3'd0;
      m_axis_tfdf_fhp     <= TM_FHP_OID_IDLE_FRAME;
      m_axis_tfdf_is_oid  <= 1'b1;
      irq_obc_pkt_len_err <= 1'b0;
    end else begin
      irq_obc_pkt_len_err <= 1'b0;

      // 1. Non-Mutating OBC Space Packet Ingress Length Validator (Audit R3-3)
      if (s_axis_pkt_tvalid && s_axis_pkt_tready) begin
        pkt_buf[wr_spec_ptr_q] <= s_axis_pkt_tdata;
        if (cur_pkt_byte_cnt_q == 16'd0) begin
          active_vcid_q <= s_axis_pkt_vcid;
        end else if (cur_pkt_byte_cnt_q == 16'd4) begin
          hdr_expected_len_q[15:8] <= s_axis_pkt_tdata;
        end else if (cur_pkt_byte_cnt_q == 16'd5) begin
          hdr_expected_len_q[7:0]  <= s_axis_pkt_tdata;
        end

        if (s_axis_pkt_tlast) begin
          logic [15:0] actual_total;
          logic [15:0] expected_total;
          actual_total   = cur_pkt_byte_cnt_q + 16'd1;
          expected_total = ((cur_pkt_byte_cnt_q == 16'd5) ?
                            {hdr_expected_len_q[15:8], s_axis_pkt_tdata} : hdr_expected_len_q) + 16'd7;
          if ((actual_total >= 16'd7) && (actual_total == expected_total)) begin
            wr_spec_ptr_q   <= wr_spec_ptr_q + 11'd1;
            wr_commit_ptr_q <= wr_spec_ptr_q + 11'd1;
          end else begin
            wr_spec_ptr_q       <= wr_commit_ptr_q;
            irq_obc_pkt_len_err <= 1'b1;
          end
          cur_pkt_byte_cnt_q <= 16'd0;
        end else begin
          wr_spec_ptr_q      <= wr_spec_ptr_q + 11'd1;
          cur_pkt_byte_cnt_q <= cur_pkt_byte_cnt_q + 16'd1;
        end
      end

      // 2. Closed-Form Cycle-0 FHP Calculation & TFDF Segmenter (TX2)
      if (!emitting_frame_q) begin
        if (m_axis_tfdf_tready) begin
          m_axis_tfdf_tvalid <= 1'b0;
          m_axis_tfdf_tlast  <= 1'b0;
        end
        if (request_next_frame && (!m_axis_tfdf_tvalid || m_axis_tfdf_tready)) begin
          emitting_frame_q <= 1'b1;
          tfdf_idx_q       <= 11'd0;
          if ((committed_bytes == 11'd0) && (rem_in_cur_pkt_q == 11'd0)) begin
            emitting_oid_q <= 1'b1;
            latched_fhp_q  <= TM_FHP_OID_IDLE_FRAME;
          end else begin
            emitting_oid_q <= 1'b0;
            if (rem_in_cur_pkt_q < tfdf_byte_len_cfg) begin
              latched_fhp_q <= rem_in_cur_pkt_q;
            end else begin
              latched_fhp_q <= TM_FHP_NO_PKT_START;
            end
          end
        end
      end else if (!m_axis_tfdf_tvalid || m_axis_tfdf_tready) begin
        m_axis_tfdf_tvalid <= 1'b1;
        m_axis_tfdf_vcid   <= active_vcid_q;
        m_axis_tfdf_is_oid <= emitting_oid_q;
        m_axis_tfdf_fhp    <= latched_fhp_q;
        m_axis_tfdf_tlast  <= ((tfdf_idx_q + 11'd1) == tfdf_byte_len_cfg);

        if (emitting_oid_q || ((committed_bytes == 11'd0) && (rem_in_cur_pkt_q == 11'd0))) begin
          m_axis_tfdf_tdata <= 8'hAA;
        end else begin
          m_axis_tfdf_tdata <= pkt_buf[rd_ptr_q];
          rd_ptr_q          <= rd_ptr_q + 11'd1;
          if (rem_in_cur_pkt_q == 11'd0) begin
            logic [15:0] pkt_c_len;
            pkt_c_len        = {pkt_buf[rd_ptr_q + 11'd4], pkt_buf[rd_ptr_q + 11'd5]};
            rem_in_cur_pkt_q <= pkt_c_len[10:0] + 11'd6;
          end else begin
            rem_in_cur_pkt_q <= rem_in_cur_pkt_q - 11'd1;
          end
        end

        if ((tfdf_idx_q + 11'd1) == tfdf_byte_len_cfg) begin
          emitting_frame_q <= 1'b0;
        end else begin
          tfdf_idx_q <= tfdf_idx_q + 11'd1;
        end
      end
    end
  end

endmodule : ccsds_vc_arbiter_mux
