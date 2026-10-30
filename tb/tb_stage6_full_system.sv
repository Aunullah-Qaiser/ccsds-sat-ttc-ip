//=============================================================================
// File Name   : tb_stage6_full_system.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Description : Stage 6 Self-Checking Full-System Multi-Clock Testbench (v2.34.0):
//                 - Drives 4 truly independent asynchronous clock domains:
//                     * clk_sys     : 100.0 MHz (#5.000 ns)
//                     * clk_adc_iq  : 120.0 MHz (#4.167 ns)
//                     * clk_tx_sym  :  50.0 MHz (#10.000 ns)
//                     * clk_tc_safe :  16.0 MHz (#31.250 ns)
//                 - Full Top-Level Spacecraft Transceiver (`ccsds_sat_ttc_top`)
//                 - Verifies all 6 Pre-Hardware Deployment Audit Upgrades:
//                     1. 16-bit AD9361 I/Q Bus internal 4-bit slice & pad
//                     2. Uplink Rx CDC FIFO (`clk_adc_iq` -> `clk_tc_safe`) +
//                        bit-to-LLR serializer -> `u_asm_corr` (`0xEB90` lock)
//                     3. Per-domain 2-FF asynchronous-assert / synchronous-deassert
//                        reset synchronizer bridges (`rst_sys_n..rst_adc_n`)
//                     4. Runtime SDLS 256-bit Master Key & Security Association
//                        provisioning via AXI4-Lite CSR (`0x28..0x50`)
//                     5. External `pps_1hz_in` rising-edge OBT synchronization
//                     6. Downlink CADU Pseudo-Randomizer (`tm_rand_en_cfg`)
//=============================================================================

