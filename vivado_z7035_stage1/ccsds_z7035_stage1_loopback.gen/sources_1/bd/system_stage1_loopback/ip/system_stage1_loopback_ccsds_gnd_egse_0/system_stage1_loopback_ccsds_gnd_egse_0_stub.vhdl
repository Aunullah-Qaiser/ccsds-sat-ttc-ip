-- Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- Copyright 2022-2026 Advanced Micro Devices, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2026.1.1 (win64) Build 6605303 Fri Sep 04 12:46:29 BST 2026
-- Date        : Fri Nov  6 10:35:44 2026
-- Host        : Sagittarius running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub
--               c:/Users/abc12/Documents/ccsds_sat_ttc_ip/vivado_z7035_stage1/ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ip/system_stage1_loopback_ccsds_gnd_egse_0/system_stage1_loopback_ccsds_gnd_egse_0_stub.vhdl
-- Design      : system_stage1_loopback_ccsds_gnd_egse_0
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7z035ifbg676-2L
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity system_stage1_loopback_ccsds_gnd_egse_0 is
  Port ( 
    s_axi_awaddr : in STD_LOGIC_VECTOR ( 7 downto 0 );
    s_axi_awvalid : in STD_LOGIC;
    s_axi_awready : out STD_LOGIC;
    s_axi_wdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
    s_axi_wstrb : in STD_LOGIC_VECTOR ( 3 downto 0 );
    s_axi_wvalid : in STD_LOGIC;
    s_axi_wready : out STD_LOGIC;
    s_axi_bresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
    s_axi_bvalid : out STD_LOGIC;
    s_axi_bready : in STD_LOGIC;
    s_axi_araddr : in STD_LOGIC_VECTOR ( 7 downto 0 );
    s_axi_arvalid : in STD_LOGIC;
    s_axi_arready : out STD_LOGIC;
    s_axi_rdata : out STD_LOGIC_VECTOR ( 31 downto 0 );
    s_axi_rresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
    s_axi_rvalid : out STD_LOGIC;
    s_axi_rready : in STD_LOGIC;
    m_axis_rx_pkt_tvalid : out STD_LOGIC;
    m_axis_rx_pkt_tready : in STD_LOGIC;
    m_axis_rx_pkt_tdata : out STD_LOGIC_VECTOR ( 7 downto 0 );
    m_axis_rx_pkt_tlast : out STD_LOGIC;
    m_axis_rx_pkt_tuser : out STD_LOGIC_VECTOR ( 63 downto 0 );
    s_axis_tx_pkt_tvalid : in STD_LOGIC;
    s_axis_tx_pkt_tready : out STD_LOGIC;
    s_axis_tx_pkt_tdata : in STD_LOGIC_VECTOR ( 7 downto 0 );
    s_axis_tx_pkt_tlast : in STD_LOGIC;
    s_axis_tx_pkt_tuser : in STD_LOGIC_VECTOR ( 63 downto 0 );
    clk_sys : in STD_LOGIC;
    clk_tc_safe : in STD_LOGIC;
    clk_tx_sym : in STD_LOGIC;
    clk_adc_iq : in STD_LOGIC;
    rst_n : in STD_LOGIC;
    pps_1hz_in : in STD_LOGIC;
    link_proto_override_en : in STD_LOGIC_VECTOR ( 1 downto 0 );
    ul_fec_override_en : in STD_LOGIC_VECTOR ( 1 downto 0 );
    sdls_en_cfg : in STD_LOGIC;
    bc_require_sdls_cfg : in STD_LOGIC;
    pn_ranging_en_cfg : in STD_LOGIC;
    pn_t4b_mode_cfg : in STD_LOGIC;
    turnaround_xband_cfg : in STD_LOGIC;
    mod_mode_cfg : in STD_LOGIC_VECTOR ( 1 downto 0 );
    line_code_cfg : in STD_LOGIC_VECTOR ( 1 downto 0 );
    default_tx_vcid_cfg : in STD_LOGIC_VECTOR ( 5 downto 0 );
    rx_i_adc_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
    rx_q_adc_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
    rx_iq_valid_in : in STD_LOGIC;
    tx_i_dac_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
    tx_q_dac_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
    tx_iq_valid_out : out STD_LOGIC;
    dl_cadu_mon_valid : out STD_LOGIC;
    dl_cadu_mon_data : out STD_LOGIC_VECTOR ( 7 downto 0 );
    dl_cadu_mon_last : out STD_LOGIC;
    hcpd_obc_reset_pulse : out STD_LOGIC;
    hcpd_safe_mode_force : out STD_LOGIC;
    hcpd_rf_chain_select : out STD_LOGIC_VECTOR ( 1 downto 0 );
    pn_ranging_locked_out : out STD_LOGIC;
    fault_irq_out : out STD_LOGIC;
    edac_scrub_req_out : out STD_LOGIC
  );

  attribute CHECK_LICENSE_TYPE : string;
  attribute CHECK_LICENSE_TYPE of system_stage1_loopback_ccsds_gnd_egse_0 : entity is "system_stage1_loopback_ccsds_gnd_egse_0,ccsds_sat_ttc_bd_wrapper,{}";
  attribute CORE_GENERATION_INFO : string;
  attribute CORE_GENERATION_INFO of system_stage1_loopback_ccsds_gnd_egse_0 : entity is "system_stage1_loopback_ccsds_gnd_egse_0,ccsds_sat_ttc_bd_wrapper,{x_ipProduct=Vivado 2026.1.1,x_ipVendor=xilinx.com,x_ipLibrary=module_ref,x_ipName=ccsds_sat_ttc_bd_wrapper,x_ipVersion=1.0,x_ipCoreRevision=1,x_ipLanguage=VERILOG,x_ipSimLanguage=MIXED,ROLE_MODE=1,ENABLE_SDLS=1,ENABLE_UL_LDPC=1,IQ_BUS_WIDTH=16,RX_MSB_ALIGNED=1}";
  attribute DowngradeIPIdentifiedWarnings : string;
  attribute DowngradeIPIdentifiedWarnings of system_stage1_loopback_ccsds_gnd_egse_0 : entity is "yes";
  attribute IP_DEFINITION_SOURCE : string;
  attribute IP_DEFINITION_SOURCE of system_stage1_loopback_ccsds_gnd_egse_0 : entity is "module_ref";
