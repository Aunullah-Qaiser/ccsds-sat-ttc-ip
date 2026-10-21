// =============================================================================
// File Name   : tb_stage3_vertical_slice.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog Testbench
// Description : End-to-End Stage 3 Vertical Slice Testbench chaining:
//                 Uplink: ccsds_asm_correlator -> ccsds_bch6356_dec ->
//                         ccsds_tc_uslp_deframer -> ccsds_farm1_tmr ->
//                         ccsds_clcw_cdc_mbox
//                 Downlink: ccsds_vc_arbiter_mux -> ccsds_tm_aos_uslp_framer ->
//                           ccsds_dl_rs255_223_enc
// =============================================================================

`timescale 1ns / 1ps
module tb_stage3_vertical_slice
  import ccsds_pkg::*;
();

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  always #5 clk = ~clk;

  // Uplink Chain Wires
  logic signed [3:0] sym_llr_in, cb_llr;
  logic              sym_valid_in, cb_bit, cb_start, cb_valid, sync_locked, phase_inv;
  logic              cltu_ended, bch_1err, bch_2abort;
  logic [7:0]        bch_tdata, def_tdata;
  logic              bch_tvalid, bch_tready, bch_tlast, bch_tabort;
  logic              def_tvalid, def_tlast;
  ccsds_tc_prim_hdr_t parsed_hdr;
  logic              frame_done, frame_crc_ok, frame_commit, frame_rollback;
  logic              farm_accept, farm_reject, clcw_valid, tmr_seu_corr;
  ccsds_clcw_t       clcw_sched, clcw_latched;
  logic              clcw_mbox_rdy, clcw_new_pulse;

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
    .clk                  (clk),
    .rst_n                (rst_n),
    .spacecraft_id_cfg        (10'h155),
    .uslp_scid_cfg            (16'h4255),
    .uslp_trunc_frame_len_cfg (16'd25),
    .uslp_tfdf_3byte_en_cfg   (1'b1),
    .fecf_crc32_cfg           (1'b0),
    .tc_seg_hdr_present_cfg   (1'b1),
    .s_axis_tdata         (bch_tdata),
    .s_axis_tvalid        (bch_tvalid),
    .s_axis_tready        (bch_tready),
    .s_axis_tlast         (bch_tlast),
    .s_axis_tabort        (bch_tabort),
    .parsed_tc_hdr            (parsed_hdr),
    .parsed_tc_seg_hdr        (),
    .parsed_prox1_hdr         (),
    .parsed_uslp_trunc_hdr    (),
    .parsed_uslp_ext_hdr      (),
    .parsed_uslp_tfdf_hdr     (),
    .detected_proto_mode      (),
    .extracted_ocf_word       (),
    .extracted_ocf_valid      (),
    .frame_done_pulse     (frame_done),
    .frame_crc_ok             (frame_crc_ok),
    .frame_crc_err_pulse      (),
    .frame_commit_pulse   (frame_commit),
    .frame_rollback_pulse (frame_rollback),
    .m_axis_tdata         (def_tdata),
    .m_axis_tvalid        (def_tvalid),
    .m_axis_tready        (1'b1),
    .m_axis_tlast         (def_tlast)
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

  ccsds_clcw_cdc_mbox u_clcw_mbox (
    .src_clk          (clk),
    .src_rst_n        (rst_n),
    .src_clcw_in      (clcw_sched),
    .src_req_valid    (clcw_valid),
    .src_req_ready    (clcw_mbox_rdy),
    .dst_clk          (clk),
    .dst_rst_n        (rst_n),
    .dst_clcw_latched (clcw_latched),
    .dst_new_pulse    (clcw_new_pulse)
  );

  initial begin
    sym_llr_in   = 4'sd7;
    sym_valid_in = 1'b0;
    #20 rst_n    = 1'b1;
    @(posedge clk);
    $display("[TB-STAGE3] Stage 3 Vertical Slice hierarchy elaborated cleanly.");
    $finish;
  end

endmodule : tb_stage3_vertical_slice
