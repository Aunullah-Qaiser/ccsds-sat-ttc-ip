// =============================================================================
// File Name   : ccsds_sat_ttc_bd_wrapper.v
// Project     : CCSDS-SAT-TTC-IP (v2.40.3)
// Target      : Xilinx Zynq-7000 XC7Z035IFBG676-2L (ADRV9361-Z7035 SOM + BOB)
// Tool        : AMD / Xilinx Vivado 2026.1.1 IP Integrator (Block Design)
// Description : Verilog-2001 Module Reference Wrapper around ccsds_sat_ttc_top.sv.
//               - Exposes only the active AXI4-Lite (s_axi) and Space Packet
//                 AXI4-Stream (s_axis_tx_pkt, m_axis_rx_pkt) bus interfaces
//                 synchronous to clk_sys (100 MHz), preventing [BD 41-967] and
//                 [BD 41-1306] warnings on unused bypass/monitor streams.
//               - Provides `RX_MSB_ALIGNED` parameter (1 = arithmetic right-shift
//                 [15:4] so looping 16-bit tx_i/q_dac_out[15:0] directly into
//                 rx_i/q_adc_in[15:0] or connecting to AD9361 16-bit MSB-aligned
//                 SSI preserves exact 12-bit Q1.11 scaling).
// =============================================================================
`timescale 1ns / 1ps

module ccsds_sat_ttc_bd_wrapper #(
  parameter integer ROLE_MODE       = 2,  // 0=Spacecraft Flight, 1=Ground EGSE, 2=Universal/Loopback
  parameter integer ENABLE_SDLS     = 1,  // 1=Include AES-128-CTR/GCM engine, 0=Bypass
  parameter integer ENABLE_UL_LDPC  = 1,  // 1=Include Short-LDPC(128,64) decoder, 0=BCH-only
  parameter integer IQ_BUS_WIDTH    = 16, // 12 or 16
  parameter integer RX_MSB_ALIGNED  = 1   // 1=Slice rx_i/q_adc_in[15:4] (matches tx_i/q_dac_out[15:4] & AD9361)
)(
  // ---------------------------------------------------------------------------
  // 1. AXI4-Lite Control & Status Register (CSR) Slave Interface (0x00..0x50)
  // ---------------------------------------------------------------------------
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi AWADDR" *)
  (* X_INTERFACE_PARAMETER = "PROTOCOL AXI4LITE, DATA_WIDTH 32, ADDR_WIDTH 8" *)
  input  wire [7:0]              s_axi_awaddr,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi AWVALID" *)
  input  wire                    s_axi_awvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi AWREADY" *)
  output wire                    s_axi_awready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi WDATA" *)
  input  wire [31:0]             s_axi_wdata,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi WSTRB" *)
  input  wire [3:0]              s_axi_wstrb,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi WVALID" *)
  input  wire                    s_axi_wvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi WREADY" *)
  output wire                    s_axi_wready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi BRESP" *)
  output wire [1:0]              s_axi_bresp,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi BVALID" *)
  output wire                    s_axi_bvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi BREADY" *)
  input  wire                    s_axi_bready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi ARADDR" *)
  input  wire [7:0]              s_axi_araddr,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi ARVALID" *)
  input  wire                    s_axi_arvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi ARREADY" *)
  output wire                    s_axi_arready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi RDATA" *)
  output wire [31:0]             s_axi_rdata,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi RRESP" *)
  output wire [1:0]              s_axi_rresp,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi RVALID" *)
  output wire                    s_axi_rvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi RREADY" *)
  input  wire                    s_axi_rready,

  // ---------------------------------------------------------------------------
  // 2. OBC AXI4-Stream Space Packet Egress (m_axis_rx_pkt) & Ingress (s_axis_tx_pkt)
  // ---------------------------------------------------------------------------
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_rx_pkt TVALID" *)
  output wire                    m_axis_rx_pkt_tvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_rx_pkt TREADY" *)
  input  wire                    m_axis_rx_pkt_tready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_rx_pkt TDATA" *)
  output wire [7:0]              m_axis_rx_pkt_tdata,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_rx_pkt TLAST" *)
  output wire                    m_axis_rx_pkt_tlast,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_rx_pkt TUSER" *)
  output wire [63:0]             m_axis_rx_pkt_tuser,

  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_tx_pkt TVALID" *)
  input  wire                    s_axis_tx_pkt_tvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_tx_pkt TREADY" *)
  output wire                    s_axis_tx_pkt_tready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_tx_pkt TDATA" *)
  input  wire [7:0]              s_axis_tx_pkt_tdata,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_tx_pkt TLAST" *)
  input  wire                    s_axis_tx_pkt_tlast,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_tx_pkt TUSER" *)
  input  wire [63:0]             s_axis_tx_pkt_tuser,

  // ---------------------------------------------------------------------------
  // 3. Clocks, Master Reset & 1-PPS Time Reference
  // ---------------------------------------------------------------------------
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk_sys CLK" *)
  (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axi:m_axis_rx_pkt:s_axis_tx_pkt, ASSOCIATED_RESET rst_n, FREQ_HZ 100000000" *)
  input  wire                    clk_sys,

  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk_tc_safe CLK" *)
  (* X_INTERFACE_PARAMETER = "FREQ_HZ 16000000" *)
  input  wire                    clk_tc_safe,

  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk_tx_sym CLK" *)
  (* X_INTERFACE_PARAMETER = "FREQ_HZ 50000000" *)
  input  wire                    clk_tx_sym,

  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk_adc_iq CLK" *)
  (* X_INTERFACE_PARAMETER = "FREQ_HZ 120000000" *)
  input  wire                    clk_adc_iq,

  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst_n RST" *)
  (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
  input  wire                    rst_n,

  input  wire                    pps_1hz_in,

  // ---------------------------------------------------------------------------
  // 4. Hardware Mission Straps & Default Tx VCID Strap
  // ---------------------------------------------------------------------------
  input  wire [1:0]              link_proto_override_en,
  input  wire [1:0]              ul_fec_override_en,
  input  wire                    sdls_en_cfg,
  input  wire                    bc_require_sdls_cfg,
  input  wire                    pn_ranging_en_cfg,
  input  wire                    pn_t4b_mode_cfg,
  input  wire                    turnaround_xband_cfg,
  input  wire [1:0]              mod_mode_cfg,
  input  wire [1:0]              line_code_cfg,
  input  wire [5:0]              default_tx_vcid_cfg,

  // ---------------------------------------------------------------------------
  // 5. Baseband RF I/Q ADC Inputs & DAC Outputs
  // ---------------------------------------------------------------------------
  input  wire signed [IQ_BUS_WIDTH-1:0] rx_i_adc_in,
  input  wire signed [IQ_BUS_WIDTH-1:0] rx_q_adc_in,
  input  wire                    rx_iq_valid_in,

  output wire signed [IQ_BUS_WIDTH-1:0] tx_i_dac_out,
  output wire signed [IQ_BUS_WIDTH-1:0] tx_q_dac_out,
  output wire                    tx_iq_valid_out,

  // ---------------------------------------------------------------------------
  // 6. Optional CADU Monitor Tap (Non-AXI Naming for ILA Probing) & Status
  // ---------------------------------------------------------------------------
  output wire                    dl_cadu_mon_valid,
  output wire [7:0]              dl_cadu_mon_data,
  output wire                    dl_cadu_mon_last,

  output wire                    hcpd_obc_reset_pulse,
  output wire                    hcpd_safe_mode_force,
  output wire [1:0]              hcpd_rf_chain_select,
  output wire                    pn_ranging_locked_out,
  output wire                    fault_irq_out,
  output wire                    edac_scrub_req_out
);

  wire signed [IQ_BUS_WIDTH-1:0] rx_i_aligned;
  wire signed [IQ_BUS_WIDTH-1:0] rx_q_aligned;

  generate
    if (IQ_BUS_WIDTH == 16 && RX_MSB_ALIGNED == 1) begin : g_rx_msb_shift
      assign rx_i_aligned = {{4{rx_i_adc_in[15]}}, rx_i_adc_in[15:4]};
      assign rx_q_aligned = {{4{rx_q_adc_in[15]}}, rx_q_adc_in[15:4]};
    end else begin : g_rx_direct
      assign rx_i_aligned = rx_i_adc_in;
      assign rx_q_aligned = rx_q_adc_in;
    end
  endgenerate

  wire [63:0] tx_pkt_tuser_eff = (s_axis_tx_pkt_tuser == 64'd0)
                               ? {16'd0, default_tx_vcid_cfg, 42'd0}
                               : s_axis_tx_pkt_tuser;

  wire ul_sym_tready_unused;

  ccsds_sat_ttc_top #(
    .ROLE_MODE              (ROLE_MODE),
    .ENABLE_SDLS            (ENABLE_SDLS[0]),
    .ENABLE_UL_LDPC         (ENABLE_UL_LDPC[0]),
    .IQ_BUS_WIDTH           (IQ_BUS_WIDTH)
  ) u_ccsds_sat_ttc_top (
    .clk_sys                (clk_sys),
    .clk_tc_safe            (clk_tc_safe),
    .clk_tx_sym             (clk_tx_sym),
    .clk_adc_iq             (clk_adc_iq),
    .rst_n                  (rst_n),
    .pps_1hz_in             (pps_1hz_in),

    .s_axi_awaddr           (s_axi_awaddr),
    .s_axi_awvalid          (s_axi_awvalid),
    .s_axi_awready          (s_axi_awready),
    .s_axi_wdata            (s_axi_wdata),
    .s_axi_wstrb            (s_axi_wstrb),
    .s_axi_wvalid           (s_axi_wvalid),
    .s_axi_wready           (s_axi_wready),
    .s_axi_bresp            (s_axi_bresp),
    .s_axi_bvalid           (s_axi_bvalid),
    .s_axi_bready           (s_axi_bready),
    .s_axi_araddr           (s_axi_araddr),
    .s_axi_arvalid          (s_axi_arvalid),
    .s_axi_arready          (s_axi_arready),
    .s_axi_rdata            (s_axi_rdata),
    .s_axi_rresp            (s_axi_rresp),
    .s_axi_rvalid           (s_axi_rvalid),
    .s_axi_rready           (s_axi_rready),

    .link_proto_override_en (link_proto_override_en),
    .ul_fec_override_en     (ul_fec_override_en),
    .sdls_en_cfg            (sdls_en_cfg),
    .bc_require_sdls_cfg    (bc_require_sdls_cfg),
    .pn_ranging_en_cfg      (pn_ranging_en_cfg),
    .pn_t4b_mode_cfg        (pn_t4b_mode_cfg),
    .turnaround_xband_cfg   (turnaround_xband_cfg),
    .mod_mode_cfg           (mod_mode_cfg),
    .line_code_cfg          (line_code_cfg),

    .rx_i_adc_in            (rx_i_aligned),
    .rx_q_adc_in            (rx_q_aligned),
    .rx_iq_valid_in         (rx_iq_valid_in),

    .s_axis_ul_sym_tvalid   (1'b0),
    .s_axis_ul_sym_tready   (ul_sym_tready_unused),
    .s_axis_ul_sym_tdata    (8'd0),
    .s_axis_ul_sym_tlast    (1'b0),

    .m_axis_rx_pkt_tvalid   (m_axis_rx_pkt_tvalid),
    .m_axis_rx_pkt_tready   (m_axis_rx_pkt_tready),
    .m_axis_rx_pkt_tdata    (m_axis_rx_pkt_tdata),
    .m_axis_rx_pkt_tlast    (m_axis_rx_pkt_tlast),
    .m_axis_rx_pkt_tuser    (m_axis_rx_pkt_tuser),

    .s_axis_tx_pkt_tvalid   (s_axis_tx_pkt_tvalid),
    .s_axis_tx_pkt_tready   (s_axis_tx_pkt_tready),
    .s_axis_tx_pkt_tdata    (s_axis_tx_pkt_tdata),
    .s_axis_tx_pkt_tlast    (s_axis_tx_pkt_tlast),
    .s_axis_tx_pkt_tuser    (tx_pkt_tuser_eff),

    .m_axis_dl_cad_tvalid   (dl_cadu_mon_valid),
    .m_axis_dl_cad_tready   (1'b1),
    .m_axis_dl_cad_tdata    (dl_cadu_mon_data),
    .m_axis_dl_cad_tlast    (dl_cadu_mon_last),

    .tx_i_dac_out           (tx_i_dac_out),
    .tx_q_dac_out           (tx_q_dac_out),
    .tx_iq_valid_out        (tx_iq_valid_out),

    .hcpd_obc_reset_pulse   (hcpd_obc_reset_pulse),
    .hcpd_safe_mode_force   (hcpd_safe_mode_force),
    .hcpd_rf_chain_select   (hcpd_rf_chain_select),
    .pn_All_Locked_out      (pn_ranging_locked_out),
    .fault_irq_out          (fault_irq_out),
    .edac_scrub_req_out     (edac_scrub_req_out)
  );

endmodule
