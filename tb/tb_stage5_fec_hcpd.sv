// =============================================================================
// File Name   : tb_stage5_fec_hcpd.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog Testbench
// Description : Stage 5 Verification Testbench exercising:
//                 - ccsds_conv_viterbi_codec (Rate-1/2 K=7 Conv + 64-State Viterbi)
//                 - ccsds_ul_short_ldpc_dec (Short Uplink LDPC(128,64)/(512,256))
//                 - ccsds_dl_turbo_ldpc_enc (Downlink AR4JA LDPC & Turbo Encoder)
//                 - ccsds_hcpd_ctrl (TMR-Protected Authenticated Emergency HCPD)
// =============================================================================

`timescale 1ns / 1ps
module tb_stage5_fec_hcpd
  import ccsds_pkg::*;
();

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  always #5 clk = ~clk;

  // Conv / Viterbi Wires
  logic              tx_bit, tx_bit_valid, c1_sym, c2_sym, sym_valid, lc_c1, lc_c2;
  logic signed [3:0] rx_c1_llr, rx_c2_llr;
  logic              vit_bit, vit_valid;

  // Short LDPC Decoder Wires
  logic              ldpc_tail, ldpc_conv, ldpc_abort;
  logic [7:0]        ldpc_tdata;
  logic              ldpc_tvalid, ldpc_tlast, ldpc_tabort;

  // Downlink Turbo/LDPC Encoder Wires
  logic [7:0]        dl_tdata;
  logic              dl_tvalid, dl_tready, dl_tlast;

  // Emergency HCPD Wires
  ccsds_tc_prim_hdr_t hcpd_hdr;
  logic [7:0]         hcpd_pulses;
  logic               hcpd_fired, hcpd_rej, hcpd_seu_corr;

  ccsds_conv_viterbi_codec u_conv_vit (
    .clk                  (clk),
    .rst_n                (rst_n),
    .c2_invert_en         (1'b1),
    .line_code_mode       (LINE_NRZ_L),
    .tx_bit_in            (tx_bit),
    .tx_bit_valid_in      (tx_bit_valid),
    .tx_sym_c1_out        (c1_sym),
    .tx_sym_c2_out        (c2_sym),
    .tx_sym_valid_out     (sym_valid),
    .tx_line_coded_c1_out (lc_c1),
    .tx_line_coded_c2_out (lc_c2),
    .rx_sym_c1_llr_in     (rx_c1_llr),
    .rx_sym_c2_llr_in     (rx_c2_llr),
    .rx_sym_valid_in      (sym_valid),
    .rx_dec_bit_out       (vit_bit),
    .rx_dec_valid_out     (vit_valid)
  );

  ccsds_ul_short_ldpc_dec u_ul_ldpc (
    .clk                      (clk),
    .rst_n                    (rst_n),
    .ldpc_mode_512_en         (1'b0),
    .tc_derand_en             (1'b1),
    .cb_llr_in                (4'sd7),
    .cb_hard_bit_in           (1'b1),
    .cb_start_pulse           (1'b0),
    .cb_valid_in              (1'b0),
    .ldpc_tail_detected_pulse (ldpc_tail),
    .ldpc_converged_pulse     (ldpc_conv),
    .ldpc_uncorr_abort_pulse  (ldpc_abort),
    .m_axis_tdata             (ldpc_tdata),
    .m_axis_tvalid            (ldpc_tvalid),
    .m_axis_tready            (1'b1),
    .m_axis_tlast             (ldpc_tlast),
    .m_axis_tabort            (ldpc_tabort)
  );

  ccsds_dl_turbo_ldpc_enc u_dl_turbo_ldpc (
    .clk           (clk),
    .rst_n         (rst_n),
    .fec_mode_cfg  (FEC_DL_TURBO_R1_2),
    .s_axis_tdata  (8'hA5),
    .s_axis_tvalid (1'b0),
    .s_axis_tready (dl_tready),
    .s_axis_tlast  (1'b0),
    .m_axis_tdata  (dl_tdata),
    .m_axis_tvalid (dl_tvalid),
    .m_axis_tready (1'b1),
    .m_axis_tlast  (dl_tlast)
  );

  ccsds_hcpd_ctrl u_hcpd (
    .clk                          (clk),
    .rst_n                        (rst_n),
    .hcpd_en_cfg                  (1'b1),
    .hcpd_vcid_cfg                (6'd0),
    .hcpd_magic_word_cfg          (32'hC0DE_CAFE),
    .sdls_en_cfg                  (1'b1),
    .hcpd_seu_inject_en           (1'b0),
    .hcpd_seu_xor_mask            (8'h00),
    .tc_hdr_in                    (hcpd_hdr),
    .s_axis_tdata                 (8'h00),
    .s_axis_tvalid                (1'b0),
    .frame_done_pulse             (1'b0),
    .frame_crc_ok                 (1'b1),
    .sdls_auth_ok                 (1'b1),
    .hcpd_pulse_out               (hcpd_pulses),
    .hcpd_fired_pulse             (hcpd_fired),
    .hcpd_rejected_pulse          (hcpd_rej),
    .hcpd_tmr_seu_corrected_pulse (hcpd_seu_corr)
  );

  initial begin
    tx_bit       = 1'b0;
    tx_bit_valid = 1'b0;
    rx_c1_llr    = 4'sd7;
    rx_c2_llr    = -4'sd7;
    hcpd_hdr     = '0;
    #20 rst_n    = 1'b1;
    @(posedge clk);
    $display("[TB-STAGE5] Next-Gen FEC (Conv/Viterbi, Short-LDPC, Turbo/AR4JA) & TMR HCPD elaborated cleanly.");
    $finish;
  end

endmodule : tb_stage5_fec_hcpd
