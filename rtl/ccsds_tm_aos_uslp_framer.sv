// =============================================================================
// File Name   : ccsds_tm_aos_uslp_framer.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog (Synthesizable)
// Description : Multi-Protocol Downlink/Bidirectional Transfer Frame Builder
//               supporting:
//                 1. Telemetry (TM, CCSDS 132.0-B-3, PROTO_TM):
//                    6B Primary Header + TFDF + 4B OCF (CLCW) + 2B CRC-16.
//                 2. Advanced Orbiting Systems (AOS, CCSDS 732.0-B-4, PROTO_AOS):
//                    6B Primary Header + optional 2B GF(2^4) FHEC RS(10,6) +
//                    2B M_PDU Header (FHP) + TFDF + 4B OCF + 2B CRC-16.
//                 3. Proximity-1 (CCSDS 211.0-B-6, PROTO_PROX1):
//                    5B Primary Header + TFDF (or PLCW SPDU) + 4B CRC-32.
//                 4. Unified Space Link Protocol (USLP, CCSDS 732.1-B-3, PROTO_USLP):
//                    Truncated 4B or Extended 7..14B Primary Header + 1B/3B
//                    TFDFH (Rule, UPID, FHP) + TFDF + 4B OCF + 2B/4B CRC-16/32.
// =============================================================================
`timescale 1ns / 1ps

module ccsds_tm_aos_uslp_framer
  import ccsds_pkg::*;
#(
  parameter int unsigned NUM_VC = DEFAULT_NUM_VC
) (
  input  logic        clk,
  input  logic        rst_n,

  input  logic [9:0]  spacecraft_id_cfg,
  input  logic        ocf_en_cfg,
  input  logic        fecf_en_cfg,
  input  ccsds_clcw_t clcw_mbox_in,

  // Multi-Protocol Stage 4 Configuration Inputs
  input  logic [2:0]  proto_mode_cfg,
  input  logic        aos_fhec_en_cfg,
  input  logic [15:0] uslp_scid_cfg,
  input  logic        uslp_trunc_mode_cfg,
  input  logic [2:0]  uslp_vcf_cnt_len_cfg,
  input  logic [4:0]  uslp_upid_cfg,
  input  logic        fecf_crc32_cfg,
  input  logic [10:0] tfdf_byte_len_cfg,
  input  logic        obt_sec_hdr_en_cfg,
  input  logic [47:0] obt_cuc_timestamp_48b,

  // Segmented TFDF Payload Input from TX2 (or TX4 SDLS Encryptor)
  input  logic [7:0]  s_axis_tfdf_tdata,
  input  logic        s_axis_tfdf_tvalid,
  output logic        s_axis_tfdf_tready,
  input  logic        s_axis_tfdf_tlast,
  input  logic [2:0]  s_axis_tfdf_vcid,
  input  logic [10:0] s_axis_tfdf_fhp,

  // Complete Transfer Frame Output to TX6 Downlink FEC Encoders
  output logic [7:0]  m_axis_frame_tdata,
  output logic        m_axis_frame_tvalid,
  input  logic        m_axis_frame_tready,
  output logic        m_axis_frame_tlast
);

  typedef enum logic [1:0] {
    FRAMER_SEND_HDR  = 2'd0,
    FRAMER_SEND_TFDF = 2'd1,
    FRAMER_SEND_OCF  = 2'd2,
    FRAMER_SEND_FECF = 2'd3
  } framer_state_e;

  framer_state_e state_q;
  logic [4:0]    sub_idx_q;
  logic [4:0]    hdr_total_bytes_q;
  logic [127:0]  hdr_shift_q;
  logic [7:0]    mc_cnt_q;
  logic [23:0]   vc_cnt_q [0:NUM_VC-1];
  logic [31:0]   ocf_shift_q;
  logic [15:0]   crc16_q;
  logic [31:0]   crc32_q;
  logic          use_crc32_q;
  logic          use_ocf_q;

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

  function automatic logic [3:0] mul_gf16(input logic [3:0] a, input logic [3:0] b);
    logic [3:0] p;
    logic [3:0] cur;
    logic       hi;
    p   = 4'h0;
    cur = a;
    for (int i = 0; i < 4; i++) begin
      if (b[i]) begin
        p = p ^ cur;
      end
      hi  = cur[3];
      cur = {cur[2:0], 1'b0};
      if (hi) begin
        cur = cur ^ 4'h3;
      end
    end
    return p;
  endfunction

  function automatic logic [15:0] compute_aos_fhec(input logic [23:0] hdr24);
    logic [3:0] r [0:3];
    logic [3:0] fb;
    logic [3:0] sym;
    r[0] = 4'h0;
    r[1] = 4'h0;
    r[2] = 4'h0;
    r[3] = 4'h0;
    for (int k = 5; k >= 0; k--) begin
      sym  = hdr24[k*4 +: 4];
      fb   = sym ^ r[0];
      r[0] = r[1] ^ mul_gf16(fb, 4'h8);
      r[1] = r[2] ^ mul_gf16(fb, 4'h2);
      r[2] = r[3] ^ mul_gf16(fb, 4'h8);
      r[3] =        mul_gf16(fb, 4'h1);
    end
    return {r[0], r[1], r[2], r[3]};
  endfunction

  assign s_axis_tfdf_tready = (state_q == FRAMER_SEND_TFDF) && m_axis_frame_tready;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q             <= FRAMER_SEND_HDR;
      sub_idx_q           <= 5'd0;
      hdr_total_bytes_q   <= 5'd6;
      hdr_shift_q         <= 128'd0;
      mc_cnt_q            <= 8'd0;
      for (int v = 0; v < NUM_VC; v++) begin
        vc_cnt_q[v] <= 24'd0;
      end
      ocf_shift_q         <= 32'd0;
      crc16_q             <= INIT_CRC16_CCITT;
      crc32_q             <= INIT_CRC32_PROX1;
      use_crc32_q         <= 1'b0;
      use_ocf_q           <= 1'b0;
      m_axis_frame_tdata  <= 8'h00;
      m_axis_frame_tvalid <= 1'b0;
      m_axis_frame_tlast  <= 1'b0;
    end else if (m_axis_frame_tready) begin
      m_axis_frame_tvalid <= 1'b0;
      m_axis_frame_tlast  <= 1'b0;

      unique case (state_q)
        FRAMER_SEND_HDR: begin
          if (sub_idx_q == 5'd0) begin
            if (s_axis_tfdf_tvalid) begin
              logic [127:0] built_hdr;
              logic [4:0]   built_len;
              logic         built_crc32;
              logic         built_ocf;
              built_hdr   = 128'd0;
              built_len   = 5'd6;
              built_crc32 = 1'b0;
              built_ocf   = ocf_en_cfg;

              if (proto_mode_cfg == PROTO_AOS) begin
                ccsds_aos_prim_hdr_t ah;
                logic [23:0]         prot24;
                logic [15:0]         fhec16;
                logic [15:0]         mpdu16;
                ah.tfvn         = 2'b01;
                ah.scid         = spacecraft_id_cfg[7:0];
                ah.vcid         = (s_axis_tfdf_fhp == TM_FHP_OID_IDLE_FRAME) ? AOS_USLP_VCID_OID : {3'b000, s_axis_tfdf_vcid};
                ah.vc_frame_cnt = vc_cnt_q[s_axis_tfdf_vcid];
                ah.replay_flag  = 1'b0;
                ah.vc_cnt_usage = 1'b1;
                ah.rsvd_spare   = 2'b00;
                ah.vc_cnt_cycle = 4'h0;
                prot24          = {ah.tfvn, ah.scid, ah.vcid, ah.replay_flag, ah.vc_cnt_usage, ah.rsvd_spare, ah.vc_cnt_cycle};
                fhec16          = compute_aos_fhec(prot24);
                mpdu16          = {5'b00000, s_axis_tfdf_fhp};
                if (aos_fhec_en_cfg) begin
                  built_hdr = {48'(ah), fhec16, mpdu16, 48'd0};
                  built_len = 5'd10;
                end else begin
                  built_hdr = {48'(ah), mpdu16, 64'd0};
                  built_len = 5'd8;
                end
                built_crc32 = 1'b0;
                built_ocf   = ocf_en_cfg;
              end else if (proto_mode_cfg == PROTO_PROX1) begin
                ccsds_prox1_prim_hdr_t ph;
                ph.tfvn          = 2'b10;
                ph.qos_ind       = 1'b0;
                ph.pdu_type_id   = 1'b0;
                ph.dfc_id        = 2'b11;
                ph.scid          = spacecraft_id_cfg;
                ph.pcid          = 1'b0;
                ph.port_id       = s_axis_tfdf_vcid;
                ph.src_dst_id    = 1'b0;
                ph.frame_len     = tfdf_byte_len_cfg + 11'd5 - 11'd1;
                ph.frame_seq_num = vc_cnt_q[s_axis_tfdf_vcid][7:0];
                built_hdr        = {40'(ph), 88'd0};
                built_len        = 5'd5;
                built_crc32      = 1'b1;
                built_ocf        = 1'b0;
              end else if (proto_mode_cfg == PROTO_USLP) begin
                ccsds_uslp_trunc_hdr_t uh;
                uh.tfvn           = 4'b1100;
                uh.scid           = (uslp_scid_cfg != 16'd0) ? uslp_scid_cfg : {6'd0, spacecraft_id_cfg};
                uh.src_dst_id     = 1'b0;
                uh.vcid           = (s_axis_tfdf_fhp == TM_FHP_OID_IDLE_FRAME) ? AOS_USLP_VCID_OID : {3'b000, s_axis_tfdf_vcid};
                uh.map_id         = 4'd0;
                uh.end_of_ph_flag = uslp_trunc_mode_cfg;
                built_crc32       = fecf_crc32_cfg;
                built_ocf         = (!uslp_trunc_mode_cfg) && ocf_en_cfg;

                if (uslp_trunc_mode_cfg) begin
                  logic [7:0] tfdfh1;
                  tfdfh1    = {3'b000, (s_axis_tfdf_fhp == TM_FHP_OID_IDLE_FRAME) ? 5'b11111 : uslp_upid_cfg};
                  built_hdr = {32'(uh), tfdfh1, 88'd0};
                  built_len = 5'd5;
                end else begin
                  ccsds_uslp_ext_hdr_t  eh;
                  ccsds_uslp_tfdf_hdr_t th;
                  logic [15:0]          fecf_bytes;
                  logic [15:0]          ocf_bytes;
                  logic [15:0]          tot_octets;
                  fecf_bytes          = fecf_en_cfg ? (fecf_crc32_cfg ? 16'd4 : 16'd2) : 16'd0;
                  ocf_bytes           = ocf_en_cfg ? 16'd4 : 16'd0;
                  tot_octets          = 16'd11 + {5'd0, tfdf_byte_len_cfg} + ocf_bytes + fecf_bytes;
                  eh.frame_len        = tot_octets - 16'd1;
                  eh.bypass_flag      = 1'b0;
                  eh.ctrl_cmd_flag    = 1'b0;
                  eh.rsvd_spare       = 2'b00;
                  eh.ocf_flag         = ocf_en_cfg;
                  eh.vcf_cnt_len      = 3'd1;
                  th.tfdf_constr_rule = 3'b000;
                  th.up_id            = (s_axis_tfdf_fhp == TM_FHP_OID_IDLE_FRAME) ? 5'b11111 : uslp_upid_cfg;
                  th.fhp_or_lvo       = {5'b00000, s_axis_tfdf_fhp};
                  built_hdr           = {32'(uh), 24'(eh), vc_cnt_q[s_axis_tfdf_vcid][7:0], 24'(th), 40'd0};
                  built_len           = 5'd11;
                end
              end else begin
                ccsds_tm_prim_hdr_t h;
                h.tfvn           = 2'b00;
                h.scid           = spacecraft_id_cfg;
                h.vcid           = s_axis_tfdf_vcid;
                h.ocf_flag       = ocf_en_cfg;
                h.mc_frame_cnt   = mc_cnt_q;
                h.vc_frame_cnt   = vc_cnt_q[s_axis_tfdf_vcid][7:0];
                h.sec_hdr_flag   = obt_sec_hdr_en_cfg;
                h.sync_flag      = 1'b0;
                h.pkt_order_flag = 1'b0;
                h.seg_len_id     = 2'b11;
                h.first_hdr_ptr  = s_axis_tfdf_fhp;
                if (obt_sec_hdr_en_cfg) begin
                  // 6B TM Primary Hdr + 8B OBT Secondary Hdr (1B Sec_Hdr_ID=0x07 + 1B Epoch=0x00 + 6B CUC48) = 14B
                  built_hdr = {48'(h), 8'h07, 8'h00, obt_cuc_timestamp_48b, 16'd0};
                  built_len = 5'd14;
                end else begin
                  built_hdr = {48'(h), 80'd0};
                  built_len = 5'd6;
                end
                built_crc32      = 1'b0;
                built_ocf        = ocf_en_cfg;
              end

              m_axis_frame_tdata         <= built_hdr[127:120];
              m_axis_frame_tvalid        <= 1'b1;
              hdr_shift_q                <= {built_hdr[119:0], 8'h00};
              hdr_total_bytes_q          <= built_len;
              use_crc32_q                <= built_crc32;
              use_ocf_q                  <= built_ocf;
              ocf_shift_q                <= 32'(clcw_mbox_in);
              crc16_q                    <= step_crc16(INIT_CRC16_CCITT, built_hdr[127:120]);
              crc32_q                    <= step_crc32(INIT_CRC32_PROX1, built_hdr[127:120]);
              mc_cnt_q                   <= mc_cnt_q + 8'd1;
              vc_cnt_q[s_axis_tfdf_vcid] <= vc_cnt_q[s_axis_tfdf_vcid] + 24'd1;
              sub_idx_q                  <= 5'd1;
            end
          end else begin
            m_axis_frame_tdata  <= hdr_shift_q[127:120];
            m_axis_frame_tvalid <= 1'b1;
            crc16_q             <= step_crc16(crc16_q, hdr_shift_q[127:120]);
            crc32_q             <= step_crc32(crc32_q, hdr_shift_q[127:120]);
            hdr_shift_q         <= {hdr_shift_q[119:0], 8'h00};
            if (sub_idx_q + 5'd1 == hdr_total_bytes_q) begin
              sub_idx_q <= 5'd0;
              state_q   <= FRAMER_SEND_TFDF;
            end else begin
              sub_idx_q <= sub_idx_q + 5'd1;
            end
          end
        end

        FRAMER_SEND_TFDF: begin
          if (s_axis_tfdf_tvalid) begin
            m_axis_frame_tdata  <= s_axis_tfdf_tdata;
            m_axis_frame_tvalid <= 1'b1;
            crc16_q             <= step_crc16(crc16_q, s_axis_tfdf_tdata);
            crc32_q             <= step_crc32(crc32_q, s_axis_tfdf_tdata);
            if (s_axis_tfdf_tlast) begin
              sub_idx_q <= 5'd0;
              if (use_ocf_q) begin
                state_q <= FRAMER_SEND_OCF;
              end else if (fecf_en_cfg || (proto_mode_cfg == PROTO_PROX1)) begin
                state_q <= FRAMER_SEND_FECF;
              end else begin
                m_axis_frame_tlast <= 1'b1;
                state_q            <= FRAMER_SEND_HDR;
              end
            end
          end
        end

        FRAMER_SEND_OCF: begin
          m_axis_frame_tdata  <= ocf_shift_q[31:24];
          m_axis_frame_tvalid <= 1'b1;
          crc16_q             <= step_crc16(crc16_q, ocf_shift_q[31:24]);
          crc32_q             <= step_crc32(crc32_q, ocf_shift_q[31:24]);
          ocf_shift_q         <= {ocf_shift_q[23:0], 8'h00};
          if (sub_idx_q == 5'd3) begin
            sub_idx_q <= 5'd0;
            if (fecf_en_cfg) begin
              state_q <= FRAMER_SEND_FECF;
            end else begin
              m_axis_frame_tlast <= 1'b1;
              state_q            <= FRAMER_SEND_HDR;
            end
          end else begin
            sub_idx_q <= sub_idx_q + 5'd1;
          end
        end

        FRAMER_SEND_FECF: begin
          m_axis_frame_tvalid <= 1'b1;
          if (use_crc32_q) begin
            unique case (sub_idx_q)
              5'd0: begin
                m_axis_frame_tdata <= crc32_q[31:24];
                sub_idx_q          <= 5'd1;
              end
              5'd1: begin
                m_axis_frame_tdata <= crc32_q[23:16];
                sub_idx_q          <= 5'd2;
              end
              5'd2: begin
                m_axis_frame_tdata <= crc32_q[15:8];
                sub_idx_q          <= 5'd3;
              end
              default: begin
                m_axis_frame_tdata <= crc32_q[7:0];
                m_axis_frame_tlast <= 1'b1;
                sub_idx_q          <= 5'd0;
                state_q            <= FRAMER_SEND_HDR;
              end
            endcase
          end else begin
            if (sub_idx_q == 5'd0) begin
              m_axis_frame_tdata <= crc16_q[15:8];
              sub_idx_q          <= 5'd1;
            end else begin
              m_axis_frame_tdata <= crc16_q[7:0];
              m_axis_frame_tlast <= 1'b1;
              sub_idx_q          <= 5'd0;
              state_q            <= FRAMER_SEND_HDR;
            end
          end
        end

        default: state_q <= FRAMER_SEND_HDR;
      endcase
    end
  end

endmodule : ccsds_tm_aos_uslp_framer
