// =============================================================================
// File Name   : ccsds_pkt_reassembler.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog (Synthesizable)
// Description : CCSDS 133.0-B-2 Space Packet & TC MAP SDU Reassembler (RX7 in
//               Spacecraft Uplink Chain and Downlink EGSE Packet Extractor):
//                 - Collects and validates the 6-octet Space Packet Primary
//                   Header (ccsds_space_pkt_hdr_t) across single or spanning
//                   Transfer Frame Data Fields before emitting any header octets.
//                 - Preserves all user APIDs (0x000..0x7FE) without dropping
//                   Byte 0, while completely stripping Idle Space Packets
//                   (APID == 11'h7FF) and inter-packet idle fill octets (0xE0/0x55).
//                 - Supports First Header Pointer (FHP) resynchronization,
//                   latching `frame_start_pulse` and `frame_fhp_in` across
//                   downstream AXI-Stream backpressure (`m_axis_pkt_tready==0`,
//                   Fix P1-6).
//                 - Fix CR-30 (clk_sys Fmax Optimization): Decouples 48-bit
//                   hdr_shift_q[47:0]/CE from s_axis_tdata idle-byte compare
//                   and eliminates the 17-bit +1 adder on ph.pkt_data_len by
//                   counting rem_body_bytes_q from pkt_data_len down to 0.
// =============================================================================
`timescale 1ns / 1ps

module ccsds_pkt_reassembler
  import ccsds_pkg::*;
(
  input  logic                   clk,
  input  logic                   rst_n,

  input  logic                   fhp_resync_en,
  input  logic [10:0]            frame_fhp_in,
  input  logic                   frame_start_pulse,

  // Input TFDF Payload Stream
  input  logic [7:0]             s_axis_tdata,
  input  logic                   s_axis_tvalid,
  output logic                   s_axis_tready,
  input  logic                   s_axis_tlast,

  // Reassembled Space Packet Output Stream (Idle APID=0x7FF stripped)
  output logic [7:0]             m_axis_pkt_tdata,
  output logic                   m_axis_pkt_tvalid,
  input  logic                   m_axis_pkt_tready,
  output logic                   m_axis_pkt_tlast,
  output ccsds_space_pkt_hdr_t   parsed_pkt_hdr,
  output logic                   pkt_completed_pulse,
  output logic                   idle_pkt_stripped_pulse,
  output logic                   pkt_len_err_pulse
);

  typedef enum logic [1:0] {
    REASM_SKIP_TO_FHP   = 2'd0,
    REASM_COLLECT_HDR   = 2'd1,
    REASM_EMIT_HDR_1_5  = 2'd2,
    REASM_DATA_BODY     = 2'd3
  } reasm_state_e;

  reasm_state_e         state_q;
  logic [47:0]          hdr_shift_q;
  logic [39:0]          hdr_emit_shift_q;
  logic [2:0]           hdr_idx_q;
  logic [15:0]          rem_body_bytes_q;
  logic [10:0]          skip_cnt_q;
  logic                 is_idle_apid_q;
  logic                 fhp_pending_q;
  logic [10:0]          latched_fhp_q;
  ccsds_space_pkt_hdr_t cur_pkt_hdr_q;

  assign s_axis_tready  = m_axis_pkt_tready && (state_q != REASM_EMIT_HDR_1_5);
  assign parsed_pkt_hdr = cur_pkt_hdr_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q                 <= REASM_COLLECT_HDR;
      hdr_shift_q             <= 48'd0;
      hdr_emit_shift_q        <= 40'd0;
      hdr_idx_q               <= 3'd0;
      rem_body_bytes_q        <= 16'd0;
      skip_cnt_q              <= 11'd0;
      is_idle_apid_q          <= 1'b0;
      fhp_pending_q           <= 1'b0;
      latched_fhp_q           <= 11'd0;
      cur_pkt_hdr_q           <= '0;
      m_axis_pkt_tdata        <= 8'h00;
      m_axis_pkt_tvalid       <= 1'b0;
      m_axis_pkt_tlast        <= 1'b0;
      pkt_completed_pulse     <= 1'b0;
      idle_pkt_stripped_pulse <= 1'b0;
      pkt_len_err_pulse       <= 1'b0;
    end else begin
      // Latch FHP resynchronization request even when downstream backpressure (m_axis_pkt_tready == 0) stalls the pipeline (Fix P1-6)
      if (frame_start_pulse && fhp_resync_en && !m_axis_pkt_tready) begin
        fhp_pending_q <= 1'b1;
        latched_fhp_q <= frame_fhp_in;
      end

      if (m_axis_pkt_tready) begin
        logic        fhp_trig;
        logic [10:0] eff_fhp;

        m_axis_pkt_tvalid       <= 1'b0;
        m_axis_pkt_tlast        <= 1'b0;
        pkt_completed_pulse     <= 1'b0;
        idle_pkt_stripped_pulse <= 1'b0;
        pkt_len_err_pulse       <= 1'b0;

        fhp_trig      = (frame_start_pulse && fhp_resync_en) || fhp_pending_q;
        eff_fhp       = (frame_start_pulse && fhp_resync_en) ? frame_fhp_in : latched_fhp_q;
        fhp_pending_q <= 1'b0;

        if (fhp_trig && (state_q == REASM_SKIP_TO_FHP)) begin
          if (eff_fhp == TM_FHP_OID_IDLE_FRAME || eff_fhp == TM_FHP_NO_PKT_START) begin
            skip_cnt_q <= 11'h7FF;
          end else if (eff_fhp == 11'd0) begin
            hdr_idx_q <= 3'd0;
            state_q   <= REASM_COLLECT_HDR;
          end else begin
            skip_cnt_q <= eff_fhp;
          end
        end else if (state_q == REASM_EMIT_HDR_1_5) begin
          // Drain validated header bytes 1..5 before streaming body bytes
          m_axis_pkt_tdata  <= hdr_emit_shift_q[39:32];
          m_axis_pkt_tvalid <= 1'b1;
          hdr_emit_shift_q  <= {hdr_emit_shift_q[31:0], 8'h00};
          if (hdr_idx_q == 3'd4) begin
            hdr_idx_q <= 3'd0;
            state_q   <= REASM_DATA_BODY;
          end else begin
            hdr_idx_q <= hdr_idx_q + 3'd1;
          end
        end else if (s_axis_tvalid && s_axis_tready) begin
          unique case (state_q)
            REASM_SKIP_TO_FHP: begin
              if (skip_cnt_q != 11'h7FF) begin
                if (skip_cnt_q <= 11'd1) begin
                  hdr_idx_q <= 3'd0;
                  state_q   <= REASM_COLLECT_HDR;
                end else begin
                  skip_cnt_q <= skip_cnt_q - 11'd1;
                end
              end
            end

            REASM_COLLECT_HDR: begin
              logic [47:0] nxt_hdr48;
              // Unconditional shift decouples hdr_shift_q[47:0]/CE from s_axis_tdata (Fix CR-30)
              nxt_hdr48   = {hdr_shift_q[39:0], s_axis_tdata};
              hdr_shift_q <= nxt_hdr48;

              if ((hdr_idx_q == 3'd0) && ((s_axis_tdata == 8'hE0) || (s_axis_tdata == 8'h55))) begin
                hdr_idx_q <= 3'd0;
              end else if (hdr_idx_q == 3'd5) begin
                ccsds_space_pkt_hdr_t ph;
                logic                 idle_pkt;
                ph               = ccsds_space_pkt_hdr_t'(nxt_hdr48);
                cur_pkt_hdr_q    <= ph;
                idle_pkt         = (ph.apid == 11'h7FF);
                is_idle_apid_q   <= idle_pkt;
                rem_body_bytes_q <= ph.pkt_data_len; // Direct wire load (0 CARRY8 levels on s_axis_tdata!)
                hdr_idx_q        <= 3'd0;

                if (ph.pkt_vn != 3'b000) begin
                  pkt_len_err_pulse <= 1'b1;
                  if (fhp_resync_en) begin
                    state_q    <= REASM_SKIP_TO_FHP;
                    skip_cnt_q <= 11'h7FF;
                  end else begin
                    state_q <= REASM_COLLECT_HDR;
                  end
                end else if (idle_pkt) begin
                  // Idle Space Packet (APID=0x7FF): emit 0 header bytes and discard body
                  state_q <= REASM_DATA_BODY;
                end else begin
                  // Valid user Space Packet: emit Header Byte 0 now and Header Bytes 1..5 next
                  m_axis_pkt_tdata  <= nxt_hdr48[47:40];
                  m_axis_pkt_tvalid <= 1'b1;
                  hdr_emit_shift_q  <= nxt_hdr48[39:0];
                  state_q           <= REASM_EMIT_HDR_1_5;
                end
              end else begin
                hdr_idx_q <= hdr_idx_q + 3'd1;
              end
            end

            REASM_DATA_BODY: begin
              if (!is_idle_apid_q) begin
                m_axis_pkt_tdata  <= s_axis_tdata;
                m_axis_pkt_tvalid <= 1'b1;
                m_axis_pkt_tlast  <= (rem_body_bytes_q == 16'd0);
              end
              if (rem_body_bytes_q == 16'd0) begin
                pkt_completed_pulse     <= !is_idle_apid_q;
                idle_pkt_stripped_pulse <= is_idle_apid_q;
                state_q                 <= REASM_COLLECT_HDR;
              end else begin
                rem_body_bytes_q <= rem_body_bytes_q - 16'd1;
              end
            end

            default: state_q <= REASM_COLLECT_HDR;
          endcase
        end
      end
    end
  end

endmodule : ccsds_pkt_reassembler
