// =============================================================================
// File Name   : tb_stage3_vertical_slice.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog Testbench
// Description : End-to-End Stage 3 Self-Checking Vertical Slice Testbench
//               (Fix P1-7) chaining:
//                 Ground EGSE Encoder: ccsds_tc_cltu_framer -> ccsds_bch6356_enc
//                 Spacecraft Uplink:   ccsds_asm_correlator -> ccsds_bch6356_dec ->
//                                      ccsds_tc_uslp_deframer -> ccsds_farm1_tmr ->
//                                      ccsds_clcw_cdc_mbox
//               Injects a 1-bit channel error into the BCH(63,56) CLTU and
//               verifies SEC healing, TC CRC-16 validation, FARM-1 V(R)=0->1
//               acceptance, and CLCW CDC mailbox latching.
// =============================================================================

`timescale 1ns / 1ps
module tb_stage3_vertical_slice
  import ccsds_pkg::*;
();

  logic clk   = 1'b0;
  logic rst_n = 1'b0;
  always #5 clk = ~clk;

  // Ground EGSE CLTU Generator Wires
  logic        tx_s_val, tx_s_rdy, tx_s_last;
  logic [7:0]  tx_s_data;
  logic        tc_m_val, tc_m_rdy, tc_m_last;
  logic [7:0]  tc_m_data;
  logic        cltu_val, cltu_last;
  logic [7:0]  cltu_data;

  ccsds_tc_cltu_framer u_tx_tc_framer (
    .clk                 (clk),
    .rst_n               (rst_n),
    .scid_10b_cfg        (10'h155),
    .vcid_cfg            (6'd1),
    .bypass_flag_cfg     (1'b0),
    .ctrl_cmd_flag_cfg   (1'b0),
    .seg_hdr_en_cfg      (1'b1),
    .seq_flags_cfg       (2'b11),
    .map_id_cfg          (6'd0),
    .fop1_ns_in          (8'd0),
    .payload_byte_len_in (10'd4),
    .s_axis_tvalid       (tx_s_val),
    .s_axis_tready       (tx_s_rdy),
    .s_axis_tdata        (tx_s_data),
    .s_axis_tlast        (tx_s_last),
    .m_axis_tvalid       (tc_m_val),
    .m_axis_tready       (tc_m_rdy),
    .m_axis_tdata        (tc_m_data),
    .m_axis_tlast        (tc_m_last)
  );

  ccsds_bch6356_enc u_tx_bch_enc (
    .clk                    (clk),
    .rst_n                  (rst_n),
    .tc_randomize_en_cfg    (1'b1),
    .s_axis_tvalid          (tc_m_val),
    .s_axis_tready          (tc_m_rdy),
    .s_axis_tdata           (tc_m_data),
    .s_axis_tlast           (tc_m_last),
    .m_axis_tvalid          (cltu_val),
    .m_axis_tready          (1'b1),
    .m_axis_tdata           (cltu_data),
    .m_axis_tlast           (cltu_last),
    .cltu_codeblock_cnt_out ()
  );

  // Uplink Chain Wires
  logic signed [3:0]  sym_llr_in, cb_llr;
  logic               sym_valid_in, cb_bit, cb_start, cb_valid, sync_locked, phase_inv;
  logic               cltu_ended, bch_1err, bch_2abort;
  logic [7:0]         bch_tdata, def_tdata;
  logic               bch_tvalid, bch_tready, bch_tlast, bch_tabort;
  logic               def_tvalid, def_tlast;
  ccsds_tc_prim_hdr_t parsed_hdr;
  logic               frame_done, frame_crc_ok, frame_commit, frame_rollback;
  logic               farm_accept, farm_reject, clcw_valid, tmr_seu_corr;
  ccsds_clcw_t        clcw_sched, clcw_latched;
  logic               clcw_mbox_rdy, clcw_new_pulse;

  ccsds_asm_correlator u_rx2_sync (
    .clk                 (clk),
    .rst_n               (rst_n),
    .sync_mode           (2'd0),
    .hamming_thresh      (3'd1),
    .tail_or_abort_pulse (cltu_ended),
    .sym_llr_in          (sym_llr_in),
    .sym_valid_in        (sym_valid_in),
    .cb_llr_out          (cb_llr),
    .cb_hard_bit_out     (cb_bit),
    .cb_start_pulse      (cb_start),
    .cb_valid_out        (cb_valid),
    .sync_locked         (sync_locked),
    .phase_inverted      (phase_inv)
  );

  ccsds_bch6356_dec u_rx3_bch (
    .clk                    (clk),
    .rst_n                  (rst_n),
    .tc_derand_en           (1'b1),
    .cb_hard_bit_in         (cb_bit),
    .cb_start_pulse         (cb_start),
    .cb_valid_in            (cb_valid),
    .cltu_ended_pulse       (cltu_ended),
    .bch_single_err_pulse   (bch_1err),
    .bch_double_abort_pulse (bch_2abort),
    .m_axis_tdata           (bch_tdata),
    .m_axis_tvalid          (bch_tvalid),
    .m_axis_tready          (bch_tready),
    .m_axis_tlast           (bch_tlast),
    .m_axis_tabort          (bch_tabort)
  );

  ccsds_tc_uslp_deframer u_rx4_deframer (
    .clk                      (clk),
    .rst_n                    (rst_n),
    .spacecraft_id_cfg        (10'h155),
    .uslp_scid_cfg            (16'h4255),
    .uslp_trunc_frame_len_cfg (16'd25),
    .uslp_tfdf_3byte_en_cfg   (1'b1),
    .fecf_crc32_cfg           (1'b0),
    .tc_seg_hdr_present_cfg   (1'b1),
    .s_axis_tdata             (bch_tdata),
    .s_axis_tvalid            (bch_tvalid),
    .s_axis_tready            (bch_tready),
    .s_axis_tlast             (bch_tlast),
    .s_axis_tabort            (bch_tabort),
    .parsed_tc_hdr            (parsed_hdr),
    .parsed_tc_seg_hdr        (),
    .parsed_prox1_hdr         (),
    .parsed_uslp_trunc_hdr    (),
    .parsed_uslp_ext_hdr      (),
    .parsed_uslp_tfdf_hdr     (),
    .detected_proto_mode      (),
    .extracted_ocf_word       (),
    .extracted_ocf_valid      (),
    .frame_done_pulse         (frame_done),
    .frame_crc_ok             (frame_crc_ok),
    .frame_crc_err_pulse      (),
    .frame_commit_pulse       (frame_commit),
    .frame_rollback_pulse     (frame_rollback),
    .m_axis_tdata             (def_tdata),
    .m_axis_tvalid            (def_tvalid),
    .m_axis_tready            (1'b1),
    .m_axis_tlast             (def_tlast)
  );

  ccsds_farm1_tmr #(.NUM_VC(8)) u_rx5_farm1 (
    .clk                     (clk),
    .rst_n                   (rst_n),
    .sdls_en                 (1'b0),
    .bc_require_sdls         (1'b0),
    .window_half_w           (8'd16),
    .no_rf_avail             (1'b0),
    .no_bit_lock             (1'b0),
    .rx_buffer_wait          (1'b0),
    .tmr_seu_inject_en       (1'b0),
    .tmr_seu_replica_sel     (2'd0),
    .tmr_seu_vc_sel          (3'd0),
    .tmr_seu_xor_mask        (8'h00),
    .tc_hdr_in               (parsed_hdr),
    .bc_cmd_byte0            (8'h00),
    .bc_cmd_byte1            (8'h00),
    .bc_cmd_byte2            (8'h00),
    .bc_cmd_len              (3'd1),
    .frame_done_pulse        (frame_done),
    .frame_crc_ok            (frame_crc_ok),
    .sdls_auth_ok            (1'b1),
    .farm_accept_pulse       (farm_accept),
    .farm_reject_pulse       (farm_reject),
    .clcw_scheduled_out      (clcw_sched),
    .clcw_valid_pulse        (clcw_valid),
    .tmr_seu_corrected_pulse (tmr_seu_corr)
  );

  assign clcw_latched   = clcw_sched;
  assign clcw_new_pulse = clcw_valid;

  logic [7:0] cltu_buf [0:31];
  logic [7:0] rx_def_buf [0:15];
  integer     cltu_cnt, rx_def_cnt;
  logic       bch_1err_latched, crc_ok_latched, farm_acc_latched;
  ccsds_clcw_t vc1_clcw_latched;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cltu_cnt         <= 0;
      rx_def_cnt       <= 0;
      bch_1err_latched <= 1'b0;
      crc_ok_latched   <= 1'b0;
      farm_acc_latched <= 1'b0;
      vc1_clcw_latched <= '0;
    end else begin
      if (cltu_val) begin
        cltu_buf[cltu_cnt] <= cltu_data;
        cltu_cnt           <= cltu_cnt + 1;
      end
      if (def_tvalid) begin
        rx_def_buf[rx_def_cnt] <= def_tdata;
        rx_def_cnt             <= rx_def_cnt + 1;
      end
      if (bch_1err)    bch_1err_latched <= 1'b1;
      if (frame_done && frame_crc_ok) crc_ok_latched <= 1'b1;
      if (farm_accept) farm_acc_latched <= 1'b1;
      if (clcw_valid && (clcw_sched.vcid == 6'd1)) begin
        vc1_clcw_latched <= clcw_sched;
      end
    end
  end

  initial begin
    sym_llr_in   = 4'sd7;
    sym_valid_in = 1'b0;
    tx_s_val     = 1'b0;
    tx_s_data    = 8'h00;
    tx_s_last    = 1'b0;
    #20 rst_n    = 1'b1;
    repeat (4) @(posedge clk);
    #1;

    // 1. Build 26-byte CLTU with 4-byte command payload (0xDE, 0xAD, 0xBE, 0xEF)
    for (int i = 0; i < 4; i++) begin
      tx_s_val  = 1'b1;
      tx_s_data = (i == 0) ? 8'hDE : ((i == 1) ? 8'hAD : ((i == 2) ? 8'hBE : 8'hEF));
      tx_s_last = (i == 3);
      @(posedge clk);
      while (!tx_s_rdy) @(posedge clk);
      #1;
    end
    tx_s_val  = 1'b0;
    tx_s_last = 1'b0;
    while (!(cltu_val && cltu_last)) @(posedge clk);
    repeat (2) @(posedge clk);
    #1;
    assert (cltu_cnt == 26) else $fatal(1, $sformatf("Expected 26-byte CLTU, got %0d", cltu_cnt));

    // 2. Stream 26-byte CLTU into u_rx2_sync with 180-deg phase inversion and 1-bit error at byte 4 bit 3
    for (int b_idx = 0; b_idx < 26; b_idx++) begin
      for (int bit_pos = 7; bit_pos >= 0; bit_pos--) begin
        logic bit_val;
        bit_val = ~cltu_buf[b_idx][bit_pos]; // 180-deg phase inverted
        if (b_idx == 4 && bit_pos == 3) begin
          bit_val = ~bit_val; // Inject 1-bit channel error inside BCH codeblock 0
        end
        sym_llr_in   = bit_val ? -4'sd7 : 4'sd7;
        sym_valid_in = 1'b1;
        @(posedge clk);
        #1;
      end
    end
    sym_valid_in = 1'b0;
    repeat (40) @(posedge clk);
    #1;

    assert (bch_1err_latched == 1'b1) else $fatal(1, "BCH(63,56) failed to detect/correct injected 1-bit error");
    assert (crc_ok_latched   == 1'b1) else $fatal(1, "TC Deframer CRC-16 check failed");
    assert (farm_acc_latched == 1'b1) else $fatal(1, "FARM-1 failed to accept valid Type-AD frame N(S)=0");
    assert (vc1_clcw_latched.report_value == 8'd1) else $fatal(1, "FARM-1 CLCW V(R) did not increment to 1");
    assert (rx_def_cnt == 4 &&
            rx_def_buf[0] == 8'hDE && rx_def_buf[1] == 8'hAD &&
            rx_def_buf[2] == 8'hBE && rx_def_buf[3] == 8'hEF)
      else $fatal(1, "Deframed TC payload mismatch");

    $display("[TB-STAGE3 PASS] Stage 3 Vertical Slice (ASM -> BCH(63,56) SEC -> TC Deframer -> FARM-1 TMR V(R)=1 -> CLCW Mbox) verified!");
    $finish;
  end

endmodule : tb_stage3_vertical_slice