`timescale 1ns / 1ps

module tb_stage6_full_system;
  import ccsds_pkg::*;

  // 4 Independent Asynchronous Spacecraft Clock Domains (Fix P0-5)
  logic clk_sys     = 1'b0;
  logic clk_adc_iq  = 1'b0;
  logic clk_tx_sym  = 1'b0;
  logic clk_tc_safe = 1'b0;
  logic rst_n       = 1'b0;
  logic pps_1hz_in  = 1'b0;

  always #5.000  clk_sys     = ~clk_sys;     // 100.0 MHz
  always #4.167  clk_adc_iq  = ~clk_adc_iq;  // 120.0 MHz
  always #10.000 clk_tx_sym  = ~clk_tx_sym;  //  50.0 MHz
  always #31.250 clk_tc_safe = ~clk_tc_safe; //  16.0 MHz

  logic        s_axi_awvalid, s_axi_awready;
  logic [7:0]  s_axi_awaddr;
  logic        s_axi_wvalid, s_axi_wready;
  logic [31:0] s_axi_wdata;
  logic [3:0]  s_axi_wstrb;
  logic        s_axi_bvalid, s_axi_bready;
  logic [1:0]  s_axi_bresp;
  logic        s_axi_arvalid, s_axi_arready;
  logic [7:0]  s_axi_araddr;
  logic        s_axi_rvalid, s_axi_rready;
  logic [31:0] s_axi_rdata;
  logic [1:0]  s_axi_rresp;

  logic [1:0]  link_proto_override_en;
  logic [1:0]  ul_fec_override_en;
  logic        sdls_en_cfg;
  logic        bc_require_sdls_cfg;
  logic        pn_ranging_en_cfg;
  logic        pn_t4b_mode_cfg;
  logic        turnaround_xband_cfg;
  logic [1:0]  mod_mode_cfg;
  logic [1:0]  line_code_cfg;

  // 16-bit AD9361 Transceiver I/Q Buses (`IQ_BUS_WIDTH = 16`)
  logic signed [15:0] rx_i_adc_in, rx_q_adc_in;
  logic               rx_iq_valid_in;
  logic               s_axis_ul_sym_tvalid, s_axis_ul_sym_tready, s_axis_ul_sym_tlast;
  logic [7:0]         s_axis_ul_sym_tdata;

  logic               m_axis_rx_pkt_tvalid, m_axis_rx_pkt_tready, m_axis_rx_pkt_tlast;
  logic [7:0]         m_axis_rx_pkt_tdata;
  ccsds_tuser_t       m_axis_rx_pkt_tuser;

  logic               s_axis_tx_pkt_tvalid, s_axis_tx_pkt_tready, s_axis_tx_pkt_tlast;
  logic [7:0]         s_axis_tx_pkt_tdata;
  ccsds_tuser_t       s_axis_tx_pkt_tuser;

  logic               m_axis_dl_cad_tvalid, m_axis_dl_cad_tready, m_axis_dl_cad_tlast;
  logic [7:0]         m_axis_dl_cad_tdata;

  logic signed [15:0] tx_i_dac_out, tx_q_dac_out;
  logic               tx_iq_valid_out;

  logic        hcpd_obc_reset_pulse;
  logic        hcpd_safe_mode_force;
  logic [1:0]  hcpd_rf_chain_select;
  logic        pn_All_Locked_out;
  logic        fault_irq_out;
  logic        edac_scrub_req_out;

  ccsds_sat_ttc_top #(
    .ROLE_MODE    (0),
    .IQ_BUS_WIDTH (16)
  ) u_dut (
    .clk_sys               (clk_sys),
    .clk_tc_safe           (clk_tc_safe),
    .clk_tx_sym            (clk_tx_sym),
    .clk_adc_iq            (clk_adc_iq),
    .rst_n                 (rst_n),
    .pps_1hz_in            (pps_1hz_in),
    .s_axi_awvalid         (s_axi_awvalid),
    .s_axi_awready         (s_axi_awready),
    .s_axi_awaddr          (s_axi_awaddr),
    .s_axi_wvalid          (s_axi_wvalid),
    .s_axi_wready          (s_axi_wready),
    .s_axi_wdata           (s_axi_wdata),
    .s_axi_wstrb           (s_axi_wstrb),
    .s_axi_bvalid          (s_axi_bvalid),
    .s_axi_bready          (s_axi_bready),
    .s_axi_bresp           (s_axi_bresp),
    .s_axi_arvalid         (s_axi_arvalid),
    .s_axi_arready         (s_axi_arready),
    .s_axi_araddr          (s_axi_araddr),
    .s_axi_rvalid          (s_axi_rvalid),
    .s_axi_rready          (s_axi_rready),
    .s_axi_rdata           (s_axi_rdata),
    .s_axi_rresp           (s_axi_rresp),
    .link_proto_override_en(link_proto_override_en),
    .ul_fec_override_en    (ul_fec_override_en),
    .sdls_en_cfg           (sdls_en_cfg),
    .bc_require_sdls_cfg   (bc_require_sdls_cfg),
    .pn_ranging_en_cfg     (pn_ranging_en_cfg),
    .pn_t4b_mode_cfg       (pn_t4b_mode_cfg),
    .turnaround_xband_cfg  (turnaround_xband_cfg),
    .mod_mode_cfg          (mod_mode_cfg),
    .line_code_cfg         (line_code_cfg),
    .rx_i_adc_in           (rx_i_adc_in),
    .rx_q_adc_in           (rx_q_adc_in),
    .rx_iq_valid_in        (rx_iq_valid_in),
    .s_axis_ul_sym_tvalid  (s_axis_ul_sym_tvalid),
    .s_axis_ul_sym_tready  (s_axis_ul_sym_tready),
    .s_axis_ul_sym_tdata   (s_axis_ul_sym_tdata),
    .s_axis_ul_sym_tlast   (s_axis_ul_sym_tlast),
    .m_axis_rx_pkt_tvalid  (m_axis_rx_pkt_tvalid),
    .m_axis_rx_pkt_tready  (m_axis_rx_pkt_tready),
    .m_axis_rx_pkt_tdata   (m_axis_rx_pkt_tdata),
    .m_axis_rx_pkt_tlast   (m_axis_rx_pkt_tlast),
    .m_axis_rx_pkt_tuser   (m_axis_rx_pkt_tuser),
    .s_axis_tx_pkt_tvalid  (s_axis_tx_pkt_tvalid),
    .s_axis_tx_pkt_tready  (s_axis_tx_pkt_tready),
    .s_axis_tx_pkt_tdata   (s_axis_tx_pkt_tdata),
    .s_axis_tx_pkt_tlast   (s_axis_tx_pkt_tlast),
    .s_axis_tx_pkt_tuser   (s_axis_tx_pkt_tuser),
    .m_axis_dl_cad_tvalid  (m_axis_dl_cad_tvalid),
    .m_axis_dl_cad_tready  (m_axis_dl_cad_tready),
    .m_axis_dl_cad_tdata   (m_axis_dl_cad_tdata),
    .m_axis_dl_cad_tlast   (m_axis_dl_cad_tlast),
    .tx_i_dac_out          (tx_i_dac_out),
    .tx_q_dac_out          (tx_q_dac_out),
    .tx_iq_valid_out       (tx_iq_valid_out),
    .hcpd_obc_reset_pulse  (hcpd_obc_reset_pulse),
    .hcpd_safe_mode_force  (hcpd_safe_mode_force),
    .hcpd_rf_chain_select  (hcpd_rf_chain_select),
    .pn_All_Locked_out     (pn_All_Locked_out),
    .fault_irq_out         (fault_irq_out),
    .edac_scrub_req_out    (edac_scrub_req_out)
  );

  task automatic axi_write(input logic [7:0] addr, input logic [31:0] data);
    @(posedge clk_sys);
    #1;
    s_axi_awaddr  = addr;
    s_axi_awvalid = 1'b1;
    s_axi_wdata   = data;
    s_axi_wstrb   = 4'hF;
    s_axi_wvalid  = 1'b1;
    s_axi_bready  = 1'b1;
    @(posedge clk_sys);
    while (!(s_axi_awready && s_axi_wready)) @(posedge clk_sys);
    #1;
    s_axi_awvalid = 1'b0;
    s_axi_wvalid  = 1'b0;
  endtask

  task automatic axi_read(input logic [7:0] addr, output logic [31:0] rdata);
    @(posedge clk_sys);
    #1;
    s_axi_araddr  = addr;
    s_axi_arvalid = 1'b1;
    s_axi_rready  = 1'b1;
    @(posedge clk_sys);
    while (!s_axi_arready) @(posedge clk_sys);
    rdata = s_axi_rdata;
    #1;
    s_axi_arvalid = 1'b0;
  endtask

  initial begin
    logic [31:0] rval, obt_t0, obt_t1;
    rst_n                  = 1'b0;
    pps_1hz_in             = 1'b0;
    s_axi_awvalid          = 1'b0;
    s_axi_awaddr           = 8'd0;
    s_axi_wvalid           = 1'b0;
    s_axi_wdata            = 32'd0;
    s_axi_wstrb            = 4'hF;
    s_axi_bready           = 1'b1;
    s_axi_arvalid          = 1'b0;
    s_axi_araddr           = 8'd0;
    s_axi_rready           = 1'b1;
    link_proto_override_en = 2'b00;
    ul_fec_override_en     = 2'd1; // BCH(63,56) CLTU mode to test u_rx_phy_cdc_fifo -> u_asm_corr
    sdls_en_cfg            = 1'b1;
    bc_require_sdls_cfg    = 1'b0;
    pn_ranging_en_cfg      = 1'b0;
    pn_t4b_mode_cfg        = 1'b1;
    turnaround_xband_cfg   = 1'b1;
    mod_mode_cfg           = 2'd0; // BPSK
    line_code_cfg          = 2'd0; // NRZ-L
    rx_i_adc_in            = 16'sd1024;
    rx_q_adc_in            = 16'sd0;
    rx_iq_valid_in         = 1'b0;
    s_axis_ul_sym_tvalid   = 1'b0;
    s_axis_ul_sym_tdata    = 8'd0;
    s_axis_ul_sym_tlast    = 1'b0;
    m_axis_rx_pkt_tready   = 1'b1;
    s_axis_tx_pkt_tvalid   = 1'b0;
    s_axis_tx_pkt_tdata    = 8'd0;
    s_axis_tx_pkt_tlast    = 1'b0;
    s_axis_tx_pkt_tuser    = '0;
    m_axis_dl_cad_tready   = 1'b1;

    #150 rst_n = 1'b1;
    repeat (6) @(posedge clk_tc_safe);

    // 1. Verify Per-Domain 2-FF Reset Synchronizer Bridges & 16-bit AD9361 I/Q Slice/Pad
    assert (u_dut.rst_sys_n == 1'b1 && u_dut.rst_tc_n == 1'b1 &&
            u_dut.rst_tx_n  == 1'b1 && u_dut.rst_adc_n == 1'b1)
      else $fatal(1, "Reset synchronizer bridges failed to deassert cleanly");
    assert (u_dut.phy_rx_i_12b == 12'sd1024 && tx_i_dac_out[3:0] == 4'b0000)
      else $fatal(1, "16-bit AD9361 I/Q internal 4-bit slice/pad mismatch");

    // 2. Perform AXI4-Lite Read of CORE_ID_VER (0x00 -> 32'hCC5D_0230)
    axi_read(8'h00, rval);
    $display("[TB-STAGE6] AXI4-Lite CSR Version Register Read: 0x%08X", rval);
    assert (rval == 32'hCC5D_0230) else $fatal(1, "Unexpected CSR Version ID");

    // 3. Verify External `pps_1hz_in` Pin & OBT Coarse Counter Synchronization (0x10)
    axi_read(8'h10, obt_t0);
    @(posedge clk_sys);
    pps_1hz_in = 1'b1;
    repeat (4) @(posedge clk_sys);
    pps_1hz_in = 1'b0;
    repeat (4) @(posedge clk_sys);
    axi_read(8'h10, obt_t1);
    assert (obt_t1 == (obt_t0 + 32'd1))
      else $fatal(1, $sformatf("Expected OBT coarse increment on pps_1hz_in: %0d -> %0d", obt_t0, obt_t1));

    // 4. Verify Runtime SDLS Key & Security Association Provisioning via CSR (0x28..0x50)
    axi_write(8'h28, 32'hCAFE_BABE);
    axi_write(8'h4C, 32'h0000_0042); // SA_WR_SPI = 0x0042
    axi_write(8'h50, 32'h0000_0100); // SA_WR_SEQ = 0x0100
    axi_write(8'h48, (32'd1 << 31) | (32'd2 << 16) | 32'h0042); // SA_WR_EN=1, VCID=2, TX_SPI=0x0042
    repeat (6) @(posedge clk_tc_safe);
    assert (u_dut.tc_mkey_sync_q[31:0] == 32'hCAFE_BABE && u_dut.tc_sa_wr_spi_sync_q == 16'h0042)
      else $fatal(1, "Runtime SDLS Key/SA CDC synchronization failed");

    // 5. Verify Downlink CADU Pseudo-Randomizer Enable (`CTRL_USLP_RS_CFG[30]`)
    axi_write(8'h08, (32'd1 << 30) | (32'd1 << 29) | (32'd195 << 20) | (32'd1 << 16) | 32'h4255);
    repeat (2) @(posedge clk_sys);
    assert (u_dut.csr_tm_rand_en == 1'b1)
      else $fatal(1, "Downlink CADU Pseudo-Randomizer enable failed to set");

    // 6. Verify Uplink Rx CDC FIFO (`u_phy_modem` -> `u_rx_phy_cdc_fifo` -> `u_asm_corr`)
    //    Inject 16-bit CLTU Start Marker (16'hEB90) over 16-bit ADC I/Q bus at 1-SPS BPSK
    for (int b = 15; b >= 0; b--) begin
      @(posedge clk_adc_iq);
      #1;
      rx_iq_valid_in = 1'b1;
      rx_i_adc_in    = CLTU_START_SEQ_16B[b] ? -16'sd1024 : 16'sd1024;
      rx_q_adc_in    = 16'sd0;
    end
    @(posedge clk_adc_iq);
    #1;
    rx_iq_valid_in = 1'b0;
    repeat (24) @(posedge clk_tc_safe);
    assert (u_dut.asm_sync_locked == 1'b1)
      else $fatal(1, "Uplink Rx CDC FIFO -> ASM Correlator failed to lock on 0xEB90 over 16-bit ADC bus!");

    $display("[TB-STAGE6 PASS] Full Spacecraft Transceiver (ccsds_sat_ttc_top, 4 Asynchronous Clocks, 16-bit AD9361 IQ, Rx CDC FIFO, Reset Bridges, Runtime SDLS, 1PPS & CADU Randomizer) verified cleanly.");
    $finish;
  end

endmodule
