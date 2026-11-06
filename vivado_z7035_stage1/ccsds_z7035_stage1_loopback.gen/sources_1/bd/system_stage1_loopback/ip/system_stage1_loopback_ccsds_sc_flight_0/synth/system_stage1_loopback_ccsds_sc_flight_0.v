// (c) Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// (c) Copyright 2022-2026 Advanced Micro Devices, Inc. All rights reserved.
// 
// This file contains confidential and proprietary information
// of AMD and is protected under U.S. and international copyright
// and other intellectual property laws.
// 
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// AMD, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND AMD HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) AMD shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or AMD had been advised of the
// possibility of the same.
// 
// CRITICAL APPLICATIONS
// AMD products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of AMD products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
// 
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
// 
// DO NOT MODIFY THIS FILE.


// IP VLNV: xilinx.com:module_ref:ccsds_sat_ttc_bd_wrapper:1.0
// IP Revision: 1

(* X_CORE_INFO = "ccsds_sat_ttc_bd_wrapper,Vivado 2026.1.1" *)
(* CHECK_LICENSE_TYPE = "system_stage1_loopback_ccsds_sc_flight_0,ccsds_sat_ttc_bd_wrapper,{}" *)
(* CORE_GENERATION_INFO = "system_stage1_loopback_ccsds_sc_flight_0,ccsds_sat_ttc_bd_wrapper,{x_ipProduct=Vivado 2026.1.1,x_ipVendor=xilinx.com,x_ipLibrary=module_ref,x_ipName=ccsds_sat_ttc_bd_wrapper,x_ipVersion=1.0,x_ipCoreRevision=1,x_ipLanguage=VERILOG,x_ipSimLanguage=MIXED,ROLE_MODE=0,ENABLE_SDLS=1,ENABLE_UL_LDPC=1,IQ_BUS_WIDTH=16,RX_MSB_ALIGNED=1}" *)
(* IP_DEFINITION_SOURCE = "module_ref" *)
(* DowngradeIPIdentifiedWarnings = "yes" *)
module system_stage1_loopback_ccsds_sc_flight_0 (
  s_axi_awaddr,
  s_axi_awvalid,
  s_axi_awready,
  s_axi_wdata,
  s_axi_wstrb,
  s_axi_wvalid,
  s_axi_wready,
  s_axi_bresp,
  s_axi_bvalid,
  s_axi_bready,
  s_axi_araddr,
  s_axi_arvalid,
  s_axi_arready,
  s_axi_rdata,
  s_axi_rresp,
  s_axi_rvalid,
  s_axi_rready,
  m_axis_rx_pkt_tvalid,
  m_axis_rx_pkt_tready,
  m_axis_rx_pkt_tdata,
  m_axis_rx_pkt_tlast,
  m_axis_rx_pkt_tuser,
  s_axis_tx_pkt_tvalid,
  s_axis_tx_pkt_tready,
  s_axis_tx_pkt_tdata,
  s_axis_tx_pkt_tlast,
  s_axis_tx_pkt_tuser,
  clk_sys,
  clk_tc_safe,
  clk_tx_sym,
  clk_adc_iq,
  rst_n,
  pps_1hz_in,
  link_proto_override_en,
  ul_fec_override_en,
  sdls_en_cfg,
  bc_require_sdls_cfg,
  pn_ranging_en_cfg,
  pn_t4b_mode_cfg,
  turnaround_xband_cfg,
  mod_mode_cfg,
  line_code_cfg,
  default_tx_vcid_cfg,
  rx_i_adc_in,
  rx_q_adc_in,
  rx_iq_valid_in,
  tx_i_dac_out,
  tx_q_dac_out,
  tx_iq_valid_out,
  dl_cadu_mon_valid,
  dl_cadu_mon_data,
  dl_cadu_mon_last,
  hcpd_obc_reset_pulse,
  hcpd_safe_mode_force,
  hcpd_rf_chain_select,
  pn_ranging_locked_out,
  fault_irq_out,
  edac_scrub_req_out
);

