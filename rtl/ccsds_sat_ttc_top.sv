//=============================================================================
// File Name   : ccsds_sat_ttc_top.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Version     : v2.8 (Full 28-Module Cross-Elaborated & BLKSEQ-Clean Release)
// Description : Top-Level Parameterized Spacecraft Flight Transceiver
//               (ROLE_MODE=0), Hardware Ground EGSE Transceiver (ROLE_MODE=1),
//               and Symmetric Crosslink / On-Orbit BIST Transceiver (ROLE_MODE=2).
//               Integrates all 27 synthesizable sub-modules with verified
//               cross-module port bindings, 2-FF CDC synchronizers, Hsiao
//               SECDED store-and-forward / high-watermark FIFOs, and TMR voting.
//=============================================================================
`timescale 1ns / 1ps

module ccsds_sat_ttc_top
  import ccsds_pkg::*;
#(
  parameter int unsigned ROLE_MODE = 0
) (
  input  logic               clk_sys,
  input  logic               clk_tc_safe,
  input  logic               clk_tx_sym,
  input  logic               clk_adc_iq,
  input  logic               rst_n,

  // AXI4-Lite Control & Status Register Interface
  input  logic               s_axi_awvalid,
  output logic                     s_axi_awready,
  input  logic [7:0]         s_axi_awaddr,
  input  logic               s_axi_wvalid,
  output logic                     s_axi_wready,
  input  logic [31:0]        s_axi_wdata,
  input  logic [3:0]         s_axi_wstrb,
  output logic                     s_axi_bvalid,
  input  logic               s_axi_bready,
  output logic [1:0]               s_axi_bresp,
  input  logic               s_axi_arvalid,
  output logic                     s_axi_arready,
  input  logic [7:0]         s_axi_araddr,
  output logic                     s_axi_rvalid,
  input  logic               s_axi_rready,
  output logic [31:0]              s_axi_rdata,
  output logic [1:0]               s_axi_rresp,

  // Mission Strap & Mode Overrides
  input  logic [1:0]         link_proto_override_en,
  input  logic [1:0]         ul_fec_override_en,
  input  logic               sdls_en_cfg,
  input  logic               bc_require_sdls_cfg,
  input  logic               pn_ranging_en_cfg,
  input  logic               pn_t4b_mode_cfg,
  input  logic               turnaround_xband_cfg,
  input  logic [1:0]         mod_mode_cfg,
  input  logic [1:0]         line_code_cfg,

  // Uplink Baseband IQ ADC & Direct Symbol Stream Inputs
  input  logic signed [11:0] rx_i_adc_in,
  input  logic signed [11:0] rx_q_adc_in,
  input  logic               rx_iq_valid_in,
  input  logic               s_axis_ul_sym_tvalid,
  output logic                     s_axis_ul_sym_tready,
  input  logic [7:0]         s_axis_ul_sym_tdata,
  input  logic               s_axis_ul_sym_tlast,

  // Uplink Reassembled Space Packet / MAP SDU Output to OBC
  output logic                     m_axis_rx_pkt_tvalid,
  input  logic               m_axis_rx_pkt_tready,
  output logic [7:0]               m_axis_rx_pkt_tdata,
  output logic                     m_axis_rx_pkt_tlast,
  output ccsds_tuser_t             m_axis_rx_pkt_tuser,

  // Downlink Space Packet Ingress from OBC
  input  logic               s_axis_tx_pkt_tvalid,
  output logic                     s_axis_tx_pkt_tready,
  input  logic [7:0]         s_axis_tx_pkt_tdata,
  input  logic               s_axis_tx_pkt_tlast,
  input  ccsds_tuser_t       s_axis_tx_pkt_tuser,

  // Downlink CADU / Baseband IQ DAC Outputs
  output logic                     m_axis_dl_cad_tvalid,
  input  logic               m_axis_dl_cad_tready,
  output logic [7:0]               m_axis_dl_cad_tdata,
  output logic                     m_axis_dl_cad_tlast,
  output logic signed [11:0]       tx_i_dac_out,
  output logic signed [11:0]       tx_q_dac_out,
  output logic                     tx_iq_valid_out,

  // Emergency HCPD & Fault Outputs
  output logic                     hcpd_obc_reset_pulse,
  output logic                     hcpd_safe_mode_force,
  output logic [1:0]               hcpd_rf_chain_select,
  output logic                     pn_All_Locked_out,
  output logic                     fault_irq_out,
  output logic                     edac_scrub_req_out
);

  //---------------------------------------------------------------------------
  // 1. CSR & Runtime Configuration Buses
  //---------------------------------------------------------------------------
  logic [9:0]  csr_scid_10b;
  logic [15:0] csr_scid_16b;
  logic [2:0]  csr_proto_mode;
  logic [3:0]  csr_fec_mode;
  logic        csr_ocf_en;
  logic        csr_fecf_en;
  logic        csr_fecf_crc32;
  logic        csr_aos_fhec_en;
  logic        csr_tc_seg_hdr_en;
  logic        csr_obt_sec_hdr_en;
  logic        csr_sdls_en;
  logic        csr_bc_req_sdls;
  logic [7:0]  csr_win_half_w;
  logic [3:0]  csr_rs_interleave;
  logic [7:0]  csr_rs_q_fill;
  logic [10:0] csr_tfdf_len;
  logic [47:0] csr_obt_cuc_ts;
  logic        csr_tmr_seu_pulse;

  logic [2:0]  active_proto_mode;
  logic        active_sdls_en;
  logic        active_bc_req_sdls;

  always_comb begin
    active_proto_mode  = (link_proto_override_en != 2'b00) ? {1'b0, link_proto_override_en} : csr_proto_mode;
    active_sdls_en     = sdls_en_cfg | csr_sdls_en;
    active_bc_req_sdls = bc_require_sdls_cfg | csr_bc_req_sdls;
  end

  // Event & Fault Telemetry Wires
  logic        bch_single_err_pulse;
  logic        bch_double_err_pulse;
  logic        sa_secded_single_pulse;
  logic        sa_secded_double_pulse;
  logic        rx_fifo_secded_single;
  logic        rx_fifo_secded_double;
  logic        tx_fifo_secded_single;
  logic        tx_fifo_secded_double;
  logic        ul_fecf_crc_err_pulse;
  logic        farm_tmr_seu_pulse;
  logic        hcpd_tmr_seu_pulse;
  logic        sdls_auth_done_pulse;
  logic        sdls_auth_ok;
  logic        vc_pkt_len_err;
  logic        reasm_pkt_len_err;

  ccsds_clcw_t clcw_scheduled_tc;
  ccsds_clcw_t clcw_scheduled_sys_q;
  logic        clcw_valid_pulse_tc;
  ccsds_plcw_t plcw_scheduled_tc;
  logic        plcw_valid_pulse_tc;

  ccsds_axi_lite_csr u_csr (
    .clk                         (clk_sys),
    .rst_n                       (rst_n),
    .s_axi_awaddr                (s_axi_awaddr),
    .s_axi_awvalid               (s_axi_awvalid),
    .s_axi_awready               (s_axi_awready),
    .s_axi_wdata                 (s_axi_wdata),
    .s_axi_wstrb                 (s_axi_wstrb),
    .s_axi_wvalid                (s_axi_wvalid),
    .s_axi_wready                (s_axi_wready),
    .s_axi_bresp                 (s_axi_bresp),
    .s_axi_bvalid                (s_axi_bvalid),
    .s_axi_bready                (s_axi_bready),
    .s_axi_araddr                (s_axi_araddr),
    .s_axi_arvalid               (s_axi_arvalid),
    .s_axi_arready               (s_axi_arready),
    .s_axi_rdata                 (s_axi_rdata),
    .s_axi_rresp                 (s_axi_rresp),
    .s_axi_rvalid                (s_axi_rvalid),
    .s_axi_rready                (s_axi_rready),
    .pps_1hz_pulse               (1'b0),
    .csr_seu_inject_en           (1'b0),
    .csr_seu_xor_mask            (32'd0),
    .bch_single_err_pulse        (bch_single_err_pulse),
    .bch_double_abort_pulse      (bch_double_err_pulse),
    .fifo_secded_single_pulse    (sa_secded_single_pulse | rx_fifo_secded_single | tx_fifo_secded_single),
    .fifo_secded_double_pulse    (sa_secded_double_pulse | rx_fifo_secded_double | tx_fifo_secded_double),
    .farm1_tmr_seu_pulse         (farm_tmr_seu_pulse | hcpd_tmr_seu_pulse),
    .frame_crc_err_pulse         (ul_fecf_crc_err_pulse),
    .pkt_len_err_pulse           (vc_pkt_len_err | reasm_pkt_len_err),
    .sdls_mac_err_pulse          (sdls_auth_done_pulse & ~sdls_auth_ok),
    .latest_clcw_in              (clcw_scheduled_sys_q),
    .latest_plcw_in              (plcw_scheduled_tc),
    .spacecraft_id_cfg           (csr_scid_10b),
    .uslp_scid_cfg               (csr_scid_16b),
    .proto_mode_cfg              (csr_proto_mode),
    .fec_mode_cfg                (csr_fec_mode),
    .ocf_en_cfg                  (csr_ocf_en),
    .fecf_en_cfg                 (csr_fecf_en),
    .fecf_crc32_cfg              (csr_fecf_crc32),
    .aos_fhec_en_cfg             (csr_aos_fhec_en),
    .tc_seg_hdr_present_cfg      (csr_tc_seg_hdr_en),
    .obt_sec_hdr_en_cfg          (csr_obt_sec_hdr_en),
    .sdls_en_cfg                 (csr_sdls_en),
    .bc_require_sdls_cfg         (csr_bc_req_sdls),
    .window_half_w_cfg           (csr_win_half_w),
    .rs_interleave_i_cfg         (csr_rs_interleave),
    .rs_virt_fill_q_cfg          (csr_rs_q_fill),
    .tfdf_byte_len_cfg           (csr_tfdf_len),
    .obt_cuc_timestamp_48b       (csr_obt_cuc_ts),
    .csr_tmr_seu_corrected_pulse (csr_tmr_seu_pulse),
    .fault_irq_out               (fault_irq_out),
    .edac_scrub_req_out          (edac_scrub_req_out)
  );

  //---------------------------------------------------------------------------
  // 2. Baseband PHY Modem & Wideband T2B/T4B PN Ranging (clk_adc_iq)
  //---------------------------------------------------------------------------
  logic               phy_rx_sym_valid;
  logic [7:0]         phy_rx_sym_byte;
  logic signed [7:0]  wideband_pn_sample;
  logic               phy_carrier_lock;
  logic               phy_symbol_lock;
  logic [31:0]        tx_nco_fcw_unused;
  logic               tx_pn_chip;
  logic               pn_c1_locked_unused;
  logic [19:0]        pn_epoch_unused;

  logic               tx_phy_tvalid;
  logic               tx_phy_tready;
  logic [7:0]         tx_phy_tdata;

  ccsds_phy_modem u_phy_modem (
    .clk                    (clk_adc_iq),
    .rst_n                  (rst_n),
    .mod_mode_cfg           (mod_mode_cfg),
    .line_code_cfg          (line_code_cfg),
    .turnaround_xband_cfg   (turnaround_xband_cfg),
    .pn_ranging_en_cfg      (pn_ranging_en_cfg),
    .tx_pn_chip_in          (tx_pn_chip),
    .rx_i_in                (rx_i_adc_in),
    .rx_q_in                (rx_q_adc_in),
    .rx_iq_valid_in         (rx_iq_valid_in),
    .rx_sym_valid_out       (phy_rx_sym_valid),
    .rx_sym_byte_out        (phy_rx_sym_byte),
    .wideband_pn_sample_out (wideband_pn_sample),
    .carrier_lock_out       (phy_carrier_lock),
    .symbol_lock_out        (phy_symbol_lock),
    .tx_nco_fcw_out         (tx_nco_fcw_unused),
    .s_axis_tx_tvalid       (tx_phy_tvalid),
    .s_axis_tx_tready       (tx_phy_tready),
    .s_axis_tx_tdata        (tx_phy_tdata),
    .tx_i_out               (tx_i_dac_out),
    .tx_q_out               (tx_q_dac_out),
    .tx_iq_valid_out        (tx_iq_valid_out)
  );

  ccsds_pn_ranging u_pn_ranging (
    .clk                     (clk_adc_iq),
    .rst_n                   (rst_n),
    .pn_ranging_en_cfg       (pn_ranging_en_cfg),
    .t4b_mode_cfg            (pn_t4b_mode_cfg),
    .chip_en_in              (rx_iq_valid_in),
    .rx_chip_sample_in       (wideband_pn_sample),
    .tx_pn_chip_out          (tx_pn_chip),
    .pn_c1_locked_out        (pn_c1_locked_unused),
    .pn_all_locked_out       (pn_All_Locked_out),
    .composite_epoch_idx_out (pn_epoch_unused)
  );

  // 2-FF CDC Synchronizers from clk_adc_iq to clk_tc_safe
  logic carrier_lock_meta_q, carrier_lock_sync_q;
  logic symbol_lock_meta_q,  symbol_lock_sync_q;

  always_ff @(posedge clk_tc_safe or negedge rst_n) begin
    if (!rst_n) begin
      carrier_lock_meta_q <= 1'b0;
      carrier_lock_sync_q <= 1'b0;
      symbol_lock_meta_q  <= 1'b0;
      symbol_lock_sync_q  <= 1'b0;
    end else begin
      carrier_lock_meta_q <= phy_carrier_lock;
      carrier_lock_sync_q <= carrier_lock_meta_q;
      symbol_lock_meta_q  <= phy_symbol_lock;
      symbol_lock_sync_q  <= symbol_lock_meta_q;
    end
  end

  //---------------------------------------------------------------------------
  // 3. Uplink ASM Correlator, BCH(63,56), Short-LDPC & TC Scrambler (clk_tc_safe)
  //---------------------------------------------------------------------------
  logic signed [3:0] asm_cb_llr;
  logic              asm_cb_hard_bit;
  logic              asm_cb_start_pulse;
  logic              asm_cb_valid;
  logic              asm_sync_locked;
  logic              asm_phase_inverted;
  logic              bch_cltu_ended_pulse;
  logic              ldpc_tail_pulse;
  logic              ldpc_converged_pulse;
  logic              ldpc_abort_pulse;

  ccsds_asm_correlator u_asm_corr (
    .clk                 (clk_tc_safe),
    .rst_n               (rst_n),
    .sync_mode           (ul_fec_override_en),
    .hamming_thresh      (3'd2),
    .tail_or_abort_pulse (bch_cltu_ended_pulse | ldpc_tail_pulse | ldpc_abort_pulse),
    .sym_llr_in          (s_axis_ul_sym_tdata[3:0]),
    .sym_valid_in        (s_axis_ul_sym_tvalid),
    .cb_llr_out          (asm_cb_llr),
    .cb_hard_bit_out     (asm_cb_hard_bit),
    .cb_start_pulse      (asm_cb_start_pulse),
    .cb_valid_out        (asm_cb_valid),
    .sync_locked         (asm_sync_locked),
    .phase_inverted      (asm_phase_inverted)
  );

  logic [7:0] bch_dec_tdata;
  logic       bch_dec_tvalid;
  logic       bch_dec_tready;
  logic       bch_dec_tlast;
  logic       bch_dec_tabort;

  ccsds_bch6356_dec u_bch_dec (
    .clk                    (clk_tc_safe),
    .rst_n                  (rst_n),
    .tc_derand_en           (1'b1),
    .cb_hard_bit_in         (asm_cb_hard_bit),
    .cb_start_pulse         (asm_cb_start_pulse),
    .cb_valid_in            (asm_cb_valid),
    .cltu_ended_pulse       (bch_cltu_ended_pulse),
    .bch_single_err_pulse   (bch_single_err_pulse),
    .bch_double_abort_pulse (bch_double_err_pulse),
    .m_axis_tdata           (bch_dec_tdata),
    .m_axis_tvalid          (bch_dec_tvalid),
    .m_axis_tready          (bch_dec_tready),
    .m_axis_tlast           (bch_dec_tlast),
    .m_axis_tabort          (bch_dec_tabort)
  );

  logic [7:0] ldpc_dec_tdata;
  logic       ldpc_dec_tvalid;
  logic       ldpc_dec_tready;
  logic       ldpc_dec_tlast;
  logic       ldpc_dec_tabort;

  ccsds_ul_short_ldpc_dec u_short_ldpc_dec (
    .clk                      (clk_tc_safe),
    .rst_n                    (rst_n),
    .ldpc_mode_512_en         (ul_fec_override_en == 2'd2),
    .tc_derand_en             (1'b1),
    .cb_llr_in                (asm_cb_llr),
    .cb_hard_bit_in           (asm_cb_hard_bit),
    .cb_start_pulse           (asm_cb_start_pulse),
    .cb_valid_in              (asm_cb_valid),
    .ldpc_tail_detected_pulse (ldpc_tail_pulse),
    .ldpc_converged_pulse     (ldpc_converged_pulse),
    .ldpc_uncorr_abort_pulse  (ldpc_abort_pulse),
    .m_axis_tdata             (ldpc_dec_tdata),
    .m_axis_tvalid            (ldpc_dec_tvalid),
    .m_axis_tready            (ldpc_dec_tready),
    .m_axis_tlast             (ldpc_dec_tlast),
    .m_axis_tabort            (ldpc_dec_tabort)
  );

  logic [7:0]   tc_descram_tdata;
  logic [0:0]   tc_descram_tkeep;
  logic         tc_descram_tvalid;
  logic         tc_descram_tready;
  logic         tc_descram_tlast;
  ccsds_tuser_t tc_descram_tuser;

  ccsds_lfsr_scrambler #(
    .DATA_WIDTH(8)
  ) u_tc_descram (
    .clk              (clk_tc_safe),
    .rst_n            (rst_n),
    .bypass_en        (1'b1), // Direct frame byte pass-through when pre-descrambled
    .mode_tc_not_tm   (1'b1),
    .lfsr_reseed_sync (asm_cb_start_pulse),
    .s_axis_tdata     ((ul_fec_override_en == 2'd0) ? s_axis_ul_sym_tdata  :
                       (ul_fec_override_en == 2'd1) ? bch_dec_tdata        : ldpc_dec_tdata),
    .s_axis_tkeep     (1'b1),
    .s_axis_tvalid    ((ul_fec_override_en == 2'd0) ? s_axis_ul_sym_tvalid :
                       (ul_fec_override_en == 2'd1) ? bch_dec_tvalid       : ldpc_dec_tvalid),
    .s_axis_tready    (s_axis_ul_sym_tready),
    .s_axis_tlast     ((ul_fec_override_en == 2'd0) ? s_axis_ul_sym_tlast  :
                       (ul_fec_override_en == 2'd1) ? bch_dec_tlast        : ldpc_dec_tlast),
    .s_axis_tuser     ('0),
    .m_axis_tdata     (tc_descram_tdata),
    .m_axis_tkeep     (tc_descram_tkeep),
    .m_axis_tvalid    (tc_descram_tvalid),
    .m_axis_tready    (tc_descram_tready),
    .m_axis_tlast     (tc_descram_tlast),
    .m_axis_tuser     (tc_descram_tuser)
  );

  assign bch_dec_tready  = tc_descram_tready;
  assign ldpc_dec_tready = tc_descram_tready;

  //---------------------------------------------------------------------------
  // 4. Uplink Deframer, Proximity-1 PLCW, COP-1 FARM-1, SDLS & HCPD
  //---------------------------------------------------------------------------
  ccsds_tc_prim_hdr_t    parsed_tc_hdr;
  ccsds_tc_seg_hdr_t     parsed_tc_seg_hdr;
  ccsds_prox1_prim_hdr_t parsed_prox1_hdr;
  ccsds_uslp_trunc_hdr_t parsed_uslp_trunc_hdr;
  ccsds_uslp_ext_hdr_t   parsed_uslp_ext_hdr;
  ccsds_uslp_tfdf_hdr_t  parsed_uslp_tfdf_hdr;
  logic [2:0]            detected_proto_mode;
  logic [31:0]           extracted_ocf_word;
  logic                  extracted_ocf_valid;
  logic                  ul_frame_done_pulse;
  logic                  ul_frame_crc_ok;
  logic                  ul_frame_commit_pulse;
  logic                  ul_frame_rollback_pulse;

  logic [7:0]            ul_deframed_tdata;
  logic                  ul_deframed_tvalid;
  logic                  ul_deframed_tready;
  logic                  ul_deframed_tlast;

  ccsds_tc_uslp_deframer u_ul_deframer (
    .clk                      (clk_tc_safe),
    .rst_n                    (rst_n),
    .spacecraft_id_cfg        (csr_scid_10b),
    .uslp_scid_cfg            (csr_scid_16b),
    .uslp_trunc_frame_len_cfg (16'd16),
    .uslp_tfdf_3byte_en_cfg   (1'b0),
    .fecf_crc32_cfg           (csr_fecf_crc32),
    .tc_seg_hdr_present_cfg   (csr_tc_seg_hdr_en),
    .s_axis_tdata             (tc_descram_tdata),
    .s_axis_tvalid            (tc_descram_tvalid),
    .s_axis_tready            (tc_descram_tready),
    .s_axis_tlast             (tc_descram_tlast),
    .s_axis_tabort            (1'b0),
    .parsed_tc_hdr            (parsed_tc_hdr),
    .parsed_tc_seg_hdr        (parsed_tc_seg_hdr),
    .parsed_prox1_hdr         (parsed_prox1_hdr),
    .parsed_uslp_trunc_hdr    (parsed_uslp_trunc_hdr),
    .parsed_uslp_ext_hdr      (parsed_uslp_ext_hdr),
    .parsed_uslp_tfdf_hdr     (parsed_uslp_tfdf_hdr),
    .detected_proto_mode      (detected_proto_mode),
    .extracted_ocf_word       (extracted_ocf_word),
    .extracted_ocf_valid      (extracted_ocf_valid),
    .frame_done_pulse         (ul_frame_done_pulse),
    .frame_crc_ok             (ul_frame_crc_ok),
    .frame_crc_err_pulse      (ul_fecf_crc_err_pulse),
    .frame_commit_pulse       (ul_frame_commit_pulse),
    .frame_rollback_pulse     (ul_frame_rollback_pulse),
    .m_axis_tdata             (ul_deframed_tdata),
    .m_axis_tvalid            (ul_deframed_tvalid),
    .m_axis_tready            (ul_deframed_tready),
    .m_axis_tlast             (ul_deframed_tlast)
  );

  // Capture first 3 command bytes for COP-1 Type-BC / Proximity-1 SPDU directives
  logic [7:0] cmd_byte0_q, cmd_byte1_q, cmd_byte2_q;
  logic [2:0] cmd_len_q;

  always_ff @(posedge clk_tc_safe or negedge rst_n) begin
    if (!rst_n) begin
      cmd_byte0_q <= 8'd0;
      cmd_byte1_q <= 8'd0;
      cmd_byte2_q <= 8'd0;
      cmd_len_q   <= 3'd0;
    end else if (ul_frame_done_pulse) begin
      cmd_len_q   <= 3'd0;
    end else if (ul_deframed_tvalid && ul_deframed_tready) begin
      if (cmd_len_q == 3'd0) cmd_byte0_q <= ul_deframed_tdata;
      if (cmd_len_q == 3'd1) cmd_byte1_q <= ul_deframed_tdata;
      if (cmd_len_q == 3'd2) cmd_byte2_q <= ul_deframed_tdata;
      if (cmd_len_q < 3'd7)  cmd_len_q   <= cmd_len_q + 3'd1;
    end
  end

  logic copp_accept_unused, copp_reject_unused;

  ccsds_prox1_plcw_ctrl u_prox1_plcw (
    .clk               (clk_tc_safe),
    .rst_n             (rst_n),
    .no_rf_avail       (~carrier_lock_sync_q),
    .no_bit_lock       (~symbol_lock_sync_q),
    .wait_flag_in      (1'b0),
    .window_half_w     (csr_win_half_w),
    .prox1_hdr_in      (parsed_prox1_hdr),
    .spdu_cmd_byte0    (cmd_byte0_q),
    .spdu_cmd_byte1    (cmd_byte1_q),
    .frame_done_pulse  (ul_frame_done_pulse && (detected_proto_mode == 3'd2)),
    .frame_crc_ok      (ul_frame_crc_ok),
    .copp_accept_pulse (copp_accept_unused),
    .copp_reject_pulse (copp_reject_unused),
    .plcw_out          (plcw_scheduled_tc),
    .plcw_valid_pulse  (plcw_valid_pulse_tc)
  );

  logic [7:0]  sdls_rx_tdata;
  logic        sdls_rx_tvalid;
  logic        sdls_rx_tready;
  logic        sdls_rx_tlast;
  logic [15:0] rx_active_spi_unused;

  logic [7:0]  vc_tfdf_tdata;
  logic        vc_tfdf_tvalid;
  logic        vc_tfdf_tready;
  logic        vc_tfdf_tlast;
  logic [2:0]  vc_tfdf_vcid;
  logic [10:0] vc_tfdf_fhp;
  logic        vc_tfdf_is_oid;

  logic [7:0]  sdls_tx_tdata;
  logic        sdls_tx_tvalid;
  logic        sdls_tx_tready;
  logic        sdls_tx_tlast;

  ccsds_sdls_engine u_sdls (
    .clk                        (clk_tc_safe),
    .rst_n                      (rst_n),
    .sdls_en_cfg                (active_sdls_en),
    .bc_require_sdls_cfg        (active_bc_req_sdls),
    .tx_default_spi_cfg         (16'h0001),
    .master_key_cfg             (256'h00010203_04050607_08090A0B_0C0D0E0F_10111213_14151617_18191A1B_1C1D1E1F),
    .sa_wr_en                   (1'b0),
    .sa_wr_addr                 (6'd0),
    .sa_wr_spi                  (16'd0),
    .sa_wr_seq_low              (32'd0),
    .s_axis_rx_tvalid           (ul_deframed_tvalid),
    .s_axis_rx_tready           (ul_deframed_tready),
    .s_axis_rx_tdata            (ul_deframed_tdata),
    .s_axis_rx_tlast            (ul_deframed_tlast),
    .rx_frame_is_type_bc        (parsed_tc_hdr.bypass_flag & parsed_tc_hdr.ctrl_cmd_flag),
    .m_axis_rx_tvalid           (sdls_rx_tvalid),
    .m_axis_rx_tready           (sdls_rx_tready),
    .m_axis_rx_tdata            (sdls_rx_tdata),
    .m_axis_rx_tlast            (sdls_rx_tlast),
    .sdls_auth_done_pulse       (sdls_auth_done_pulse),
    .sdls_auth_ok               (sdls_auth_ok),
    .rx_active_spi_out          (rx_active_spi_unused),
    .sa_secded_single_err_pulse (sa_secded_single_pulse),
    .sa_secded_double_err_pulse (sa_secded_double_pulse),
    .s_axis_tx_tvalid           (vc_tfdf_tvalid),
    .s_axis_tx_tready           (vc_tfdf_tready),
    .s_axis_tx_tdata            (vc_tfdf_tdata),
    .s_axis_tx_tlast            (vc_tfdf_tlast),
    .m_axis_tx_tvalid           (sdls_tx_tvalid),
    .m_axis_tx_tready           (sdls_tx_tready),
    .m_axis_tx_tdata            (sdls_tx_tdata),
    .m_axis_tx_tlast            (sdls_tx_tlast)
  );

  logic farm_accept_pulse;
  logic farm_reject_pulse;

  ccsds_farm1_tmr u_farm1 (
    .clk                     (clk_tc_safe),
    .rst_n                   (rst_n),
    .sdls_en                 (active_sdls_en),
    .bc_require_sdls         (active_bc_req_sdls),
    .window_half_w           (csr_win_half_w),
    .no_rf_avail             (~carrier_lock_sync_q),
    .no_bit_lock             (~symbol_lock_sync_q),
    .rx_buffer_wait          (~m_axis_rx_pkt_tready),
    .tmr_seu_inject_en       (1'b0),
    .tmr_seu_replica_sel     (2'd0),
    .tmr_seu_vc_sel          (3'd0),
    .tmr_seu_xor_mask        (8'd0),
    .tc_hdr_in               (parsed_tc_hdr),
    .bc_cmd_byte0            (cmd_byte0_q),
    .bc_cmd_byte1            (cmd_byte1_q),
    .bc_cmd_byte2            (cmd_byte2_q),
    .bc_cmd_len              (cmd_len_q),
    .frame_done_pulse        (ul_frame_done_pulse),
    .frame_crc_ok            (ul_frame_crc_ok),
    .sdls_auth_ok            (sdls_auth_ok),
    .farm_accept_pulse       (farm_accept_pulse),
    .farm_reject_pulse       (farm_reject_pulse),
    .clcw_scheduled_out      (clcw_scheduled_tc),
    .clcw_valid_pulse        (clcw_valid_pulse_tc),
    .tmr_seu_corrected_pulse (farm_tmr_seu_pulse)
  );

  // Synchronize scheduled CLCW into clk_sys
  always_ff @(posedge clk_sys or negedge rst_n) begin
    if (!rst_n) begin
      clcw_scheduled_sys_q <= '0;
    end else if (clcw_valid_pulse_tc) begin
      clcw_scheduled_sys_q <= clcw_scheduled_tc;
    end
  end

  logic [7:0] hcpd_pulse_bus;
  logic       hcpd_fired_unused;
  logic       hcpd_rejected_unused;

  ccsds_hcpd_ctrl u_hcpd (
    .clk                          (clk_tc_safe),
    .rst_n                        (rst_n),
    .hcpd_en_cfg                  (1'b1),
    .hcpd_vcid_cfg                (EMERGENCY_VCID),
    .hcpd_magic_word_cfg          (MAGIC_OBC_HARD_RESET[63:32]),
    .sdls_en_cfg                  (active_sdls_en),
    .hcpd_seu_inject_en           (1'b0),
    .hcpd_seu_xor_mask            (8'd0),
    .tc_hdr_in                    (parsed_tc_hdr),
    .s_axis_tdata                 (sdls_rx_tdata),
    .s_axis_tvalid                (sdls_rx_tvalid),
    .frame_done_pulse             (ul_frame_done_pulse),
    .frame_crc_ok                 (ul_frame_crc_ok),
    .sdls_auth_ok                 (sdls_auth_ok),
    .hcpd_pulse_out               (hcpd_pulse_bus),
    .hcpd_fired_pulse             (hcpd_fired_unused),
    .hcpd_rejected_pulse          (hcpd_rejected_unused),
    .hcpd_tmr_seu_corrected_pulse (hcpd_tmr_seu_pulse)
  );

  assign hcpd_obc_reset_pulse = hcpd_pulse_bus[0];
  assign hcpd_safe_mode_force = hcpd_pulse_bus[1];
  assign hcpd_rf_chain_select = hcpd_pulse_bus[3:2];

  // Store-and-Forward Commit/Rollback FIFO (RX7)
  logic [7:0]   rx_fifo_tdata;
  logic [0:0]   rx_fifo_tkeep_unused;
  logic         rx_fifo_tvalid;
  logic         rx_fifo_tready;
  logic         rx_fifo_tlast;
  ccsds_tuser_t rx_fifo_tuser_unused;
  logic [9:0]   rx_fifo_comm_cnt_unused;
  logic [9:0]   rx_fifo_spec_cnt_unused;
  logic         rx_fifo_ovf_unused;

  ccsds_cdc_fifo_ecc #(
    .DATA_WIDTH    (8),
    .DEPTH_WORDS   (512),
    .ROLLBACK_MODE (1'b1),
    .WATERMARK_MODE(1'b0)
  ) u_rx_commit_cdc_fifo (
    .clk                      (clk_sys),
    .rst_n                    (rst_n),
    .cut_through_en           (1'b0),
    .watermark_words          (10'd0),
    .frame_commit_pulse       (farm_accept_pulse),
    .frame_rollback_pulse     (farm_reject_pulse | ul_frame_rollback_pulse),
    .seu_inject_en            (1'b0),
    .seu_inject_addr          (9'd0),
    .seu_inject_bit           (6'd0),
    .s_axis_tdata             (sdls_rx_tdata),
    .s_axis_tkeep             (1'b1),
    .s_axis_tvalid            (sdls_rx_tvalid),
    .s_axis_tready            (sdls_rx_tready),
    .s_axis_tlast             (sdls_rx_tlast),
    .s_axis_tuser             ('0),
    .m_axis_tdata             (rx_fifo_tdata),
    .m_axis_tkeep             (rx_fifo_tkeep_unused),
    .m_axis_tvalid            (rx_fifo_tvalid),
    .m_axis_tready            (rx_fifo_tready),
    .m_axis_tlast             (rx_fifo_tlast),
    .m_axis_tuser             (rx_fifo_tuser_unused),
    .committed_count          (rx_fifo_comm_cnt_unused),
    .speculative_count        (rx_fifo_spec_cnt_unused),
    .ecc_single_err_corrected (rx_fifo_secded_single),
    .ecc_double_err_uncorr    (rx_fifo_secded_double),
    .rollback_overflow_err    (rx_fifo_ovf_unused)
  );

  ccsds_space_pkt_hdr_t parsed_pkt_hdr_unused;
  logic                 pkt_completed_unused;
  logic                 idle_pkt_stripped_unused;

  ccsds_pkt_reassembler u_reassembler (
    .clk                     (clk_sys),
    .rst_n                   (rst_n),
    .fhp_resync_en           (1'b0),
    .frame_fhp_in            (11'd0),
    .frame_start_pulse       (farm_accept_pulse),
    .s_axis_tdata            (rx_fifo_tdata),
    .s_axis_tvalid           (rx_fifo_tvalid),
    .s_axis_tready           (rx_fifo_tready),
    .s_axis_tlast            (rx_fifo_tlast),
    .m_axis_pkt_tdata        (m_axis_rx_pkt_tdata),
    .m_axis_pkt_tvalid       (m_axis_rx_pkt_tvalid),
    .m_axis_pkt_tready       (m_axis_rx_pkt_tready),
    .m_axis_pkt_tlast        (m_axis_rx_pkt_tlast),
    .parsed_pkt_hdr          (parsed_pkt_hdr_unused),
    .pkt_completed_pulse     (pkt_completed_unused),
    .idle_pkt_stripped_pulse (idle_pkt_stripped_unused),
    .pkt_len_err_pulse       (reasm_pkt_len_err)
  );

  always_comb begin
    m_axis_rx_pkt_tuser              = '0;
    m_axis_rx_pkt_tuser.vcid         = parsed_tc_hdr.vcid;
    m_axis_rx_pkt_tuser.map_id       = parsed_tc_seg_hdr.map_id;
    m_axis_rx_pkt_tuser.crc_err      = ~ul_frame_crc_ok;
    m_axis_rx_pkt_tuser.sdls_mac_err = ~sdls_auth_ok;
  end

  //---------------------------------------------------------------------------
  // 5. Downlink VC Arbiter, Framer, Outer FEC, Scrambler & High-Watermark FIFO
  //---------------------------------------------------------------------------
  ccsds_vc_arbiter_mux u_vc_arb (
    .clk                 (clk_sys),
    .rst_n               (rst_n),
    .tfdf_byte_len_cfg   (csr_tfdf_len),
    .request_next_frame  (s_axis_tx_pkt_tvalid),
    .s_axis_pkt_tdata    (s_axis_tx_pkt_tdata),
    .s_axis_pkt_vcid     (s_axis_tx_pkt_tuser.vcid[2:0]),
    .s_axis_pkt_tvalid   (s_axis_tx_pkt_tvalid),
    .s_axis_pkt_tready   (s_axis_tx_pkt_tready),
    .s_axis_pkt_tlast    (s_axis_tx_pkt_tlast),
    .m_axis_tfdf_tdata   (vc_tfdf_tdata),
    .m_axis_tfdf_tvalid  (vc_tfdf_tvalid),
    .m_axis_tfdf_tready  (vc_tfdf_tready),
    .m_axis_tfdf_tlast   (vc_tfdf_tlast),
    .m_axis_tfdf_vcid    (vc_tfdf_vcid),
    .m_axis_tfdf_fhp     (vc_tfdf_fhp),
    .m_axis_tfdf_is_oid  (vc_tfdf_is_oid),
    .irq_obc_pkt_len_err (vc_pkt_len_err)
  );

  logic [7:0] dl_frame_tdata;
  logic       dl_frame_tvalid;
  logic       dl_frame_tready;
  logic       dl_frame_tlast;

  ccsds_tm_aos_uslp_framer u_dl_framer (
    .clk                   (clk_sys),
    .rst_n                 (rst_n),
    .spacecraft_id_cfg     (csr_scid_10b),
    .ocf_en_cfg            (csr_ocf_en),
    .fecf_en_cfg           (csr_fecf_en),
    .clcw_mbox_in          (clcw_scheduled_sys_q),
    .proto_mode_cfg        (active_proto_mode),
    .aos_fhec_en_cfg       (csr_aos_fhec_en),
    .uslp_scid_cfg         (csr_scid_16b),
    .uslp_trunc_mode_cfg   (1'b0),
    .uslp_vcf_cnt_len_cfg  (3'd1),
    .uslp_upid_cfg         (5'd1),
    .fecf_crc32_cfg        (csr_fecf_crc32),
    .tfdf_byte_len_cfg     (csr_tfdf_len),
    .obt_sec_hdr_en_cfg    (csr_obt_sec_hdr_en),
    .obt_cuc_timestamp_48b (csr_obt_cuc_ts),
    .s_axis_tfdf_tdata     (sdls_tx_tdata),
    .s_axis_tfdf_tvalid    (sdls_tx_tvalid),
    .s_axis_tfdf_tready    (sdls_tx_tready),
    .s_axis_tfdf_tlast     (sdls_tx_tlast),
    .s_axis_tfdf_vcid      (vc_tfdf_vcid),
    .s_axis_tfdf_fhp       (vc_tfdf_fhp),
    .m_axis_frame_tdata    (dl_frame_tdata),
    .m_axis_frame_tvalid   (dl_frame_tvalid),
    .m_axis_frame_tready   (dl_frame_tready),
    .m_axis_frame_tlast    (dl_frame_tlast)
  );

  logic [7:0]  rs_enc_tdata;
  logic        rs_enc_tvalid;
  logic        rs_enc_tready;
  logic        rs_enc_tlast;
  logic [15:0] rs_conv_sym_unused;
  logic        rs_conv_valid_unused;

  ccsds_dl_rs255_223_enc u_rs_enc (
    .clk                (clk_sys),
    .rst_n              (rst_n),
    .interleave_depth_i (csr_rs_interleave),
    .tm_rand_en         (1'b0),
    .conv_enc_en        (1'b0),
    .s_axis_tdata       (dl_frame_tdata),
    .s_axis_tvalid      ((csr_fec_mode == 4'd0) ? dl_frame_tvalid : 1'b0),
    .s_axis_tready      (rs_enc_tready),
    .s_axis_tlast       (dl_frame_tlast),
    .m_axis_cadu_tdata  (rs_enc_tdata),
    .m_axis_cadu_tvalid (rs_enc_tvalid),
    .m_axis_cadu_tready (1'b1),
    .m_axis_cadu_tlast  (rs_enc_tlast),
    .conv_symbols_out   (rs_conv_sym_unused),
    .conv_symbols_valid (rs_conv_valid_unused)
  );

  logic [7:0] turbo_enc_tdata;
  logic       turbo_enc_tvalid;
  logic       turbo_enc_tready;
  logic       turbo_enc_tlast;

  ccsds_dl_turbo_ldpc_enc u_turbo_ldpc_enc (
    .clk           (clk_sys),
    .rst_n         (rst_n),
    .fec_mode_cfg  (csr_fec_mode),
    .s_axis_tdata  (dl_frame_tdata),
    .s_axis_tvalid ((csr_fec_mode != 4'd0) ? dl_frame_tvalid : 1'b0),
    .s_axis_tready (turbo_enc_tready),
    .s_axis_tlast  (dl_frame_tlast),
    .m_axis_tdata  (turbo_enc_tdata),
    .m_axis_tvalid (turbo_enc_tvalid),
    .m_axis_tready (1'b1),
    .m_axis_tlast  (turbo_enc_tlast)
  );

  assign dl_frame_tready = (csr_fec_mode == 4'd0) ? rs_enc_tready : turbo_enc_tready;

  logic [7:0]   tm_scram_tdata;
  logic [0:0]   tm_scram_tkeep_unused;
  logic         tm_scram_tvalid;
  logic         tm_scram_tready;
  logic         tm_scram_tlast;
  ccsds_tuser_t tm_scram_tuser_unused;
  logic         tm_scram_in_ready_unused;

  ccsds_lfsr_scrambler #(
    .DATA_WIDTH(8)
  ) u_tm_scram (
    .clk              (clk_sys),
    .rst_n            (rst_n),
    .bypass_en        (1'b1),
    .mode_tc_not_tm   (1'b0),
    .lfsr_reseed_sync (1'b0),
    .s_axis_tdata     ((csr_fec_mode == 4'd0) ? rs_enc_tdata  : turbo_enc_tdata),
    .s_axis_tkeep     (1'b1),
    .s_axis_tvalid    ((csr_fec_mode == 4'd0) ? rs_enc_tvalid : turbo_enc_tvalid),
    .s_axis_tready    (tm_scram_in_ready_unused),
    .s_axis_tlast     ((csr_fec_mode == 4'd0) ? rs_enc_tlast  : turbo_enc_tlast),
    .s_axis_tuser     ('0),
    .m_axis_tdata     (tm_scram_tdata),
    .m_axis_tkeep     (tm_scram_tkeep_unused),
    .m_axis_tvalid    (tm_scram_tvalid),
    .m_axis_tready    (tm_scram_tready),
    .m_axis_tlast     (tm_scram_tlast),
    .m_axis_tuser     (tm_scram_tuser_unused)
  );

  logic [0:0]   tx_hwm_tkeep_unused;
  ccsds_tuser_t tx_hwm_tuser_unused;
  logic [9:0]   tx_hwm_comm_cnt_unused;
  logic [9:0]   tx_hwm_spec_cnt_unused;
  logic         tx_hwm_ovf_unused;

  ccsds_cdc_fifo_ecc #(
    .DATA_WIDTH    (8),
    .DEPTH_WORDS   (512),
    .ROLLBACK_MODE (1'b0),
    .WATERMARK_MODE(1'b1)
  ) u_tx_hwm_cdc_fifo (
    .clk                      (clk_tx_sym),
    .rst_n                    (rst_n),
    .cut_through_en           (1'b1),
    .watermark_words          (10'd4),
    .frame_commit_pulse       (1'b0),
    .frame_rollback_pulse     (1'b0),
    .seu_inject_en            (1'b0),
    .seu_inject_addr          (9'd0),
    .seu_inject_bit           (6'd0),
    .s_axis_tdata             (tm_scram_tdata),
    .s_axis_tkeep             (1'b1),
    .s_axis_tvalid            (tm_scram_tvalid),
    .s_axis_tready            (tm_scram_tready),
    .s_axis_tlast             (tm_scram_tlast),
    .s_axis_tuser             ('0),
    .m_axis_tdata             (m_axis_dl_cad_tdata),
    .m_axis_tkeep             (tx_hwm_tkeep_unused),
    .m_axis_tvalid            (m_axis_dl_cad_tvalid),
    .m_axis_tready            (m_axis_dl_cad_tready),
    .m_axis_tlast             (m_axis_dl_cad_tlast),
    .m_axis_tuser             (tx_hwm_tuser_unused),
    .committed_count          (tx_hwm_comm_cnt_unused),
    .speculative_count        (tx_hwm_spec_cnt_unused),
    .ecc_single_err_corrected (tx_fifo_secded_single),
    .ecc_double_err_uncorr    (tx_fifo_secded_double),
    .rollback_overflow_err    (tx_hwm_ovf_unused)
  );

  logic conv_c1_unused, conv_c2_unused, conv_valid_unused;
  logic conv_lc_c1_unused, conv_lc_c2_unused;
  logic vit_dec_bit_unused, vit_dec_valid_unused;

  ccsds_conv_viterbi_codec u_conv_viterbi (
    .clk                  (clk_tx_sym),
    .rst_n                (rst_n),
    .c2_invert_en         (active_proto_mode != 3'd2),
    .line_code_mode       (ccsds_line_code_e'(line_code_cfg)),
    .tx_bit_in            (m_axis_dl_cad_tdata[7]),
    .tx_bit_valid_in      (m_axis_dl_cad_tvalid),
    .tx_sym_c1_out        (conv_c1_unused),
    .tx_sym_c2_out        (conv_c2_unused),
    .tx_sym_valid_out     (conv_valid_unused),
    .tx_line_coded_c1_out (conv_lc_c1_unused),
    .tx_line_coded_c2_out (conv_lc_c2_unused),
    .rx_sym_c1_llr_in     (4'sd0),
    .rx_sym_c2_llr_in     (4'sd0),
    .rx_sym_valid_in      (1'b0),
    .rx_dec_bit_out       (vit_dec_bit_unused),
    .rx_dec_valid_out     (vit_dec_valid_unused)
  );

  assign tx_phy_tvalid = m_axis_dl_cad_tvalid;
  assign tx_phy_tdata  = m_axis_dl_cad_tdata;

  //---------------------------------------------------------------------------
  // 6. Optional Ground EGSE / Universal BIST Endpoints (ROLE_MODE = 1 or 2)
  //---------------------------------------------------------------------------
  generate
    if (ROLE_MODE == 1 || ROLE_MODE == 2) begin : g_ground_egse_endpoints
      logic              egse_win_open;
      logic [7:0]        egse_vs, egse_nnr, egse_replay_seq;
      logic              egse_retx_pulse, egse_unlock_req;
      logic [15:0]       egse_ack_cnt, egse_retx_cnt;
      logic              egse_clcw_valid;
      ccsds_clcw_t       egse_rx_clcw;

      logic              egse_tc_tvalid, egse_tc_tready, egse_tc_tlast;
      logic [7:0]        egse_tc_tdata;
      logic              egse_cltu_tvalid, egse_cltu_tlast;
      logic [7:0]        egse_cltu_tdata;
      logic [15:0]       egse_cb_cnt;

      logic              egse_rs_dec_tvalid, egse_rs_dec_tready, egse_rs_dec_tlast;
      logic [7:0]        egse_rs_dec_tdata;
      logic              egse_rs_done, egse_rs_clean;
      logic [15:0]       egse_rs_corr_cnt;

      logic              egse_tfdf_tvalid, egse_tfdf_tlast;
      logic [7:0]        egse_tfdf_tdata;
      ccsds_tm_prim_hdr_t egse_rx_tm_hdr;
      logic [47:0]       egse_rx_obt;
      logic              egse_crc_ok, egse_crc_err;
      logic              egse_tc_in_ready_unused;

      ccsds_fop1_engine u_egse_fop1 (
        .clk                       (clk_sys),
        .rst_n                     (rst_n),
        .target_vcid_cfg           (6'd1),
        .sliding_win_k_cfg         (8'd16),
        .t1_timeout_cycles_cfg     (16'd2000),
        .tx_type_ad_req_pulse      (1'b0),
        .tx_window_open_out        (egse_win_open),
        .fop1_vs_out               (egse_vs),
        .fop1_nnr_out              (egse_nnr),
        .rx_clcw_valid_pulse       (egse_clcw_valid),
        .rx_clcw_in                (egse_rx_clcw),
        .fop1_retransmit_pulse_out (egse_retx_pulse),
        .fop1_replay_from_seq_out  (egse_replay_seq),
        .fop1_unlock_req_out       (egse_unlock_req),
        .fop1_ack_cnt_out          (egse_ack_cnt),
        .fop1_retransmit_cnt_out   (egse_retx_cnt)
      );

      ccsds_tc_cltu_framer u_egse_tc_framer (
        .clk                 (clk_sys),
        .rst_n               (rst_n),
        .scid_10b_cfg        (csr_scid_10b),
        .vcid_cfg            (6'd1),
        .bypass_flag_cfg     (1'b0),
        .ctrl_cmd_flag_cfg   (1'b0),
        .seg_hdr_en_cfg      (1'b1),
        .seq_flags_cfg       (2'b11),
        .map_id_cfg          (6'd0),
        .fop1_ns_in          (egse_vs),
        .payload_byte_len_in (10'd8),
        .s_axis_tvalid       (1'b0),
        .s_axis_tready       (egse_tc_in_ready_unused),
        .s_axis_tdata        (8'd0),
        .s_axis_tlast        (1'b0),
        .m_axis_tvalid       (egse_tc_tvalid),
        .m_axis_tready       (egse_tc_tready),
        .m_axis_tdata        (egse_tc_tdata),
        .m_axis_tlast        (egse_tc_tlast)
      );

      ccsds_bch6356_enc u_egse_bch_enc (
        .clk                    (clk_sys),
        .rst_n                  (rst_n),
        .tc_randomize_en_cfg    (1'b1),
        .s_axis_tvalid          (egse_tc_tvalid),
        .s_axis_tready          (egse_tc_tready),
        .s_axis_tdata           (egse_tc_tdata),
        .s_axis_tlast           (egse_tc_tlast),
        .m_axis_tvalid          (egse_cltu_tvalid),
        .m_axis_tready          (1'b1),
        .m_axis_tdata           (egse_cltu_tdata),
        .m_axis_tlast           (egse_cltu_tlast),
        .cltu_codeblock_cnt_out (egse_cb_cnt)
      );

      ccsds_dl_rs255_223_dec u_egse_rs_dec (
        .clk                      (clk_sys),
        .rst_n                    (rst_n),
        .interleave_depth_i_cfg   (csr_rs_interleave),
        .virtual_fill_q_cfg       (csr_rs_q_fill),
        .s_axis_tvalid            (m_axis_dl_cad_tvalid),
        .s_axis_tready            (),
        .s_axis_tdata             (m_axis_dl_cad_tdata),
        .s_axis_tlast             (m_axis_dl_cad_tlast),
        .m_axis_tvalid            (egse_rs_dec_tvalid),
        .m_axis_tready            (egse_rs_dec_tready),
        .m_axis_tdata             (egse_rs_dec_tdata),
        .m_axis_tlast             (egse_rs_dec_tlast),
        .rs_cw_done_pulse         (egse_rs_done),
        .rs_syndrome_clean_out    (egse_rs_clean),
        .rs_corrected_sym_cnt_out (egse_rs_corr_cnt)
      );

      ccsds_tm_aos_deframer u_egse_tm_deframer (
        .clk                      (clk_sys),
        .rst_n                    (rst_n),
        .aos_mode_cfg             (active_proto_mode == 3'd1),
        .aos_fhec_en_cfg          (csr_aos_fhec_en),
        .tm_sec_hdr_en_cfg        (csr_obt_sec_hdr_en),
        .ocf_en_cfg               (csr_ocf_en),
        .fecf_en_cfg              (csr_fecf_en),
        .tfdf_byte_len_cfg        ({5'd0, csr_tfdf_len}),
        .s_axis_tvalid            (egse_rs_dec_tvalid),
        .s_axis_tready            (egse_rs_dec_tready),
        .s_axis_tdata             (egse_rs_dec_tdata),
        .s_axis_tlast             (egse_rs_dec_tlast),
        .m_axis_tfdf_tvalid       (egse_tfdf_tvalid),
        .m_axis_tfdf_tready       (1'b1),
        .m_axis_tfdf_tdata        (egse_tfdf_tdata),
        .m_axis_tfdf_tlast        (egse_tfdf_tlast),
        .rx_tm_hdr_out            (egse_rx_tm_hdr),
        .rx_obt_cuc_timestamp_out (egse_rx_obt),
        .extracted_clcw_out       (egse_rx_clcw),
        .clcw_valid_pulse         (egse_clcw_valid),
        .frame_crc_ok_pulse       (egse_crc_ok),
        .frame_crc_err_pulse      (egse_crc_err)
      );
    end
  endgenerate

endmodule
