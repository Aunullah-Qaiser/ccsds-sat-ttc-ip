// =============================================================================
// File Name   : ccsds_tc_uslp_deframer.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog (Synthesizable)
// Description : Multi-Protocol Uplink/Bidirectional Deframer supporting:
//                 1. Classic Telecommand (TC, CCSDS 232.0-B-4, TFVN=2'b00):
//                    5B Primary Header + optional 1B Segment Hdr, Frame_Length
//                    0x55 CLTU fill stripper (Audit R1-1 & R2-2), CRC-16 (0x1021).
//                 2. Proximity-1 Version-3 (CCSDS 211.0-B-6, TFVN=2'b10):
//                    5B Primary Header (Frame_Length C = Hdr+Data-1) + 32-bit
//                    Proximity-1 CRC-32 (0x00A00805, residue 0x00000000).
//                 3. Unified Space Link Protocol (USLP, CCSDS 732.1-B-3, TFVN=4'hC):
//                    Truncated 4B Primary Header (end_of_ph_flag=1) or Extended
//                    Variable 7..14B Primary Header (vcf_cnt_len=0..7) + 1B/3B
//                    TFDFH (with UPID & FHP/LVO), optional 4B OCF, and CRC-16/32.
// =============================================================================
`timescale 1ns / 1ps

module ccsds_tc_uslp_deframer
  import ccsds_pkg::*;
(
  input  logic                  clk,
  input  logic                  rst_n,

  input  logic [9:0]            spacecraft_id_cfg,
  input  logic [15:0]           uslp_scid_cfg,
  input  logic [15:0]           uslp_trunc_frame_len_cfg,
  input  logic                  uslp_tfdf_3byte_en_cfg,
  input  logic                  fecf_crc32_cfg,
  input  logic                  tc_seg_hdr_present_cfg,

  // 8-bit De-Randomized Octet Stream from RX3 (ccsds_bch6356_dec / LDPC / Viterbi)
  input  logic [7:0]            s_axis_tdata,
  input  logic                  s_axis_tvalid,
  output logic                  s_axis_tready,
  input  logic                  s_axis_tlast,
  input  logic                  s_axis_tabort,

  // Per-Frame Header & Validation Outputs to RX5 (FARM-1 / COP-P) & RX7 (Rollback FIFO)
  output ccsds_tc_prim_hdr_t    parsed_tc_hdr,
  output ccsds_tc_seg_hdr_t     parsed_tc_seg_hdr,
  output ccsds_prox1_prim_hdr_t parsed_prox1_hdr,
  output ccsds_uslp_trunc_hdr_t parsed_uslp_trunc_hdr,
  output ccsds_uslp_ext_hdr_t   parsed_uslp_ext_hdr,
  output ccsds_uslp_tfdf_hdr_t  parsed_uslp_tfdf_hdr,
  output logic [2:0]            detected_proto_mode,
  output logic [31:0]           extracted_ocf_word,
  output logic                  extracted_ocf_valid,
  output logic                  frame_done_pulse,
  output logic                  frame_crc_ok,
  output logic                  frame_crc_err_pulse,
  output logic                  frame_commit_pulse,
  output logic                  frame_rollback_pulse,

  // Extracted Payload Byte Stream to RX6/RX7
  output logic [7:0]            m_axis_tdata,
  output logic                  m_axis_tvalid,
  input  logic                  m_axis_tready,
  output logic                  m_axis_tlast
);

  typedef enum logic [2:0] {
    DEFRAME_IDLE_OR_HDR0  = 3'd0,
    DEFRAME_TC_PROX_HDR   = 3'd1,
    DEFRAME_USLP_BASE_HDR = 3'd2,
    DEFRAME_USLP_EXT_HDR  = 3'd3,
    DEFRAME_USLP_VCF_CNT  = 3'd4,
    DEFRAME_USLP_TFDF_HDR = 3'd5,
    DEFRAME_BODY_AND_CRC  = 3'd6
  } deframe_state_e;

  deframe_state_e        state_q;
  logic [39:0]           hdr40_shift_q;
  logic [31:0]           uslp_base_shift_q;
  logic [23:0]           uslp_ext_shift_q;
  logic [23:0]           uslp_tfdf_shift_q;
  logic [31:0]           ocf_shift_q;
  logic [3:0]            hdr_idx_q;
  logic [15:0]           total_frame_bytes_q;
  logic [15:0]           payload_start_byte_q;
  logic [15:0]           payload_end_byte_q;
  logic [15:0]           ocf_start_byte_q;
  logic [15:0]           byte_cnt_q;
  logic [15:0]           crc16_q;
  logic [31:0]           crc32_q;
  logic                  use_crc32_q;
  logic                  is_idle_uslp_frame_q;

  ccsds_tc_prim_hdr_t    cur_tc_hdr_q;
  ccsds_tc_seg_hdr_t     cur_tc_seg_hdr_q;
  ccsds_prox1_prim_hdr_t cur_prox1_hdr_q;
  ccsds_uslp_trunc_hdr_t cur_uslp_trunc_q;
  ccsds_uslp_ext_hdr_t   cur_uslp_ext_q;
  ccsds_uslp_tfdf_hdr_t  cur_uslp_tfdf_q;
  logic [2:0]            cur_proto_q;

  function automatic logic [15:0] step_crc16(input logic [15:0] crc_in, input logic [7:0] b);
    logic [15:0] c;
    c = crc_in ^ {b, 8'h00};
    for (int i = 0; i < 8; i++) begin
      if (c[15]) begin
        c = (c << 1) ^ POLY_CRC16_CCITT;
      end else begin
        c = (c << 1);
      end
    end
    return c;
  endfunction

  function automatic logic [31:0] step_crc32(input logic [31:0] crc_in, input logic [7:0] b);
    logic [31:0] c;
    c = crc_in ^ {b, 24'h00_0000};
    for (int i = 0; i < 8; i++) begin
      if (c[31]) begin
        c = (c << 1) ^ POLY_CRC32_PROX1;
      end else begin
        c = (c << 1);
      end
    end
    return c;
  endfunction

  assign s_axis_tready         = m_axis_tready || !m_axis_tvalid;
  assign parsed_tc_hdr         = cur_tc_hdr_q;
  assign parsed_tc_seg_hdr     = cur_tc_seg_hdr_q;
  assign parsed_prox1_hdr      = cur_prox1_hdr_q;
  assign parsed_uslp_trunc_hdr = cur_uslp_trunc_q;
  assign parsed_uslp_ext_hdr   = cur_uslp_ext_q;
  assign parsed_uslp_tfdf_hdr  = cur_uslp_tfdf_q;
  assign detected_proto_mode   = cur_proto_q;
  assign extracted_ocf_word    = ocf_shift_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q              <= DEFRAME_IDLE_OR_HDR0;
      hdr40_shift_q        <= 40'd0;
      uslp_base_shift_q    <= 32'd0;
      uslp_ext_shift_q     <= 24'd0;
      uslp_tfdf_shift_q    <= 24'd0;
      ocf_shift_q          <= 32'd0;
      hdr_idx_q            <= 4'd0;
      total_frame_bytes_q  <= 16'd0;
      payload_start_byte_q <= 16'd0;
      payload_end_byte_q   <= 16'd0;
      ocf_start_byte_q     <= 16'd0;
      byte_cnt_q           <= 16'd0;
      crc16_q              <= INIT_CRC16_CCITT;
      crc32_q              <= INIT_CRC32_PROX1;
      use_crc32_q          <= 1'b0;
      is_idle_uslp_frame_q <= 1'b0;
      cur_tc_hdr_q         <= '0;
      cur_tc_seg_hdr_q     <= '0;
      cur_prox1_hdr_q      <= '0;
      cur_uslp_trunc_q     <= '0;
      cur_uslp_ext_q       <= '0;
      cur_uslp_tfdf_q      <= '0;
      cur_proto_q          <= PROTO_TC;
      extracted_ocf_valid  <= 1'b0;
      frame_done_pulse     <= 1'b0;
      frame_crc_ok         <= 1'b0;
      frame_crc_err_pulse  <= 1'b0;
      frame_commit_pulse   <= 1'b0;
      frame_rollback_pulse <= 1'b0;
      m_axis_tdata         <= 8'h00;
      if (m_axis_tready) begin
        m_axis_tvalid <= 1'b0;
        m_axis_tlast  <= 1'b0;
      end
    end else begin
      extracted_ocf_valid  <= 1'b0;
      frame_done_pulse     <= 1'b0;
      frame_crc_ok         <= 1'b0;
      frame_crc_err_pulse  <= 1'b0;
      frame_commit_pulse   <= 1'b0;
      frame_rollback_pulse <= 1'b0;
      if (m_axis_tready) begin
        m_axis_tvalid <= 1'b0;
        m_axis_tlast  <= 1'b0;
      end

      if (s_axis_tvalid && s_axis_tready) begin
        if (s_axis_tabort) begin
          state_q              <= DEFRAME_IDLE_OR_HDR0;
          crc16_q              <= INIT_CRC16_CCITT;
          crc32_q              <= INIT_CRC32_PROX1;
          frame_rollback_pulse <= (state_q != DEFRAME_IDLE_OR_HDR0);
        end else if (s_axis_tlast &&
                     !((state_q == DEFRAME_BODY_AND_CRC) && ((byte_cnt_q + 16'd1) == total_frame_bytes_q))) begin
          if (state_q != DEFRAME_IDLE_OR_HDR0) begin
            frame_rollback_pulse <= 1'b1;
          end
          state_q <= DEFRAME_IDLE_OR_HDR0;
          crc16_q <= INIT_CRC16_CCITT;
          crc32_q <= INIT_CRC32_PROX1;
        end else begin
          unique case (state_q)
            DEFRAME_IDLE_OR_HDR0: begin
              if (s_axis_tdata != CLTU_IDLE_FILL_OCTET) begin
                crc16_q    <= step_crc16(INIT_CRC16_CCITT, s_axis_tdata);
                crc32_q    <= step_crc32(INIT_CRC32_PROX1, s_axis_tdata);
                byte_cnt_q <= 16'd1;
                hdr_idx_q  <= 4'd1;
                if (s_axis_tdata[7:4] == 4'b1100) begin
                  uslp_base_shift_q <= {24'd0, s_axis_tdata};
                  cur_proto_q       <= PROTO_USLP;
                  use_crc32_q       <= fecf_crc32_cfg;
                  state_q           <= DEFRAME_USLP_BASE_HDR;
                end else if (s_axis_tdata[7:6] == 2'b10) begin
                  hdr40_shift_q <= {32'd0, s_axis_tdata};
                  cur_proto_q   <= PROTO_PROX1;
                  use_crc32_q   <= 1'b1;
                  state_q       <= DEFRAME_TC_PROX_HDR;
                end else begin
                  hdr40_shift_q <= {32'd0, s_axis_tdata};
                  cur_proto_q   <= PROTO_TC;
                  use_crc32_q   <= 1'b0;
                  state_q       <= DEFRAME_TC_PROX_HDR;
                end
              end
            end

            DEFRAME_TC_PROX_HDR: begin
              logic [39:0] nxt_hdr40;
              nxt_hdr40     = {hdr40_shift_q[31:0], s_axis_tdata};
              hdr40_shift_q <= nxt_hdr40;
              crc16_q       <= step_crc16(crc16_q, s_axis_tdata);
              crc32_q       <= step_crc32(crc32_q, s_axis_tdata);
              byte_cnt_q    <= byte_cnt_q + 16'd1;

              if (hdr_idx_q == 4'd4) begin
                if (cur_proto_q == PROTO_PROX1) begin
                  ccsds_prox1_prim_hdr_t ph;
                  ccsds_tc_prim_hdr_t    tc_compat;
                  logic [15:0]           tot_bytes;
                  ph        = ccsds_prox1_prim_hdr_t'(nxt_hdr40);
                  tot_bytes = {5'd0, ph.frame_len} + 16'd5;
                  cur_prox1_hdr_q         <= ph;
                  tc_compat.tfvn          = ph.tfvn;
                  tc_compat.bypass_flag   = ph.qos_ind;
                  tc_compat.ctrl_cmd_flag = ph.pdu_type_id;
                  tc_compat.rsvd_spare    = ph.dfc_id;
                  tc_compat.scid          = ph.scid;
                  tc_compat.vcid          = {2'b00, ph.pcid, ph.port_id};
                  tc_compat.frame_len     = ph.frame_len[9:0];
                  tc_compat.frame_seq_num = ph.frame_seq_num;
                  cur_tc_hdr_q            <= tc_compat;
                  total_frame_bytes_q     <= tot_bytes;
                  payload_start_byte_q    <= 16'd5;
                  payload_end_byte_q      <= tot_bytes - 16'd4;
                  ocf_start_byte_q        <= 16'hFFFF;
                  is_idle_uslp_frame_q    <= 1'b0;
                  state_q                 <= DEFRAME_BODY_AND_CRC;
                end else begin
                  ccsds_tc_prim_hdr_t th;
                  logic [15:0]        tot_bytes;
                  th        = ccsds_tc_prim_hdr_t'(nxt_hdr40);
                  tot_bytes = {6'd0, th.frame_len} + 16'd1;
                  cur_tc_hdr_q         <= th;
                  total_frame_bytes_q  <= tot_bytes;
                  payload_start_byte_q <= (th.ctrl_cmd_flag || !tc_seg_hdr_present_cfg) ? 16'd5 : 16'd6;
                  payload_end_byte_q   <= tot_bytes - 16'd2;
                  ocf_start_byte_q     <= 16'hFFFF;
                  is_idle_uslp_frame_q <= 1'b0;
                  state_q              <= DEFRAME_BODY_AND_CRC;
                end
              end else begin
                hdr_idx_q <= hdr_idx_q + 4'd1;
              end
            end

            DEFRAME_USLP_BASE_HDR: begin
              logic [31:0] nxt_base32;
              nxt_base32        = {uslp_base_shift_q[23:0], s_axis_tdata};
              uslp_base_shift_q <= nxt_base32;
              crc16_q           <= step_crc16(crc16_q, s_axis_tdata);
              crc32_q           <= step_crc32(crc32_q, s_axis_tdata);
              byte_cnt_q        <= byte_cnt_q + 16'd1;

              if (hdr_idx_q == 4'd3) begin
                ccsds_uslp_trunc_hdr_t uh;
                uh               = ccsds_uslp_trunc_hdr_t'(nxt_base32);
                cur_uslp_trunc_q <= uh;
                hdr_idx_q        <= 4'd0;
                if (uh.end_of_ph_flag) begin
                  total_frame_bytes_q <= uslp_trunc_frame_len_cfg;
                  cur_uslp_ext_q      <= '0;
                  state_q             <= DEFRAME_USLP_TFDF_HDR;
                end else begin
                  state_q <= DEFRAME_USLP_EXT_HDR;
                end
              end else begin
                hdr_idx_q <= hdr_idx_q + 4'd1;
              end
            end

            DEFRAME_USLP_EXT_HDR: begin
              logic [23:0] nxt_ext24;
              nxt_ext24        = {uslp_ext_shift_q[15:0], s_axis_tdata};
              uslp_ext_shift_q <= nxt_ext24;
              crc16_q          <= step_crc16(crc16_q, s_axis_tdata);
              crc32_q          <= step_crc32(crc32_q, s_axis_tdata);
              byte_cnt_q       <= byte_cnt_q + 16'd1;

              if (hdr_idx_q == 4'd2) begin
                ccsds_uslp_ext_hdr_t eh;
                eh                  = ccsds_uslp_ext_hdr_t'(nxt_ext24);
                cur_uslp_ext_q      <= eh;
                total_frame_bytes_q <= eh.frame_len + 16'd1;
                hdr_idx_q           <= 4'd0;
                if (eh.vcf_cnt_len == 3'd0) begin
                  state_q <= DEFRAME_USLP_TFDF_HDR;
                end else begin
                  state_q <= DEFRAME_USLP_VCF_CNT;
                end
              end else begin
                hdr_idx_q <= hdr_idx_q + 4'd1;
              end
            end

            DEFRAME_USLP_VCF_CNT: begin
              crc16_q    <= step_crc16(crc16_q, s_axis_tdata);
              crc32_q    <= step_crc32(crc32_q, s_axis_tdata);
              byte_cnt_q <= byte_cnt_q + 16'd1;
              cur_tc_hdr_q.frame_seq_num <= s_axis_tdata;
              if (hdr_idx_q + 4'd1 == {1'b0, cur_uslp_ext_q.vcf_cnt_len}) begin
                hdr_idx_q <= 4'd0;
                state_q   <= DEFRAME_USLP_TFDF_HDR;
              end else begin
                hdr_idx_q <= hdr_idx_q + 4'd1;
              end
            end

            DEFRAME_USLP_TFDF_HDR: begin
              logic [23:0] nxt_tfdf24;
              logic [15:0] nxt_cnt;
              logic [15:0] fecf_len;
              logic [15:0] ocf_len;
              nxt_cnt    = byte_cnt_q + 16'd1;
              fecf_len   = use_crc32_q ? 16'd4 : 16'd2;
              ocf_len    = (!cur_uslp_trunc_q.end_of_ph_flag && cur_uslp_ext_q.ocf_flag) ? 16'd4 : 16'd0;
              crc16_q    <= step_crc16(crc16_q, s_axis_tdata);
              crc32_q    <= step_crc32(crc32_q, s_axis_tdata);
              byte_cnt_q <= nxt_cnt;

              if (cur_uslp_trunc_q.end_of_ph_flag || !uslp_tfdf_3byte_en_cfg) begin
                ccsds_uslp_tfdf_hdr_t thdr;
                ccsds_tc_prim_hdr_t   tc_compat;
                thdr.tfdf_constr_rule   = s_axis_tdata[7:5];
                thdr.up_id              = s_axis_tdata[4:0];
                thdr.fhp_or_lvo         = 16'h0000;
                cur_uslp_tfdf_q         <= thdr;
                tc_compat.tfvn          = 2'b00;
                tc_compat.bypass_flag   = cur_uslp_trunc_q.end_of_ph_flag ? 1'b1 : cur_uslp_ext_q.bypass_flag;
                tc_compat.ctrl_cmd_flag = cur_uslp_trunc_q.end_of_ph_flag ? 1'b0 : cur_uslp_ext_q.ctrl_cmd_flag;
                tc_compat.rsvd_spare    = 2'b00;
                tc_compat.scid          = cur_uslp_trunc_q.scid[9:0];
                tc_compat.vcid          = cur_uslp_trunc_q.vcid;
                tc_compat.frame_len     = total_frame_bytes_q[9:0] - 10'd1;
                tc_compat.frame_seq_num = cur_tc_hdr_q.frame_seq_num;
                cur_tc_hdr_q            <= tc_compat;
                payload_start_byte_q    <= nxt_cnt;
                payload_end_byte_q      <= total_frame_bytes_q - fecf_len - ocf_len;
                ocf_start_byte_q        <= (ocf_len != 16'd0) ? (total_frame_bytes_q - fecf_len - 16'd4) : 16'hFFFF;
                is_idle_uslp_frame_q    <= (s_axis_tdata[4:0] == 5'b11111) || (cur_uslp_trunc_q.vcid == AOS_USLP_VCID_OID);
                state_q                 <= DEFRAME_BODY_AND_CRC;
              end else begin
                nxt_tfdf24        = {uslp_tfdf_shift_q[15:0], s_axis_tdata};
                uslp_tfdf_shift_q <= nxt_tfdf24;
                if (hdr_idx_q == 4'd2) begin
                  ccsds_uslp_tfdf_hdr_t thdr;
                  ccsds_tc_prim_hdr_t   tc_compat;
                  thdr                    = ccsds_uslp_tfdf_hdr_t'(nxt_tfdf24);
                  cur_uslp_tfdf_q         <= thdr;
                  tc_compat.tfvn          = 2'b00;
                  tc_compat.bypass_flag   = cur_uslp_ext_q.bypass_flag;
                  tc_compat.ctrl_cmd_flag = cur_uslp_ext_q.ctrl_cmd_flag;
                  tc_compat.rsvd_spare    = 2'b00;
                  tc_compat.scid          = cur_uslp_trunc_q.scid[9:0];
                  tc_compat.vcid          = cur_uslp_trunc_q.vcid;
                  tc_compat.frame_len     = total_frame_bytes_q[9:0] - 10'd1;
                  tc_compat.frame_seq_num = cur_tc_hdr_q.frame_seq_num;
                  cur_tc_hdr_q            <= tc_compat;
                  payload_start_byte_q    <= nxt_cnt;
                  payload_end_byte_q      <= total_frame_bytes_q - fecf_len - ocf_len;
                  ocf_start_byte_q        <= (ocf_len != 16'd0) ? (total_frame_bytes_q - fecf_len - 16'd4) : 16'hFFFF;
                  is_idle_uslp_frame_q    <= (thdr.up_id == 5'b11111) || (cur_uslp_trunc_q.vcid == AOS_USLP_VCID_OID);
                  state_q                 <= DEFRAME_BODY_AND_CRC;
                end else begin
                  hdr_idx_q <= hdr_idx_q + 4'd1;
                end
              end
            end

            DEFRAME_BODY_AND_CRC: begin
              logic [15:0] nxt_crc16;
              logic [31:0] nxt_crc32;
              logic [15:0] nxt_cnt;
              nxt_crc16  = step_crc16(crc16_q, s_axis_tdata);
              nxt_crc32  = step_crc32(crc32_q, s_axis_tdata);
              nxt_cnt    = byte_cnt_q + 16'd1;
              crc16_q    <= nxt_crc16;
              crc32_q    <= nxt_crc32;
              byte_cnt_q <= nxt_cnt;

              // Latch 8-bit TC Segment Header (Byte 5 of TFDF when present on Type-AD/BD)
              if ((cur_proto_q == PROTO_TC) && !cur_tc_hdr_q.ctrl_cmd_flag && tc_seg_hdr_present_cfg && (byte_cnt_q == 16'd5)) begin
                cur_tc_seg_hdr_q <= ccsds_tc_seg_hdr_t'(s_axis_tdata);
              end

              if (!is_idle_uslp_frame_q &&
                  (byte_cnt_q >= payload_start_byte_q) &&
                  (nxt_cnt <= payload_end_byte_q)) begin
                m_axis_tdata  <= s_axis_tdata;
                m_axis_tvalid <= 1'b1;
                m_axis_tlast  <= (nxt_cnt == payload_end_byte_q);
              end

              if ((ocf_start_byte_q != 16'hFFFF) &&
                  (byte_cnt_q >= ocf_start_byte_q) &&
                  (nxt_cnt <= (ocf_start_byte_q + 16'd4))) begin
                ocf_shift_q <= {ocf_shift_q[23:0], s_axis_tdata};
                if (nxt_cnt == (ocf_start_byte_q + 16'd4)) begin
                  extracted_ocf_valid <= 1'b1;
                end
              end

              if (nxt_cnt == total_frame_bytes_q) begin
                logic crc_match;
                logic scid_match;
                logic valid_frame;
                crc_match = use_crc32_q ? (nxt_crc32 == RESIDUE_CRC32_VALID)
                                        : (nxt_crc16 == RESIDUE_CRC16_VALID);
                if (cur_proto_q == PROTO_USLP) begin
                  scid_match = (cur_uslp_trunc_q.scid == uslp_scid_cfg) ||
                               (cur_uslp_trunc_q.scid[9:0] == spacecraft_id_cfg);
                end else if (cur_proto_q == PROTO_PROX1) begin
                  scid_match = (cur_prox1_hdr_q.scid == spacecraft_id_cfg);
                end else begin
                  scid_match = (cur_tc_hdr_q.scid == spacecraft_id_cfg) &&
                               (cur_tc_hdr_q.tfvn == 2'b00);
                end
                valid_frame          = crc_match && scid_match;
                frame_done_pulse     <= 1'b1;
                frame_crc_ok         <= valid_frame;
                frame_crc_err_pulse  <= !valid_frame;
                frame_commit_pulse   <= valid_frame && !is_idle_uslp_frame_q;
                frame_rollback_pulse <= !valid_frame;
                state_q              <= DEFRAME_IDLE_OR_HDR0;
                crc16_q              <= INIT_CRC16_CCITT;
                crc32_q              <= INIT_CRC32_PROX1;
              end
            end

            default: state_q <= DEFRAME_IDLE_OR_HDR0;
          endcase
        end
      end
    end
  end

endmodule : ccsds_tc_uslp_deframer