end system_stage1_loopback_ccsds_gnd_egse_0;

architecture stub of system_stage1_loopback_ccsds_gnd_egse_0 is
  attribute syn_black_box : boolean;
  attribute black_box_pad_pin : string;
  attribute syn_black_box of stub : architecture is true;
  attribute black_box_pad_pin of stub : architecture is "s_axi_awaddr[7:0],s_axi_awvalid,s_axi_awready,s_axi_wdata[31:0],s_axi_wstrb[3:0],s_axi_wvalid,s_axi_wready,s_axi_bresp[1:0],s_axi_bvalid,s_axi_bready,s_axi_araddr[7:0],s_axi_arvalid,s_axi_arready,s_axi_rdata[31:0],s_axi_rresp[1:0],s_axi_rvalid,s_axi_rready,m_axis_rx_pkt_tvalid,m_axis_rx_pkt_tready,m_axis_rx_pkt_tdata[7:0],m_axis_rx_pkt_tlast,m_axis_rx_pkt_tuser[63:0],s_axis_tx_pkt_tvalid,s_axis_tx_pkt_tready,s_axis_tx_pkt_tdata[7:0],s_axis_tx_pkt_tlast,s_axis_tx_pkt_tuser[63:0],clk_sys,clk_tc_safe,clk_tx_sym,clk_adc_iq,rst_n,pps_1hz_in,link_proto_override_en[1:0],ul_fec_override_en[1:0],sdls_en_cfg,bc_require_sdls_cfg,pn_ranging_en_cfg,pn_t4b_mode_cfg,turnaround_xband_cfg,mod_mode_cfg[1:0],line_code_cfg[1:0],default_tx_vcid_cfg[5:0],rx_i_adc_in[15:0],rx_q_adc_in[15:0],rx_iq_valid_in,tx_i_dac_out[15:0],tx_q_dac_out[15:0],tx_iq_valid_out,dl_cadu_mon_valid,dl_cadu_mon_data[7:0],dl_cadu_mon_last,hcpd_obc_reset_pulse,hcpd_safe_mode_force,hcpd_rf_chain_select[1:0],pn_ranging_locked_out,fault_irq_out,edac_scrub_req_out";
  attribute X_INTERFACE_INFO : string;
  attribute X_INTERFACE_INFO of s_axi_awaddr : signal is "xilinx.com:interface:aximm:1.0 s_axi AWADDR";
  attribute X_INTERFACE_MODE : string;
  attribute X_INTERFACE_MODE of s_axi_awaddr : signal is "slave";
  attribute X_INTERFACE_PARAMETER : string;
  attribute X_INTERFACE_PARAMETER of s_axi_awaddr : signal is "XIL_INTERFACENAME s_axi, PROTOCOL AXI4LITE, DATA_WIDTH 32, ADDR_WIDTH 8, FREQ_HZ 100000000, ID_WIDTH 0, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 0, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, MAX_BURST_LENGTH 1, PHASE 0.0, CLK_DOMAIN /clk_wiz_ccsds_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0";
  attribute X_INTERFACE_INFO of s_axi_awvalid : signal is "xilinx.com:interface:aximm:1.0 s_axi AWVALID";
  attribute X_INTERFACE_INFO of s_axi_awready : signal is "xilinx.com:interface:aximm:1.0 s_axi AWREADY";
  attribute X_INTERFACE_INFO of s_axi_wdata : signal is "xilinx.com:interface:aximm:1.0 s_axi WDATA";
  attribute X_INTERFACE_INFO of s_axi_wstrb : signal is "xilinx.com:interface:aximm:1.0 s_axi WSTRB";
  attribute X_INTERFACE_INFO of s_axi_wvalid : signal is "xilinx.com:interface:aximm:1.0 s_axi WVALID";
  attribute X_INTERFACE_INFO of s_axi_wready : signal is "xilinx.com:interface:aximm:1.0 s_axi WREADY";
  attribute X_INTERFACE_INFO of s_axi_bresp : signal is "xilinx.com:interface:aximm:1.0 s_axi BRESP";
  attribute X_INTERFACE_INFO of s_axi_bvalid : signal is "xilinx.com:interface:aximm:1.0 s_axi BVALID";
  attribute X_INTERFACE_INFO of s_axi_bready : signal is "xilinx.com:interface:aximm:1.0 s_axi BREADY";
  attribute X_INTERFACE_INFO of s_axi_araddr : signal is "xilinx.com:interface:aximm:1.0 s_axi ARADDR";
  attribute X_INTERFACE_INFO of s_axi_arvalid : signal is "xilinx.com:interface:aximm:1.0 s_axi ARVALID";
  attribute X_INTERFACE_INFO of s_axi_arready : signal is "xilinx.com:interface:aximm:1.0 s_axi ARREADY";
  attribute X_INTERFACE_INFO of s_axi_rdata : signal is "xilinx.com:interface:aximm:1.0 s_axi RDATA";
  attribute X_INTERFACE_INFO of s_axi_rresp : signal is "xilinx.com:interface:aximm:1.0 s_axi RRESP";
  attribute X_INTERFACE_INFO of s_axi_rvalid : signal is "xilinx.com:interface:aximm:1.0 s_axi RVALID";
  attribute X_INTERFACE_INFO of s_axi_rready : signal is "xilinx.com:interface:aximm:1.0 s_axi RREADY";
  attribute X_INTERFACE_INFO of m_axis_rx_pkt_tvalid : signal is "xilinx.com:interface:axis:1.0 m_axis_rx_pkt TVALID";
  attribute X_INTERFACE_MODE of m_axis_rx_pkt_tvalid : signal is "master";
  attribute X_INTERFACE_PARAMETER of m_axis_rx_pkt_tvalid : signal is "XIL_INTERFACENAME m_axis_rx_pkt, TDATA_NUM_BYTES 1, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 64, HAS_TREADY 1, HAS_TSTRB 0, HAS_TKEEP 0, HAS_TLAST 1, FREQ_HZ 100000000, PHASE 0.0, CLK_DOMAIN /clk_wiz_ccsds_clk_out1, LAYERED_METADATA undef, INSERT_VIP 0";
  attribute X_INTERFACE_INFO of m_axis_rx_pkt_tready : signal is "xilinx.com:interface:axis:1.0 m_axis_rx_pkt TREADY";
  attribute X_INTERFACE_INFO of m_axis_rx_pkt_tdata : signal is "xilinx.com:interface:axis:1.0 m_axis_rx_pkt TDATA";
  attribute X_INTERFACE_INFO of m_axis_rx_pkt_tlast : signal is "xilinx.com:interface:axis:1.0 m_axis_rx_pkt TLAST";
  attribute X_INTERFACE_INFO of m_axis_rx_pkt_tuser : signal is "xilinx.com:interface:axis:1.0 m_axis_rx_pkt TUSER";
  attribute X_INTERFACE_INFO of s_axis_tx_pkt_tvalid : signal is "xilinx.com:interface:axis:1.0 s_axis_tx_pkt TVALID";
  attribute X_INTERFACE_MODE of s_axis_tx_pkt_tvalid : signal is "slave";
  attribute X_INTERFACE_PARAMETER of s_axis_tx_pkt_tvalid : signal is "XIL_INTERFACENAME s_axis_tx_pkt, TDATA_NUM_BYTES 1, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 64, HAS_TREADY 1, HAS_TSTRB 0, HAS_TKEEP 0, HAS_TLAST 1, FREQ_HZ 100000000, PHASE 0.0, CLK_DOMAIN /clk_wiz_ccsds_clk_out1, LAYERED_METADATA undef, INSERT_VIP 0";
  attribute X_INTERFACE_INFO of s_axis_tx_pkt_tready : signal is "xilinx.com:interface:axis:1.0 s_axis_tx_pkt TREADY";
  attribute X_INTERFACE_INFO of s_axis_tx_pkt_tdata : signal is "xilinx.com:interface:axis:1.0 s_axis_tx_pkt TDATA";
  attribute X_INTERFACE_INFO of s_axis_tx_pkt_tlast : signal is "xilinx.com:interface:axis:1.0 s_axis_tx_pkt TLAST";
  attribute X_INTERFACE_INFO of s_axis_tx_pkt_tuser : signal is "xilinx.com:interface:axis:1.0 s_axis_tx_pkt TUSER";
  attribute X_INTERFACE_INFO of clk_sys : signal is "xilinx.com:signal:clock:1.0 clk_sys CLK";
  attribute X_INTERFACE_MODE of clk_sys : signal is "slave";
  attribute X_INTERFACE_PARAMETER of clk_sys : signal is "XIL_INTERFACENAME clk_sys, ASSOCIATED_BUSIF s_axi:m_axis_rx_pkt:s_axis_tx_pkt, ASSOCIATED_RESET rst_n, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN /clk_wiz_ccsds_clk_out1, INSERT_VIP 0";
  attribute X_INTERFACE_INFO of clk_tc_safe : signal is "xilinx.com:signal:clock:1.0 clk_tc_safe CLK";
  attribute X_INTERFACE_MODE of clk_tc_safe : signal is "slave";
  attribute X_INTERFACE_PARAMETER of clk_tc_safe : signal is "XIL_INTERFACENAME clk_tc_safe, FREQ_HZ 16000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN /clk_wiz_ccsds_clk_out1, INSERT_VIP 0";
  attribute X_INTERFACE_INFO of clk_tx_sym : signal is "xilinx.com:signal:clock:1.0 clk_tx_sym CLK";
  attribute X_INTERFACE_MODE of clk_tx_sym : signal is "slave";
  attribute X_INTERFACE_PARAMETER of clk_tx_sym : signal is "XIL_INTERFACENAME clk_tx_sym, FREQ_HZ 50000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN /clk_wiz_ccsds_clk_out1, INSERT_VIP 0";
  attribute X_INTERFACE_INFO of clk_adc_iq : signal is "xilinx.com:signal:clock:1.0 clk_adc_iq CLK";
  attribute X_INTERFACE_MODE of clk_adc_iq : signal is "slave";
  attribute X_INTERFACE_PARAMETER of clk_adc_iq : signal is "XIL_INTERFACENAME clk_adc_iq, FREQ_HZ 120000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN /clk_wiz_ccsds_clk_out1, INSERT_VIP 0";
  attribute X_INTERFACE_INFO of rst_n : signal is "xilinx.com:signal:reset:1.0 rst_n RST";
  attribute X_INTERFACE_MODE of rst_n : signal is "slave";
  attribute X_INTERFACE_PARAMETER of rst_n : signal is "XIL_INTERFACENAME rst_n, POLARITY ACTIVE_LOW, INSERT_VIP 0";
  attribute X_CORE_INFO : string;
  attribute X_CORE_INFO of stub : architecture is "ccsds_sat_ttc_bd_wrapper,Vivado 2026.1.1";
begin
end;
