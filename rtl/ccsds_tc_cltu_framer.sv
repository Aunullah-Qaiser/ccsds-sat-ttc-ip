//=============================================================================
// File Name   : ccsds_tc_cltu_framer.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : CCSDS 232.0-B-4 (TC Space Data Link Protocol)
// Description : Synthesizable Ground EGSE TC Transfer Frame Builder:
//                 - Prepends 40-bit (5-octet) TC Primary Header (TFVN="00",
//                   Bypass_Flag, Ctrl_Cmd_Flag, SCID[9:0], VCID[5:0],
//                   Frame_Length C = Total_Octets - 1, N(S)[7:0])
//                 - Optional 8-bit TC Segment Header (Seq_Flags[1:0], MAP_ID[5:0])
//                 - Appends 16-bit CRC-16-CCITT (0x1021, init 0xFFFF) FECF
//=============================================================================
`timescale 1ns / 1ps

module ccsds_tc_cltu_framer
  import ccsds_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // Frame Header Configuration from FOP-1 / EGSE Controller
  input  logic [9:0]  scid_10b_cfg,
  input  logic [5:0]  vcid_cfg,
  input  logic        bypass_flag_cfg,
  input  logic        ctrl_cmd_flag_cfg,
  input  logic        seg_hdr_en_cfg,
  input  logic [1:0]  seq_flags_cfg,
  input  logic [5:0]  map_id_cfg,
  input  logic [7:0]  fop1_ns_in,
  input  logic [9:0]  payload_byte_len_in,

  // Input Telecommand Payload Stream
  input  logic        s_axis_tvalid,
  output logic              s_axis_tready,
  input  logic [7:0]  s_axis_tdata,
  input  logic        s_axis_tlast,

  // Output Complete TC Transfer Frame (With FECF CRC-16)
  output logic              m_axis_tvalid,
  input  logic        m_axis_tready,
  output logic [7:0]        m_axis_tdata,
  output logic              m_axis_tlast
);

  function automatic logic [15:0] step_crc16(input logic [15:0] crc_in, input logic [7:0] d);
    logic [15:0] c;
    begin
      c = crc_in ^ {d, 8'h00};
      for (int i = 0; i < 8; i++) begin
        if (c[15]) c = (c << 1) ^ 16'h1021;
        else       c = (c << 1);
      end
      return c;
    end
  endfunction

  typedef enum logic [2:0] {
    TC_FRM_IDLE    = 3'd0,
    TC_FRM_HDR     = 3'd1,
    TC_FRM_SEG_HDR = 3'd2,
    TC_FRM_BODY    = 3'd3,
    TC_FRM_CRC_HI  = 3'd4,
    TC_FRM_CRC_LO  = 3'd5
  } tc_frm_state_e;

  tc_frm_state_e state_q;
  logic [2:0]    hdr_idx_q;
  logic [39:0]   hdr_word_q;
  logic [15:0]   crc_q;
  logic [7:0]    first_byte_q;
  logic          first_last_q;
  logic          has_seg_hdr_q;

  assign s_axis_tready = (state_q == TC_FRM_IDLE || (state_q == TC_FRM_BODY && hdr_idx_q != 3'd4)) && m_axis_tready;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q       <= TC_FRM_IDLE;
      hdr_idx_q     <= 3'd0;
      hdr_word_q    <= 40'd0;
      crc_q         <= 16'hFFFF;
      first_byte_q  <= 8'd0;
      first_last_q  <= 1'b0;
      has_seg_hdr_q <= 1'b0;
      m_axis_tvalid <= 1'b0;
      m_axis_tdata  <= 8'd0;
      m_axis_tlast  <= 1'b0;
    end else begin
      if (m_axis_tready) begin
        m_axis_tvalid <= 1'b0;
        m_axis_tlast  <= 1'b0;
      end

      case (state_q)
        TC_FRM_IDLE: begin
          if (s_axis_tvalid && m_axis_tready) begin
            logic [9:0]  c_len;
            logic [39:0] h40;
            logic        use_seg;
            use_seg       = seg_hdr_en_cfg && !ctrl_cmd_flag_cfg;
            c_len         = 10'd5 + (use_seg ? 10'd1 : 10'd0) + payload_byte_len_in + 10'd2 - 10'd1;
            h40           = {2'b00, bypass_flag_cfg, ctrl_cmd_flag_cfg, 2'b00, scid_10b_cfg, vcid_cfg, c_len, fop1_ns_in};
            hdr_word_q    <= h40;
            first_byte_q  <= s_axis_tdata;
            first_last_q  <= s_axis_tlast;
            has_seg_hdr_q <= use_seg;
            m_axis_tvalid <= 1'b1;
            m_axis_tdata  <= h40[39:32];
            m_axis_tlast  <= 1'b0;
            crc_q         <= step_crc16(16'hFFFF, h40[39:32]);
            hdr_idx_q     <= 3'd1;
            state_q       <= TC_FRM_HDR;
          end
        end

        TC_FRM_HDR: begin
          if (m_axis_tready) begin
            logic [7:0] hb;
            hb            = hdr_word_q[(4 - hdr_idx_q) * 8 +: 8];
            m_axis_tvalid <= 1'b1;
            m_axis_tdata  <= hb;
            m_axis_tlast  <= 1'b0;
            crc_q         <= step_crc16(crc_q, hb);
            if (hdr_idx_q == 3'd4) begin
              if (has_seg_hdr_q) begin
                state_q <= TC_FRM_SEG_HDR;
              end else begin
                state_q <= TC_FRM_BODY;
              end
            end else begin
              hdr_idx_q <= hdr_idx_q + 3'd1;
            end
          end
        end

        TC_FRM_SEG_HDR: begin
          if (m_axis_tready) begin
            logic [7:0] sb;
            sb            = {seq_flags_cfg, map_id_cfg};
            m_axis_tvalid <= 1'b1;
            m_axis_tdata  <= sb;
            m_axis_tlast  <= 1'b0;
            crc_q         <= step_crc16(crc_q, sb);
            state_q       <= TC_FRM_BODY;
          end
        end

        TC_FRM_BODY: begin
          if (m_axis_tready) begin
            if (hdr_idx_q == 3'd4) begin
              hdr_idx_q     <= 3'd5;
              m_axis_tvalid <= 1'b1;
              m_axis_tdata  <= first_byte_q;
              m_axis_tlast  <= 1'b0;
              crc_q         <= step_crc16(crc_q, first_byte_q);
              if (first_last_q) begin
                state_q <= TC_FRM_CRC_HI;
              end
            end else if (s_axis_tvalid) begin
              m_axis_tvalid <= 1'b1;
              m_axis_tdata  <= s_axis_tdata;
              m_axis_tlast  <= 1'b0;
              crc_q         <= step_crc16(crc_q, s_axis_tdata);
              if (s_axis_tlast) begin
                state_q <= TC_FRM_CRC_HI;
              end
            end
          end
        end

        TC_FRM_CRC_HI: begin
          if (m_axis_tready) begin
            m_axis_tvalid <= 1'b1;
            m_axis_tdata  <= crc_q[15:8];
            m_axis_tlast  <= 1'b0;
            state_q       <= TC_FRM_CRC_LO;
          end
        end

        TC_FRM_CRC_LO: begin
          if (m_axis_tready) begin
            m_axis_tvalid <= 1'b1;
            m_axis_tdata  <= crc_q[7:0];
            m_axis_tlast  <= 1'b1;
            state_q       <= TC_FRM_IDLE;
          end
        end

        default: state_q <= TC_FRM_IDLE;
      endcase
    end
  end

endmodule