(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi AWADDR" *)
(* X_INTERFACE_MODE = "slave" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s_axi, PROTOCOL AXI4LITE, DATA_WIDTH 32, ADDR_WIDTH 8, FREQ_HZ 100000000, ID_WIDTH 0, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 0, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, MAX_BURST_LENGTH 1, PHASE 0.0, CLK_DOMAIN /clk_wiz_ccsds_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREAD\
S 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *)
input wire [7 : 0] s_axi_awaddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi AWVALID" *)
input wire s_axi_awvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi AWREADY" *)
output wire s_axi_awready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi WDATA" *)
input wire [31 : 0] s_axi_wdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi WSTRB" *)
input wire [3 : 0] s_axi_wstrb;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi WVALID" *)
input wire s_axi_wvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi WREADY" *)
output wire s_axi_wready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi BRESP" *)
output wire [1 : 0] s_axi_bresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi BVALID" *)
output wire s_axi_bvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi BREADY" *)
input wire s_axi_bready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi ARADDR" *)
input wire [7 : 0] s_axi_araddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi ARVALID" *)
input wire s_axi_arvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi ARREADY" *)
output wire s_axi_arready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi RDATA" *)
output wire [31 : 0] s_axi_rdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi RRESP" *)
output wire [1 : 0] s_axi_rresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi RVALID" *)
output wire s_axi_rvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi RREADY" *)
input wire s_axi_rready;
(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_rx_pkt TVALID" *)
(* X_INTERFACE_MODE = "master" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME m_axis_rx_pkt, TDATA_NUM_BYTES 1, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 64, HAS_TREADY 1, HAS_TSTRB 0, HAS_TKEEP 0, HAS_TLAST 1, FREQ_HZ 100000000, PHASE 0.0, CLK_DOMAIN /clk_wiz_ccsds_clk_out1, LAYERED_METADATA undef, INSERT_VIP 0" *)
output wire m_axis_rx_pkt_tvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_rx_pkt TREADY" *)
input wire m_axis_rx_pkt_tready;
(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_rx_pkt TDATA" *)
output wire [7 : 0] m_axis_rx_pkt_tdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_rx_pkt TLAST" *)
output wire m_axis_rx_pkt_tlast;
(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_rx_pkt TUSER" *)
output wire [63 : 0] m_axis_rx_pkt_tuser;
(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_tx_pkt TVALID" *)
(* X_INTERFACE_MODE = "slave" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s_axis_tx_pkt, TDATA_NUM_BYTES 1, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 64, HAS_TREADY 1, HAS_TSTRB 0, HAS_TKEEP 0, HAS_TLAST 1, FREQ_HZ 100000000, PHASE 0.0, CLK_DOMAIN /clk_wiz_ccsds_clk_out1, LAYERED_METADATA undef, INSERT_VIP 0" *)
input wire s_axis_tx_pkt_tvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_tx_pkt TREADY" *)
output wire s_axis_tx_pkt_tready;
(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_tx_pkt TDATA" *)
input wire [7 : 0] s_axis_tx_pkt_tdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_tx_pkt TLAST" *)
input wire s_axis_tx_pkt_tlast;
(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_tx_pkt TUSER" *)
input wire [63 : 0] s_axis_tx_pkt_tuser;
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk_sys CLK" *)
(* X_INTERFACE_MODE = "slave" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk_sys, ASSOCIATED_BUSIF s_axi:m_axis_rx_pkt:s_axis_tx_pkt, ASSOCIATED_RESET rst_n, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN /clk_wiz_ccsds_clk_out1, INSERT_VIP 0" *)
input wire clk_sys;
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk_tc_safe CLK" *)
(* X_INTERFACE_MODE = "slave" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk_tc_safe, FREQ_HZ 16000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN /clk_wiz_ccsds_clk_out1, INSERT_VIP 0" *)
input wire clk_tc_safe;
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk_tx_sym CLK" *)
(* X_INTERFACE_MODE = "slave" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk_tx_sym, FREQ_HZ 50000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN /clk_wiz_ccsds_clk_out1, INSERT_VIP 0" *)
input wire clk_tx_sym;
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk_adc_iq CLK" *)
(* X_INTERFACE_MODE = "slave" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk_adc_iq, FREQ_HZ 120000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN /clk_wiz_ccsds_clk_out1, INSERT_VIP 0" *)
input wire clk_adc_iq;
(* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst_n RST" *)
(* X_INTERFACE_MODE = "slave" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME rst_n, POLARITY ACTIVE_LOW, INSERT_VIP 0" *)
input wire rst_n;
input wire pps_1hz_in;
input wire [1 : 0] link_proto_override_en;
input wire [1 : 0] ul_fec_override_en;
input wire sdls_en_cfg;
input wire bc_require_sdls_cfg;
input wire pn_ranging_en_cfg;
input wire pn_t4b_mode_cfg;
input wire turnaround_xband_cfg;
input wire [1 : 0] mod_mode_cfg;
input wire [1 : 0] line_code_cfg;
input wire [5 : 0] default_tx_vcid_cfg;
input wire [15 : 0] rx_i_adc_in;
input wire [15 : 0] rx_q_adc_in;
input wire rx_iq_valid_in;
output wire [15 : 0] tx_i_dac_out;
output wire [15 : 0] tx_q_dac_out;
output wire tx_iq_valid_out;
output wire dl_cadu_mon_valid;
output wire [7 : 0] dl_cadu_mon_data;
output wire dl_cadu_mon_last;
output wire hcpd_obc_reset_pulse;
output wire hcpd_safe_mode_force;
output wire [1 : 0] hcpd_rf_chain_select;
output wire pn_ranging_locked_out;
output wire fault_irq_out;
output wire edac_scrub_req_out;

  ccsds_sat_ttc_bd_wrapper #(
    .ROLE_MODE(0),
    .ENABLE_SDLS(1),
    .ENABLE_UL_LDPC(1),
    .IQ_BUS_WIDTH(16),
    .RX_MSB_ALIGNED(1)
  ) inst (
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready),
    .m_axis_rx_pkt_tvalid(m_axis_rx_pkt_tvalid),
    .m_axis_rx_pkt_tready(m_axis_rx_pkt_tready),
    .m_axis_rx_pkt_tdata(m_axis_rx_pkt_tdata),
    .m_axis_rx_pkt_tlast(m_axis_rx_pkt_tlast),
    .m_axis_rx_pkt_tuser(m_axis_rx_pkt_tuser),
    .s_axis_tx_pkt_tvalid(s_axis_tx_pkt_tvalid),
    .s_axis_tx_pkt_tready(s_axis_tx_pkt_tready),
    .s_axis_tx_pkt_tdata(s_axis_tx_pkt_tdata),
    .s_axis_tx_pkt_tlast(s_axis_tx_pkt_tlast),
    .s_axis_tx_pkt_tuser(s_axis_tx_pkt_tuser),
    .clk_sys(clk_sys),
    .clk_tc_safe(clk_tc_safe),
    .clk_tx_sym(clk_tx_sym),
    .clk_adc_iq(clk_adc_iq),
    .rst_n(rst_n),
    .pps_1hz_in(pps_1hz_in),
    .link_proto_override_en(link_proto_override_en),
    .ul_fec_override_en(ul_fec_override_en),
    .sdls_en_cfg(sdls_en_cfg),
    .bc_require_sdls_cfg(bc_require_sdls_cfg),
    .pn_ranging_en_cfg(pn_ranging_en_cfg),
    .pn_t4b_mode_cfg(pn_t4b_mode_cfg),
    .turnaround_xband_cfg(turnaround_xband_cfg),
    .mod_mode_cfg(mod_mode_cfg),
    .line_code_cfg(line_code_cfg),
    .default_tx_vcid_cfg(default_tx_vcid_cfg),
    .rx_i_adc_in(rx_i_adc_in),
    .rx_q_adc_in(rx_q_adc_in),
    .rx_iq_valid_in(rx_iq_valid_in),
    .tx_i_dac_out(tx_i_dac_out),
    .tx_q_dac_out(tx_q_dac_out),
    .tx_iq_valid_out(tx_iq_valid_out),
    .dl_cadu_mon_valid(dl_cadu_mon_valid),
    .dl_cadu_mon_data(dl_cadu_mon_data),
    .dl_cadu_mon_last(dl_cadu_mon_last),
    .hcpd_obc_reset_pulse(hcpd_obc_reset_pulse),
    .hcpd_safe_mode_force(hcpd_safe_mode_force),
    .hcpd_rf_chain_select(hcpd_rf_chain_select),
    .pn_ranging_locked_out(pn_ranging_locked_out),
    .fault_irq_out(fault_irq_out),
    .edac_scrub_req_out(edac_scrub_req_out)
  );
endmodule
