// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2026 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2026.1.1 (win64) Build 6605303 Fri Sep 04 12:46:29 BST 2026
// Date        : Fri Nov  6 10:32:44 2026
// Host        : Sagittarius running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               c:/Users/abc12/Documents/ccsds_sat_ttc_ip/vivado_z7035_stage1/ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ip/system_stage1_loopback_ccsds_sc_flight_0/system_stage1_loopback_ccsds_sc_flight_0_stub.v
// Design      : system_stage1_loopback_ccsds_sc_flight_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z035ifbg676-2L
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* CHECK_LICENSE_TYPE = "system_stage1_loopback_ccsds_sc_flight_0,ccsds_sat_ttc_bd_wrapper,{}" *) (* CORE_GENERATION_INFO = "system_stage1_loopback_ccsds_sc_flight_0,ccsds_sat_ttc_bd_wrapper,{x_ipProduct=Vivado 2026.1.1,x_ipVendor=xilinx.com,x_ipLibrary=module_ref,x_ipName=ccsds_sat_ttc_bd_wrapper,x_ipVersion=1.0,x_ipCoreRevision=1,x_ipLanguage=VERILOG,x_ipSimLanguage=MIXED,ROLE_MODE=0,ENABLE_SDLS=1,ENABLE_UL_LDPC=1,IQ_BUS_WIDTH=16,RX_MSB_ALIGNED=1}" *) (* DowngradeIPIdentifiedWarnings = "yes" *) 
(* IP_DEFINITION_SOURCE = "module_ref" *) (* X_CORE_INFO = "ccsds_sat_ttc_bd_wrapper,Vivado 2026.1.1" *) 
module system_stage1_loopback_ccsds_sc_flight_0(s_axi_awaddr, s_axi_awvalid, s_axi_awready, 
  s_axi_wdata, s_axi_wstrb, s_axi_wvalid, s_axi_wready, s_axi_bresp, s_axi_bvalid, 
  s_axi_bready, s_axi_araddr, s_axi_arvalid, s_axi_arready, s_axi_rdata, s_axi_rresp, 
  s_axi_rvalid, s_axi_rready, m_axis_rx_pkt_tvalid, m_axis_rx_pkt_tready, 
  m_axis_rx_pkt_tdata, m_axis_rx_pkt_tlast, m_axis_rx_pkt_tuser, s_axis_tx_pkt_tvalid, 
  s_axis_tx_pkt_tready, s_axis_tx_pkt_tdata, s_axis_tx_pkt_tlast, s_axis_tx_pkt_tuser, 
  clk_sys, clk_tc_safe, clk_tx_sym, clk_adc_iq, rst_n, pps_1hz_in, link_proto_override_en, 
  ul_fec_override_en, sdls_en_cfg, bc_require_sdls_cfg, pn_ranging_en_cfg, pn_t4b_mode_cfg, 
  turnaround_xband_cfg, mod_mode_cfg, line_code_cfg, default_tx_vcid_cfg, rx_i_adc_in, 
  rx_q_adc_in, rx_iq_valid_in, tx_i_dac_out, tx_q_dac_out, tx_iq_valid_out, 
  dl_cadu_mon_valid, dl_cadu_mon_data, dl_cadu_mon_last, hcpd_obc_reset_pulse, 
  hcpd_safe_mode_force, hcpd_rf_chain_select, pn_ranging_locked_out, fault_irq_out, 
  edac_scrub_req_out)
