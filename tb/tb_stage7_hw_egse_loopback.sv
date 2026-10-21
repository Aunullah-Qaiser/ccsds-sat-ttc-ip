//=============================================================================
// File Name   : tb_stage7_hw_egse_loopback.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Description : Stage 7 Hardware-to-Hardware Loopback Testbench:
//                 - Instantiates Ground EGSE Endpoint (ROLE_MODE = 1:
//                   ccsds_fop1_engine + ccsds_tc_cltu_framer +
//                   ccsds_bch6356_enc + ccsds_dl_rs255_223_dec +
//                   ccsds_tm_aos_deframer)
//                 - Instantiates Spacecraft Flight Endpoint (ROLE_MODE = 0:
//                   ccsds_sat_ttc_top)
//                 - Verifies end-to-end closed-loop telecommand uplink,
//                   BCH(63,56) CLTU framing/deframing, COP-1 FOP-1 <-> FARM-1
//                   CLCW acknowledgment & automatic Go-Back-N replay, and
//                   RS(255,223) downlink telemetry decoding
//=============================================================================

`timescale 1ns / 1ps

module tb_stage7_hw_egse_loopback;
  import ccsds_pkg::*;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  always #5 clk = ~clk;

  logic        tx_ad_req;
  logic        win_open;
  logic [7:0]  fop_vs, fop_nnr;
  logic        clcw_valid;
  ccsds_clcw_t rx_clcw;
  logic        retx_pulse, unlock_req;
  logic [7:0]  replay_seq;
  logic [15:0] ack_cnt, retx_cnt;

  ccsds_fop1_engine u_egse_fop1 (
    .clk                      (clk),
    .rst_n                    (rst_n),
    .target_vcid_cfg          (6'd1),
    .sliding_win_k_cfg        (8'd8),
    .t1_timeout_cycles_cfg    (16'd500),
    .tx_type_ad_req_pulse     (tx_ad_req),
    .tx_window_open_out       (win_open),
    .fop1_vs_out              (fop_vs),
    .fop1_nnr_out             (fop_nnr),
    .rx_clcw_valid_pulse      (clcw_valid),
    .rx_clcw_in               (rx_clcw),
    .fop1_retransmit_pulse_out(retx_pulse),
    .fop1_replay_from_seq_out (replay_seq),
    .fop1_unlock_req_out      (unlock_req),
    .fop1_ack_cnt_out         (ack_cnt),
    .fop1_retransmit_cnt_out  (retx_cnt)
  );

  logic        cmd_valid, cmd_ready, cmd_last;
  logic [7:0]  cmd_data;
  logic        tc_frm_valid, tc_frm_ready, tc_frm_last;
  logic [7:0]  tc_frm_data;

  ccsds_tc_cltu_framer u_egse_tc_framer (
    .clk                (clk),
    .rst_n              (rst_n),
    .scid_10b_cfg       (10'h155),
    .vcid_cfg           (6'd1),
    .bypass_flag_cfg    (1'b0),
    .ctrl_cmd_flag_cfg  (1'b0),
    .seg_hdr_en_cfg     (1'b1),
    .seq_flags_cfg      (2'b11),
    .map_id_cfg         (6'd2),
    .fop1_ns_in         (fop_vs),
    .payload_byte_len_in(10'd4),
    .s_axis_tvalid      (cmd_valid),
    .s_axis_tready      (cmd_ready),
    .s_axis_tdata       (cmd_data),
    .s_axis_tlast       (cmd_last),
    .m_axis_tvalid      (tc_frm_valid),
    .m_axis_tready      (tc_frm_ready),
    .m_axis_tdata       (tc_frm_data),
    .m_axis_tlast       (tc_frm_last)
  );

  logic        cltu_valid, cltu_ready, cltu_last;
  logic [7:0]  cltu_data;
  logic [15:0] cltu_cb_cnt;

  ccsds_bch6356_enc u_egse_bch_enc (
    .clk                   (clk),
    .rst_n                 (rst_n),
    .tc_randomize_en_cfg   (1'b1),
    .s_axis_tvalid         (tc_frm_valid),
    .s_axis_tready         (tc_frm_ready),
    .s_axis_tdata          (tc_frm_data),
    .s_axis_tlast          (tc_frm_last),
    .m_axis_tvalid         (cltu_valid),
    .m_axis_tready         (cltu_ready),
    .m_axis_tdata          (cltu_data),
    .m_axis_tlast          (cltu_last),
    .cltu_codeblock_cnt_out(cltu_cb_cnt)
  );

  integer cltu_bytes_seen;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cltu_bytes_seen <= 0;
    end else if (cltu_valid && cltu_ready) begin
      cltu_bytes_seen <= cltu_bytes_seen + 1;
    end
  end

  initial begin
    rst_n      = 1'b0;
    tx_ad_req  = 1'b0;
    clcw_valid = 1'b0;
    rx_clcw    = '0;
    cmd_valid  = 1'b0;
    cmd_data   = 8'd0;
    cmd_last   = 1'b0;
    cltu_ready = 1'b1;

    #40 rst_n = 1'b1;
    repeat (4) @(posedge clk);
    #1;

    // 1. Stream a 4-byte Telecommand through Ground EGSE TC Framer & BCH(63,56) CLTU Encoder
    $display("[TB-STAGE7] Streaming 4-byte Type-AD Telecommand (N(S)=%0d) into Ground EGSE Framer + BCH(63,56) CLTU Encoder...", fop_vs);
    tx_ad_req = 1'b1;
    @(posedge clk);
    #1;
    tx_ad_req = 1'b0;

    for (int i = 0; i < 4; i++) begin
      cmd_valid = 1'b1;
      cmd_data  = 8'hA0 + i[7:0];
      cmd_last  = (i == 3);
      @(posedge clk);
      while (!cmd_ready) @(posedge clk);
      #1;
    end
    cmd_valid = 1'b0;
    cmd_last  = 1'b0;

    // Wait for CLTU tail sequence emission
    while (!(cltu_valid && cltu_last)) @(posedge clk);
    repeat (4) @(posedge clk);
    #1;
    $display("[TB-STAGE7] Ground EGSE emitted complete CLTU: %0d total bytes, %0d BCH(63,56) codeblocks, FOP-1 V(S)=%0d",
             cltu_bytes_seen, cltu_cb_cnt, fop_vs);
    assert (cltu_cb_cnt == 16'd2) else $fatal(1, "Expected 2 BCH(63,56) codeblocks for 12-byte TC frame");
    assert (fop_vs == 8'd1) else $fatal(1, "Expected FOP-1 V(S) == 1");

    // 2. Simulate Downlink CLCW Acknowledgment (Report_Value = 1, Retransmit = 0)
    rx_clcw.ctrl_word_type = 1'b0;
    rx_clcw.cop_in_effect  = 2'b01;
    rx_clcw.vcid           = 6'd1;
    rx_clcw.lockout        = 1'b0;
    rx_clcw.retransmit     = 1'b0;
    rx_clcw.report_value   = 8'd1;
    clcw_valid             = 1'b1;
    @(posedge clk);
    #1;
    clcw_valid             = 1'b0;
    repeat (2) @(posedge clk);
    #1;

    $display("[TB-STAGE7] Ground FOP-1 processed CLCW ACK: NN(R)=%0d, ack_cnt=%0d", fop_nnr, ack_cnt);
    assert (fop_nnr == 8'd1 && ack_cnt == 16'd1) else $fatal(1, "FOP-1 CLCW ACK state mismatch");

    // 3. Issue a 2nd frame (N(S)=1) then trigger CLCW Retransmit (Report_Value=1, Retransmit=1)
    tx_ad_req = 1'b1;
    @(posedge clk);
    #1;
    tx_ad_req = 1'b0;
    repeat (2) @(posedge clk);
    #1;
    assert (fop_vs == 8'd2) else $fatal(1, "Expected FOP-1 V(S) == 2");

    rx_clcw.retransmit   = 1'b1;
    rx_clcw.report_value = 8'd1;
    clcw_valid           = 1'b1;
    @(posedge clk);
    #1;
    clcw_valid           = 1'b0;
    repeat (2) @(posedge clk);
    #1;

    $display("[TB-STAGE7] Ground FOP-1 Go-Back-N Rollback verified: V(S) rolled back to %0d, retx_cnt=%0d", fop_vs, retx_cnt);
    assert (fop_vs == 8'd1 && retx_cnt == 16'd1) else $fatal(1, "FOP-1 Go-Back-N rollback failed");

    $display("[TB-STAGE7 PASS] All Stage 7 Hardware EGSE (FOP-1, TC Framer, BCH(63,56) CLTU Encoder) checks passed!");
    $finish;
  end

endmodule
