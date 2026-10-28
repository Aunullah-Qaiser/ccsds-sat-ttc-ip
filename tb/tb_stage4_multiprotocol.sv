// =============================================================================
// File Name   : tb_stage4_multiprotocol.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog Testbench
// Description : Stage 4 Self-Checking Multi-Protocol Verification Testbench
//               (Fix P1-7) exercising:
//                 - ccsds_tm_aos_uslp_framer (TM, AOS + GF(2^4) FHEC, Prox-1, USLP)
//                 - ccsds_tc_uslp_deframer (TC, Prox-1 + CRC-32, USLP Trunc/Ext)
//                 - ccsds_pkt_reassembler (Space Packet reassembly, APID=0x7FF
//                   Idle Packet stripping, & FHP backpressure latch)
//                 - ccsds_prox1_plcw_ctrl (COP-P V(R), Expedited, PLCW)
// =============================================================================

`timescale 1ns / 1ps
module tb_stage4_multiprotocol
  import ccsds_pkg::*;
();

  logic clk   = 1'b0;
  logic rst_n = 1'b0;
  always #5 clk = ~clk;

  logic [7:0]  tfdf_tdata, frame_tdata, def_tdata, pkt_tdata;
  logic        tfdf_tvalid, tfdf_tready, tfdf_tlast;
  logic        frame_tvalid, frame_tready, frame_tlast;
  logic        def_tvalid, def_tready, def_tlast;
  logic        pkt_tvalid, pkt_tlast;
  logic [2:0]  proto_mode_cfg, det_proto;
  logic        crc32_en_cfg;
  logic [31:0] ext_ocf;
  logic        ext_ocf_valid, frame_done, frame_crc_ok, frame_commit, frame_rollback;
  logic        pkt_done, idle_stripped, pkt_len_err;
  logic        copp_acc, copp_rej, plcw_valid;

  ccsds_tc_prim_hdr_t    parsed_tc;
  ccsds_prox1_prim_hdr_t parsed_prox1;
  ccsds_uslp_trunc_hdr_t parsed_uslp_tr;
  ccsds_uslp_ext_hdr_t   parsed_uslp_ex;
  ccsds_uslp_tfdf_hdr_t  parsed_uslp_tf;
  ccsds_space_pkt_hdr_t  parsed_pkt;
  ccsds_plcw_t           plcw_word;

  ccsds_tm_aos_uslp_framer #(.NUM_VC(8)) u_framer (
    .clk                   (clk),
    .rst_n                 (rst_n),
    .spacecraft_id_cfg     (10'h155),
    .ocf_en_cfg            (1'b1),
    .fecf_en_cfg           (1'b1),
    .clcw_mbox_in          (32'h0104_0003),
    .proto_mode_cfg        (proto_mode_cfg),
    .aos_fhec_en_cfg       (1'b1),
    .uslp_scid_cfg         (16'h4255),
    .uslp_trunc_mode_cfg   (1'b0),
    .uslp_vcf_cnt_len_cfg  (3'd1),
    .uslp_upid_cfg         (5'd1),
    .fecf_crc32_cfg        (crc32_en_cfg),
    .tfdf_byte_len_cfg     (11'd16),
    .obt_sec_hdr_en_cfg    (1'b0),
    .obt_cuc_timestamp_48b (48'h6530_0000_0001),
    .s_axis_tfdf_tdata     (tfdf_tdata),
    .s_axis_tfdf_tvalid    (tfdf_tvalid),
    .s_axis_tfdf_tready    (tfdf_tready),
    .s_axis_tfdf_tlast     (tfdf_tlast),
    .s_axis_tfdf_vcid      (3'd1),
    .s_axis_tfdf_fhp       (11'd0),
    .m_axis_frame_tdata    (frame_tdata),
    .m_axis_frame_tvalid   (frame_tvalid),
    .m_axis_frame_tready   (frame_tready),
    .m_axis_frame_tlast    (frame_tlast)
  );

  ccsds_tc_uslp_deframer u_deframer (
    .clk                      (clk),
    .rst_n                    (rst_n),
    .spacecraft_id_cfg        (10'h155),
    .uslp_scid_cfg            (16'h4255),
    .uslp_trunc_frame_len_cfg (16'd25),
    .uslp_tfdf_3byte_en_cfg   (1'b0),
    .fecf_crc32_cfg           (crc32_en_cfg),
    .tc_seg_hdr_present_cfg   (1'b1),
    .s_axis_tdata             (frame_tdata),
    .s_axis_tvalid            (frame_tvalid),
    .s_axis_tready            (frame_tready),
    .s_axis_tlast             (frame_tlast),
    .s_axis_tabort            (1'b0),
    .parsed_tc_hdr            (parsed_tc),
    .parsed_tc_seg_hdr        (),
    .parsed_prox1_hdr         (parsed_prox1),
    .parsed_uslp_trunc_hdr    (parsed_uslp_tr),
    .parsed_uslp_ext_hdr      (parsed_uslp_ex),
    .parsed_uslp_tfdf_hdr     (parsed_uslp_tf),
    .detected_proto_mode      (det_proto),
    .extracted_ocf_word       (ext_ocf),
    .extracted_ocf_valid      (ext_ocf_valid),
    .frame_done_pulse         (frame_done),
    .frame_crc_ok             (frame_crc_ok),
    .frame_crc_err_pulse      (),
    .frame_commit_pulse       (frame_commit),
    .frame_rollback_pulse     (frame_rollback),
    .m_axis_tdata             (def_tdata),
    .m_axis_tvalid            (def_tvalid),
    .m_axis_tready            (def_tready),
    .m_axis_tlast             (def_tlast)
  );

  ccsds_pkt_reassembler u_reasm (
    .clk                     (clk),
    .rst_n                   (rst_n),
    .fhp_resync_en           (1'b0),
    .frame_fhp_in            (11'd0),
    .frame_start_pulse       (1'b0),
    .s_axis_tdata            (def_tdata),
    .s_axis_tvalid           (def_tvalid),
    .s_axis_tready           (def_tready),
    .s_axis_tlast            (def_tlast),
    .m_axis_pkt_tdata        (pkt_tdata),
    .m_axis_pkt_tvalid       (pkt_tvalid),
    .m_axis_pkt_tready       (1'b1),
    .m_axis_pkt_tlast        (pkt_tlast),
    .parsed_pkt_hdr          (parsed_pkt),
    .pkt_completed_pulse     (pkt_done),
    .idle_pkt_stripped_pulse (idle_stripped),
    .pkt_len_err_pulse       (pkt_len_err)
  );

  ccsds_prox1_plcw_ctrl u_prox1_copp (
    .clk               (clk),
    .rst_n             (rst_n),
    .no_rf_avail       (1'b0),
    .no_bit_lock       (1'b0),
    .wait_flag_in      (1'b0),
    .window_half_w     (8'd16),
    .prox1_hdr_in      (parsed_prox1),
    .spdu_cmd_byte0    (8'h00),
    .spdu_cmd_byte1    (8'h00),
    .frame_done_pulse  (frame_done),
    .frame_crc_ok      (frame_crc_ok),
    .copp_accept_pulse (copp_acc),
    .copp_reject_pulse (copp_rej),
    .plcw_out          (plcw_word),
    .plcw_valid_pulse  (plcw_valid)
  );

  logic [7:0] rx_pkt_buf [0:31];
  integer     rx_pkt_cnt;
  logic       uslp_crc_ok_latched, ocf_ok_latched, idle_strip_latched;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_pkt_cnt          <= 0;
      uslp_crc_ok_latched <= 1'b0;
      ocf_ok_latched      <= 1'b0;
      idle_strip_latched  <= 1'b0;
    end else begin
      if (pkt_tvalid) begin
        rx_pkt_buf[rx_pkt_cnt] <= pkt_tdata;
        rx_pkt_cnt             <= rx_pkt_cnt + 1;
      end
      if (frame_done && frame_crc_ok) uslp_crc_ok_latched <= 1'b1;
      if (ext_ocf_valid && (ext_ocf == 32'h0104_0003)) ocf_ok_latched <= 1'b1;
      if (idle_stripped) idle_strip_latched <= 1'b1;
    end
  end

  initial begin
    logic [7:0] sp16 [0:15];
    logic [7:0] idle16 [0:15];

    proto_mode_cfg = PROTO_USLP;
    crc32_en_cfg   = 1'b0;
    tfdf_tdata     = 8'h00;
    tfdf_tvalid    = 1'b0;
    tfdf_tlast     = 1'b0;
    #20 rst_n      = 1'b1;
    repeat (4) @(posedge clk);
    #1;

    // 1. Stream 16-byte Space Packet ("USLP_MP_OK") through USLP Framer -> USLP Deframer -> Reassembler
    sp16[0] = 8'h09; sp16[1] = 8'h55; // APID = 0x155
    sp16[2] = 8'hC0; sp16[3] = 8'h07; // Seq = 7
    sp16[4] = 8'h00; sp16[5] = 8'h09; // Data_Len = 10 - 1 = 9
    sp16[6] = "U";   sp16[7] = "S";   sp16[8] = "L";   sp16[9] = "P";
    sp16[10]= "_";   sp16[11]= "M";   sp16[12]= "P";   sp16[13]= "_";
    sp16[14]= "O";   sp16[15]= "K";

    for (int i = 0; i < 16; i++) begin
      tfdf_tvalid = 1'b1;
      tfdf_tdata  = sp16[i];
      tfdf_tlast  = (i == 15);
      @(posedge clk);
      while (!tfdf_tready) @(posedge clk);
      #1;
    end
    tfdf_tvalid = 1'b0;
    tfdf_tlast  = 1'b0;
    repeat (40) @(posedge clk);
    #1;

    assert (uslp_crc_ok_latched == 1'b1) else $fatal(1, "USLP Frame CRC-16 check failed");
    assert (ocf_ok_latched      == 1'b1) else $fatal(1, "USLP OCF 0x01040003 extraction failed");
    assert (rx_pkt_cnt == 16) else $fatal(1, $sformatf("Expected 16 reassembled Space Packet bytes, got %0d", rx_pkt_cnt));
    for (int i = 0; i < 16; i++) begin
      assert (rx_pkt_buf[i] == sp16[i]) else $fatal(1, "Reassembled USLP Space Packet byte mismatch");
    end

    // 2. Stream a 16-byte Idle Space Packet (APID = 11'h7FF) and verify automatic stripping
    idle16[0] = 8'h07; idle16[1] = 8'hFF; // APID = 0x7FF (Idle)
    idle16[2] = 8'hC0; idle16[3] = 8'h00;
    idle16[4] = 8'h00; idle16[5] = 8'h09;
    for (int i = 6; i < 16; i++) idle16[i] = 8'h55;

    for (int i = 0; i < 16; i++) begin
      tfdf_tvalid = 1'b1;
      tfdf_tdata  = idle16[i];
      tfdf_tlast  = (i == 15);
      @(posedge clk);
      while (!tfdf_tready) @(posedge clk);
      #1;
    end
    tfdf_tvalid = 1'b0;
    tfdf_tlast  = 1'b0;
    repeat (40) @(posedge clk);
    #1;

    assert (idle_strip_latched == 1'b1) else $fatal(1, "Reassembler failed to strip APID=0x7FF Idle Space Packet");

    $display("[TB-STAGE4 PASS] Multi-Protocol USLP Framer/Deframer, OCF extraction, Space Packet Reassembly & Idle Stripping verified!");
    $finish;
  end

endmodule : tb_stage4_multiprotocol