/* synthesis syn_black_box black_box_pad_pin="s_axi_awaddr[7:0],s_axi_awvalid,s_axi_awready,s_axi_wdata[31:0],s_axi_wstrb[3:0],s_axi_wvalid,s_axi_wready,s_axi_bresp[1:0],s_axi_bvalid,s_axi_bready,s_axi_araddr[7:0],s_axi_arvalid,s_axi_arready,s_axi_rdata[31:0],s_axi_rresp[1:0],s_axi_rvalid,s_axi_rready,m_axis_rx_pkt_tvalid,m_axis_rx_pkt_tready,m_axis_rx_pkt_tdata[7:0],m_axis_rx_pkt_tlast,m_axis_rx_pkt_tuser[63:0],s_axis_tx_pkt_tvalid,s_axis_tx_pkt_tready,s_axis_tx_pkt_tdata[7:0],s_axis_tx_pkt_tlast,s_axis_tx_pkt_tuser[63:0],rst_n,pps_1hz_in,link_proto_override_en[1:0],ul_fec_override_en[1:0],sdls_en_cfg,bc_require_sdls_cfg,pn_ranging_en_cfg,pn_t4b_mode_cfg,turnaround_xband_cfg,mod_mode_cfg[1:0],line_code_cfg[1:0],default_tx_vcid_cfg[5:0],rx_i_adc_in[15:0],rx_q_adc_in[15:0],rx_iq_valid_in,tx_i_dac_out[15:0],tx_q_dac_out[15:0],tx_iq_valid_out,dl_cadu_mon_valid,dl_cadu_mon_data[7:0],dl_cadu_mon_last,hcpd_obc_reset_pulse,hcpd_safe_mode_force,hcpd_rf_chain_select[1:0],pn_ranging_locked_out,fault_irq_out,edac_scrub_req_out" */
/* synthesis syn_force_seq_prim="clk_sys" */
/* synthesis syn_force_seq_prim="clk_tc_safe" */
/* synthesis syn_force_seq_prim="clk_tx_sym" */
/* synthesis syn_force_seq_prim="clk_adc_iq" */;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi AWADDR" *) (* X_INTERFACE_MODE = "slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s_axi, PROTOCOL AXI4LITE, DATA_WIDTH 32, ADDR_WIDTH 8, FREQ_HZ 100000000, ID_WIDTH 0, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 0, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, MAX_BURST_LENGTH 1, PHASE 0.0, CLK_DOMAIN /clk_wiz_ccsds_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *) input [7:0]s_axi_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi AWVALID" *) input s_axi_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi AWREADY" *) output s_axi_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi WDATA" *) input [31:0]s_axi_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi WSTRB" *) input [3:0]s_axi_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi WVALID" *) input s_axi_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi WREADY" *) output s_axi_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi BRESP" *) output [1:0]s_axi_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi BVALID" *) output s_axi_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi BREADY" *) input s_axi_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi ARADDR" *) input [7:0]s_axi_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi ARVALID" *) input s_axi_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi ARREADY" *) output s_axi_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi RDATA" *) output [31:0]s_axi_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi RRESP" *) output [1:0]s_axi_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi RVALID" *) output s_axi_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi RREADY" *) input s_axi_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_rx_pkt TVALID" *) (* X_INTERFACE_MODE = "master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME m_axis_rx_pkt, TDATA_NUM_BYTES 1, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 64, HAS_TREADY 1, HAS_TSTRB 0, HAS_TKEEP 0, HAS_TLAST 1, FREQ_HZ 100000000, PHASE 0.0, CLK_DOMAIN /clk_wiz_ccsds_clk_out1, LAYERED_METADATA undef, INSERT_VIP 0" *) output m_axis_rx_pkt_tvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_rx_pkt TREADY" *) input m_axis_rx_pkt_tready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_rx_pkt TDATA" *) output [7:0]m_axis_rx_pkt_tdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_rx_pkt TLAST" *) output m_axis_rx_pkt_tlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_rx_pkt TUSER" *) output [63:0]m_axis_rx_pkt_tuser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_tx_pkt TVALID" *) (* X_INTERFACE_MODE = "slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s_axis_tx_pkt, TDATA_NUM_BYTES 1, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 64, HAS_TREADY 1, HAS_TSTRB 0, HAS_TKEEP 0, HAS_TLAST 1, FREQ_HZ 100000000, PHASE 0.0, CLK_DOMAIN /clk_wiz_ccsds_clk_out1, LAYERED_METADATA undef, INSERT_VIP 0" *) input s_axis_tx_pkt_tvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_tx_pkt TREADY" *) output s_axis_tx_pkt_tready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_tx_pkt TDATA" *) input [7:0]s_axis_tx_pkt_tdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_tx_pkt TLAST" *) input s_axis_tx_pkt_tlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_tx_pkt TUSER" *) input [63:0]s_axis_tx_pkt_tuser;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk_sys CLK" *) (* X_INTERFACE_MODE = "slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk_sys, ASSOCIATED_BUSIF s_axi:m_axis_rx_pkt:s_axis_tx_pkt, ASSOCIATED_RESET rst_n, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN /clk_wiz_ccsds_clk_out1, INSERT_VIP 0" *) input clk_sys /* synthesis syn_isclock = 1 */;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk_tc_safe CLK" *) (* X_INTERFACE_MODE = "slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk_tc_safe, FREQ_HZ 16000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN /clk_wiz_ccsds_clk_out1, INSERT_VIP 0" *) input clk_tc_safe /* synthesis syn_isclock = 1 */;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk_tx_sym CLK" *) (* X_INTERFACE_MODE = "slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk_tx_sym, FREQ_HZ 50000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN /clk_wiz_ccsds_clk_out1, INSERT_VIP 0" *) input clk_tx_sym /* synthesis syn_isclock = 1 */;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk_adc_iq CLK" *) (* X_INTERFACE_MODE = "slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk_adc_iq, FREQ_HZ 120000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN /clk_wiz_ccsds_clk_out1, INSERT_VIP 0" *) input clk_adc_iq /* synthesis syn_isclock = 1 */;
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst_n RST" *) (* X_INTERFACE_MODE = "slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME rst_n, POLARITY ACTIVE_LOW, INSERT_VIP 0" *) input rst_n;
  input pps_1hz_in;
  input [1:0]link_proto_override_en;
  input [1:0]ul_fec_override_en;
  input sdls_en_cfg;
  input bc_require_sdls_cfg;
  input pn_ranging_en_cfg;
  input pn_t4b_mode_cfg;
  input turnaround_xband_cfg;
  input [1:0]mod_mode_cfg;
  input [1:0]line_code_cfg;
  input [5:0]default_tx_vcid_cfg;
  input [15:0]rx_i_adc_in;
  input [15:0]rx_q_adc_in;
  input rx_iq_valid_in;
  output [15:0]tx_i_dac_out;
  output [15:0]tx_q_dac_out;
  output tx_iq_valid_out;
  output dl_cadu_mon_valid;
  output [7:0]dl_cadu_mon_data;
  output dl_cadu_mon_last;
  output hcpd_obc_reset_pulse;
  output hcpd_safe_mode_force;
  output [1:0]hcpd_rf_chain_select;
  output pn_ranging_locked_out;
  output fault_irq_out;
  output edac_scrub_req_out;
endmodule
