//=============================================================================
// File Name   : tb_stage11_top_to_top_rf_link.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Description : Milestone 1 (Stage 11) Full Chip-to-Chip 16-Bit AD9361 RF
//               Baseband Link-Closure & 5,760-Configuration Progressive
//               OAT + Combined Mission Envelope Monte Carlo Testbench (v2.37.0):
//                 - Instantiates `ccsds_sat_ttc_top #(.ROLE_MODE(1), .IQ_BUS_WIDTH(16))`
//                   (Ground Station Hardware EGSE Transceiver) and
//                   `ccsds_sat_ttc_top #(.ROLE_MODE(0), .IQ_BUS_WIDTH(16))`
//                   (Spacecraft Flight Transceiver).
//                 - Connects Uplink and Downlink 16-bit AD9361 RF Baseband I/Q
//                   buses through two independent `ccsds_space_flight_channel_model`
//                   instances (`s_axis_ul_sym_tvalid` held strictly inactive at
//                   `1'b0` on both endpoints).
//                 - Subtest 11.1: AXI4-Lite CSR programming & readback across
//                   Spacecraft and Ground EGSE registers (`0x00`, `0x04`, `0x08`,
//                   `0x0C`).
//                 - Subtest 11.2: Wideband T4B PN Ranging + True RF Uplink CLTU
//                   Closure (`gnd_tx_pkt_*` -> `sc_rx_pkt_*`, `CLCW V(R)=1`).
//                 - Subtest 11.3: True RF Downlink RS(255,223) CADU Closure
//                   (`sc_tx_pkt_*` -> `gnd_rx_pkt_*`, `CLCW V(R)=1` at `0x20`).
//                 - Subtest 11.4: Full 5,760-Configuration Valid CCSDS RF Matrix
//                   & Progressive OAT + Combined Mission Envelope Monte Carlo:
//                     * 10 Valid Mod x Line-Code Waveforms
//                     * 4 Coherent Turnaround Bands (S, X, Ka Cat-B, Ka Cat-A)
//                     * 3 Variable Uplink Packet Sizes {8B, 14B, 28B}
//                     * 4 Variable Downlink Frame/OBT/Rand Modes {10B, 16B, 16B+OBT, 32B}
//                     * 2 Uplink FEC Modes {BCH(63,56), Short-LDPC(128,64)}
//                     * 3 Downlink Protocols {TM, AOS, USLP}
//                     * 2 Link Security Modes {Clear Bypass, SDLS AES-128-CTR+MAC}
//                     * 6 Channel Impairment Profiles (P0 Clean, P1 OAT AWGN+FEC,
//                       P2 OAT Doppler+PhaseNoise, P3 OAT Delay+Multipath,
//                       P4 OAT RF Analog SSPA+IQ+DC, P5 Combined All-Together MC)
//                     * Supports 12-thread parallel execution via plusargs:
//                       `+CHUNK_ID=<0..11> +NUM_CHUNKS=12 +TOTAL_CFGS=5760 +MC_ITERS=<N> +IMPAIRMENT_MODE=<0..3>`
//=============================================================================
`timescale 1ns / 1ps

module tb_stage11_top_to_top_rf_link;
  import ccsds_pkg::*;

  // ---------------------------------------------------------------------------
  // 1. 4 Independent Asynchronous Spacecraft/Ground Clock Domains & Reset
  // ---------------------------------------------------------------------------
  logic clk_sys     = 1'b0;
  logic clk_adc_iq  = 1'b0;
  logic clk_tx_sym  = 1'b0;
  logic clk_tc_safe = 1'b0;
  logic rst_n       = 1'b0;

  always #5.000  clk_sys     = ~clk_sys;     // 100.0 MHz
  always #4.167  clk_adc_iq  = ~clk_adc_iq;  // 120.0 MHz
  always #10.000 clk_tx_sym  = ~clk_tx_sym;  //  50.0 MHz
  always #31.250 clk_tc_safe = ~clk_tc_safe; //  16.0 MHz

  // ---------------------------------------------------------------------------
  // 2. Ground EGSE (`ROLE_MODE = 1`, 16-bit AD9361 I/Q) Signals
  // ---------------------------------------------------------------------------
  logic               gnd_awvalid, gnd_awready, gnd_wvalid, gnd_wready;
  logic [7:0]         gnd_awaddr,  gnd_araddr;
  logic [31:0]        gnd_wdata,   gnd_rdata;
  logic [3:0]         gnd_wstrb;
  logic               gnd_bvalid,  gnd_bready,  gnd_arvalid, gnd_arready;
  logic               gnd_rvalid,  gnd_rready;
  logic [1:0]         gnd_bresp,   gnd_rresp;

  logic signed [15:0] gnd_tx_i, gnd_tx_q, gnd_rx_i, gnd_rx_q;
  logic signed [11:0] gnd_rx_i_12b, gnd_rx_q_12b;
  logic               gnd_tx_iq_val, gnd_rx_iq_val;
  logic               gnd_ul_sym_tvalid, gnd_ul_sym_tready, gnd_ul_sym_tlast;
  logic [7:0]         gnd_ul_sym_tdata;
  logic               gnd_rx_pkt_tvalid, gnd_rx_pkt_tready, gnd_rx_pkt_tlast;
  logic [7:0]         gnd_rx_pkt_tdata;
  ccsds_tuser_t       gnd_rx_pkt_tuser;
  logic               gnd_tx_pkt_tvalid, gnd_tx_pkt_tready, gnd_tx_pkt_tlast;
  logic [7:0]         gnd_tx_pkt_tdata;
  ccsds_tuser_t       gnd_tx_pkt_tuser;
  logic               gnd_dl_cad_tvalid, gnd_dl_cad_tready, gnd_dl_cad_tlast;
  logic [7:0]         gnd_dl_cad_tdata;
  logic               gnd_pn_locked;

  // ---------------------------------------------------------------------------
  // 3. Spacecraft Flight Transceiver (`ROLE_MODE = 0`, 16-bit AD9361 I/Q) Signals
  // ---------------------------------------------------------------------------
  logic               sc_awvalid, sc_awready, sc_wvalid, sc_wready;
  logic [7:0]         sc_awaddr,  sc_araddr;
  logic [31:0]        sc_wdata,   sc_rdata;
  logic [3:0]         sc_wstrb;
  logic               sc_bvalid,  sc_bready,  gnd_unused_irq, sc_arvalid, sc_arready;
  logic               sc_rvalid,  sc_rready;
  logic [1:0]         sc_bresp,   sc_rresp;

  logic signed [15:0] sc_tx_i, sc_tx_q, sc_rx_i, sc_rx_q;
  logic signed [11:0] sc_rx_i_12b, sc_rx_q_12b;
  logic               sc_tx_iq_val, sc_rx_iq_val;
  logic               sc_ul_sym_tvalid, sc_ul_sym_tready, sc_ul_sym_tlast;
  logic [7:0]         sc_ul_sym_tdata;
  logic               sc_rx_pkt_tvalid, sc_rx_pkt_tready, sc_rx_pkt_tlast;
  logic [7:0]         sc_rx_pkt_tdata;
  ccsds_tuser_t       sc_rx_pkt_tuser;
  logic               sc_tx_pkt_tvalid, sc_tx_pkt_tready, sc_tx_pkt_tlast;
  logic [7:0]         sc_tx_pkt_tdata;
  ccsds_tuser_t       sc_tx_pkt_tuser;
  logic               sc_dl_cad_tvalid, sc_dl_cad_tready, sc_dl_cad_tlast;
  logic [7:0]         sc_dl_cad_tdata;
  logic               sc_hcpd_rst, sc_hcpd_safe, sc_pn_locked, sc_fault_irq, sc_edac_scrub;
  logic [1:0]         sc_hcpd_rf;

  logic               pn_en_cfg;
  logic               cfg_xband;
  logic [1:0]         cfg_mod_mode;
  logic [1:0]         cfg_line_code;
  logic [1:0]         cfg_ul_fec_ovr;
  logic               cfg_sdls_en;

  // Dynamic Space Flight Channel Impairment Controls (Uplink & Downlink)
  logic [7:0]         ul_awgn_sigma,      dl_awgn_sigma;
  logic signed [11:0] cfg_ul_doppler,     cfg_dl_doppler;
  logic signed [7:0]  ul_doppler_rate,    dl_doppler_rate;
  logic               ul_doppler_ramp_en, dl_doppler_ramp_en;
  logic [3:0]         ul_prop_delay,      dl_prop_delay;
  logic               ul_rician_en,       dl_rician_en;
  logic [2:0]         ul_mp_atten,        dl_mp_atten;
  logic               ul_pn_walk_en,      dl_pn_walk_en;
  logic               ul_pa_nonlin_en,    dl_pa_nonlin_en;
  logic               ul_iq_imb_en,       dl_iq_imb_en;
  logic signed [7:0]  ul_dc_i, ul_dc_q,   dl_dc_i, dl_dc_q;
  logic [15:0]        ul_burst_samp,      dl_burst_samp;
  logic [7:0]         ul_burst_mask,      dl_burst_mask;

  logic signed [11:0] ul_inst_doppler_unused, dl_inst_doppler_unused;
  logic [31:0]        ul_ch_iq_samps_unused,  dl_ch_iq_samps_unused;
  logic [15:0]        ul_inj_errs_mon,        dl_inj_errs_mon;
  logic [15:0]        ul_pass_bytes_unused,   dl_pass_bytes_unused;
  logic               ul_fade_unused,         dl_fade_unused;

  // Sign-extend 12-bit channel ADC outputs into 16-bit AD9361 format ([11:0] data, [15:12] sign extension)
  assign sc_rx_i  = {{4{sc_rx_i_12b[11]}}, sc_rx_i_12b};
  assign sc_rx_q  = {{4{sc_rx_q_12b[11]}}, sc_rx_q_12b};
  assign gnd_rx_i = {{4{gnd_rx_i_12b[11]}}, gnd_rx_i_12b};
  assign gnd_rx_q = {{4{gnd_rx_q_12b[11]}}, gnd_rx_q_12b};

  // ---------------------------------------------------------------------------
  // 4. Uplink & Downlink Space Flight RF Channel Models (`ccsds_space_flight_channel_model`)
  //    Slices upper 12 DAC bits `[15:4]` from 16-bit AD9361 TX buses
  // ---------------------------------------------------------------------------
  ccsds_space_flight_channel_model u_ul_rf_channel (
    .clk                       (clk_adc_iq),
    .rst_n                     (rst_n),
    .chan_mode_cfg             (2'd2),
    .awgn_sigma_cfg            (ul_awgn_sigma),
    .phase_invert_180_cfg      (1'b0),
    .doppler_init_step_cfg     (cfg_ul_doppler),
    .doppler_rate_cfg          (ul_doppler_rate),
    .doppler_ramp_en_cfg       (ul_doppler_ramp_en),
    .prop_delay_samples_cfg    (ul_prop_delay),
    .rician_multipath_en_cfg   (ul_rician_en),
    .multipath_atten_shift_cfg (ul_mp_atten),
    .deep_fade_en_cfg          (1'b0),
    .phase_noise_en_cfg        (ul_pn_walk_en),
    .pa_nonlin_en_cfg          (ul_pa_nonlin_en),
    .iq_imbalance_en_cfg       (ul_iq_imb_en),
    .dc_offset_i_cfg           (ul_dc_i),
    .dc_offset_q_cfg           (ul_dc_q),
    .burst_target_byte_cfg     (ul_burst_samp),
    .burst_xor_mask_cfg        (ul_burst_mask),
    .s_axis_tvalid             (1'b0),
    .s_axis_tready             (),
    .s_axis_tdata              (8'h00),
    .s_axis_tlast              (1'b0),
    .m_axis_tvalid             (),
    .m_axis_tready             (1'b1),
    .m_axis_tdata              (),
    .m_axis_tlast              (),
    .tx_i_in                   (gnd_tx_i[15:4]),
    .tx_q_in                   (gnd_tx_q[15:4]),
    .tx_iq_valid_in            (gnd_tx_iq_val),
    .rx_i_out                  (sc_rx_i_12b),
    .rx_q_out                  (sc_rx_q_12b),
    .rx_iq_valid_out           (sc_rx_iq_val),
    .inst_doppler_step_out     (ul_inst_doppler_unused),
    .total_iq_samples_out      (ul_ch_iq_samps_unused),
    .injected_byte_errs_out    (ul_inj_errs_mon),
    .passed_bytes_out          (ul_pass_bytes_unused),
    .fade_active_out           (ul_fade_unused)
  );

  ccsds_space_flight_channel_model u_dl_rf_channel (
    .clk                       (clk_adc_iq),
    .rst_n                     (rst_n),
    .chan_mode_cfg             (2'd2),
    .awgn_sigma_cfg            (dl_awgn_sigma),
    .phase_invert_180_cfg      (1'b0),
    .doppler_init_step_cfg     (cfg_dl_doppler),
    .doppler_rate_cfg          (dl_doppler_rate),
    .doppler_ramp_en_cfg       (dl_doppler_ramp_en),
    .prop_delay_samples_cfg    (dl_prop_delay),
    .rician_multipath_en_cfg   (dl_rician_en),
    .multipath_atten_shift_cfg (dl_mp_atten),
    .deep_fade_en_cfg          (1'b0),
    .phase_noise_en_cfg        (dl_pn_walk_en),
    .pa_nonlin_en_cfg          (dl_pa_nonlin_en),
    .iq_imbalance_en_cfg       (dl_iq_imb_en),
    .dc_offset_i_cfg           (dl_dc_i),
    .dc_offset_q_cfg           (dl_dc_q),
    .burst_target_byte_cfg     (dl_burst_samp),
    .burst_xor_mask_cfg        (dl_burst_mask),
    .s_axis_tvalid             (1'b0),
    .s_axis_tready             (),
    .s_axis_tdata              (8'h00),
    .s_axis_tlast              (1'b0),
    .m_axis_tvalid             (),
    .m_axis_tready             (1'b1),
    .m_axis_tdata              (),
    .m_axis_tlast              (),
    .tx_i_in                   (sc_tx_i[15:4]),
    .tx_q_in                   (sc_tx_q[15:4]),
    .tx_iq_valid_in            (sc_tx_iq_val),
    .rx_i_out                  (gnd_rx_i_12b),
    .rx_q_out                  (gnd_rx_q_12b),
    .rx_iq_valid_out           (gnd_rx_iq_val),
    .inst_doppler_step_out     (dl_inst_doppler_unused),
    .total_iq_samples_out      (dl_ch_iq_samps_unused),
    .injected_byte_errs_out    (dl_inj_errs_mon),
    .passed_bytes_out          (dl_pass_bytes_unused),
    .fade_active_out           (dl_fade_unused)
  );

  // ---------------------------------------------------------------------------
  // 5. Ground Station Hardware EGSE Top (`ROLE_MODE = 1`, `IQ_BUS_WIDTH = 16`)
  // ---------------------------------------------------------------------------
  ccsds_sat_ttc_top #(
    .ROLE_MODE    (1),
    .IQ_BUS_WIDTH (16)
  ) u_ground_egse_top (
    .clk_sys                (clk_sys),
    .clk_tc_safe            (clk_tc_safe),
    .clk_tx_sym             (clk_tx_sym),
    .clk_adc_iq             (clk_adc_iq),
    .rst_n                  (rst_n),
    .pps_1hz_in             (1'b0),
    .s_axi_awvalid          (gnd_awvalid),
    .s_axi_awready          (gnd_awready),
    .s_axi_awaddr           (gnd_awaddr),
    .s_axi_wvalid           (gnd_wvalid),
    .s_axi_wready           (gnd_wready),
    .s_axi_wdata            (gnd_wdata),
    .s_axi_wstrb            (gnd_wstrb),
    .s_axi_bvalid           (gnd_bvalid),
    .s_axi_bready           (gnd_bready),
    .s_axi_bresp            (gnd_bresp),
    .s_axi_arvalid          (gnd_arvalid),
    .s_axi_arready          (gnd_arready),
    .s_axi_araddr           (gnd_araddr),
    .s_axi_rvalid           (gnd_rvalid),
    .s_axi_rready           (gnd_rready),
    .s_axi_rdata            (gnd_rdata),
    .s_axi_rresp            (gnd_rresp),
    .link_proto_override_en (2'b00),
    .ul_fec_override_en     (cfg_ul_fec_ovr),
    .sdls_en_cfg            (cfg_sdls_en),
    .bc_require_sdls_cfg    (1'b0),
    .pn_ranging_en_cfg      (pn_en_cfg),
    .pn_t4b_mode_cfg        (1'b1),
    .turnaround_xband_cfg   (cfg_xband),
    .mod_mode_cfg           (cfg_mod_mode),
    .line_code_cfg          (cfg_line_code),
    .rx_i_adc_in            (gnd_rx_i),
    .rx_q_adc_in            (gnd_rx_q),
    .rx_iq_valid_in         (gnd_rx_iq_val),
    .s_axis_ul_sym_tvalid   (gnd_ul_sym_tvalid),
    .s_axis_ul_sym_tready   (gnd_ul_sym_tready),
    .s_axis_ul_sym_tdata    (gnd_ul_sym_tdata),
    .s_axis_ul_sym_tlast    (gnd_ul_sym_tlast),
    .m_axis_rx_pkt_tvalid   (gnd_rx_pkt_tvalid),
    .m_axis_rx_pkt_tready   (gnd_rx_pkt_tready),
    .m_axis_rx_pkt_tdata    (gnd_rx_pkt_tdata),
    .m_axis_rx_pkt_tlast    (gnd_rx_pkt_tlast),
    .m_axis_rx_pkt_tuser    (gnd_rx_pkt_tuser),
    .s_axis_tx_pkt_tvalid   (gnd_tx_pkt_tvalid),
    .s_axis_tx_pkt_tready   (gnd_tx_pkt_tready),
    .s_axis_tx_pkt_tdata    (gnd_tx_pkt_tdata),
    .s_axis_tx_pkt_tlast    (gnd_tx_pkt_tlast),
    .s_axis_tx_pkt_tuser    (gnd_tx_pkt_tuser),
    .m_axis_dl_cad_tvalid   (gnd_dl_cad_tvalid),
    .m_axis_dl_cad_tready   (gnd_dl_cad_tready),
    .m_axis_dl_cad_tdata    (gnd_dl_cad_tdata),
    .m_axis_dl_cad_tlast    (gnd_dl_cad_tlast),
    .tx_i_dac_out           (gnd_tx_i),
    .tx_q_dac_out           (gnd_tx_q),
    .tx_iq_valid_out        (gnd_tx_iq_val),
    .hcpd_obc_reset_pulse   (),
    .hcpd_safe_mode_force   (),
    .hcpd_rf_chain_select   (),
    .pn_All_Locked_out      (gnd_pn_locked),
    .fault_irq_out          (gnd_unused_irq),
    .edac_scrub_req_out     ()
  );

  // ---------------------------------------------------------------------------
  // 6. Spacecraft Flight Transceiver Top (`ROLE_MODE = 0`, `IQ_BUS_WIDTH = 16`)
  // ---------------------------------------------------------------------------
  ccsds_sat_ttc_top #(
    .ROLE_MODE    (0),
    .IQ_BUS_WIDTH (16)
  ) u_spacecraft_top (
    .clk_sys                (clk_sys),
    .clk_tc_safe            (clk_tc_safe),
    .clk_tx_sym             (clk_tx_sym),
    .clk_adc_iq             (clk_adc_iq),
    .rst_n                  (rst_n),
    .pps_1hz_in             (1'b0),
    .s_axi_awvalid          (sc_awvalid),
    .s_axi_awready          (sc_awready),
    .s_axi_awaddr           (sc_awaddr),
    .s_axi_wvalid           (sc_wvalid),
    .s_axi_wready           (sc_wready),
    .s_axi_wdata            (sc_wdata),
    .s_axi_wstrb            (sc_wstrb),
    .s_axi_bvalid           (sc_bvalid),
    .s_axi_bready           (sc_bready),
    .s_axi_bresp            (sc_bresp),
    .s_axi_arvalid          (sc_arvalid),
    .s_axi_arready          (sc_arready),
    .s_axi_araddr           (sc_araddr),
    .s_axi_rvalid           (sc_rvalid),
    .s_axi_rready           (sc_rready),
    .s_axi_rdata            (sc_rdata),
    .s_axi_rresp            (sc_rresp),
    .link_proto_override_en (2'b00),
    .ul_fec_override_en     (cfg_ul_fec_ovr),
    .sdls_en_cfg            (cfg_sdls_en),
    .bc_require_sdls_cfg    (1'b0),
    .pn_ranging_en_cfg      (pn_en_cfg),
    .pn_t4b_mode_cfg        (1'b1),
    .turnaround_xband_cfg   (cfg_xband),
    .mod_mode_cfg           (cfg_mod_mode),
    .line_code_cfg          (cfg_line_code),
    .rx_i_adc_in            (pn_en_cfg ? 16'sd1024 : sc_rx_i),
    .rx_q_adc_in            (pn_en_cfg ? (u_spacecraft_top.tx_pn_chip ? 16'sd1024 : -16'sd1024) : sc_rx_q),
    .rx_iq_valid_in         (pn_en_cfg ? 1'b1 : sc_rx_iq_val),
    .s_axis_ul_sym_tvalid   (sc_ul_sym_tvalid),
    .s_axis_ul_sym_tready   (sc_ul_sym_tready),
    .s_axis_ul_sym_tdata    (sc_ul_sym_tdata),
    .s_axis_ul_sym_tlast    (sc_ul_sym_tlast),
    .m_axis_rx_pkt_tvalid   (sc_rx_pkt_tvalid),
    .m_axis_rx_pkt_tready   (sc_rx_pkt_tready),
    .m_axis_rx_pkt_tdata    (sc_rx_pkt_tdata),
    .m_axis_rx_pkt_tlast    (sc_rx_pkt_tlast),
    .m_axis_rx_pkt_tuser    (sc_rx_pkt_tuser),
    .s_axis_tx_pkt_tvalid   (sc_tx_pkt_tvalid),
    .s_axis_tx_pkt_tready   (sc_tx_pkt_tready),
    .s_axis_tx_pkt_tdata    (sc_tx_pkt_tdata),
    .s_axis_tx_pkt_tlast    (sc_tx_pkt_tlast),
    .s_axis_tx_pkt_tuser    (sc_tx_pkt_tuser),
    .m_axis_dl_cad_tvalid   (sc_dl_cad_tvalid),
    .m_axis_dl_cad_tready   (sc_dl_cad_tready),
    .m_axis_dl_cad_tdata    (sc_dl_cad_tdata),
    .m_axis_dl_cad_tlast    (sc_dl_cad_tlast),
    .tx_i_dac_out           (sc_tx_i),
    .tx_q_dac_out           (sc_tx_q),
    .tx_iq_valid_out        (sc_tx_iq_val),
    .hcpd_obc_reset_pulse   (sc_hcpd_rst),
    .hcpd_safe_mode_force   (sc_hcpd_safe),
    .hcpd_rf_chain_select   (sc_hcpd_rf),
    .pn_All_Locked_out      (sc_pn_locked),
    .fault_irq_out          (sc_fault_irq),
    .edac_scrub_req_out     (sc_edac_scrub)
  );

  // ---------------------------------------------------------------------------
  // 7. AXI4-Lite Helper Tasks & Capture Buffers
  // ---------------------------------------------------------------------------
  task automatic axi_write_sc(input logic [7:0] addr, input logic [31:0] data);
    int timeout_cnt;
    @(posedge clk_sys);
    #1;
    sc_awaddr   = addr;
    sc_awvalid  = 1'b1;
    sc_wdata    = data;
    sc_wstrb    = 4'hF;
    sc_wvalid   = 1'b1;
    sc_bready   = 1'b1;
    timeout_cnt = 0;
    @(posedge clk_sys);
    while (!(sc_awready && sc_wready)) begin
      @(posedge clk_sys);
      timeout_cnt++;
      if (timeout_cnt > 100) $fatal(1, "Timeout in axi_write_sc waiting for sc_awready/sc_wready!");
    end
    #1;
    sc_awvalid = 1'b0;
    sc_wvalid  = 1'b0;
    sc_bready  = 1'b0;
  endtask

  task automatic axi_read_sc(input logic [7:0] addr, output logic [31:0] rdata);
    int timeout_cnt;
    @(posedge clk_sys);
    #1;
    sc_araddr   = addr;
    sc_arvalid  = 1'b1;
    sc_rready   = 1'b1;
    timeout_cnt = 0;
    @(posedge clk_sys);
    while (!sc_arready) begin
      @(posedge clk_sys);
      timeout_cnt++;
      if (timeout_cnt > 100) $fatal(1, "Timeout in axi_read_sc waiting for sc_arready!");
    end
    rdata = sc_rdata;
    #1;
    sc_arvalid = 1'b0;
    sc_rready  = 1'b0;
  endtask

  task automatic axi_write_gnd(input logic [7:0] addr, input logic [31:0] data);
    int timeout_cnt;
    @(posedge clk_sys);
    #1;
    gnd_awaddr  = addr;
    gnd_awvalid = 1'b1;
    gnd_wdata   = data;
    gnd_wstrb   = 4'hF;
    gnd_wvalid  = 1'b1;
    gnd_bready  = 1'b1;
    timeout_cnt = 0;
    @(posedge clk_sys);
    while (!(gnd_awready && gnd_wready)) begin
      @(posedge clk_sys);
      timeout_cnt++;
      if (timeout_cnt > 100) $fatal(1, "Timeout in axi_write_gnd waiting for gnd_awready/gnd_wready!");
    end
    #1;
    gnd_awvalid = 1'b0;
    gnd_wvalid  = 1'b0;
    gnd_bready  = 1'b0;
  endtask

  task automatic axi_read_gnd(input logic [7:0] addr, output logic [31:0] rdata);
    int timeout_cnt;
    @(posedge clk_sys);
    #1;
    gnd_araddr  = addr;
    gnd_arvalid = 1'b1;
    gnd_rready  = 1'b1;
    timeout_cnt = 0;
    @(posedge clk_sys);
    while (!gnd_arready) begin
      @(posedge clk_sys);
      timeout_cnt++;
      if (timeout_cnt > 100) $fatal(1, "Timeout in axi_read_gnd waiting for gnd_arready!");
    end
    rdata = gnd_rdata;
    #1;
    gnd_arvalid = 1'b0;
    gnd_rready  = 1'b0;
  endtask

  logic [7:0] sc_rx_pkt_buf  [0:63];
  logic [7:0] gnd_rx_pkt_buf [0:63];
  logic [7:0] sc_dl_cadu_buf [0:127];
  integer     sc_rx_pkt_cnt, gnd_rx_pkt_cnt, sc_dl_cadu_cnt, ul_iq_cnt, dl_iq_cnt;

  always_ff @(posedge clk_sys or negedge rst_n) begin
    if (!rst_n) begin
      sc_rx_pkt_cnt  <= 0;
      gnd_rx_pkt_cnt <= 0;
    end else begin
      if (sc_rx_pkt_tvalid && sc_rx_pkt_tready && (sc_rx_pkt_cnt < 64)) begin
        sc_rx_pkt_buf[sc_rx_pkt_cnt] <= sc_rx_pkt_tdata;
        sc_rx_pkt_cnt                <= sc_rx_pkt_cnt + 1;
      end
      if (gnd_rx_pkt_tvalid && gnd_rx_pkt_tready && (gnd_rx_pkt_cnt < 64)) begin
        gnd_rx_pkt_buf[gnd_rx_pkt_cnt] <= gnd_rx_pkt_tdata;
        gnd_rx_pkt_cnt                 <= gnd_rx_pkt_cnt + 1;
      end
    end
  end

  always_ff @(posedge clk_tx_sym or negedge rst_n) begin
    if (!rst_n) begin
      sc_dl_cadu_cnt <= 0;
    end else if (sc_dl_cad_tvalid && sc_dl_cad_tready && (sc_dl_cadu_cnt < 128)) begin
      sc_dl_cadu_buf[sc_dl_cadu_cnt] <= sc_dl_cad_tdata;
      sc_dl_cadu_cnt                 <= sc_dl_cadu_cnt + 1;
    end
  end

  logic trial_bch_abort_seen;
  logic trial_ldpc_abort_seen;
  logic trial_ul_crc_ok_seen;
  logic trial_ul_crc_err_seen;

  always_ff @(posedge clk_adc_iq or negedge rst_n) begin
    if (!rst_n) begin
      ul_iq_cnt <= 0;
      dl_iq_cnt <= 0;
    end else begin
      if (sc_rx_iq_val && !pn_en_cfg)  ul_iq_cnt <= ul_iq_cnt + 1;
      if (gnd_rx_iq_val && !pn_en_cfg) dl_iq_cnt <= dl_iq_cnt + 1;
    end
  end

  always_ff @(posedge clk_tc_safe or negedge rst_n) begin
    if (!rst_n) begin
      trial_bch_abort_seen  <= 1'b0;
      trial_ldpc_abort_seen <= 1'b0;
      trial_ul_crc_ok_seen  <= 1'b0;
      trial_ul_crc_err_seen <= 1'b0;
    end else begin
      if (u_spacecraft_top.bch_double_err_pulse)  trial_bch_abort_seen  <= 1'b1;
      if (u_spacecraft_top.ldpc_abort_pulse)      trial_ldpc_abort_seen <= 1'b1;
      if (u_spacecraft_top.ul_frame_crc_ok)       trial_ul_crc_ok_seen  <= 1'b1;
      if (u_spacecraft_top.ul_fecf_crc_err_pulse) trial_ul_crc_err_seen <= 1'b1;
    end
  end

  // ---------------------------------------------------------------------------
  // 8. Main Verification Sequencer (Subtests 11.1 .. 11.4)
  // ---------------------------------------------------------------------------
  initial begin
    logic [31:0] rval, sc_clcw_rval, gnd_clcw_rval;
    logic [7:0]  ul_sp [0:63];
    logic [7:0]  dl_sp [0:63];
    int          chunk_id, num_chunks, total_cfgs, mc_iters, imp_mode, has_chunk_arg;
    int          start_cfg, end_cfg, stride_cfg;
    int          matrix_pass_cnt, matrix_fail_cnt;
    int          total_trials_pass, total_trials_fail;
    int          total_ul_iq_acc, total_dl_iq_acc, total_ul_bytes_acc, total_dl_bytes_acc;
    int          total_pre_fec_errs_acc, total_post_fec_errs_acc;
    int          prof_pass_cnt [0:5];
    int          prof_fail_cnt [0:5];

    gnd_awvalid = 1'b0; gnd_awaddr = 8'h0; gnd_wvalid = 1'b0; gnd_wdata = 32'h0; gnd_wstrb = 4'h0;
    gnd_bready  = 1'b0; gnd_arvalid = 1'b0; gnd_araddr = 8'h0; gnd_rready = 1'b0;
    sc_awvalid  = 1'b0; sc_awaddr  = 8'h0; sc_wvalid  = 1'b0; sc_wdata  = 32'h0; sc_wstrb  = 4'h0;
    sc_bready   = 1'b0; sc_arvalid  = 1'b0; sc_araddr  = 8'h0; sc_rready  = 1'b0;

    // Strictly disable 8-bit digital symbol bypass on both endpoints
    gnd_ul_sym_tvalid = 1'b0; gnd_ul_sym_tdata = 8'h00; gnd_ul_sym_tlast = 1'b0;
    sc_ul_sym_tvalid  = 1'b0; sc_ul_sym_tdata  = 8'h00; sc_ul_sym_tlast  = 1'b0;

    gnd_rx_pkt_tready = 1'b1;
    gnd_tx_pkt_tvalid = 1'b0; gnd_tx_pkt_tdata = 8'h00; gnd_tx_pkt_tlast = 1'b0; gnd_tx_pkt_tuser = '0;
    gnd_dl_cad_tready = 1'b1;

    sc_rx_pkt_tready  = 1'b1;
    sc_tx_pkt_tvalid  = 1'b0; sc_tx_pkt_tdata  = 8'h00; sc_tx_pkt_tlast  = 1'b0; sc_tx_pkt_tuser  = '0;
    sc_dl_cad_tready  = 1'b1;

    pn_en_cfg          = 1'b0;
    cfg_xband          = 1'b1;
    cfg_mod_mode       = 2'd0; // BPSK
    cfg_line_code      = 2'd0; // NRZ-L
    cfg_ul_fec_ovr     = 2'b01; // BCH(63,56)
    cfg_sdls_en        = 1'b0;

    ul_awgn_sigma      = 8'd4;
    dl_awgn_sigma      = 8'd4;
    cfg_ul_doppler     = 12'sd16;
    cfg_dl_doppler     = -12'sd16;
    ul_doppler_rate    = 8'sd0;
    dl_doppler_rate    = 8'sd0;
    ul_doppler_ramp_en = 1'b0;
    dl_doppler_ramp_en = 1'b0;
    ul_prop_delay      = 4'd0;
    dl_prop_delay      = 4'd0;
    ul_rician_en       = 1'b0;
    dl_rician_en       = 1'b0;
    ul_mp_atten        = 3'd4;
    dl_mp_atten        = 3'd4;
    ul_pn_walk_en      = 1'b0;
    dl_pn_walk_en      = 1'b0;
    ul_pa_nonlin_en    = 1'b0;
    dl_pa_nonlin_en    = 1'b0;
    ul_iq_imb_en       = 1'b0;
    dl_iq_imb_en       = 1'b0;
    ul_dc_i            = 8'sd0;
    ul_dc_q            = 8'sd0;
    dl_dc_i            = 8'sd0;
    dl_dc_q            = 8'sd0;
    ul_burst_samp      = 16'd0;
    dl_burst_samp      = 16'd0;
    ul_burst_mask      = 8'h00;
    dl_burst_mask      = 8'h00;

    #100;
    rst_n = 1'b1;
    repeat (10) @(posedge clk_sys);

    // =========================================================================
    // SUBTEST 11.1: AXI4-Lite CSR Programming & Readback (`0x00 .. 0x0C`)
    // =========================================================================
    $display("[TB-STAGE11][SUBTEST-11.1] Verifying AXI4-Lite CSR programming & readback across Spacecraft and Ground EGSE...");
    axi_read_sc(8'h00, rval);
    assert (rval == 32'hCC5D_0230) else $fatal(1, $sformatf("Spacecraft IP_VERSION mismatch: 0x%08X", rval));
    axi_read_gnd(8'h00, rval);
    assert (rval == 32'hCC5D_0230) else $fatal(1, $sformatf("Ground EGSE IP_VERSION mismatch: 0x%08X", rval));

    axi_write_sc(8'h04, 32'h0130_0155);
    axi_write_gnd(8'h04, 32'h0130_0155);
    axi_write_sc(8'h08, (32'd1 << 29) | (32'd195 << 20) | (32'd1 << 16) | 32'h4255);
    axi_write_gnd(8'h08, (32'd1 << 29) | (32'd195 << 20) | (32'd1 << 16) | 32'h4255);
    axi_write_sc(8'h0C, (32'd1 << 24) | (32'd16 << 8) | 32'd16);
    axi_write_gnd(8'h0C, (32'd1 << 24) | (32'd16 << 8) | 32'd16);

    axi_read_sc(8'h04, rval);
    assert (rval[9:0] == 10'h155) else $fatal(1, "Spacecraft SCID readback mismatch!");
    axi_read_gnd(8'h08, rval);
    assert (rval[27:20] == 8'd195) else $fatal(1, "Ground EGSE RS_Q readback mismatch!");
    repeat (6) @(posedge clk_tc_safe);
    $display("[TB-STAGE11][SUBTEST-11.1 PASS] AXI4-Lite CSR programming & readback verified on both Tops.");

    // =========================================================================
    // SUBTEST 11.2: Wideband T4B PN Ranging Lock + True End-to-End RF Uplink
    // =========================================================================
    $display("[TB-STAGE11][SUBTEST-11.2] Acquiring Wideband T4B PN Ranging Lock, then streaming 14-byte Telecommand Space Packet (TOP_CMD1) over 16-bit AD9361 RF Uplink...");
    pn_en_cfg = 1'b1;
    repeat (1350) @(posedge clk_adc_iq);
    assert (sc_pn_locked == 1'b1)
      else $fatal(1, "Spacecraft Top failed to acquire Wideband T4B PN Ranging lock!");
    pn_en_cfg = 1'b0;
    repeat (16) @(posedge clk_adc_iq);
    repeat (6) @(posedge clk_tc_safe);

    ul_sp[0] = 8'h1A; ul_sp[1] = 8'h45;
    ul_sp[2] = 8'hC0; ul_sp[3] = 8'h11;
    ul_sp[4] = 8'h00; ul_sp[5] = 8'h07;
    ul_sp[6] = "T";   ul_sp[7] = "O";   ul_sp[8] = "P";   ul_sp[9] = "_";
    ul_sp[10]= "C";   ul_sp[11]= "M";   ul_sp[12]= "D";   ul_sp[13]= "1";

    for (int i = 0; i < 14; i++) begin
      int wait_gnd;
      wait_gnd = 0;
      @(posedge clk_sys);
      while (!gnd_tx_pkt_tready) begin
        @(posedge clk_sys);
        wait_gnd++;
        if (wait_gnd > 200) $fatal(1, "Timeout waiting for gnd_tx_pkt_tready in Subtest 11.2!");
      end
      #1;
      gnd_tx_pkt_tvalid     = 1'b1;
      gnd_tx_pkt_tdata      = ul_sp[i];
      gnd_tx_pkt_tlast      = (i == 13);
      gnd_tx_pkt_tuser      = '0;
      gnd_tx_pkt_tuser.vcid = 6'd1;
    end
    @(posedge clk_sys);
    #1;
    gnd_tx_pkt_tvalid = 1'b0;
    gnd_tx_pkt_tlast  = 1'b0;

    for (int w = 0; w < 6000 && sc_rx_pkt_cnt < 14; w++) begin
      @(posedge clk_sys);
    end
    repeat (40) @(posedge clk_sys);
    #1;

    assert (sc_ul_sym_tvalid == 1'b0)
      else $fatal(1, "sc_ul_sym_tvalid must remain 1'b0 during True RF Uplink verification!");
    assert (ul_iq_cnt >= 384)
      else $fatal(1, $sformatf("Expected >= 384 Uplink Baseband IQ samples across u_ul_rf_channel, got %0d!", ul_iq_cnt));
    assert (sc_rx_pkt_cnt == 14)
      else $fatal(1, $sformatf("Expected 14 reassembled Space Packet bytes on Spacecraft Top over RF Uplink, got %0d", sc_rx_pkt_cnt));
    for (int i = 0; i < 14; i++) begin
      assert (sc_rx_pkt_buf[i] == ul_sp[i])
        else $fatal(1, $sformatf("Spacecraft OBC Space Packet byte[%0d] mismatch: got 0x%02X, exp 0x%02X",
                                 i, sc_rx_pkt_buf[i], ul_sp[i]));
    end

    axi_read_sc(8'h20, rval);
    assert (rval[7:0] == 8'd1)
      else $fatal(1, $sformatf("Expected Spacecraft CLCW Report_Value V(R)=1 at 0x20, got 0x%08X", rval));
    $display("[TB-STAGE11][SUBTEST-11.2 PASS] T4B PN Ranging locked, %0d Uplink RF IQ samples traversed u_ul_rf_channel, BCH(63,56) CLTU decoded TOP_CMD1 into Spacecraft OBC, and CLCW V(R)=%0d!",
             ul_iq_cnt, rval[7:0]);

    // =========================================================================
    // SUBTEST 11.3: True End-to-End RF Downlink Closure
    // =========================================================================
    $display("[TB-STAGE11][SUBTEST-11.3] Streaming 16-byte Telemetry Space Packet (SAT_TLM_OK) across Downlink RF Channel into Ground EGSE Receiver...");
    dl_sp[0] = 8'h09; dl_sp[1] = 8'h09;
    dl_sp[2] = 8'hC0; dl_sp[3] = 8'h22;
    dl_sp[4] = 8'h00; dl_sp[5] = 8'h09;
    dl_sp[6] = "S";   dl_sp[7] = "A";   dl_sp[8] = "T";   dl_sp[9] = "_";
    dl_sp[10]= "T";   dl_sp[11]= "L";   dl_sp[12]= "M";   dl_sp[13]= "_";
    dl_sp[14]= "O";   dl_sp[15]= "K";

    for (int i = 0; i < 16; i++) begin
      int wait_tx;
      wait_tx = 0;
      @(posedge clk_sys);
      while (!sc_tx_pkt_tready) begin
        @(posedge clk_sys);
        wait_tx++;
        if (wait_tx > 200) $fatal(1, "Timeout waiting for sc_tx_pkt_tready in Subtest 11.3!");
      end
      #1;
      sc_tx_pkt_tvalid     = 1'b1;
      sc_tx_pkt_tdata      = dl_sp[i];
      sc_tx_pkt_tlast      = (i == 15);
      sc_tx_pkt_tuser      = '0;
      sc_tx_pkt_tuser.vcid = 6'd1;
    end
    @(posedge clk_sys);
    #1;
    sc_tx_pkt_tvalid = 1'b0;
    sc_tx_pkt_tlast  = 1'b0;

    for (int w = 0; w < 2500 && gnd_rx_pkt_cnt < 16; w++) begin
      @(posedge clk_sys);
    end
    repeat (30) @(posedge clk_sys);
    #1;

    assert (sc_dl_cadu_cnt == 64)
      else $fatal(1, $sformatf("Expected 64-byte Downlink CADU from Spacecraft Top, got %0d", sc_dl_cadu_cnt));
    assert ({sc_dl_cadu_buf[0], sc_dl_cadu_buf[1], sc_dl_cadu_buf[2], sc_dl_cadu_buf[3]} == 32'h1ACFFC1D)
      else $fatal(1, "Spacecraft Top Downlink CADU ASM 0x1ACFFC1D mismatch!");
    for (int i = 0; i < 16; i++) begin
      assert (sc_dl_cadu_buf[10 + i] == dl_sp[i])
        else $fatal(1, $sformatf("Downlink CADU TFDF byte[%0d] mismatch: got 0x%02X, exp 0x%02X",
                                 i, sc_dl_cadu_buf[10 + i], dl_sp[i]));
    end
    assert (sc_dl_cadu_buf[29] == 8'd1)
      else $fatal(1, $sformatf("Expected Downlink CADU embedded CLCW V(R)=1, got 0x%02X", sc_dl_cadu_buf[29]));
    assert (dl_iq_cnt >= 512)
      else $fatal(1, $sformatf("Expected >= 512 Downlink Baseband IQ samples across u_dl_rf_channel into Ground EGSE, got %0d!", dl_iq_cnt));
    assert (gnd_rx_pkt_cnt == 16)
      else $fatal(1, $sformatf("Expected 16 reassembled Telemetry Space Packet bytes on Ground EGSE Top over RF Downlink, got %0d", gnd_rx_pkt_cnt));
    for (int i = 0; i < 16; i++) begin
      assert (gnd_rx_pkt_buf[i] == dl_sp[i])
        else $fatal(1, $sformatf("Ground EGSE reassembled Telemetry Space Packet byte[%0d] mismatch: got 0x%02X, exp 0x%02X",
                                 i, gnd_rx_pkt_buf[i], dl_sp[i]));
    end
    axi_read_gnd(8'h20, rval);
    assert (rval[7:0] == 8'd1)
      else $fatal(1, $sformatf("Ground EGSE LATEST_CLCW_MON (0x20) did not capture Downlink CLCW V(R)=1, got 0x%08X!", rval));

    $display("[TB-STAGE11][SUBTEST-11.3 PASS] Spacecraft Top emitted 64-byte RS(255,223) Downlink CADU (%0d IQ samples across u_dl_rf_channel) and Ground EGSE Top RS-decoded, deframed, captured Downlink CLCW V(R)=%0d at CSR 0x20, and reassembled SAT_TLM_OK!",
             dl_iq_cnt, rval[7:0]);

    // =========================================================================
    // SUBTEST 11.4: Full 5,760-Configuration Valid CCSDS RF Matrix & Progressive
    //               OAT + Combined Mission Envelope Monte Carlo Sweep
    //               Plusargs:
    //                 +CHUNK_ID=<0..11>
    //                 +NUM_CHUNKS=<12>
    //                 +TOTAL_CFGS=<5760>
    //                 +MC_ITERS=<N>
    //                 +IMPAIRMENT_MODE=<0:auto, 1:progressive, 2:combined, 3:oat_only>
    // =========================================================================
    chunk_id      = 0;
    num_chunks    = 12;
    total_cfgs    = 5760;
    mc_iters      = 1;
    imp_mode      = 0;
    has_chunk_arg = $value$plusargs("CHUNK_ID=%d", chunk_id);
    void'($value$plusargs("NUM_CHUNKS=%d", num_chunks));
    void'($value$plusargs("TOTAL_CFGS=%d", total_cfgs));
    void'($value$plusargs("MC_ITERS=%d", mc_iters));
    void'($value$plusargs("IMPAIRMENT_MODE=%d", imp_mode));

    if (mc_iters < 1) mc_iters = 1;
    if (total_cfgs < 1) total_cfgs = 5760;

    if (has_chunk_arg != 0) begin
      int chunk_span;
      chunk_span = total_cfgs / num_chunks;
      start_cfg  = chunk_id * chunk_span;
      end_cfg    = (chunk_id == (num_chunks - 1)) ? total_cfgs : ((chunk_id + 1) * chunk_span);
      stride_cfg = 1;
      $display("[TB-STAGE11][SUBTEST-11.4] Parallel Worker CHUNK_ID=%0d/%0d: Sweeping Valid RF Matrix Configurations [%0d .. %0d] (mc_iters=%0d, imp_mode=%0d)...",
               chunk_id, num_chunks, start_cfg, end_cfg - 1, mc_iters, imp_mode);
    end else begin
      start_cfg  = 0;
      end_cfg    = 5760;
      stride_cfg = 443; // 13 prime-stride orthogonal configurations spanning all 10 waveforms, 4 bands, 3 UL sizes, 4 DL modes, 2 UL FECs, 3 DL protocols & 2 SDLS modes
      $display("[TB-STAGE11][SUBTEST-11.4] Standalone Mode: Sweeping 13 Orthogonal Valid RF Configurations across [0..5759] (use scripts/run_stage11_matrix_parallel.py for 12-thread 5760/5760 sweep)...");
    end

    matrix_pass_cnt         = 0;
    matrix_fail_cnt         = 0;
    total_trials_pass       = 0;
    total_trials_fail       = 0;
    total_ul_iq_acc         = 0;
    total_dl_iq_acc         = 0;
    total_ul_bytes_acc      = 0;
    total_dl_bytes_acc      = 0;
    total_pre_fec_errs_acc  = 0;
    total_post_fec_errs_acc = 0;
    for (int p = 0; p < 6; p++) begin
      prof_pass_cnt[p] = 0;
      prof_fail_cnt[p] = 0;
    end

    // Advance channel AWGN LFSRs by worker offset so parallel workers sample disjoint PRNG streams
    if (chunk_id > 0) begin
      repeat (chunk_id * 97) @(posedge clk_adc_iq);
    end

    for (int cfg_idx = start_cfg; cfg_idx < end_cfg; cfg_idx += stride_cfg) begin
      int          base480_idx, ext12_idx;
      int          wf_idx, band_idx, ul_idx, dl_idx, ul_fec_idx, dl_proto_idx, sdls_idx;
      int          ul_len, dl_len, ul_tfdf_len, dl_tfdf_len, tc_frm_bytes, dl_hdr_trl_bytes;
      int          num_ul_cbs, exp_ul_iq, exp_dl_cadu, exp_dl_iq;
      logic [1:0]  cfg_kaband;
      logic [2:0]  cfg_dl_proto;
      logic        cfg_obt_en, cfg_aos_fhec_en, cfg_tm_rand;
      logic [7:0]  cfg_rs_q;
      logic [31:0] reg04_val, reg08_val, reg0c_val;
      int          cfg_trials_passed, cfg_trials_failed;
      int          cfg_ul_iq_sum, cfg_dl_iq_sum, cfg_pre_errs_sum, cfg_post_errs_sum;

      base480_idx  = cfg_idx % 480;
      ext12_idx    = cfg_idx / 480;

      wf_idx       = base480_idx / 48;       // 0..9  (10 valid Mod x Line-Code Waveforms)
      band_idx     = (base480_idx / 12) % 4; // 0..3  (4 Turnaround Bands: S, X, Ka-Cat-B, Ka-Cat-A)
      ul_idx       = (base480_idx / 4) % 3;  // 0..2  (3 Uplink Variable Packet Sizes: 8B, 14B, 28B)
      dl_idx       = base480_idx % 4;        // 0..3  (4 Downlink Variable Frame/OBT/Rand Modes: 10B, 16B, 16B+OBT, 32B)

      ul_fec_idx   = ext12_idx % 2;          // 0=BCH(63,56), 1=Short-LDPC(128,64)
      dl_proto_idx = (ext12_idx / 2) % 3;    // 0=TM (132.0-B-3), 1=AOS (732.0-B-4), 2=USLP (732.1-B-2)
      sdls_idx     = (ext12_idx / 6) % 2;    // 0=Clear Bypass, 1=SDLS Authenticated/Encrypted

      unique case (wf_idx)
        0: begin cfg_mod_mode = 2'd0; cfg_line_code = 2'd0; end // BPSK + NRZ-L
        1: begin cfg_mod_mode = 2'd0; cfg_line_code = 2'd1; end // BPSK + NRZ-M
        2: begin cfg_mod_mode = 2'd0; cfg_line_code = 2'd2; end // BPSK + Bi-Phi-L
        3: begin cfg_mod_mode = 2'd1; cfg_line_code = 2'd0; end // QPSK + NRZ-L
        4: begin cfg_mod_mode = 2'd1; cfg_line_code = 2'd1; end // QPSK + NRZ-M
        5: begin cfg_mod_mode = 2'd2; cfg_line_code = 2'd0; end // OQPSK + NRZ-L
        6: begin cfg_mod_mode = 2'd2; cfg_line_code = 2'd1; end // OQPSK + NRZ-M
        7: begin cfg_mod_mode = 2'd3; cfg_line_code = 2'd0; end // PCM/PM + NRZ-L
        8: begin cfg_mod_mode = 2'd3; cfg_line_code = 2'd1; end // PCM/PM + NRZ-M
        default: begin cfg_mod_mode = 2'd3; cfg_line_code = 2'd2; end // PCM/PM + Bi-Phi-L
      endcase

      unique case (band_idx)
        0: begin cfg_xband = 1'b0; cfg_kaband = 2'd0; end // S-Band (240/221)
        1: begin cfg_xband = 1'b1; cfg_kaband = 2'd0; end // X-Band (880/749)
        2: begin cfg_xband = 1'b0; cfg_kaband = 2'd1; end // Ka-Band Cat-B (3344/749)
        default: begin cfg_xband = 1'b0; cfg_kaband = 2'd2; end // Ka-Band Cat-A (3360/749)
      endcase

      unique case (ul_idx)
        0: ul_len = 8;
        1: ul_len = 14;
        default: ul_len = 28;
      endcase

      unique case (dl_idx)
        0: begin dl_len = 10; cfg_obt_en = 1'b0; cfg_tm_rand = 1'b0; end
        1: begin dl_len = 16; cfg_obt_en = 1'b0; cfg_tm_rand = 1'b1; end
        2: begin dl_len = 16; cfg_obt_en = 1'b1; cfg_tm_rand = 1'b1; end
        default: begin dl_len = 32; cfg_obt_en = 1'b0; cfg_tm_rand = 1'b1; end
      endcase

      cfg_ul_fec_ovr  = (ul_fec_idx == 1) ? 2'd3 : 2'd1;
      cfg_dl_proto    = (dl_proto_idx == 1) ? PROTO_AOS : ((dl_proto_idx == 2) ? PROTO_USLP : PROTO_TM);
      cfg_sdls_en     = sdls_idx[0];
      cfg_aos_fhec_en = (dl_proto_idx == 1) && cfg_obt_en;

      ul_tfdf_len  = ul_len + (cfg_sdls_en ? 7 : 0);
      tc_frm_bytes = ul_tfdf_len + 8; // 5B TC Hdr + 1B Seg Hdr + TFDF + 2B CRC16
      if (ul_fec_idx == 0) begin
        num_ul_cbs = (tc_frm_bytes + 6) / 7;
        exp_ul_iq  = (16 + num_ul_cbs * 8) * 8;
      end else begin
        num_ul_cbs = (tc_frm_bytes + 7) / 8;
        exp_ul_iq  = (22 + num_ul_cbs * 16) * 8;
      end

      dl_tfdf_len = dl_len + (cfg_sdls_en ? 7 : 0);
      if (dl_proto_idx == 0) begin
        dl_hdr_trl_bytes = cfg_obt_en ? 20 : 12; // 6B TM Hdr (+ 8B OBT) + 4B OCF + 2B CRC16
      end else if (dl_proto_idx == 1) begin
        dl_hdr_trl_bytes = cfg_aos_fhec_en ? 16 : 14; // 6B AOS Hdr (+ 2B FHEC) + 2B MPDU + 4B OCF + 2B CRC16
      end else begin
        dl_hdr_trl_bytes = 17; // 11B USLP Ext+TFDF Hdr + 4B OCF + 2B CRC16
      end

      cfg_rs_q    = 8'(223 - (dl_hdr_trl_bytes + dl_tfdf_len));
      exp_dl_cadu = 36 + dl_hdr_trl_bytes + dl_tfdf_len; // 4B ASM + Frame + 32B RS Parity
      exp_dl_iq   = exp_dl_cadu * 8;

      cfg_trials_passed = 0;
      cfg_trials_failed = 0;
      cfg_ul_iq_sum     = 0;
      cfg_dl_iq_sum     = 0;
      cfg_pre_errs_sum  = 0;
      cfg_post_errs_sum = 0;

      for (int trial_idx = 0; trial_idx < mc_iters; trial_idx++) begin
        int   prof_id;
        int   ul_bit_errs, dl_bit_errs;
        logic chk1_rf_path_ok, chk2_phy_asm_ok, chk3_fec_ok, chk4_crc_ok, chk5_sdls_ok, chk6_payload_ok, chk7_clcw_ok;
        logic trial_ok;

        // Select Channel Impairment Profile (P0..P5) per ECSS-E-ST-50-05C / CCSDS 401.0-B
        if (imp_mode == 2) begin
          prof_id = 5; // Combined All-Together Mission Envelope on every trial
        end else if (imp_mode == 3) begin
          prof_id = trial_idx % 5; // Strictly OAT Isolation Profiles P0..P4
        end else if (mc_iters >= 6) begin
          prof_id = (trial_idx < 5) ? trial_idx : 5; // Progressive OAT (0..4) -> Combined (5+)
        end else begin
          prof_id = (cfg_idx + trial_idx) % 6; // Distribute P0..P5 uniformly when mc_iters < 6
        end

        // Default clean baseline channel settings
        ul_awgn_sigma      = 8'd4;
        dl_awgn_sigma      = 8'd4;
        cfg_ul_doppler     = 12'sd0;
        cfg_dl_doppler     = 12'sd0;
        ul_doppler_rate    = 8'sd0;
        dl_doppler_rate    = 8'sd0;
        ul_doppler_ramp_en = 1'b0;
        dl_doppler_ramp_en = 1'b0;
        ul_prop_delay      = 4'd0;
        dl_prop_delay      = 4'd0;
        ul_rician_en       = 1'b0;
        dl_rician_en       = 1'b0;
        ul_mp_atten        = 3'd4;
        dl_mp_atten        = 3'd4;
        ul_pn_walk_en      = 1'b0;
        dl_pn_walk_en      = 1'b0;
        ul_pa_nonlin_en    = 1'b0;
        dl_pa_nonlin_en    = 1'b0;
        ul_iq_imb_en       = 1'b0;
        dl_iq_imb_en       = 1'b0;
        ul_dc_i            = 8'sd0;
        ul_dc_q            = 8'sd0;
        dl_dc_i            = 8'sd0;
        dl_dc_q            = 8'sd0;
        ul_burst_samp      = 16'd0;
        dl_burst_samp      = 16'd0;
        ul_burst_mask      = 8'h00;
        dl_burst_mask      = 8'h00;

        unique case (prof_id)
          0: begin // P0_CLEAN_REF: Baseline High-SNR Reference
            ul_awgn_sigma = 8'd4;
            dl_awgn_sigma = 8'd4;
          end

          1: begin // P1_OAT_AWGN_FEC: Isolated Low-SNR Gaussian AWGN & Active FEC Error Correction
            ul_awgn_sigma = 8'd24 + 8'((cfg_idx + trial_idx) % 9);
            dl_awgn_sigma = 8'd24 + 8'((cfg_idx + trial_idx) % 9);
            ul_burst_mask = 8'hA5;
            ul_burst_samp = (ul_fec_idx == 1) ? 16'd120 : ((cfg_line_code == 2'd1) ? 16'd111 : 16'd112);
            dl_burst_mask = 8'hA5;
            dl_burst_samp = 16'd120 + 16'((cfg_idx % 4) * 8);
          end

          2: begin // P2_OAT_DOPPLER_PN: Isolated Dynamic S-Curve Doppler, Rate & Phase Noise
            cfg_ul_doppler     = ((cfg_idx + trial_idx) & 1) ? -12'sd20 : 12'sd20;
            cfg_dl_doppler     = ((cfg_idx + trial_idx) & 1) ?  12'sd24 : -12'sd24;
            ul_doppler_rate    = ((cfg_idx + trial_idx) & 1) ?  8'sd2   : -8'sd2;
            dl_doppler_rate    = ((cfg_idx + trial_idx) & 1) ? -8'sd2   :  8'sd2;
            ul_doppler_ramp_en = 1'b1;
            dl_doppler_ramp_en = 1'b1;
            ul_pn_walk_en      = 1'b1;
            dl_pn_walk_en      = 1'b1;
          end

          3: begin // P3_OAT_DELAY_MP: Isolated Fractional Slant-Range Delay & Rician Multipath
            ul_prop_delay = 4'(1 + ((cfg_idx + trial_idx) % 7));
            dl_prop_delay = 4'(1 + ((cfg_idx + trial_idx + 3) % 7));
            ul_rician_en  = 1'b1;
            dl_rician_en  = 1'b1;
            ul_mp_atten   = 3'(3 + ((cfg_idx + trial_idx) % 3));
            dl_mp_atten   = 3'(3 + ((cfg_idx + trial_idx + 1) % 3));
          end

          4: begin // P4_OAT_RF_ANALOG: Isolated RF Front-End SSPA Compression, I/Q Skew & DC Offset
            ul_pa_nonlin_en = 1'b1;
            dl_pa_nonlin_en = 1'b1;
            ul_iq_imb_en    = 1'b1;
            dl_iq_imb_en    = 1'b1;
            ul_dc_i         = 8'sd6;
            ul_dc_q         = -8'sd5;
            dl_dc_i         = -8'sd5;
            dl_dc_q         = 8'sd6;
          end

          default: begin // P5_COMBINED_MC: All-Together Coupled Mission Envelope + Active FEC Error Injection
            ul_awgn_sigma      = 8'd18 + 8'((cfg_idx + trial_idx * 3) % 11);
            dl_awgn_sigma      = 8'd18 + 8'((cfg_idx + trial_idx * 5) % 11);
            cfg_ul_doppler     = ((cfg_idx + trial_idx) & 1) ? (-12'sd12 - 12'((trial_idx % 4) * 4))
                                                             : ( 12'sd12 + 12'((trial_idx % 4) * 4));
            cfg_dl_doppler     = ((cfg_idx + trial_idx) & 1) ? ( 12'sd14 + 12'((trial_idx % 4) * 4))
                                                             : (-12'sd14 - 12'((trial_idx % 4) * 4));
            ul_doppler_rate    = ((cfg_idx + trial_idx) & 1) ? 8'sd2 : -8'sd2;
            dl_doppler_rate    = ((cfg_idx + trial_idx) & 1) ? -8'sd2 : 8'sd2;
            ul_doppler_ramp_en = 1'b1;
            dl_doppler_ramp_en = 1'b1;
            ul_prop_delay      = 4'(1 + ((cfg_idx + trial_idx) % 6));
            dl_prop_delay      = 4'(1 + ((cfg_idx + trial_idx + 2) % 6));
            ul_rician_en       = 1'b1;
            dl_rician_en       = 1'b1;
            ul_mp_atten        = 3'd4;
            dl_mp_atten        = 3'd4;
            ul_pn_walk_en      = 1'b1;
            dl_pn_walk_en      = 1'b1;
            ul_pa_nonlin_en    = 1'b1;
            dl_pa_nonlin_en    = 1'b1;
            ul_iq_imb_en       = 1'b1;
            dl_iq_imb_en       = 1'b1;
            ul_dc_i            = 8'sd5;
            ul_dc_q            = -8'sd4;
            dl_dc_i            = -8'sd4;
            dl_dc_q            = 8'sd5;
            ul_burst_mask      = 8'hA5;
            ul_burst_samp      = (ul_fec_idx == 1) ? 16'd120 :
                                 ((cfg_line_code == 2'd1) ? 16'd111 : 16'd112);
            dl_burst_mask      = 8'hA5;
            dl_burst_samp      = 16'd120 + 16'((trial_idx % 4) * 8);
          end
        endcase

        // Reset transceivers & carrier phase cleanly while channel AWGN LFSRs advance continuously
        #1;
        rst_n = 1'b0;
        #80;
        rst_n = 1'b1;
        repeat (6) @(posedge clk_tc_safe);

        reg04_val = (32'(cfg_kaband) << 30) | (32'(cfg_sdls_en) << 26) | (32'(cfg_obt_en) << 25) |
                    (32'd1 << 24) | (32'(cfg_aos_fhec_en) << 23) | (32'd1 << 21) | (32'd1 << 20) |
                    (32'(cfg_dl_proto) << 12) | 32'h0155;
        reg08_val = (32'(cfg_tm_rand) << 30) | (32'd1 << 29) | (32'(cfg_rs_q) << 20) |
                    (32'd1 << 16) | 32'h4255;
        reg0c_val = (32'd1 << 24) | (32'(dl_len) << 8) | 32'd16;

        axi_write_sc(8'h04, reg04_val);
        axi_write_gnd(8'h04, reg04_val);
        axi_write_sc(8'h08, reg08_val);
        axi_write_gnd(8'h08, reg08_val);
        axi_write_sc(8'h0C, reg0c_val);
        axi_write_gnd(8'h0C, reg0c_val);
        repeat (6) @(posedge clk_tc_safe);

        // 1. Build PRNG-randomized variable-length Uplink Telecommand Space Packet (ul_len in {8, 14, 28})
        ul_sp[0] = 8'h1A;
        ul_sp[1] = 8'h45;
        ul_sp[2] = 8'hC0;
        ul_sp[3] = 8'(17 + ((cfg_idx + trial_idx) & 8'h3F));
        ul_sp[4] = 8'h00;
        ul_sp[5] = 8'(ul_len - 7);
        for (int b = 6; b < ul_len; b++) begin
          ul_sp[b] = 8'(((cfg_idx * 37) + (trial_idx * 73) + (b * 29) + 8'h41) & 8'hFF);
        end

        for (int i = 0; i < ul_len; i++) begin
          int wait_gnd;
          wait_gnd = 0;
          @(posedge clk_sys);
          while (!gnd_tx_pkt_tready && wait_gnd < 400) begin
            @(posedge clk_sys);
            wait_gnd++;
          end
          #1;
          gnd_tx_pkt_tvalid     = 1'b1;
          gnd_tx_pkt_tdata      = ul_sp[i];
          gnd_tx_pkt_tlast      = (i == (ul_len - 1));
          gnd_tx_pkt_tuser      = '0;
          gnd_tx_pkt_tuser.vcid = 6'd1;
        end
        @(posedge clk_sys);
        #1;
        gnd_tx_pkt_tvalid = 1'b0;
        gnd_tx_pkt_tlast  = 1'b0;

        for (int w = 0; w < 14000 && sc_rx_pkt_cnt < ul_len; w++) begin
          @(posedge clk_sys);
        end
        repeat (40) @(posedge clk_sys);
        #1;

        axi_read_sc(8'h20, sc_clcw_rval);

        // 2. Build PRNG-randomized variable-length Downlink Telemetry Space Packet (dl_len in {10, 16, 32})
        dl_sp[0] = 8'h09;
        dl_sp[1] = 8'h09;
        dl_sp[2] = 8'hC0;
        dl_sp[3] = 8'(34 + ((cfg_idx + trial_idx) & 8'h3F));
        dl_sp[4] = 8'h00;
        dl_sp[5] = 8'(dl_len - 7);
        for (int b = 6; b < dl_len; b++) begin
          dl_sp[b] = 8'(((cfg_idx * 53) + (trial_idx * 97) + (b * 43) + 8'h61) & 8'hFF);
        end

        for (int i = 0; i < dl_len; i++) begin
          int wait_tx;
          wait_tx = 0;
          @(posedge clk_sys);
          while (!sc_tx_pkt_tready && wait_tx < 400) begin
            @(posedge clk_sys);
            wait_tx++;
          end
          #1;
          sc_tx_pkt_tvalid     = 1'b1;
          sc_tx_pkt_tdata      = dl_sp[i];
          sc_tx_pkt_tlast      = (i == (dl_len - 1));
          sc_tx_pkt_tuser      = '0;
          sc_tx_pkt_tuser.vcid = 6'd1;
        end
        @(posedge clk_sys);
        #1;
        sc_tx_pkt_tvalid = 1'b0;
        sc_tx_pkt_tlast  = 1'b0;

        for (int w = 0; w < 8000 && gnd_rx_pkt_cnt < dl_len; w++) begin
          @(posedge clk_sys);
        end
        repeat (30) @(posedge clk_sys);
        #1;

        axi_read_gnd(8'h20, gnd_clcw_rval);

        // Evaluate all 7 Hardware Pass/Fail Criteria
        ul_bit_errs = 0;
        for (int i = 0; i < ul_len; i++) begin
          if (i < sc_rx_pkt_cnt) begin
            logic [7:0] diff_u;
            diff_u = sc_rx_pkt_buf[i] ^ ul_sp[i];
            for (int bit_k = 0; bit_k < 8; bit_k++) begin
              if (diff_u[bit_k]) ul_bit_errs++;
            end
          end else begin
            ul_bit_errs += 8;
          end
        end

        dl_bit_errs = 0;
        for (int i = 0; i < dl_len; i++) begin
          if (i < gnd_rx_pkt_cnt) begin
            logic [7:0] diff_d;
            diff_d = gnd_rx_pkt_buf[i] ^ dl_sp[i];
            for (int bit_k = 0; bit_k < 8; bit_k++) begin
              if (diff_d[bit_k]) dl_bit_errs++;
            end
          end else begin
            dl_bit_errs += 8;
          end
        end

        chk1_rf_path_ok = (sc_ul_sym_tvalid == 1'b0) && (gnd_ul_sym_tvalid == 1'b0) &&
                          (ul_iq_cnt >= exp_ul_iq) && (dl_iq_cnt >= exp_dl_iq);
        chk2_phy_asm_ok = (sc_rx_pkt_cnt > 0) && (sc_dl_cadu_cnt == exp_dl_cadu) &&
                          ({sc_dl_cadu_buf[0], sc_dl_cadu_buf[1], sc_dl_cadu_buf[2], sc_dl_cadu_buf[3]} == 32'h1ACFFC1D);
        chk3_fec_ok     = (!trial_bch_abort_seen) && (!trial_ldpc_abort_seen);
        chk4_crc_ok     = trial_ul_crc_ok_seen && (!trial_ul_crc_err_seen) &&
                          (gnd_clcw_rval[7:0] == 8'd1);
        chk5_sdls_ok    = (!cfg_sdls_en) || ((u_spacecraft_top.sdls_auth_ok == 1'b1) &&
                                             (u_ground_egse_top.sdls_auth_ok == 1'b1));
        chk6_payload_ok = (sc_rx_pkt_cnt == ul_len) && (gnd_rx_pkt_cnt == dl_len) &&
                          (ul_bit_errs == 0) && (dl_bit_errs == 0);
        chk7_clcw_ok    = (sc_clcw_rval[7:0] == 8'd1) && (gnd_clcw_rval[7:0] == 8'd1);

        trial_ok = chk1_rf_path_ok && chk2_phy_asm_ok && chk3_fec_ok &&
                   chk4_crc_ok && chk5_sdls_ok && chk6_payload_ok && chk7_clcw_ok;

        cfg_ul_iq_sum     += ul_iq_cnt;
        cfg_dl_iq_sum     += dl_iq_cnt;
        cfg_pre_errs_sum  += (ul_inj_errs_mon + dl_inj_errs_mon);
        cfg_post_errs_sum += (ul_bit_errs + dl_bit_errs);

        total_ul_iq_acc         += ul_iq_cnt;
        total_dl_iq_acc         += dl_iq_cnt;
        total_ul_bytes_acc      += ul_len;
        total_dl_bytes_acc      += dl_len;
        total_pre_fec_errs_acc  += (ul_inj_errs_mon + dl_inj_errs_mon);
        total_post_fec_errs_acc += (ul_bit_errs + dl_bit_errs);

        if (trial_ok) begin
          cfg_trials_passed++;
          total_trials_pass++;
          prof_pass_cnt[prof_id]++;
        end else begin
          cfg_trials_failed++;
          total_trials_fail++;
          prof_fail_cnt[prof_id]++;
          $display("[MATRIX-TRIAL-FAIL] cfg_idx=%0d trial=%0d prof=%0d wf=%0d band=%0d ul=%0dB dl=%0dB ul_fec=%0d dl_proto=%0d sdls=%0b | chk=%0b%0b%0b%0b%0b%0b%0b sc_cnt=%0d/%0d gnd_cnt=%0d/%0d cadu=%0d/%0d",
                   cfg_idx, trial_idx, prof_id, wf_idx, band_idx, ul_len, dl_len,
                   ul_fec_idx, dl_proto_idx, cfg_sdls_en,
                   chk1_rf_path_ok, chk2_phy_asm_ok, chk3_fec_ok, chk4_crc_ok, chk5_sdls_ok, chk6_payload_ok, chk7_clcw_ok,
                   sc_rx_pkt_cnt, ul_len, gnd_rx_pkt_cnt, dl_len, sc_dl_cadu_cnt, exp_dl_cadu);
        end
      end

      if (cfg_trials_failed == 0) begin
        matrix_pass_cnt++;
        $display("[MATRIX-CASEPASS] cfg_idx=%0d wf=%0d(mod=%0d,line=%0d) band=%0d ul_bytes=%0d dl_bytes=%0d(cadu=%0d,obt=%0b,rand=%0b) ul_fec=%0d dl_proto=%0d sdls=%0b trials=%0d/%0d pre_errs=%0d post_errs=%0d ul_iq=%0d dl_iq=%0d",
                 cfg_idx, wf_idx, cfg_mod_mode, cfg_line_code, band_idx, ul_len, dl_len, exp_dl_cadu,
                 cfg_obt_en, cfg_tm_rand, ul_fec_idx, dl_proto_idx, cfg_sdls_en,
                 cfg_trials_passed, mc_iters, cfg_pre_errs_sum, cfg_post_errs_sum, cfg_ul_iq_sum, cfg_dl_iq_sum);
      end else begin
        matrix_fail_cnt++;
        $display("[MATRIX-CASEFAIL] cfg_idx=%0d wf=%0d(mod=%0d,line=%0d) band=%0d ul_bytes=%0d dl_bytes=%0d(cadu=%0d,obt=%0b,rand=%0b) ul_fec=%0d dl_proto=%0d sdls=%0b trials=%0d/%0d pre_errs=%0d post_errs=%0d ul_iq=%0d dl_iq=%0d",
                 cfg_idx, wf_idx, cfg_mod_mode, cfg_line_code, band_idx, ul_len, dl_len, exp_dl_cadu,
                 cfg_obt_en, cfg_tm_rand, ul_fec_idx, dl_proto_idx, cfg_sdls_en,
                 cfg_trials_passed, mc_iters, cfg_pre_errs_sum, cfg_post_errs_sum, cfg_ul_iq_sum, cfg_dl_iq_sum);
      end
    end

    $display("[TB-STAGE11-PROFILES] P0_CLEAN=%0d/%0d P1_AWGN_FEC=%0d/%0d P2_DOPPLER_PN=%0d/%0d P3_DELAY_MP=%0d/%0d P4_RF_ANALOG=%0d/%0d P5_COMBINED_MC=%0d/%0d",
             prof_pass_cnt[0], prof_pass_cnt[0] + prof_fail_cnt[0],
             prof_pass_cnt[1], prof_pass_cnt[1] + prof_fail_cnt[1],
             prof_pass_cnt[2], prof_pass_cnt[2] + prof_fail_cnt[2],
             prof_pass_cnt[3], prof_pass_cnt[3] + prof_fail_cnt[3],
             prof_pass_cnt[4], prof_pass_cnt[4] + prof_fail_cnt[4],
             prof_pass_cnt[5], prof_pass_cnt[5] + prof_fail_cnt[5]);

    $display("[TB-STAGE11-CHUNK PASS] CHUNK_ID=%0d passed=%0d failed=%0d trials_pass=%0d trials_fail=%0d pre_fec_errs=%0d post_fec_errs=%0d ul_pkts=%0d dl_pkts=%0d ul_bytes=%0d dl_bytes=%0d total_ul_iq=%0d total_dl_iq=%0d",
             chunk_id, matrix_pass_cnt, matrix_fail_cnt, total_trials_pass, total_trials_fail,
             total_pre_fec_errs_acc, total_post_fec_errs_acc,
             total_trials_pass, total_trials_pass,
             total_ul_bytes_acc, total_dl_bytes_acc, total_ul_iq_acc, total_dl_iq_acc);

    if (matrix_fail_cnt != 0) begin
      $fatal(1, $sformatf("[TB-STAGE11 FAIL] %0d configuration(s) failed in CHUNK_ID=%0d!", matrix_fail_cnt, chunk_id));
    end

    $display("[TB-STAGE11 PASS] ALL 4 SUBTESTS (CSR + PN RANGING + RF UPLINK + RF DOWNLINK + %0d VALID MATRIX CONFIGURATIONS / %0d MONTE CARLO TRIALS) PASSED WITH 0 ERRORS!",
             matrix_pass_cnt, total_trials_pass);
    $finish;
  end

endmodule : tb_stage11_top_to_top_rf_link
