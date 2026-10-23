//=============================================================================
// File Name   : ccsds_tm_aos_deframer.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : CCSDS 132.0-B-3 (TM) & CCSDS 732.0-B-4 (AOS)
// Description : Synthesizable Ground EGSE TM / AOS Downlink Deframer:
//                 - Parses 6-octet TM Primary Header or 6/8-octet AOS Primary
//                   Header
//                 - Extracts optional 8-octet CUC On-Board Time (OBT)
//                   Secondary Header timestamp (CCSDS 301.0-B-4)
//                 - Streams TFDF payload bytes to Ground Space Packet
//                   Reassembler
//                 - Extracts 32-bit OCF (CLCW) and validates trailing 16-bit
//                   CRC-16-CCITT FECF (residue == 16'h0000)
//=============================================================================
`timescale 1ns / 1ps

module ccsds_tm_aos_deframer
  import ccsds_pkg::*;
(
  input  logic          clk,
  input  logic          rst_n,

  // Configuration
  input  logic          aos_mode_cfg,
  input  logic          aos_fhec_en_cfg,
  input  logic          tm_sec_hdr_en_cfg,
  input  logic          ocf_en_cfg,
  input  logic          fecf_en_cfg,
  input  logic [15:0]   tfdf_byte_len_cfg,

  // Input Downlink Transfer Frame Byte Stream
  input  logic          s_axis_tvalid,
  output logic                s_axis_tready,
  input  logic [7:0]    s_axis_tdata,
  input  logic          s_axis_tlast,

  // Output Extracted TFDF Payload Stream
  output logic                m_axis_tfdf_tvalid,
  input  logic          m_axis_tfdf_tready,
  output logic [7:0]          m_axis_tfdf_tdata,
  output logic                m_axis_tfdf_tlast,

  // Extracted Headers, CUC Timestamp, CLCW & CRC Status
  output ccsds_tm_prim_hdr_t  rx_tm_hdr_out,
  output logic [47:0]         rx_obt_cuc_timestamp_out,
  output ccsds_clcw_t         extracted_clcw_out,
  output logic                clcw_valid_pulse,
  output logic                frame_crc_ok_pulse,
  output logic                frame_crc_err_pulse
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
    DL_DEF_IDLE    = 3'd0,
    DL_DEF_HDR     = 3'd1,
    DL_DEF_SEC_HDR = 3'd2,
    DL_DEF_TFDF    = 3'd3,
    DL_DEF_OCF     = 3'd4,
    DL_DEF_FECF    = 3'd5
  } dl_def_state_e;

  dl_def_state_e state_q;
  logic [3:0]    hdr_idx_q;
  logic [47:0]   hdr_shift_q;
  logic [63:0]   sec_hdr_shift_q;
  logic [15:0]   tfdf_cnt_q;
  logic [31:0]   ocf_shift_q;
  logic [15:0]   crc_q;

  assign s_axis_tready = m_axis_tfdf_tready || !m_axis_tfdf_tvalid;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q                  <= DL_DEF_IDLE;
      hdr_idx_q                <= 4'd0;
      hdr_shift_q              <= 48'd0;
      sec_hdr_shift_q          <= 64'd0;
      tfdf_cnt_q               <= 16'd0;
      ocf_shift_q              <= 32'd0;
      crc_q                    <= 16'hFFFF;
      m_axis_tfdf_tvalid       <= 1'b0;
      m_axis_tfdf_tdata        <= 8'd0;
      m_axis_tfdf_tlast        <= 1'b0;
      rx_tm_hdr_out            <= '0;
      rx_obt_cuc_timestamp_out <= 48'd0;
      extracted_clcw_out       <= '0;
      clcw_valid_pulse         <= 1'b0;
      frame_crc_ok_pulse       <= 1'b0;
      frame_crc_err_pulse      <= 1'b0;
    end else begin
      clcw_valid_pulse    <= 1'b0;
      frame_crc_ok_pulse  <= 1'b0;
      frame_crc_err_pulse <= 1'b0;
      if (m_axis_tfdf_tready) begin
        m_axis_tfdf_tvalid <= 1'b0;
        m_axis_tfdf_tlast  <= 1'b0;
      end

      if (s_axis_tvalid && s_axis_tready) begin
        logic [15:0] nxt_crc;
        nxt_crc = step_crc16(state_q == DL_DEF_IDLE ? 16'hFFFF : crc_q, s_axis_tdata);
        crc_q   <= nxt_crc;

        case (state_q)
          DL_DEF_IDLE: begin
            hdr_shift_q <= {40'd0, s_axis_tdata};
            hdr_idx_q   <= 4'd1;
            state_q     <= DL_DEF_HDR;
          end

          DL_DEF_HDR: begin
            logic [3:0] hdr_len;
            hdr_len = (aos_mode_cfg && aos_fhec_en_cfg) ? 4'd8 : 4'd6;
            if (hdr_idx_q < 4'd6) begin
              hdr_shift_q <= {hdr_shift_q[39:0], s_axis_tdata};
            end
            if (hdr_idx_q == (hdr_len - 4'd1)) begin
              if (hdr_len == 4'd6) begin
                rx_tm_hdr_out <= ccsds_tm_prim_hdr_t'({hdr_shift_q[39:0], s_axis_tdata});
              end
              hdr_idx_q  <= 4'd0;
              tfdf_cnt_q <= 16'd0;
              if (!aos_mode_cfg && tm_sec_hdr_en_cfg) begin
                state_q <= DL_DEF_SEC_HDR;
              end else begin
                state_q <= DL_DEF_TFDF;
              end
            end else begin
              hdr_idx_q <= hdr_idx_q + 4'd1;
            end
          end

          DL_DEF_SEC_HDR: begin
            sec_hdr_shift_q <= {sec_hdr_shift_q[55:0], s_axis_tdata};
            if (hdr_idx_q == 4'd7) begin
              logic [63:0] full_sec;
              full_sec                 = {sec_hdr_shift_q[55:0], s_axis_tdata};
              rx_obt_cuc_timestamp_out <= full_sec[47:0];
              hdr_idx_q                <= 4'd0;
              state_q                  <= DL_DEF_TFDF;
            end else begin
              hdr_idx_q <= hdr_idx_q + 4'd1;
            end
          end

          DL_DEF_TFDF: begin
            m_axis_tfdf_tvalid <= 1'b1;
            m_axis_tfdf_tdata  <= s_axis_tdata;
            m_axis_tfdf_tlast  <= (tfdf_cnt_q == (tfdf_byte_len_cfg - 16'd1));
            if (tfdf_cnt_q == (tfdf_byte_len_cfg - 16'd1)) begin
              hdr_idx_q <= 4'd0;
              if (ocf_en_cfg) begin
                state_q <= DL_DEF_OCF;
              end else if (fecf_en_cfg) begin
                state_q <= DL_DEF_FECF;
              end else begin
                state_q <= DL_DEF_IDLE;
              end
            end else begin
              tfdf_cnt_q <= tfdf_cnt_q + 16'd1;
            end
          end

          DL_DEF_OCF: begin
            ocf_shift_q <= {ocf_shift_q[23:0], s_axis_tdata};
            if (hdr_idx_q == 4'd3) begin
              extracted_clcw_out <= ccsds_clcw_t'({ocf_shift_q[23:0], s_axis_tdata});
              hdr_idx_q          <= 4'd0;
              if (fecf_en_cfg) begin
                state_q <= DL_DEF_FECF;
              end else begin
                clcw_valid_pulse <= 1'b1;
                state_q          <= DL_DEF_IDLE;
              end
            end else begin
              hdr_idx_q <= hdr_idx_q + 4'd1;
            end
          end

          DL_DEF_FECF: begin
            if (hdr_idx_q == 4'd1 || s_axis_tlast) begin
              if (nxt_crc == 16'h0000) begin
                frame_crc_ok_pulse <= 1'b1;
                if (ocf_en_cfg) begin
                  clcw_valid_pulse <= 1'b1;
                end
              end else begin
                frame_crc_err_pulse <= 1'b1;
              end
              state_q <= DL_DEF_IDLE;
            end else begin
              hdr_idx_q <= hdr_idx_q + 4'd1;
            end
          end

          default: state_q <= DL_DEF_IDLE;
        endcase
      end
    end
  end

endmodule
