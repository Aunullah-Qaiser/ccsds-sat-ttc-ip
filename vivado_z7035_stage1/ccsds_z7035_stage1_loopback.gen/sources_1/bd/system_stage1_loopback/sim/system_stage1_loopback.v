//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2026 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2026.1.1 (win64) Build 6605303 Fri Sep 04 12:46:29 BST 2026
//Date        : Fri Nov  6 10:26:56 2026
//Host        : Sagittarius running 64-bit major release  (build 9200)
//Command     : generate_target system_stage1_loopback.bd
//Design      : system_stage1_loopback
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module m00_couplers_imp_13VHS0A
   (M_ACLK,
    M_ARESETN,
    M_AXI_araddr,
    M_AXI_arready,
    M_AXI_arvalid,
    M_AXI_awaddr,
    M_AXI_awready,
    M_AXI_awvalid,
    M_AXI_bready,
    M_AXI_bresp,
    M_AXI_bvalid,
    M_AXI_rdata,
    M_AXI_rready,
    M_AXI_rresp,
    M_AXI_rvalid,
    M_AXI_wdata,
    M_AXI_wready,
    M_AXI_wstrb,
    M_AXI_wvalid,
    S_ACLK,
    S_ARESETN,
    S_AXI_araddr,
    S_AXI_arready,
    S_AXI_arvalid,
    S_AXI_awaddr,
    S_AXI_awready,
    S_AXI_awvalid,
    S_AXI_bready,
    S_AXI_bresp,
    S_AXI_bvalid,
    S_AXI_rdata,
    S_AXI_rready,
    S_AXI_rresp,
    S_AXI_rvalid,
    S_AXI_wdata,
    S_AXI_wready,
    S_AXI_wstrb,
    S_AXI_wvalid);
  input M_ACLK;
  input M_ARESETN;
  output [31:0]M_AXI_araddr;
  input M_AXI_arready;
  output M_AXI_arvalid;
  output [31:0]M_AXI_awaddr;
  input M_AXI_awready;
  output M_AXI_awvalid;
  output M_AXI_bready;
  input [1:0]M_AXI_bresp;
  input M_AXI_bvalid;
  input [31:0]M_AXI_rdata;
  output M_AXI_rready;
  input [1:0]M_AXI_rresp;
  input M_AXI_rvalid;
  output [31:0]M_AXI_wdata;
  input M_AXI_wready;
  output [3:0]M_AXI_wstrb;
  output M_AXI_wvalid;
  input S_ACLK;
  input S_ARESETN;
  input [31:0]S_AXI_araddr;
  output S_AXI_arready;
  input S_AXI_arvalid;
  input [31:0]S_AXI_awaddr;
  output S_AXI_awready;
  input S_AXI_awvalid;
  input S_AXI_bready;
  output [1:0]S_AXI_bresp;
  output S_AXI_bvalid;
  output [31:0]S_AXI_rdata;
  input S_AXI_rready;
  output [1:0]S_AXI_rresp;
  output S_AXI_rvalid;
  input [31:0]S_AXI_wdata;
  output S_AXI_wready;
  input [3:0]S_AXI_wstrb;
  input S_AXI_wvalid;

  wire [31:0]M_AXI_araddr;
  wire M_AXI_arvalid;
  wire [31:0]M_AXI_awaddr;
  wire M_AXI_awvalid;
  wire M_AXI_bready;
  wire M_AXI_rready;
  wire [31:0]M_AXI_wdata;
  wire [3:0]M_AXI_wstrb;
  wire M_AXI_wvalid;
  wire S_AXI_arready;
  wire S_AXI_awready;
  wire [1:0]S_AXI_bresp;
  wire S_AXI_bvalid;
  wire [31:0]S_AXI_rdata;
  wire [1:0]S_AXI_rresp;
  wire S_AXI_rvalid;
  wire S_AXI_wready;

  assign M_AXI_araddr = S_AXI_araddr[31:0];
  assign M_AXI_arvalid = S_AXI_arvalid;
  assign M_AXI_awaddr = S_AXI_awaddr[31:0];
  assign M_AXI_awvalid = S_AXI_awvalid;
  assign M_AXI_bready = S_AXI_bready;
  assign M_AXI_rready = S_AXI_rready;
  assign M_AXI_wdata = S_AXI_wdata[31:0];
  assign M_AXI_wstrb = S_AXI_wstrb[3:0];
  assign M_AXI_wvalid = S_AXI_wvalid;
  assign S_AXI_arready = M_AXI_arready;
  assign S_AXI_awready = M_AXI_awready;
  assign S_AXI_bresp = M_AXI_bresp[1:0];
  assign S_AXI_bvalid = M_AXI_bvalid;
  assign S_AXI_rdata = M_AXI_rdata[31:0];
  assign S_AXI_rresp = M_AXI_rresp[1:0];
  assign S_AXI_rvalid = M_AXI_rvalid;
  assign S_AXI_wready = M_AXI_wready;
endmodule

module m01_couplers_imp_Z2SR6O
   (M_ACLK,
    M_ARESETN,
    M_AXI_araddr,
    M_AXI_arready,
    M_AXI_arvalid,
    M_AXI_awaddr,
    M_AXI_awready,
    M_AXI_awvalid,
    M_AXI_bready,
    M_AXI_bresp,
    M_AXI_bvalid,
    M_AXI_rdata,
    M_AXI_rready,
    M_AXI_rresp,
    M_AXI_rvalid,
    M_AXI_wdata,
    M_AXI_wready,
    M_AXI_wstrb,
    M_AXI_wvalid,
    S_ACLK,
    S_ARESETN,
    S_AXI_araddr,
    S_AXI_arready,
    S_AXI_arvalid,
    S_AXI_awaddr,
    S_AXI_awready,
    S_AXI_awvalid,
    S_AXI_bready,
    S_AXI_bresp,
    S_AXI_bvalid,
    S_AXI_rdata,
    S_AXI_rready,
    S_AXI_rresp,
    S_AXI_rvalid,
    S_AXI_wdata,
    S_AXI_wready,
    S_AXI_wstrb,
    S_AXI_wvalid);
  input M_ACLK;
  input M_ARESETN;
  output [31:0]M_AXI_araddr;
  input M_AXI_arready;
  output M_AXI_arvalid;
  output [31:0]M_AXI_awaddr;
  input M_AXI_awready;
  output M_AXI_awvalid;
  output M_AXI_bready;
  input [1:0]M_AXI_bresp;
  input M_AXI_bvalid;
  input [31:0]M_AXI_rdata;
  output M_AXI_rready;
  input [1:0]M_AXI_rresp;
  input M_AXI_rvalid;
  output [31:0]M_AXI_wdata;
  input M_AXI_wready;
  output [3:0]M_AXI_wstrb;
  output M_AXI_wvalid;
  input S_ACLK;
  input S_ARESETN;
  input [31:0]S_AXI_araddr;
  output S_AXI_arready;
  input S_AXI_arvalid;
  input [31:0]S_AXI_awaddr;
  output S_AXI_awready;
  input S_AXI_awvalid;
  input S_AXI_bready;
  output [1:0]S_AXI_bresp;
  output S_AXI_bvalid;
  output [31:0]S_AXI_rdata;
  input S_AXI_rready;
  output [1:0]S_AXI_rresp;
  output S_AXI_rvalid;
  input [31:0]S_AXI_wdata;
  output S_AXI_wready;
  input [3:0]S_AXI_wstrb;
  input S_AXI_wvalid;

  wire [31:0]M_AXI_araddr;
  wire M_AXI_arvalid;
  wire [31:0]M_AXI_awaddr;
  wire M_AXI_awvalid;
  wire M_AXI_bready;
  wire M_AXI_rready;
  wire [31:0]M_AXI_wdata;
  wire [3:0]M_AXI_wstrb;
  wire M_AXI_wvalid;
  wire S_AXI_arready;
  wire S_AXI_awready;
  wire [1:0]S_AXI_bresp;
  wire S_AXI_bvalid;
  wire [31:0]S_AXI_rdata;
  wire [1:0]S_AXI_rresp;
  wire S_AXI_rvalid;
  wire S_AXI_wready;

  assign M_AXI_araddr = S_AXI_araddr[31:0];
  assign M_AXI_arvalid = S_AXI_arvalid;
  assign M_AXI_awaddr = S_AXI_awaddr[31:0];
  assign M_AXI_awvalid = S_AXI_awvalid;
  assign M_AXI_bready = S_AXI_bready;
  assign M_AXI_rready = S_AXI_rready;
  assign M_AXI_wdata = S_AXI_wdata[31:0];
  assign M_AXI_wstrb = S_AXI_wstrb[3:0];
  assign M_AXI_wvalid = S_AXI_wvalid;
  assign S_AXI_arready = M_AXI_arready;
  assign S_AXI_awready = M_AXI_awready;
  assign S_AXI_bresp = M_AXI_bresp[1:0];
  assign S_AXI_bvalid = M_AXI_bvalid;
  assign S_AXI_rdata = M_AXI_rdata[31:0];
  assign S_AXI_rresp = M_AXI_rresp[1:0];
  assign S_AXI_rvalid = M_AXI_rvalid;
  assign S_AXI_wready = M_AXI_wready;
endmodule

module m02_couplers_imp_1EWFHGF
   (M_ACLK,
    M_ARESETN,
    M_AXI_araddr,
    M_AXI_arready,
    M_AXI_arvalid,
    M_AXI_awaddr,
    M_AXI_awready,
    M_AXI_awvalid,
    M_AXI_bready,
    M_AXI_bresp,
    M_AXI_bvalid,
    M_AXI_rdata,
    M_AXI_rready,
    M_AXI_rresp,
    M_AXI_rvalid,
    M_AXI_wdata,
    M_AXI_wready,
    M_AXI_wstrb,
    M_AXI_wvalid,
    S_ACLK,
    S_ARESETN,
    S_AXI_araddr,
    S_AXI_arready,
    S_AXI_arvalid,
    S_AXI_awaddr,
    S_AXI_awready,
    S_AXI_awvalid,
    S_AXI_bready,
    S_AXI_bresp,
    S_AXI_bvalid,
    S_AXI_rdata,
    S_AXI_rready,
    S_AXI_rresp,
    S_AXI_rvalid,
    S_AXI_wdata,
    S_AXI_wready,
    S_AXI_wstrb,
    S_AXI_wvalid);
  input M_ACLK;
  input M_ARESETN;
  output [31:0]M_AXI_araddr;
  input M_AXI_arready;
  output M_AXI_arvalid;
  output [31:0]M_AXI_awaddr;
  input M_AXI_awready;
  output M_AXI_awvalid;
  output M_AXI_bready;
  input [1:0]M_AXI_bresp;
  input M_AXI_bvalid;
  input [31:0]M_AXI_rdata;
  output M_AXI_rready;
  input [1:0]M_AXI_rresp;
  input M_AXI_rvalid;
  output [31:0]M_AXI_wdata;
  input M_AXI_wready;
  output [3:0]M_AXI_wstrb;
  output M_AXI_wvalid;
  input S_ACLK;
  input S_ARESETN;
  input [31:0]S_AXI_araddr;
  output S_AXI_arready;
  input S_AXI_arvalid;
  input [31:0]S_AXI_awaddr;
  output S_AXI_awready;
  input S_AXI_awvalid;
  input S_AXI_bready;
  output [1:0]S_AXI_bresp;
  output S_AXI_bvalid;
  output [31:0]S_AXI_rdata;
  input S_AXI_rready;
  output [1:0]S_AXI_rresp;
  output S_AXI_rvalid;
  input [31:0]S_AXI_wdata;
  output S_AXI_wready;
  input [3:0]S_AXI_wstrb;
  input S_AXI_wvalid;

  wire [31:0]M_AXI_araddr;
  wire M_AXI_arvalid;
  wire [31:0]M_AXI_awaddr;
  wire M_AXI_awvalid;
  wire M_AXI_bready;
  wire M_AXI_rready;
  wire [31:0]M_AXI_wdata;
  wire [3:0]M_AXI_wstrb;
  wire M_AXI_wvalid;
  wire S_AXI_arready;
  wire S_AXI_awready;
  wire [1:0]S_AXI_bresp;
  wire S_AXI_bvalid;
  wire [31:0]S_AXI_rdata;
  wire [1:0]S_AXI_rresp;
  wire S_AXI_rvalid;
  wire S_AXI_wready;

  assign M_AXI_araddr = S_AXI_araddr[31:0];
  assign M_AXI_arvalid = S_AXI_arvalid;
  assign M_AXI_awaddr = S_AXI_awaddr[31:0];
  assign M_AXI_awvalid = S_AXI_awvalid;
  assign M_AXI_bready = S_AXI_bready;
  assign M_AXI_rready = S_AXI_rready;
  assign M_AXI_wdata = S_AXI_wdata[31:0];
  assign M_AXI_wstrb = S_AXI_wstrb[3:0];
  assign M_AXI_wvalid = S_AXI_wvalid;
  assign S_AXI_arready = M_AXI_arready;
  assign S_AXI_awready = M_AXI_awready;
  assign S_AXI_bresp = M_AXI_bresp[1:0];
  assign S_AXI_bvalid = M_AXI_bvalid;
  assign S_AXI_rdata = M_AXI_rdata[31:0];
  assign S_AXI_rresp = M_AXI_rresp[1:0];
  assign S_AXI_rvalid = M_AXI_rvalid;
  assign S_AXI_wready = M_AXI_wready;
endmodule

module m03_couplers_imp_JLT7ED
   (M_ACLK,
    M_ARESETN,
    M_AXI_araddr,
    M_AXI_arready,
    M_AXI_arvalid,
    M_AXI_awaddr,
    M_AXI_awready,
    M_AXI_awvalid,
    M_AXI_bready,
    M_AXI_bresp,
    M_AXI_bvalid,
    M_AXI_rdata,
    M_AXI_rready,
    M_AXI_rresp,
    M_AXI_rvalid,
    M_AXI_wdata,
    M_AXI_wready,
    M_AXI_wstrb,
    M_AXI_wvalid,
    S_ACLK,
    S_ARESETN,
    S_AXI_araddr,
    S_AXI_arready,
    S_AXI_arvalid,
    S_AXI_awaddr,
    S_AXI_awready,
    S_AXI_awvalid,
    S_AXI_bready,
    S_AXI_bresp,
    S_AXI_bvalid,
    S_AXI_rdata,
    S_AXI_rready,
    S_AXI_rresp,
    S_AXI_rvalid,
    S_AXI_wdata,
    S_AXI_wready,
    S_AXI_wstrb,
    S_AXI_wvalid);
  input M_ACLK;
  input M_ARESETN;
  output [31:0]M_AXI_araddr;
  input M_AXI_arready;
  output M_AXI_arvalid;
  output [31:0]M_AXI_awaddr;
  input M_AXI_awready;
  output M_AXI_awvalid;
  output M_AXI_bready;
  input [1:0]M_AXI_bresp;
  input M_AXI_bvalid;
  input [31:0]M_AXI_rdata;
  output M_AXI_rready;
  input [1:0]M_AXI_rresp;
  input M_AXI_rvalid;
  output [31:0]M_AXI_wdata;
  input M_AXI_wready;
  output [3:0]M_AXI_wstrb;
  output M_AXI_wvalid;
  input S_ACLK;
  input S_ARESETN;
  input [31:0]S_AXI_araddr;
  output S_AXI_arready;
  input S_AXI_arvalid;
  input [31:0]S_AXI_awaddr;
  output S_AXI_awready;
  input S_AXI_awvalid;
  input S_AXI_bready;
  output [1:0]S_AXI_bresp;
  output S_AXI_bvalid;
  output [31:0]S_AXI_rdata;
  input S_AXI_rready;
  output [1:0]S_AXI_rresp;
  output S_AXI_rvalid;
  input [31:0]S_AXI_wdata;
  output S_AXI_wready;
  input [3:0]S_AXI_wstrb;
  input S_AXI_wvalid;

  wire [31:0]M_AXI_araddr;
  wire M_AXI_arvalid;
  wire [31:0]M_AXI_awaddr;
  wire M_AXI_awvalid;
  wire M_AXI_bready;
  wire M_AXI_rready;
  wire [31:0]M_AXI_wdata;
  wire [3:0]M_AXI_wstrb;
  wire M_AXI_wvalid;
  wire S_AXI_arready;
  wire S_AXI_awready;
  wire [1:0]S_AXI_bresp;
  wire S_AXI_bvalid;
  wire [31:0]S_AXI_rdata;
  wire [1:0]S_AXI_rresp;
  wire S_AXI_rvalid;
  wire S_AXI_wready;

  assign M_AXI_araddr = S_AXI_araddr[31:0];
  assign M_AXI_arvalid = S_AXI_arvalid;
  assign M_AXI_awaddr = S_AXI_awaddr[31:0];
  assign M_AXI_awvalid = S_AXI_awvalid;
  assign M_AXI_bready = S_AXI_bready;
  assign M_AXI_rready = S_AXI_rready;
  assign M_AXI_wdata = S_AXI_wdata[31:0];
  assign M_AXI_wstrb = S_AXI_wstrb[3:0];
  assign M_AXI_wvalid = S_AXI_wvalid;
  assign S_AXI_arready = M_AXI_arready;
  assign S_AXI_awready = M_AXI_awready;
  assign S_AXI_bresp = M_AXI_bresp[1:0];
  assign S_AXI_bvalid = M_AXI_bvalid;
  assign S_AXI_rdata = M_AXI_rdata[31:0];
  assign S_AXI_rresp = M_AXI_rresp[1:0];
  assign S_AXI_rvalid = M_AXI_rvalid;
  assign S_AXI_wready = M_AXI_wready;
endmodule

module m04_couplers_imp_1YJHGKG
   (M_ACLK,
    M_ARESETN,
    M_AXI_araddr,
    M_AXI_arready,
    M_AXI_arvalid,
    M_AXI_awaddr,
    M_AXI_awready,
    M_AXI_awvalid,
    M_AXI_bready,
    M_AXI_bresp,
    M_AXI_bvalid,
    M_AXI_rdata,
    M_AXI_rready,
    M_AXI_rresp,
    M_AXI_rvalid,
    M_AXI_wdata,
    M_AXI_wready,
    M_AXI_wstrb,
    M_AXI_wvalid,
    S_ACLK,
    S_ARESETN,
    S_AXI_araddr,
    S_AXI_arready,
    S_AXI_arvalid,
    S_AXI_awaddr,
    S_AXI_awready,
    S_AXI_awvalid,
    S_AXI_bready,
    S_AXI_bresp,
    S_AXI_bvalid,
    S_AXI_rdata,
    S_AXI_rready,
    S_AXI_rresp,
    S_AXI_rvalid,
    S_AXI_wdata,
    S_AXI_wready,
    S_AXI_wstrb,
    S_AXI_wvalid);
  input M_ACLK;
  input M_ARESETN;
  output [31:0]M_AXI_araddr;
  input M_AXI_arready;
  output M_AXI_arvalid;
  output [31:0]M_AXI_awaddr;
  input M_AXI_awready;
  output M_AXI_awvalid;
  output M_AXI_bready;
  input [1:0]M_AXI_bresp;
  input M_AXI_bvalid;
  input [31:0]M_AXI_rdata;
  output M_AXI_rready;
  input [1:0]M_AXI_rresp;
  input M_AXI_rvalid;
  output [31:0]M_AXI_wdata;
  input M_AXI_wready;
  output [3:0]M_AXI_wstrb;
  output M_AXI_wvalid;
  input S_ACLK;
  input S_ARESETN;
  input [31:0]S_AXI_araddr;
  output S_AXI_arready;
  input S_AXI_arvalid;
  input [31:0]S_AXI_awaddr;
  output S_AXI_awready;
  input S_AXI_awvalid;
  input S_AXI_bready;
  output [1:0]S_AXI_bresp;
  output S_AXI_bvalid;
  output [31:0]S_AXI_rdata;
  input S_AXI_rready;
  output [1:0]S_AXI_rresp;
  output S_AXI_rvalid;
  input [31:0]S_AXI_wdata;
  output S_AXI_wready;
  input [3:0]S_AXI_wstrb;
  input S_AXI_wvalid;

  wire [31:0]M_AXI_araddr;
  wire M_AXI_arvalid;
  wire [31:0]M_AXI_awaddr;
  wire M_AXI_awvalid;
  wire M_AXI_bready;
  wire M_AXI_rready;
  wire [31:0]M_AXI_wdata;
  wire [3:0]M_AXI_wstrb;
  wire M_AXI_wvalid;
  wire S_AXI_arready;
  wire S_AXI_awready;
  wire [1:0]S_AXI_bresp;
  wire S_AXI_bvalid;
  wire [31:0]S_AXI_rdata;
  wire [1:0]S_AXI_rresp;
  wire S_AXI_rvalid;
  wire S_AXI_wready;

  assign M_AXI_araddr = S_AXI_araddr[31:0];
  assign M_AXI_arvalid = S_AXI_arvalid;
  assign M_AXI_awaddr = S_AXI_awaddr[31:0];
  assign M_AXI_awvalid = S_AXI_awvalid;
  assign M_AXI_bready = S_AXI_bready;
  assign M_AXI_rready = S_AXI_rready;
  assign M_AXI_wdata = S_AXI_wdata[31:0];
  assign M_AXI_wstrb = S_AXI_wstrb[3:0];
  assign M_AXI_wvalid = S_AXI_wvalid;
  assign S_AXI_arready = M_AXI_arready;
  assign S_AXI_awready = M_AXI_awready;
  assign S_AXI_bresp = M_AXI_bresp[1:0];
  assign S_AXI_bvalid = M_AXI_bvalid;
  assign S_AXI_rdata = M_AXI_rdata[31:0];
  assign S_AXI_rresp = M_AXI_rresp[1:0];
  assign S_AXI_rvalid = M_AXI_rvalid;
  assign S_AXI_wready = M_AXI_wready;
endmodule

module s00_couplers_imp_13IPBE4
   (M_ACLK,
    M_ARESETN,
    M_AXI_araddr,
    M_AXI_arprot,
    M_AXI_arready,
    M_AXI_arvalid,
    M_AXI_awaddr,
    M_AXI_awprot,
    M_AXI_awready,
    M_AXI_awvalid,
    M_AXI_bready,
    M_AXI_bresp,
    M_AXI_bvalid,
    M_AXI_rdata,
    M_AXI_rready,
    M_AXI_rresp,
    M_AXI_rvalid,
    M_AXI_wdata,
    M_AXI_wready,
    M_AXI_wstrb,
    M_AXI_wvalid,
    S_ACLK,
    S_ARESETN,
    S_AXI_araddr,
    S_AXI_arburst,
    S_AXI_arcache,
    S_AXI_arid,
    S_AXI_arlen,
    S_AXI_arlock,
    S_AXI_arprot,
    S_AXI_arqos,
    S_AXI_arready,
    S_AXI_arsize,
    S_AXI_arvalid,
    S_AXI_awaddr,
    S_AXI_awburst,
    S_AXI_awcache,
    S_AXI_awid,
    S_AXI_awlen,
    S_AXI_awlock,
    S_AXI_awprot,
    S_AXI_awqos,
    S_AXI_awready,
    S_AXI_awsize,
    S_AXI_awvalid,
    S_AXI_bid,
    S_AXI_bready,
    S_AXI_bresp,
    S_AXI_bvalid,
    S_AXI_rdata,
    S_AXI_rid,
    S_AXI_rlast,
    S_AXI_rready,
    S_AXI_rresp,
    S_AXI_rvalid,
    S_AXI_wdata,
    S_AXI_wid,
    S_AXI_wlast,
    S_AXI_wready,
    S_AXI_wstrb,
    S_AXI_wvalid);
  input M_ACLK;
  input M_ARESETN;
  output [31:0]M_AXI_araddr;
  output [2:0]M_AXI_arprot;
  input M_AXI_arready;
  output M_AXI_arvalid;
  output [31:0]M_AXI_awaddr;
  output [2:0]M_AXI_awprot;
  input M_AXI_awready;
  output M_AXI_awvalid;
  output M_AXI_bready;
  input [1:0]M_AXI_bresp;
  input M_AXI_bvalid;
  input [31:0]M_AXI_rdata;
  output M_AXI_rready;
  input [1:0]M_AXI_rresp;
  input M_AXI_rvalid;
  output [31:0]M_AXI_wdata;
  input M_AXI_wready;
  output [3:0]M_AXI_wstrb;
  output M_AXI_wvalid;
  input S_ACLK;
  input S_ARESETN;
  input [31:0]S_AXI_araddr;
  input [1:0]S_AXI_arburst;
  input [3:0]S_AXI_arcache;
  input [11:0]S_AXI_arid;
  input [3:0]S_AXI_arlen;
  input [1:0]S_AXI_arlock;
  input [2:0]S_AXI_arprot;
  input [3:0]S_AXI_arqos;
  output S_AXI_arready;
  input [2:0]S_AXI_arsize;
  input S_AXI_arvalid;
  input [31:0]S_AXI_awaddr;
  input [1:0]S_AXI_awburst;
  input [3:0]S_AXI_awcache;
  input [11:0]S_AXI_awid;
  input [3:0]S_AXI_awlen;
  input [1:0]S_AXI_awlock;
  input [2:0]S_AXI_awprot;
  input [3:0]S_AXI_awqos;
  output S_AXI_awready;
  input [2:0]S_AXI_awsize;
  input S_AXI_awvalid;
  output [11:0]S_AXI_bid;
  input S_AXI_bready;
  output [1:0]S_AXI_bresp;
  output S_AXI_bvalid;
  output [31:0]S_AXI_rdata;
  output [11:0]S_AXI_rid;
  output S_AXI_rlast;
  input S_AXI_rready;
  output [1:0]S_AXI_rresp;
  output S_AXI_rvalid;
  input [31:0]S_AXI_wdata;
  input [11:0]S_AXI_wid;
  input S_AXI_wlast;
  output S_AXI_wready;
  input [3:0]S_AXI_wstrb;
  input S_AXI_wvalid;

  wire [31:0]M_AXI_araddr;
  wire [2:0]M_AXI_arprot;
  wire M_AXI_arready;
  wire M_AXI_arvalid;
  wire [31:0]M_AXI_awaddr;
  wire [2:0]M_AXI_awprot;
  wire M_AXI_awready;
  wire M_AXI_awvalid;
  wire M_AXI_bready;
  wire [1:0]M_AXI_bresp;
  wire M_AXI_bvalid;
  wire [31:0]M_AXI_rdata;
  wire M_AXI_rready;
  wire [1:0]M_AXI_rresp;
  wire M_AXI_rvalid;
  wire [31:0]M_AXI_wdata;
  wire M_AXI_wready;
  wire [3:0]M_AXI_wstrb;
  wire M_AXI_wvalid;
  wire S_ACLK;
  wire S_ARESETN;
  wire [31:0]S_AXI_araddr;
  wire [1:0]S_AXI_arburst;
  wire [3:0]S_AXI_arcache;
  wire [11:0]S_AXI_arid;
  wire [3:0]S_AXI_arlen;
  wire [1:0]S_AXI_arlock;
  wire [2:0]S_AXI_arprot;
  wire [3:0]S_AXI_arqos;
  wire S_AXI_arready;
  wire [2:0]S_AXI_arsize;
  wire S_AXI_arvalid;
  wire [31:0]S_AXI_awaddr;
  wire [1:0]S_AXI_awburst;
  wire [3:0]S_AXI_awcache;
  wire [11:0]S_AXI_awid;
  wire [3:0]S_AXI_awlen;
  wire [1:0]S_AXI_awlock;
  wire [2:0]S_AXI_awprot;
  wire [3:0]S_AXI_awqos;
  wire S_AXI_awready;
  wire [2:0]S_AXI_awsize;
  wire S_AXI_awvalid;
  wire [11:0]S_AXI_bid;
  wire S_AXI_bready;
  wire [1:0]S_AXI_bresp;
  wire S_AXI_bvalid;
  wire [31:0]S_AXI_rdata;
  wire [11:0]S_AXI_rid;
  wire S_AXI_rlast;
  wire S_AXI_rready;
  wire [1:0]S_AXI_rresp;
  wire S_AXI_rvalid;
  wire [31:0]S_AXI_wdata;
  wire [11:0]S_AXI_wid;
  wire S_AXI_wlast;
  wire S_AXI_wready;
  wire [3:0]S_AXI_wstrb;
  wire S_AXI_wvalid;

  system_stage1_loopback_axi_ic_gp0_imp_auto_pc_0 auto_pc
       (.aclk(S_ACLK),
        .aresetn(S_ARESETN),
        .m_axi_araddr(M_AXI_araddr),
        .m_axi_arprot(M_AXI_arprot),
        .m_axi_arready(M_AXI_arready),
        .m_axi_arvalid(M_AXI_arvalid),
        .m_axi_awaddr(M_AXI_awaddr),
        .m_axi_awprot(M_AXI_awprot),
        .m_axi_awready(M_AXI_awready),
        .m_axi_awvalid(M_AXI_awvalid),
        .m_axi_bready(M_AXI_bready),
        .m_axi_bresp(M_AXI_bresp),
        .m_axi_bvalid(M_AXI_bvalid),
        .m_axi_rdata(M_AXI_rdata),
        .m_axi_rready(M_AXI_rready),
        .m_axi_rresp(M_AXI_rresp),
        .m_axi_rvalid(M_AXI_rvalid),
        .m_axi_wdata(M_AXI_wdata),
        .m_axi_wready(M_AXI_wready),
        .m_axi_wstrb(M_AXI_wstrb),
        .m_axi_wvalid(M_AXI_wvalid),
        .s_axi_araddr(S_AXI_araddr),
        .s_axi_arburst(S_AXI_arburst),
        .s_axi_arcache(S_AXI_arcache),
        .s_axi_arid(S_AXI_arid),
        .s_axi_arlen(S_AXI_arlen),
        .s_axi_arlock(S_AXI_arlock),
        .s_axi_arprot(S_AXI_arprot),
        .s_axi_arqos(S_AXI_arqos),
        .s_axi_arready(S_AXI_arready),
        .s_axi_arsize(S_AXI_arsize),
        .s_axi_arvalid(S_AXI_arvalid),
        .s_axi_awaddr(S_AXI_awaddr),
        .s_axi_awburst(S_AXI_awburst),
        .s_axi_awcache(S_AXI_awcache),
        .s_axi_awid(S_AXI_awid),
        .s_axi_awlen(S_AXI_awlen),
        .s_axi_awlock(S_AXI_awlock),
        .s_axi_awprot(S_AXI_awprot),
        .s_axi_awqos(S_AXI_awqos),
        .s_axi_awready(S_AXI_awready),
        .s_axi_awsize(S_AXI_awsize),
        .s_axi_awvalid(S_AXI_awvalid),
        .s_axi_bid(S_AXI_bid),
        .s_axi_bready(S_AXI_bready),
        .s_axi_bresp(S_AXI_bresp),
        .s_axi_bvalid(S_AXI_bvalid),
        .s_axi_rdata(S_AXI_rdata),
        .s_axi_rid(S_AXI_rid),
        .s_axi_rlast(S_AXI_rlast),
        .s_axi_rready(S_AXI_rready),
        .s_axi_rresp(S_AXI_rresp),
        .s_axi_rvalid(S_AXI_rvalid),
        .s_axi_wdata(S_AXI_wdata),
        .s_axi_wid(S_AXI_wid),
        .s_axi_wlast(S_AXI_wlast),
        .s_axi_wready(S_AXI_wready),
        .s_axi_wstrb(S_AXI_wstrb),
        .s_axi_wvalid(S_AXI_wvalid));
endmodule

(* CORE_GENERATION_INFO = "system_stage1_loopback,IP_Integrator,{x_ipVendor=xilinx.com,x_ipLibrary=BlockDiagram,x_ipName=system_stage1_loopback,x_ipVersion=1.00.a,x_ipLanguage=VERILOG}" *) (* HW_HANDOFF = "system_stage1_loopback.hwdef" *) 
module system_stage1_loopback
   (DDR_addr,
    DDR_ba,
    DDR_cas_n,
    DDR_ck_n,
    DDR_ck_p,
    DDR_cke,
    DDR_cs_n,
    DDR_dm,
    DDR_dq,
    DDR_dqs_n,
    DDR_dqs_p,
    DDR_odt,
    DDR_ras_n,
    DDR_reset_n,
    DDR_we_n,
    FIXED_IO_ddr_vrn,
    FIXED_IO_ddr_vrp,
    FIXED_IO_mio,
    FIXED_IO_ps_clk,
    FIXED_IO_ps_porb,
    FIXED_IO_ps_srstb);
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR ADDR" *) (* X_INTERFACE_MODE = "Master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME DDR, AXI_ARBITRATION_SCHEME TDM, BURST_LENGTH 8, CAN_DEBUG false, CAS_LATENCY 11, CAS_WRITE_LATENCY 11, CS_ENABLED true, DATA_MASK_ENABLED true, DATA_WIDTH 8, MEMORY_TYPE COMPONENTS, MEM_ADDR_MAP ROW_COLUMN_BANK, SLOT Single, TIMEPERIOD_PS 1250" *) inout [14:0]DDR_addr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR BA" *) inout [2:0]DDR_ba;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR CAS_N" *) inout DDR_cas_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR CK_N" *) inout DDR_ck_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR CK_P" *) inout DDR_ck_p;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR CKE" *) inout DDR_cke;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR CS_N" *) inout DDR_cs_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR DM" *) inout [3:0]DDR_dm;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR DQ" *) inout [31:0]DDR_dq;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR DQS_N" *) inout [3:0]DDR_dqs_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR DQS_P" *) inout [3:0]DDR_dqs_p;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR ODT" *) inout DDR_odt;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR RAS_N" *) inout DDR_ras_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR RESET_N" *) inout DDR_reset_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR WE_N" *) inout DDR_we_n;
  (* X_INTERFACE_INFO = "xilinx.com:display_processing_system7:fixedio:1.0 FIXED_IO DDR_VRN" *) (* X_INTERFACE_MODE = "Master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME FIXED_IO, CAN_DEBUG false" *) inout FIXED_IO_ddr_vrn;
  (* X_INTERFACE_INFO = "xilinx.com:display_processing_system7:fixedio:1.0 FIXED_IO DDR_VRP" *) inout FIXED_IO_ddr_vrp;
  (* X_INTERFACE_INFO = "xilinx.com:display_processing_system7:fixedio:1.0 FIXED_IO MIO" *) inout [53:0]FIXED_IO_mio;
  (* X_INTERFACE_INFO = "xilinx.com:display_processing_system7:fixedio:1.0 FIXED_IO PS_CLK" *) inout FIXED_IO_ps_clk;
  (* X_INTERFACE_INFO = "xilinx.com:display_processing_system7:fixedio:1.0 FIXED_IO PS_PORB" *) inout FIXED_IO_ps_porb;
  (* X_INTERFACE_INFO = "xilinx.com:display_processing_system7:fixedio:1.0 FIXED_IO PS_SRSTB" *) inout FIXED_IO_ps_srstb;

  wire [14:0]DDR_addr;
  wire [2:0]DDR_ba;
  wire DDR_cas_n;
  wire DDR_ck_n;
  wire DDR_ck_p;
  wire DDR_cke;
  wire DDR_cs_n;
  wire [3:0]DDR_dm;
  wire [31:0]DDR_dq;
  wire [3:0]DDR_dqs_n;
  wire [3:0]DDR_dqs_p;
  wire DDR_odt;
  wire DDR_ras_n;
  wire DDR_reset_n;
  wire DDR_we_n;
  wire FIXED_IO_ddr_vrn;
  wire FIXED_IO_ddr_vrp;
  wire [53:0]FIXED_IO_mio;
  wire FIXED_IO_ps_clk;
  wire FIXED_IO_ps_porb;
  wire FIXED_IO_ps_srstb;
  wire [19:0]axi_gpio_straps_gpio_io_o;
  wire [31:0]axi_ic_gp0_M00_AXI_ARADDR;
  wire axi_ic_gp0_M00_AXI_ARREADY;
  wire axi_ic_gp0_M00_AXI_ARVALID;
  wire [31:0]axi_ic_gp0_M00_AXI_AWADDR;
  wire axi_ic_gp0_M00_AXI_AWREADY;
  wire axi_ic_gp0_M00_AXI_AWVALID;
  wire axi_ic_gp0_M00_AXI_BREADY;
  wire [1:0]axi_ic_gp0_M00_AXI_BRESP;
  wire axi_ic_gp0_M00_AXI_BVALID;
  wire [31:0]axi_ic_gp0_M00_AXI_RDATA;
  wire axi_ic_gp0_M00_AXI_RREADY;
  wire [1:0]axi_ic_gp0_M00_AXI_RRESP;
  wire axi_ic_gp0_M00_AXI_RVALID;
  wire [31:0]axi_ic_gp0_M00_AXI_WDATA;
  wire axi_ic_gp0_M00_AXI_WREADY;
  wire [3:0]axi_ic_gp0_M00_AXI_WSTRB;
  wire axi_ic_gp0_M00_AXI_WVALID;
  wire [31:0]axi_ic_gp0_M01_AXI_ARADDR;
  wire axi_ic_gp0_M01_AXI_ARREADY;
  wire axi_ic_gp0_M01_AXI_ARVALID;
  wire [31:0]axi_ic_gp0_M01_AXI_AWADDR;
  wire axi_ic_gp0_M01_AXI_AWREADY;
  wire axi_ic_gp0_M01_AXI_AWVALID;
  wire axi_ic_gp0_M01_AXI_BREADY;
  wire [1:0]axi_ic_gp0_M01_AXI_BRESP;
  wire axi_ic_gp0_M01_AXI_BVALID;
  wire [31:0]axi_ic_gp0_M01_AXI_RDATA;
  wire axi_ic_gp0_M01_AXI_RREADY;
  wire [1:0]axi_ic_gp0_M01_AXI_RRESP;
  wire axi_ic_gp0_M01_AXI_RVALID;
  wire [31:0]axi_ic_gp0_M01_AXI_WDATA;
  wire axi_ic_gp0_M01_AXI_WREADY;
  wire [3:0]axi_ic_gp0_M01_AXI_WSTRB;
  wire axi_ic_gp0_M01_AXI_WVALID;
  wire [31:0]axi_ic_gp0_M02_AXI_ARADDR;
  wire axi_ic_gp0_M02_AXI_ARREADY;
  wire axi_ic_gp0_M02_AXI_ARVALID;
  wire [31:0]axi_ic_gp0_M02_AXI_AWADDR;
  wire axi_ic_gp0_M02_AXI_AWREADY;
  wire axi_ic_gp0_M02_AXI_AWVALID;
  wire axi_ic_gp0_M02_AXI_BREADY;
  wire [1:0]axi_ic_gp0_M02_AXI_BRESP;
  wire axi_ic_gp0_M02_AXI_BVALID;
  wire [31:0]axi_ic_gp0_M02_AXI_RDATA;
  wire axi_ic_gp0_M02_AXI_RREADY;
  wire [1:0]axi_ic_gp0_M02_AXI_RRESP;
  wire axi_ic_gp0_M02_AXI_RVALID;
  wire [31:0]axi_ic_gp0_M02_AXI_WDATA;
  wire axi_ic_gp0_M02_AXI_WREADY;
  wire [3:0]axi_ic_gp0_M02_AXI_WSTRB;
  wire axi_ic_gp0_M02_AXI_WVALID;
  wire [31:0]axi_ic_gp0_M03_AXI_ARADDR;
  wire axi_ic_gp0_M03_AXI_ARREADY;
  wire axi_ic_gp0_M03_AXI_ARVALID;
  wire [31:0]axi_ic_gp0_M03_AXI_AWADDR;
  wire axi_ic_gp0_M03_AXI_AWREADY;
  wire axi_ic_gp0_M03_AXI_AWVALID;
  wire axi_ic_gp0_M03_AXI_BREADY;
  wire [1:0]axi_ic_gp0_M03_AXI_BRESP;
  wire axi_ic_gp0_M03_AXI_BVALID;
  wire [31:0]axi_ic_gp0_M03_AXI_RDATA;
  wire axi_ic_gp0_M03_AXI_RREADY;
  wire [1:0]axi_ic_gp0_M03_AXI_RRESP;
  wire axi_ic_gp0_M03_AXI_RVALID;
  wire [31:0]axi_ic_gp0_M03_AXI_WDATA;
  wire axi_ic_gp0_M03_AXI_WREADY;
  wire [3:0]axi_ic_gp0_M03_AXI_WSTRB;
  wire axi_ic_gp0_M03_AXI_WVALID;
  wire [31:0]axi_ic_gp0_M04_AXI_ARADDR;
  wire axi_ic_gp0_M04_AXI_ARREADY;
  wire axi_ic_gp0_M04_AXI_ARVALID;
  wire [31:0]axi_ic_gp0_M04_AXI_AWADDR;
  wire axi_ic_gp0_M04_AXI_AWREADY;
  wire axi_ic_gp0_M04_AXI_AWVALID;
  wire axi_ic_gp0_M04_AXI_BREADY;
  wire [1:0]axi_ic_gp0_M04_AXI_BRESP;
  wire axi_ic_gp0_M04_AXI_BVALID;
  wire [31:0]axi_ic_gp0_M04_AXI_RDATA;
  wire axi_ic_gp0_M04_AXI_RREADY;
  wire [1:0]axi_ic_gp0_M04_AXI_RRESP;
  wire axi_ic_gp0_M04_AXI_RVALID;
  wire [31:0]axi_ic_gp0_M04_AXI_WDATA;
  wire axi_ic_gp0_M04_AXI_WREADY;
  wire [3:0]axi_ic_gp0_M04_AXI_WSTRB;
  wire axi_ic_gp0_M04_AXI_WVALID;
  wire [7:0]ccsds_gnd_egse_dw_32to8_M_AXIS_TDATA;
  wire ccsds_gnd_egse_dw_32to8_M_AXIS_TLAST;
  wire ccsds_gnd_egse_dw_32to8_M_AXIS_TREADY;
  wire ccsds_gnd_egse_dw_32to8_M_AXIS_TVALID;
  wire [31:0]ccsds_gnd_egse_dw_8to32_M_AXIS_TDATA;
  wire [3:0]ccsds_gnd_egse_dw_8to32_M_AXIS_TKEEP;
  wire ccsds_gnd_egse_dw_8to32_M_AXIS_TLAST;
  wire ccsds_gnd_egse_dw_8to32_M_AXIS_TREADY;
  wire ccsds_gnd_egse_dw_8to32_M_AXIS_TVALID;
  wire [7:0]ccsds_gnd_egse_m_axis_rx_pkt_TDATA;
  wire ccsds_gnd_egse_m_axis_rx_pkt_TLAST;
  wire ccsds_gnd_egse_m_axis_rx_pkt_TREADY;
  wire [63:0]ccsds_gnd_egse_m_axis_rx_pkt_TUSER;
  wire ccsds_gnd_egse_m_axis_rx_pkt_TVALID;
  wire [31:0]ccsds_gnd_egse_pkt_fifo_AXI_STR_TXD_TDATA;
  wire [3:0]ccsds_gnd_egse_pkt_fifo_AXI_STR_TXD_TKEEP;
  wire ccsds_gnd_egse_pkt_fifo_AXI_STR_TXD_TLAST;
  wire ccsds_gnd_egse_pkt_fifo_AXI_STR_TXD_TREADY;
  wire ccsds_gnd_egse_pkt_fifo_AXI_STR_TXD_TVALID;
  wire [15:0]ccsds_gnd_egse_tx_i_dac_out;
  wire ccsds_gnd_egse_tx_iq_valid_out;
  wire [15:0]ccsds_gnd_egse_tx_q_dac_out;
  wire [7:0]ccsds_sc_flight_dw_32to8_M_AXIS_TDATA;
  wire ccsds_sc_flight_dw_32to8_M_AXIS_TLAST;
  wire ccsds_sc_flight_dw_32to8_M_AXIS_TREADY;
  wire ccsds_sc_flight_dw_32to8_M_AXIS_TVALID;
  wire [31:0]ccsds_sc_flight_dw_8to32_M_AXIS_TDATA;
  wire [3:0]ccsds_sc_flight_dw_8to32_M_AXIS_TKEEP;
  wire ccsds_sc_flight_dw_8to32_M_AXIS_TLAST;
  wire ccsds_sc_flight_dw_8to32_M_AXIS_TREADY;
  wire ccsds_sc_flight_dw_8to32_M_AXIS_TVALID;
  wire ccsds_sc_flight_edac_scrub_req_out;
  wire ccsds_sc_flight_fault_irq_out;
  wire ccsds_sc_flight_hcpd_obc_reset_pulse;
  wire [1:0]ccsds_sc_flight_hcpd_rf_chain_select;
  wire ccsds_sc_flight_hcpd_safe_mode_force;
  wire [7:0]ccsds_sc_flight_m_axis_rx_pkt_TDATA;
  wire ccsds_sc_flight_m_axis_rx_pkt_TLAST;
  wire ccsds_sc_flight_m_axis_rx_pkt_TREADY;
  wire [63:0]ccsds_sc_flight_m_axis_rx_pkt_TUSER;
  wire ccsds_sc_flight_m_axis_rx_pkt_TVALID;
  wire [31:0]ccsds_sc_flight_pkt_fifo_AXI_STR_TXD_TDATA;
  wire [3:0]ccsds_sc_flight_pkt_fifo_AXI_STR_TXD_TKEEP;
  wire ccsds_sc_flight_pkt_fifo_AXI_STR_TXD_TLAST;
  wire ccsds_sc_flight_pkt_fifo_AXI_STR_TXD_TREADY;
  wire ccsds_sc_flight_pkt_fifo_AXI_STR_TXD_TVALID;
  wire ccsds_sc_flight_pn_ranging_locked_out;
  wire [15:0]ccsds_sc_flight_tx_i_dac_out;
  wire ccsds_sc_flight_tx_iq_valid_out;
  wire [15:0]ccsds_sc_flight_tx_q_dac_out;
  wire clk_wiz_ccsds_clk_out1;
  wire clk_wiz_ccsds_clk_out2;
  wire clk_wiz_ccsds_clk_out3;
  wire clk_wiz_ccsds_clk_out4;
  wire clk_wiz_ccsds_locked;
  wire [6:0]concat_status_7b_dout;
  wire processing_system7_0_FCLK_CLK0;
  wire processing_system7_0_FCLK_RESET0_N;
  wire [31:0]processing_system7_0_M_AXI_GP0_ARADDR;
  wire [1:0]processing_system7_0_M_AXI_GP0_ARBURST;
  wire [3:0]processing_system7_0_M_AXI_GP0_ARCACHE;
  wire [11:0]processing_system7_0_M_AXI_GP0_ARID;
  wire [3:0]processing_system7_0_M_AXI_GP0_ARLEN;
  wire [1:0]processing_system7_0_M_AXI_GP0_ARLOCK;
  wire [2:0]processing_system7_0_M_AXI_GP0_ARPROT;
  wire [3:0]processing_system7_0_M_AXI_GP0_ARQOS;
  wire processing_system7_0_M_AXI_GP0_ARREADY;
  wire [2:0]processing_system7_0_M_AXI_GP0_ARSIZE;
  wire processing_system7_0_M_AXI_GP0_ARVALID;
  wire [31:0]processing_system7_0_M_AXI_GP0_AWADDR;
  wire [1:0]processing_system7_0_M_AXI_GP0_AWBURST;
  wire [3:0]processing_system7_0_M_AXI_GP0_AWCACHE;
  wire [11:0]processing_system7_0_M_AXI_GP0_AWID;
  wire [3:0]processing_system7_0_M_AXI_GP0_AWLEN;
  wire [1:0]processing_system7_0_M_AXI_GP0_AWLOCK;
  wire [2:0]processing_system7_0_M_AXI_GP0_AWPROT;
  wire [3:0]processing_system7_0_M_AXI_GP0_AWQOS;
  wire processing_system7_0_M_AXI_GP0_AWREADY;
  wire [2:0]processing_system7_0_M_AXI_GP0_AWSIZE;
  wire processing_system7_0_M_AXI_GP0_AWVALID;
  wire [11:0]processing_system7_0_M_AXI_GP0_BID;
  wire processing_system7_0_M_AXI_GP0_BREADY;
  wire [1:0]processing_system7_0_M_AXI_GP0_BRESP;
  wire processing_system7_0_M_AXI_GP0_BVALID;
  wire [31:0]processing_system7_0_M_AXI_GP0_RDATA;
  wire [11:0]processing_system7_0_M_AXI_GP0_RID;
  wire processing_system7_0_M_AXI_GP0_RLAST;
  wire processing_system7_0_M_AXI_GP0_RREADY;
  wire [1:0]processing_system7_0_M_AXI_GP0_RRESP;
  wire processing_system7_0_M_AXI_GP0_RVALID;
  wire [31:0]processing_system7_0_M_AXI_GP0_WDATA;
  wire [11:0]processing_system7_0_M_AXI_GP0_WID;
  wire processing_system7_0_M_AXI_GP0_WLAST;
  wire processing_system7_0_M_AXI_GP0_WREADY;
  wire [3:0]processing_system7_0_M_AXI_GP0_WSTRB;
  wire processing_system7_0_M_AXI_GP0_WVALID;
  wire [0:0]rst_clk_sys_100M_interconnect_aresetn;
  wire [0:0]rst_clk_sys_100M_peripheral_aresetn;
  wire [0:0]sl_bc_sdls_Dout;
  wire [1:0]sl_line_code_Dout;
  wire [1:0]sl_mod_mode_Dout;
  wire [0:0]sl_pn_en_Dout;
  wire [0:0]sl_pn_t4b_Dout;
  wire [0:0]sl_pps_pulse_Dout;
  wire [1:0]sl_proto_ovr_Dout;
  wire [0:0]sl_sdls_en_Dout;
  wire [0:0]sl_turn_xb_Dout;
  wire [5:0]sl_tx_vcid_Dout;
  wire [1:0]sl_ul_fec_Dout;

  system_stage1_loopback_axi_gpio_straps_0 axi_gpio_straps
       (.gpio2_io_i(concat_status_7b_dout),
        .gpio_io_o(axi_gpio_straps_gpio_io_o),
        .s_axi_aclk(clk_wiz_ccsds_clk_out1),
        .s_axi_araddr(axi_ic_gp0_M00_AXI_ARADDR[8:0]),
        .s_axi_aresetn(rst_clk_sys_100M_peripheral_aresetn),
        .s_axi_arready(axi_ic_gp0_M00_AXI_ARREADY),
        .s_axi_arvalid(axi_ic_gp0_M00_AXI_ARVALID),
        .s_axi_awaddr(axi_ic_gp0_M00_AXI_AWADDR[8:0]),
        .s_axi_awready(axi_ic_gp0_M00_AXI_AWREADY),
        .s_axi_awvalid(axi_ic_gp0_M00_AXI_AWVALID),
        .s_axi_bready(axi_ic_gp0_M00_AXI_BREADY),
        .s_axi_bresp(axi_ic_gp0_M00_AXI_BRESP),
        .s_axi_bvalid(axi_ic_gp0_M00_AXI_BVALID),
        .s_axi_rdata(axi_ic_gp0_M00_AXI_RDATA),
        .s_axi_rready(axi_ic_gp0_M00_AXI_RREADY),
        .s_axi_rresp(axi_ic_gp0_M00_AXI_RRESP),
        .s_axi_rvalid(axi_ic_gp0_M00_AXI_RVALID),
        .s_axi_wdata(axi_ic_gp0_M00_AXI_WDATA),
        .s_axi_wready(axi_ic_gp0_M00_AXI_WREADY),
        .s_axi_wstrb(axi_ic_gp0_M00_AXI_WSTRB),
        .s_axi_wvalid(axi_ic_gp0_M00_AXI_WVALID));
  system_stage1_loopback_axi_ic_gp0_0 axi_ic_gp0
       (.ACLK(clk_wiz_ccsds_clk_out1),
        .ARESETN(rst_clk_sys_100M_interconnect_aresetn),
        .M00_ACLK(clk_wiz_ccsds_clk_out1),
        .M00_ARESETN(rst_clk_sys_100M_peripheral_aresetn),
        .M00_AXI_araddr(axi_ic_gp0_M00_AXI_ARADDR),
        .M00_AXI_arready(axi_ic_gp0_M00_AXI_ARREADY),
        .M00_AXI_arvalid(axi_ic_gp0_M00_AXI_ARVALID),
        .M00_AXI_awaddr(axi_ic_gp0_M00_AXI_AWADDR),
        .M00_AXI_awready(axi_ic_gp0_M00_AXI_AWREADY),
        .M00_AXI_awvalid(axi_ic_gp0_M00_AXI_AWVALID),
        .M00_AXI_bready(axi_ic_gp0_M00_AXI_BREADY),
        .M00_AXI_bresp(axi_ic_gp0_M00_AXI_BRESP),
        .M00_AXI_bvalid(axi_ic_gp0_M00_AXI_BVALID),
        .M00_AXI_rdata(axi_ic_gp0_M00_AXI_RDATA),
        .M00_AXI_rready(axi_ic_gp0_M00_AXI_RREADY),
        .M00_AXI_rresp(axi_ic_gp0_M00_AXI_RRESP),
        .M00_AXI_rvalid(axi_ic_gp0_M00_AXI_RVALID),
        .M00_AXI_wdata(axi_ic_gp0_M00_AXI_WDATA),
        .M00_AXI_wready(axi_ic_gp0_M00_AXI_WREADY),
        .M00_AXI_wstrb(axi_ic_gp0_M00_AXI_WSTRB),
        .M00_AXI_wvalid(axi_ic_gp0_M00_AXI_WVALID),
        .M01_ACLK(clk_wiz_ccsds_clk_out1),
        .M01_ARESETN(rst_clk_sys_100M_peripheral_aresetn),
        .M01_AXI_araddr(axi_ic_gp0_M01_AXI_ARADDR),
        .M01_AXI_arready(axi_ic_gp0_M01_AXI_ARREADY),
        .M01_AXI_arvalid(axi_ic_gp0_M01_AXI_ARVALID),
        .M01_AXI_awaddr(axi_ic_gp0_M01_AXI_AWADDR),
        .M01_AXI_awready(axi_ic_gp0_M01_AXI_AWREADY),
        .M01_AXI_awvalid(axi_ic_gp0_M01_AXI_AWVALID),
        .M01_AXI_bready(axi_ic_gp0_M01_AXI_BREADY),
        .M01_AXI_bresp(axi_ic_gp0_M01_AXI_BRESP),
        .M01_AXI_bvalid(axi_ic_gp0_M01_AXI_BVALID),
        .M01_AXI_rdata(axi_ic_gp0_M01_AXI_RDATA),
        .M01_AXI_rready(axi_ic_gp0_M01_AXI_RREADY),
        .M01_AXI_rresp(axi_ic_gp0_M01_AXI_RRESP),
        .M01_AXI_rvalid(axi_ic_gp0_M01_AXI_RVALID),
        .M01_AXI_wdata(axi_ic_gp0_M01_AXI_WDATA),
        .M01_AXI_wready(axi_ic_gp0_M01_AXI_WREADY),
        .M01_AXI_wstrb(axi_ic_gp0_M01_AXI_WSTRB),
        .M01_AXI_wvalid(axi_ic_gp0_M01_AXI_WVALID),
        .M02_ACLK(clk_wiz_ccsds_clk_out1),
        .M02_ARESETN(rst_clk_sys_100M_peripheral_aresetn),
        .M02_AXI_araddr(axi_ic_gp0_M02_AXI_ARADDR),
        .M02_AXI_arready(axi_ic_gp0_M02_AXI_ARREADY),
        .M02_AXI_arvalid(axi_ic_gp0_M02_AXI_ARVALID),
        .M02_AXI_awaddr(axi_ic_gp0_M02_AXI_AWADDR),
        .M02_AXI_awready(axi_ic_gp0_M02_AXI_AWREADY),
        .M02_AXI_awvalid(axi_ic_gp0_M02_AXI_AWVALID),
        .M02_AXI_bready(axi_ic_gp0_M02_AXI_BREADY),
        .M02_AXI_bresp(axi_ic_gp0_M02_AXI_BRESP),
        .M02_AXI_bvalid(axi_ic_gp0_M02_AXI_BVALID),
        .M02_AXI_rdata(axi_ic_gp0_M02_AXI_RDATA),
        .M02_AXI_rready(axi_ic_gp0_M02_AXI_RREADY),
        .M02_AXI_rresp(axi_ic_gp0_M02_AXI_RRESP),
        .M02_AXI_rvalid(axi_ic_gp0_M02_AXI_RVALID),
        .M02_AXI_wdata(axi_ic_gp0_M02_AXI_WDATA),
        .M02_AXI_wready(axi_ic_gp0_M02_AXI_WREADY),
        .M02_AXI_wstrb(axi_ic_gp0_M02_AXI_WSTRB),
        .M02_AXI_wvalid(axi_ic_gp0_M02_AXI_WVALID),
        .M03_ACLK(clk_wiz_ccsds_clk_out1),
        .M03_ARESETN(rst_clk_sys_100M_peripheral_aresetn),
        .M03_AXI_araddr(axi_ic_gp0_M03_AXI_ARADDR),
        .M03_AXI_arready(axi_ic_gp0_M03_AXI_ARREADY),
        .M03_AXI_arvalid(axi_ic_gp0_M03_AXI_ARVALID),
        .M03_AXI_awaddr(axi_ic_gp0_M03_AXI_AWADDR),
        .M03_AXI_awready(axi_ic_gp0_M03_AXI_AWREADY),
        .M03_AXI_awvalid(axi_ic_gp0_M03_AXI_AWVALID),
        .M03_AXI_bready(axi_ic_gp0_M03_AXI_BREADY),
        .M03_AXI_bresp(axi_ic_gp0_M03_AXI_BRESP),
        .M03_AXI_bvalid(axi_ic_gp0_M03_AXI_BVALID),
        .M03_AXI_rdata(axi_ic_gp0_M03_AXI_RDATA),
        .M03_AXI_rready(axi_ic_gp0_M03_AXI_RREADY),
        .M03_AXI_rresp(axi_ic_gp0_M03_AXI_RRESP),
        .M03_AXI_rvalid(axi_ic_gp0_M03_AXI_RVALID),
        .M03_AXI_wdata(axi_ic_gp0_M03_AXI_WDATA),
        .M03_AXI_wready(axi_ic_gp0_M03_AXI_WREADY),
        .M03_AXI_wstrb(axi_ic_gp0_M03_AXI_WSTRB),
        .M03_AXI_wvalid(axi_ic_gp0_M03_AXI_WVALID),
        .M04_ACLK(clk_wiz_ccsds_clk_out1),
        .M04_ARESETN(rst_clk_sys_100M_peripheral_aresetn),
        .M04_AXI_araddr(axi_ic_gp0_M04_AXI_ARADDR),
        .M04_AXI_arready(axi_ic_gp0_M04_AXI_ARREADY),
        .M04_AXI_arvalid(axi_ic_gp0_M04_AXI_ARVALID),
        .M04_AXI_awaddr(axi_ic_gp0_M04_AXI_AWADDR),
        .M04_AXI_awready(axi_ic_gp0_M04_AXI_AWREADY),
        .M04_AXI_awvalid(axi_ic_gp0_M04_AXI_AWVALID),
        .M04_AXI_bready(axi_ic_gp0_M04_AXI_BREADY),
        .M04_AXI_bresp(axi_ic_gp0_M04_AXI_BRESP),
        .M04_AXI_bvalid(axi_ic_gp0_M04_AXI_BVALID),
        .M04_AXI_rdata(axi_ic_gp0_M04_AXI_RDATA),
        .M04_AXI_rready(axi_ic_gp0_M04_AXI_RREADY),
        .M04_AXI_rresp(axi_ic_gp0_M04_AXI_RRESP),
        .M04_AXI_rvalid(axi_ic_gp0_M04_AXI_RVALID),
        .M04_AXI_wdata(axi_ic_gp0_M04_AXI_WDATA),
        .M04_AXI_wready(axi_ic_gp0_M04_AXI_WREADY),
        .M04_AXI_wstrb(axi_ic_gp0_M04_AXI_WSTRB),
        .M04_AXI_wvalid(axi_ic_gp0_M04_AXI_WVALID),
        .S00_ACLK(clk_wiz_ccsds_clk_out1),
        .S00_ARESETN(rst_clk_sys_100M_peripheral_aresetn),
        .S00_AXI_araddr(processing_system7_0_M_AXI_GP0_ARADDR),
        .S00_AXI_arburst(processing_system7_0_M_AXI_GP0_ARBURST),
        .S00_AXI_arcache(processing_system7_0_M_AXI_GP0_ARCACHE),
        .S00_AXI_arid(processing_system7_0_M_AXI_GP0_ARID),
        .S00_AXI_arlen(processing_system7_0_M_AXI_GP0_ARLEN),
        .S00_AXI_arlock(processing_system7_0_M_AXI_GP0_ARLOCK),
        .S00_AXI_arprot(processing_system7_0_M_AXI_GP0_ARPROT),
        .S00_AXI_arqos(processing_system7_0_M_AXI_GP0_ARQOS),
        .S00_AXI_arready(processing_system7_0_M_AXI_GP0_ARREADY),
        .S00_AXI_arsize(processing_system7_0_M_AXI_GP0_ARSIZE),
        .S00_AXI_arvalid(processing_system7_0_M_AXI_GP0_ARVALID),
        .S00_AXI_awaddr(processing_system7_0_M_AXI_GP0_AWADDR),
        .S00_AXI_awburst(processing_system7_0_M_AXI_GP0_AWBURST),
        .S00_AXI_awcache(processing_system7_0_M_AXI_GP0_AWCACHE),
        .S00_AXI_awid(processing_system7_0_M_AXI_GP0_AWID),
        .S00_AXI_awlen(processing_system7_0_M_AXI_GP0_AWLEN),
        .S00_AXI_awlock(processing_system7_0_M_AXI_GP0_AWLOCK),
        .S00_AXI_awprot(processing_system7_0_M_AXI_GP0_AWPROT),
        .S00_AXI_awqos(processing_system7_0_M_AXI_GP0_AWQOS),
        .S00_AXI_awready(processing_system7_0_M_AXI_GP0_AWREADY),
        .S00_AXI_awsize(processing_system7_0_M_AXI_GP0_AWSIZE),
        .S00_AXI_awvalid(processing_system7_0_M_AXI_GP0_AWVALID),
        .S00_AXI_bid(processing_system7_0_M_AXI_GP0_BID),
        .S00_AXI_bready(processing_system7_0_M_AXI_GP0_BREADY),
        .S00_AXI_bresp(processing_system7_0_M_AXI_GP0_BRESP),
        .S00_AXI_bvalid(processing_system7_0_M_AXI_GP0_BVALID),
        .S00_AXI_rdata(processing_system7_0_M_AXI_GP0_RDATA),
        .S00_AXI_rid(processing_system7_0_M_AXI_GP0_RID),
        .S00_AXI_rlast(processing_system7_0_M_AXI_GP0_RLAST),
        .S00_AXI_rready(processing_system7_0_M_AXI_GP0_RREADY),
        .S00_AXI_rresp(processing_system7_0_M_AXI_GP0_RRESP),
        .S00_AXI_rvalid(processing_system7_0_M_AXI_GP0_RVALID),
        .S00_AXI_wdata(processing_system7_0_M_AXI_GP0_WDATA),
        .S00_AXI_wid(processing_system7_0_M_AXI_GP0_WID),
        .S00_AXI_wlast(processing_system7_0_M_AXI_GP0_WLAST),
        .S00_AXI_wready(processing_system7_0_M_AXI_GP0_WREADY),
        .S00_AXI_wstrb(processing_system7_0_M_AXI_GP0_WSTRB),
        .S00_AXI_wvalid(processing_system7_0_M_AXI_GP0_WVALID));
  system_stage1_loopback_ccsds_gnd_egse_0 ccsds_gnd_egse
       (.bc_require_sdls_cfg(sl_bc_sdls_Dout),
        .clk_adc_iq(clk_wiz_ccsds_clk_out4),
        .clk_sys(clk_wiz_ccsds_clk_out1),
        .clk_tc_safe(clk_wiz_ccsds_clk_out2),
        .clk_tx_sym(clk_wiz_ccsds_clk_out3),
        .default_tx_vcid_cfg(sl_tx_vcid_Dout),
        .line_code_cfg(sl_line_code_Dout),
        .link_proto_override_en(sl_proto_ovr_Dout),
        .m_axis_rx_pkt_tdata(ccsds_gnd_egse_m_axis_rx_pkt_TDATA),
        .m_axis_rx_pkt_tlast(ccsds_gnd_egse_m_axis_rx_pkt_TLAST),
        .m_axis_rx_pkt_tready(ccsds_gnd_egse_m_axis_rx_pkt_TREADY),
        .m_axis_rx_pkt_tuser(ccsds_gnd_egse_m_axis_rx_pkt_TUSER),
        .m_axis_rx_pkt_tvalid(ccsds_gnd_egse_m_axis_rx_pkt_TVALID),
        .mod_mode_cfg(sl_mod_mode_Dout),
        .pn_ranging_en_cfg(sl_pn_en_Dout),
        .pn_t4b_mode_cfg(sl_pn_t4b_Dout),
        .pps_1hz_in(sl_pps_pulse_Dout),
        .rst_n(rst_clk_sys_100M_peripheral_aresetn),
        .rx_i_adc_in(ccsds_sc_flight_tx_i_dac_out),
        .rx_iq_valid_in(ccsds_sc_flight_tx_iq_valid_out),
        .rx_q_adc_in(ccsds_sc_flight_tx_q_dac_out),
        .s_axi_araddr(axi_ic_gp0_M01_AXI_ARADDR[7:0]),
        .s_axi_arready(axi_ic_gp0_M01_AXI_ARREADY),
        .s_axi_arvalid(axi_ic_gp0_M01_AXI_ARVALID),
        .s_axi_awaddr(axi_ic_gp0_M01_AXI_AWADDR[7:0]),
        .s_axi_awready(axi_ic_gp0_M01_AXI_AWREADY),
        .s_axi_awvalid(axi_ic_gp0_M01_AXI_AWVALID),
        .s_axi_bready(axi_ic_gp0_M01_AXI_BREADY),
        .s_axi_bresp(axi_ic_gp0_M01_AXI_BRESP),
        .s_axi_bvalid(axi_ic_gp0_M01_AXI_BVALID),
        .s_axi_rdata(axi_ic_gp0_M01_AXI_RDATA),
        .s_axi_rready(axi_ic_gp0_M01_AXI_RREADY),
        .s_axi_rresp(axi_ic_gp0_M01_AXI_RRESP),
        .s_axi_rvalid(axi_ic_gp0_M01_AXI_RVALID),
        .s_axi_wdata(axi_ic_gp0_M01_AXI_WDATA),
        .s_axi_wready(axi_ic_gp0_M01_AXI_WREADY),
        .s_axi_wstrb(axi_ic_gp0_M01_AXI_WSTRB),
        .s_axi_wvalid(axi_ic_gp0_M01_AXI_WVALID),
        .s_axis_tx_pkt_tdata(ccsds_gnd_egse_dw_32to8_M_AXIS_TDATA),
        .s_axis_tx_pkt_tlast(ccsds_gnd_egse_dw_32to8_M_AXIS_TLAST),
        .s_axis_tx_pkt_tready(ccsds_gnd_egse_dw_32to8_M_AXIS_TREADY),
        .s_axis_tx_pkt_tuser({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axis_tx_pkt_tvalid(ccsds_gnd_egse_dw_32to8_M_AXIS_TVALID),
        .sdls_en_cfg(sl_sdls_en_Dout),
        .turnaround_xband_cfg(sl_turn_xb_Dout),
        .tx_i_dac_out(ccsds_gnd_egse_tx_i_dac_out),
        .tx_iq_valid_out(ccsds_gnd_egse_tx_iq_valid_out),
        .tx_q_dac_out(ccsds_gnd_egse_tx_q_dac_out),
        .ul_fec_override_en(sl_ul_fec_Dout));
  system_stage1_loopback_ccsds_gnd_egse_dw_32to8_0 ccsds_gnd_egse_dw_32to8
       (.aclk(clk_wiz_ccsds_clk_out1),
        .aresetn(rst_clk_sys_100M_peripheral_aresetn),
        .m_axis_tdata(ccsds_gnd_egse_dw_32to8_M_AXIS_TDATA),
        .m_axis_tlast(ccsds_gnd_egse_dw_32to8_M_AXIS_TLAST),
        .m_axis_tready(ccsds_gnd_egse_dw_32to8_M_AXIS_TREADY),
        .m_axis_tvalid(ccsds_gnd_egse_dw_32to8_M_AXIS_TVALID),
        .s_axis_tdata(ccsds_gnd_egse_pkt_fifo_AXI_STR_TXD_TDATA),
        .s_axis_tkeep(ccsds_gnd_egse_pkt_fifo_AXI_STR_TXD_TKEEP),
        .s_axis_tlast(ccsds_gnd_egse_pkt_fifo_AXI_STR_TXD_TLAST),
        .s_axis_tready(ccsds_gnd_egse_pkt_fifo_AXI_STR_TXD_TREADY),
        .s_axis_tvalid(ccsds_gnd_egse_pkt_fifo_AXI_STR_TXD_TVALID));
  system_stage1_loopback_ccsds_gnd_egse_dw_8to32_0 ccsds_gnd_egse_dw_8to32
       (.aclk(clk_wiz_ccsds_clk_out1),
        .aresetn(rst_clk_sys_100M_peripheral_aresetn),
        .m_axis_tdata(ccsds_gnd_egse_dw_8to32_M_AXIS_TDATA),
        .m_axis_tkeep(ccsds_gnd_egse_dw_8to32_M_AXIS_TKEEP),
        .m_axis_tlast(ccsds_gnd_egse_dw_8to32_M_AXIS_TLAST),
        .m_axis_tready(ccsds_gnd_egse_dw_8to32_M_AXIS_TREADY),
        .m_axis_tvalid(ccsds_gnd_egse_dw_8to32_M_AXIS_TVALID),
        .s_axis_tdata(ccsds_gnd_egse_m_axis_rx_pkt_TDATA),
        .s_axis_tlast(ccsds_gnd_egse_m_axis_rx_pkt_TLAST),
        .s_axis_tready(ccsds_gnd_egse_m_axis_rx_pkt_TREADY),
        .s_axis_tuser(ccsds_gnd_egse_m_axis_rx_pkt_TUSER),
        .s_axis_tvalid(ccsds_gnd_egse_m_axis_rx_pkt_TVALID));
  system_stage1_loopback_ccsds_gnd_egse_pkt_fifo_0 ccsds_gnd_egse_pkt_fifo
       (.axi_str_rxd_tdata(ccsds_gnd_egse_dw_8to32_M_AXIS_TDATA),
        .axi_str_rxd_tkeep(ccsds_gnd_egse_dw_8to32_M_AXIS_TKEEP),
        .axi_str_rxd_tlast(ccsds_gnd_egse_dw_8to32_M_AXIS_TLAST),
        .axi_str_rxd_tready(ccsds_gnd_egse_dw_8to32_M_AXIS_TREADY),
        .axi_str_rxd_tvalid(ccsds_gnd_egse_dw_8to32_M_AXIS_TVALID),
        .axi_str_txd_tdata(ccsds_gnd_egse_pkt_fifo_AXI_STR_TXD_TDATA),
        .axi_str_txd_tkeep(ccsds_gnd_egse_pkt_fifo_AXI_STR_TXD_TKEEP),
        .axi_str_txd_tlast(ccsds_gnd_egse_pkt_fifo_AXI_STR_TXD_TLAST),
        .axi_str_txd_tready(ccsds_gnd_egse_pkt_fifo_AXI_STR_TXD_TREADY),
        .axi_str_txd_tvalid(ccsds_gnd_egse_pkt_fifo_AXI_STR_TXD_TVALID),
        .s_axi_aclk(clk_wiz_ccsds_clk_out1),
        .s_axi_araddr(axi_ic_gp0_M02_AXI_ARADDR),
        .s_axi_aresetn(rst_clk_sys_100M_peripheral_aresetn),
        .s_axi_arready(axi_ic_gp0_M02_AXI_ARREADY),
        .s_axi_arvalid(axi_ic_gp0_M02_AXI_ARVALID),
        .s_axi_awaddr(axi_ic_gp0_M02_AXI_AWADDR),
        .s_axi_awready(axi_ic_gp0_M02_AXI_AWREADY),
        .s_axi_awvalid(axi_ic_gp0_M02_AXI_AWVALID),
        .s_axi_bready(axi_ic_gp0_M02_AXI_BREADY),
        .s_axi_bresp(axi_ic_gp0_M02_AXI_BRESP),
        .s_axi_bvalid(axi_ic_gp0_M02_AXI_BVALID),
        .s_axi_rdata(axi_ic_gp0_M02_AXI_RDATA),
        .s_axi_rready(axi_ic_gp0_M02_AXI_RREADY),
        .s_axi_rresp(axi_ic_gp0_M02_AXI_RRESP),
        .s_axi_rvalid(axi_ic_gp0_M02_AXI_RVALID),
        .s_axi_wdata(axi_ic_gp0_M02_AXI_WDATA),
        .s_axi_wready(axi_ic_gp0_M02_AXI_WREADY),
        .s_axi_wstrb(axi_ic_gp0_M02_AXI_WSTRB),
        .s_axi_wvalid(axi_ic_gp0_M02_AXI_WVALID));
  system_stage1_loopback_ccsds_sc_flight_0 ccsds_sc_flight
       (.bc_require_sdls_cfg(sl_bc_sdls_Dout),
        .clk_adc_iq(clk_wiz_ccsds_clk_out4),
        .clk_sys(clk_wiz_ccsds_clk_out1),
        .clk_tc_safe(clk_wiz_ccsds_clk_out2),
        .clk_tx_sym(clk_wiz_ccsds_clk_out3),
        .default_tx_vcid_cfg(sl_tx_vcid_Dout),
        .edac_scrub_req_out(ccsds_sc_flight_edac_scrub_req_out),
        .fault_irq_out(ccsds_sc_flight_fault_irq_out),
        .hcpd_obc_reset_pulse(ccsds_sc_flight_hcpd_obc_reset_pulse),
        .hcpd_rf_chain_select(ccsds_sc_flight_hcpd_rf_chain_select),
        .hcpd_safe_mode_force(ccsds_sc_flight_hcpd_safe_mode_force),
        .line_code_cfg(sl_line_code_Dout),
        .link_proto_override_en(sl_proto_ovr_Dout),
        .m_axis_rx_pkt_tdata(ccsds_sc_flight_m_axis_rx_pkt_TDATA),
        .m_axis_rx_pkt_tlast(ccsds_sc_flight_m_axis_rx_pkt_TLAST),
        .m_axis_rx_pkt_tready(ccsds_sc_flight_m_axis_rx_pkt_TREADY),
        .m_axis_rx_pkt_tuser(ccsds_sc_flight_m_axis_rx_pkt_TUSER),
        .m_axis_rx_pkt_tvalid(ccsds_sc_flight_m_axis_rx_pkt_TVALID),
        .mod_mode_cfg(sl_mod_mode_Dout),
        .pn_ranging_en_cfg(sl_pn_en_Dout),
        .pn_ranging_locked_out(ccsds_sc_flight_pn_ranging_locked_out),
        .pn_t4b_mode_cfg(sl_pn_t4b_Dout),
        .pps_1hz_in(sl_pps_pulse_Dout),
        .rst_n(rst_clk_sys_100M_peripheral_aresetn),
        .rx_i_adc_in(ccsds_gnd_egse_tx_i_dac_out),
        .rx_iq_valid_in(ccsds_gnd_egse_tx_iq_valid_out),
        .rx_q_adc_in(ccsds_gnd_egse_tx_q_dac_out),
        .s_axi_araddr(axi_ic_gp0_M03_AXI_ARADDR[7:0]),
        .s_axi_arready(axi_ic_gp0_M03_AXI_ARREADY),
        .s_axi_arvalid(axi_ic_gp0_M03_AXI_ARVALID),
        .s_axi_awaddr(axi_ic_gp0_M03_AXI_AWADDR[7:0]),
        .s_axi_awready(axi_ic_gp0_M03_AXI_AWREADY),
        .s_axi_awvalid(axi_ic_gp0_M03_AXI_AWVALID),
        .s_axi_bready(axi_ic_gp0_M03_AXI_BREADY),
        .s_axi_bresp(axi_ic_gp0_M03_AXI_BRESP),
        .s_axi_bvalid(axi_ic_gp0_M03_AXI_BVALID),
        .s_axi_rdata(axi_ic_gp0_M03_AXI_RDATA),
        .s_axi_rready(axi_ic_gp0_M03_AXI_RREADY),
        .s_axi_rresp(axi_ic_gp0_M03_AXI_RRESP),
        .s_axi_rvalid(axi_ic_gp0_M03_AXI_RVALID),
        .s_axi_wdata(axi_ic_gp0_M03_AXI_WDATA),
        .s_axi_wready(axi_ic_gp0_M03_AXI_WREADY),
        .s_axi_wstrb(axi_ic_gp0_M03_AXI_WSTRB),
        .s_axi_wvalid(axi_ic_gp0_M03_AXI_WVALID),
        .s_axis_tx_pkt_tdata(ccsds_sc_flight_dw_32to8_M_AXIS_TDATA),
        .s_axis_tx_pkt_tlast(ccsds_sc_flight_dw_32to8_M_AXIS_TLAST),
        .s_axis_tx_pkt_tready(ccsds_sc_flight_dw_32to8_M_AXIS_TREADY),
        .s_axis_tx_pkt_tuser({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axis_tx_pkt_tvalid(ccsds_sc_flight_dw_32to8_M_AXIS_TVALID),
        .sdls_en_cfg(sl_sdls_en_Dout),
        .turnaround_xband_cfg(sl_turn_xb_Dout),
        .tx_i_dac_out(ccsds_sc_flight_tx_i_dac_out),
        .tx_iq_valid_out(ccsds_sc_flight_tx_iq_valid_out),
        .tx_q_dac_out(ccsds_sc_flight_tx_q_dac_out),
        .ul_fec_override_en(sl_ul_fec_Dout));
  system_stage1_loopback_ccsds_sc_flight_dw_32to8_0 ccsds_sc_flight_dw_32to8
       (.aclk(clk_wiz_ccsds_clk_out1),
        .aresetn(rst_clk_sys_100M_peripheral_aresetn),
        .m_axis_tdata(ccsds_sc_flight_dw_32to8_M_AXIS_TDATA),
        .m_axis_tlast(ccsds_sc_flight_dw_32to8_M_AXIS_TLAST),
        .m_axis_tready(ccsds_sc_flight_dw_32to8_M_AXIS_TREADY),
        .m_axis_tvalid(ccsds_sc_flight_dw_32to8_M_AXIS_TVALID),
        .s_axis_tdata(ccsds_sc_flight_pkt_fifo_AXI_STR_TXD_TDATA),
        .s_axis_tkeep(ccsds_sc_flight_pkt_fifo_AXI_STR_TXD_TKEEP),
        .s_axis_tlast(ccsds_sc_flight_pkt_fifo_AXI_STR_TXD_TLAST),
        .s_axis_tready(ccsds_sc_flight_pkt_fifo_AXI_STR_TXD_TREADY),
        .s_axis_tvalid(ccsds_sc_flight_pkt_fifo_AXI_STR_TXD_TVALID));
  system_stage1_loopback_ccsds_sc_flight_dw_8to32_0 ccsds_sc_flight_dw_8to32
       (.aclk(clk_wiz_ccsds_clk_out1),
        .aresetn(rst_clk_sys_100M_peripheral_aresetn),
        .m_axis_tdata(ccsds_sc_flight_dw_8to32_M_AXIS_TDATA),
        .m_axis_tkeep(ccsds_sc_flight_dw_8to32_M_AXIS_TKEEP),
        .m_axis_tlast(ccsds_sc_flight_dw_8to32_M_AXIS_TLAST),
        .m_axis_tready(ccsds_sc_flight_dw_8to32_M_AXIS_TREADY),
        .m_axis_tvalid(ccsds_sc_flight_dw_8to32_M_AXIS_TVALID),
        .s_axis_tdata(ccsds_sc_flight_m_axis_rx_pkt_TDATA),
        .s_axis_tlast(ccsds_sc_flight_m_axis_rx_pkt_TLAST),
        .s_axis_tready(ccsds_sc_flight_m_axis_rx_pkt_TREADY),
        .s_axis_tuser(ccsds_sc_flight_m_axis_rx_pkt_TUSER),
        .s_axis_tvalid(ccsds_sc_flight_m_axis_rx_pkt_TVALID));
  system_stage1_loopback_ccsds_sc_flight_pkt_fifo_0 ccsds_sc_flight_pkt_fifo
       (.axi_str_rxd_tdata(ccsds_sc_flight_dw_8to32_M_AXIS_TDATA),
        .axi_str_rxd_tkeep(ccsds_sc_flight_dw_8to32_M_AXIS_TKEEP),
        .axi_str_rxd_tlast(ccsds_sc_flight_dw_8to32_M_AXIS_TLAST),
        .axi_str_rxd_tready(ccsds_sc_flight_dw_8to32_M_AXIS_TREADY),
        .axi_str_rxd_tvalid(ccsds_sc_flight_dw_8to32_M_AXIS_TVALID),
        .axi_str_txd_tdata(ccsds_sc_flight_pkt_fifo_AXI_STR_TXD_TDATA),
        .axi_str_txd_tkeep(ccsds_sc_flight_pkt_fifo_AXI_STR_TXD_TKEEP),
        .axi_str_txd_tlast(ccsds_sc_flight_pkt_fifo_AXI_STR_TXD_TLAST),
        .axi_str_txd_tready(ccsds_sc_flight_pkt_fifo_AXI_STR_TXD_TREADY),
        .axi_str_txd_tvalid(ccsds_sc_flight_pkt_fifo_AXI_STR_TXD_TVALID),
        .s_axi_aclk(clk_wiz_ccsds_clk_out1),
        .s_axi_araddr(axi_ic_gp0_M04_AXI_ARADDR),
        .s_axi_aresetn(rst_clk_sys_100M_peripheral_aresetn),
        .s_axi_arready(axi_ic_gp0_M04_AXI_ARREADY),
        .s_axi_arvalid(axi_ic_gp0_M04_AXI_ARVALID),
        .s_axi_awaddr(axi_ic_gp0_M04_AXI_AWADDR),
        .s_axi_awready(axi_ic_gp0_M04_AXI_AWREADY),
        .s_axi_awvalid(axi_ic_gp0_M04_AXI_AWVALID),
        .s_axi_bready(axi_ic_gp0_M04_AXI_BREADY),
        .s_axi_bresp(axi_ic_gp0_M04_AXI_BRESP),
        .s_axi_bvalid(axi_ic_gp0_M04_AXI_BVALID),
        .s_axi_rdata(axi_ic_gp0_M04_AXI_RDATA),
        .s_axi_rready(axi_ic_gp0_M04_AXI_RREADY),
        .s_axi_rresp(axi_ic_gp0_M04_AXI_RRESP),
        .s_axi_rvalid(axi_ic_gp0_M04_AXI_RVALID),
        .s_axi_wdata(axi_ic_gp0_M04_AXI_WDATA),
        .s_axi_wready(axi_ic_gp0_M04_AXI_WREADY),
        .s_axi_wstrb(axi_ic_gp0_M04_AXI_WSTRB),
        .s_axi_wvalid(axi_ic_gp0_M04_AXI_WVALID));
  system_stage1_loopback_clk_wiz_ccsds_0 clk_wiz_ccsds
       (.clk_in1(processing_system7_0_FCLK_CLK0),
        .clk_out1(clk_wiz_ccsds_clk_out1),
        .clk_out2(clk_wiz_ccsds_clk_out2),
        .clk_out3(clk_wiz_ccsds_clk_out3),
        .clk_out4(clk_wiz_ccsds_clk_out4),
        .locked(clk_wiz_ccsds_locked),
        .resetn(processing_system7_0_FCLK_RESET0_N));
  assign concat_status_7b_dout = {ccsds_sc_flight_edac_scrub_req_out, ccsds_sc_flight_fault_irq_out, ccsds_sc_flight_pn_ranging_locked_out, ccsds_sc_flight_hcpd_rf_chain_select, ccsds_sc_flight_hcpd_safe_mode_force, ccsds_sc_flight_hcpd_obc_reset_pulse};
  system_stage1_loopback_processing_system7_0_0 processing_system7_0
       (.DDR_Addr(DDR_addr),
        .DDR_BankAddr(DDR_ba),
        .DDR_CAS_n(DDR_cas_n),
        .DDR_CKE(DDR_cke),
        .DDR_CS_n(DDR_cs_n),
        .DDR_Clk(DDR_ck_p),
        .DDR_Clk_n(DDR_ck_n),
        .DDR_DM(DDR_dm),
        .DDR_DQ(DDR_dq),
        .DDR_DQS(DDR_dqs_p),
        .DDR_DQS_n(DDR_dqs_n),
        .DDR_DRSTB(DDR_reset_n),
        .DDR_ODT(DDR_odt),
        .DDR_RAS_n(DDR_ras_n),
        .DDR_VRN(FIXED_IO_ddr_vrn),
        .DDR_VRP(FIXED_IO_ddr_vrp),
        .DDR_WEB(DDR_we_n),
        .FCLK_CLK0(processing_system7_0_FCLK_CLK0),
        .FCLK_RESET0_N(processing_system7_0_FCLK_RESET0_N),
        .IRQ_F2P(ccsds_sc_flight_fault_irq_out),
        .MIO(FIXED_IO_mio),
        .M_AXI_GP0_ACLK(clk_wiz_ccsds_clk_out1),
        .M_AXI_GP0_ARADDR(processing_system7_0_M_AXI_GP0_ARADDR),
        .M_AXI_GP0_ARBURST(processing_system7_0_M_AXI_GP0_ARBURST),
        .M_AXI_GP0_ARCACHE(processing_system7_0_M_AXI_GP0_ARCACHE),
        .M_AXI_GP0_ARID(processing_system7_0_M_AXI_GP0_ARID),
        .M_AXI_GP0_ARLEN(processing_system7_0_M_AXI_GP0_ARLEN),
        .M_AXI_GP0_ARLOCK(processing_system7_0_M_AXI_GP0_ARLOCK),
        .M_AXI_GP0_ARPROT(processing_system7_0_M_AXI_GP0_ARPROT),
        .M_AXI_GP0_ARQOS(processing_system7_0_M_AXI_GP0_ARQOS),
        .M_AXI_GP0_ARREADY(processing_system7_0_M_AXI_GP0_ARREADY),
        .M_AXI_GP0_ARSIZE(processing_system7_0_M_AXI_GP0_ARSIZE),
        .M_AXI_GP0_ARVALID(processing_system7_0_M_AXI_GP0_ARVALID),
        .M_AXI_GP0_AWADDR(processing_system7_0_M_AXI_GP0_AWADDR),
        .M_AXI_GP0_AWBURST(processing_system7_0_M_AXI_GP0_AWBURST),
        .M_AXI_GP0_AWCACHE(processing_system7_0_M_AXI_GP0_AWCACHE),
        .M_AXI_GP0_AWID(processing_system7_0_M_AXI_GP0_AWID),
        .M_AXI_GP0_AWLEN(processing_system7_0_M_AXI_GP0_AWLEN),
        .M_AXI_GP0_AWLOCK(processing_system7_0_M_AXI_GP0_AWLOCK),
        .M_AXI_GP0_AWPROT(processing_system7_0_M_AXI_GP0_AWPROT),
        .M_AXI_GP0_AWQOS(processing_system7_0_M_AXI_GP0_AWQOS),
        .M_AXI_GP0_AWREADY(processing_system7_0_M_AXI_GP0_AWREADY),
        .M_AXI_GP0_AWSIZE(processing_system7_0_M_AXI_GP0_AWSIZE),
        .M_AXI_GP0_AWVALID(processing_system7_0_M_AXI_GP0_AWVALID),
        .M_AXI_GP0_BID(processing_system7_0_M_AXI_GP0_BID),
        .M_AXI_GP0_BREADY(processing_system7_0_M_AXI_GP0_BREADY),
        .M_AXI_GP0_BRESP(processing_system7_0_M_AXI_GP0_BRESP),
        .M_AXI_GP0_BVALID(processing_system7_0_M_AXI_GP0_BVALID),
        .M_AXI_GP0_RDATA(processing_system7_0_M_AXI_GP0_RDATA),
        .M_AXI_GP0_RID(processing_system7_0_M_AXI_GP0_RID),
        .M_AXI_GP0_RLAST(processing_system7_0_M_AXI_GP0_RLAST),
        .M_AXI_GP0_RREADY(processing_system7_0_M_AXI_GP0_RREADY),
        .M_AXI_GP0_RRESP(processing_system7_0_M_AXI_GP0_RRESP),
        .M_AXI_GP0_RVALID(processing_system7_0_M_AXI_GP0_RVALID),
        .M_AXI_GP0_WDATA(processing_system7_0_M_AXI_GP0_WDATA),
        .M_AXI_GP0_WID(processing_system7_0_M_AXI_GP0_WID),
        .M_AXI_GP0_WLAST(processing_system7_0_M_AXI_GP0_WLAST),
        .M_AXI_GP0_WREADY(processing_system7_0_M_AXI_GP0_WREADY),
        .M_AXI_GP0_WSTRB(processing_system7_0_M_AXI_GP0_WSTRB),
        .M_AXI_GP0_WVALID(processing_system7_0_M_AXI_GP0_WVALID),
        .PS_CLK(FIXED_IO_ps_clk),
        .PS_PORB(FIXED_IO_ps_porb),
        .PS_SRSTB(FIXED_IO_ps_srstb));
  system_stage1_loopback_rst_clk_sys_100M_0 rst_clk_sys_100M
       (.aux_reset_in(1'b1),
        .dcm_locked(clk_wiz_ccsds_locked),
        .ext_reset_in(processing_system7_0_FCLK_RESET0_N),
        .interconnect_aresetn(rst_clk_sys_100M_interconnect_aresetn),
        .mb_debug_sys_rst(1'b0),
        .peripheral_aresetn(rst_clk_sys_100M_peripheral_aresetn),
        .slowest_sync_clk(clk_wiz_ccsds_clk_out1));
  assign sl_bc_sdls_Dout = axi_gpio_straps_gpio_io_o[5:5];
  assign sl_line_code_Dout = axi_gpio_straps_gpio_io_o[12:11];
  assign sl_mod_mode_Dout = axi_gpio_straps_gpio_io_o[10:9];
  assign sl_pn_en_Dout = axi_gpio_straps_gpio_io_o[6:6];
  assign sl_pn_t4b_Dout = axi_gpio_straps_gpio_io_o[7:7];
  assign sl_pps_pulse_Dout = axi_gpio_straps_gpio_io_o[19:19];
  assign sl_proto_ovr_Dout = axi_gpio_straps_gpio_io_o[1:0];
  assign sl_sdls_en_Dout = axi_gpio_straps_gpio_io_o[4:4];
  assign sl_turn_xb_Dout = axi_gpio_straps_gpio_io_o[8:8];
  assign sl_tx_vcid_Dout = axi_gpio_straps_gpio_io_o[18:13];
  assign sl_ul_fec_Dout = axi_gpio_straps_gpio_io_o[3:2];
endmodule

module system_stage1_loopback_axi_ic_gp0_0
   (ACLK,
    ARESETN,
    M00_ACLK,
    M00_ARESETN,
    M00_AXI_araddr,
    M00_AXI_arready,
    M00_AXI_arvalid,
    M00_AXI_awaddr,
    M00_AXI_awready,
    M00_AXI_awvalid,
    M00_AXI_bready,
    M00_AXI_bresp,
    M00_AXI_bvalid,
    M00_AXI_rdata,
    M00_AXI_rready,
    M00_AXI_rresp,
    M00_AXI_rvalid,
    M00_AXI_wdata,
    M00_AXI_wready,
    M00_AXI_wstrb,
    M00_AXI_wvalid,
    M01_ACLK,
    M01_ARESETN,
    M01_AXI_araddr,
    M01_AXI_arready,
    M01_AXI_arvalid,
    M01_AXI_awaddr,
    M01_AXI_awready,
    M01_AXI_awvalid,
    M01_AXI_bready,
    M01_AXI_bresp,
    M01_AXI_bvalid,
    M01_AXI_rdata,
    M01_AXI_rready,
    M01_AXI_rresp,
    M01_AXI_rvalid,
    M01_AXI_wdata,
    M01_AXI_wready,
    M01_AXI_wstrb,
    M01_AXI_wvalid,
    M02_ACLK,
    M02_ARESETN,
    M02_AXI_araddr,
    M02_AXI_arready,
    M02_AXI_arvalid,
    M02_AXI_awaddr,
    M02_AXI_awready,
    M02_AXI_awvalid,
    M02_AXI_bready,
    M02_AXI_bresp,
    M02_AXI_bvalid,
    M02_AXI_rdata,
    M02_AXI_rready,
    M02_AXI_rresp,
    M02_AXI_rvalid,
    M02_AXI_wdata,
    M02_AXI_wready,
    M02_AXI_wstrb,
    M02_AXI_wvalid,
    M03_ACLK,
    M03_ARESETN,
    M03_AXI_araddr,
    M03_AXI_arready,
    M03_AXI_arvalid,
    M03_AXI_awaddr,
    M03_AXI_awready,
    M03_AXI_awvalid,
    M03_AXI_bready,
    M03_AXI_bresp,
    M03_AXI_bvalid,
    M03_AXI_rdata,
    M03_AXI_rready,
    M03_AXI_rresp,
    M03_AXI_rvalid,
    M03_AXI_wdata,
    M03_AXI_wready,
    M03_AXI_wstrb,
    M03_AXI_wvalid,
    M04_ACLK,
    M04_ARESETN,
    M04_AXI_araddr,
    M04_AXI_arready,
    M04_AXI_arvalid,
    M04_AXI_awaddr,
    M04_AXI_awready,
    M04_AXI_awvalid,
    M04_AXI_bready,
    M04_AXI_bresp,
    M04_AXI_bvalid,
    M04_AXI_rdata,
    M04_AXI_rready,
    M04_AXI_rresp,
    M04_AXI_rvalid,
    M04_AXI_wdata,
    M04_AXI_wready,
    M04_AXI_wstrb,
    M04_AXI_wvalid,
    S00_ACLK,
    S00_ARESETN,
    S00_AXI_araddr,
    S00_AXI_arburst,
    S00_AXI_arcache,
    S00_AXI_arid,
    S00_AXI_arlen,
    S00_AXI_arlock,
    S00_AXI_arprot,
    S00_AXI_arqos,
    S00_AXI_arready,
    S00_AXI_arsize,
    S00_AXI_arvalid,
    S00_AXI_awaddr,
    S00_AXI_awburst,
    S00_AXI_awcache,
    S00_AXI_awid,
    S00_AXI_awlen,
    S00_AXI_awlock,
    S00_AXI_awprot,
    S00_AXI_awqos,
    S00_AXI_awready,
    S00_AXI_awsize,
    S00_AXI_awvalid,
    S00_AXI_bid,
    S00_AXI_bready,
    S00_AXI_bresp,
    S00_AXI_bvalid,
    S00_AXI_rdata,
    S00_AXI_rid,
    S00_AXI_rlast,
    S00_AXI_rready,
    S00_AXI_rresp,
    S00_AXI_rvalid,
    S00_AXI_wdata,
    S00_AXI_wid,
    S00_AXI_wlast,
    S00_AXI_wready,
    S00_AXI_wstrb,
    S00_AXI_wvalid);
  input ACLK;
  input ARESETN;
  input M00_ACLK;
  input M00_ARESETN;
  output [31:0]M00_AXI_araddr;
  input M00_AXI_arready;
  output M00_AXI_arvalid;
  output [31:0]M00_AXI_awaddr;
  input M00_AXI_awready;
  output M00_AXI_awvalid;
  output M00_AXI_bready;
  input [1:0]M00_AXI_bresp;
  input M00_AXI_bvalid;
  input [31:0]M00_AXI_rdata;
  output M00_AXI_rready;
  input [1:0]M00_AXI_rresp;
  input M00_AXI_rvalid;
  output [31:0]M00_AXI_wdata;
  input M00_AXI_wready;
  output [3:0]M00_AXI_wstrb;
  output M00_AXI_wvalid;
  input M01_ACLK;
  input M01_ARESETN;
  output [31:0]M01_AXI_araddr;
  input M01_AXI_arready;
  output M01_AXI_arvalid;
  output [31:0]M01_AXI_awaddr;
  input M01_AXI_awready;
  output M01_AXI_awvalid;
  output M01_AXI_bready;
  input [1:0]M01_AXI_bresp;
  input M01_AXI_bvalid;
  input [31:0]M01_AXI_rdata;
  output M01_AXI_rready;
  input [1:0]M01_AXI_rresp;
  input M01_AXI_rvalid;
  output [31:0]M01_AXI_wdata;
  input M01_AXI_wready;
  output [3:0]M01_AXI_wstrb;
  output M01_AXI_wvalid;
  input M02_ACLK;
  input M02_ARESETN;
  output [31:0]M02_AXI_araddr;
  input M02_AXI_arready;
  output M02_AXI_arvalid;
  output [31:0]M02_AXI_awaddr;
  input M02_AXI_awready;
  output M02_AXI_awvalid;
  output M02_AXI_bready;
  input [1:0]M02_AXI_bresp;
  input M02_AXI_bvalid;
  input [31:0]M02_AXI_rdata;
  output M02_AXI_rready;
  input [1:0]M02_AXI_rresp;
  input M02_AXI_rvalid;
  output [31:0]M02_AXI_wdata;
  input M02_AXI_wready;
  output [3:0]M02_AXI_wstrb;
  output M02_AXI_wvalid;
  input M03_ACLK;
  input M03_ARESETN;
  output [31:0]M03_AXI_araddr;
  input M03_AXI_arready;
  output M03_AXI_arvalid;
  output [31:0]M03_AXI_awaddr;
  input M03_AXI_awready;
  output M03_AXI_awvalid;
  output M03_AXI_bready;
  input [1:0]M03_AXI_bresp;
  input M03_AXI_bvalid;
  input [31:0]M03_AXI_rdata;
  output M03_AXI_rready;
  input [1:0]M03_AXI_rresp;
  input M03_AXI_rvalid;
  output [31:0]M03_AXI_wdata;
  input M03_AXI_wready;
  output [3:0]M03_AXI_wstrb;
  output M03_AXI_wvalid;
  input M04_ACLK;
  input M04_ARESETN;
  output [31:0]M04_AXI_araddr;
  input M04_AXI_arready;
  output M04_AXI_arvalid;
  output [31:0]M04_AXI_awaddr;
  input M04_AXI_awready;
  output M04_AXI_awvalid;
  output M04_AXI_bready;
  input [1:0]M04_AXI_bresp;
  input M04_AXI_bvalid;
  input [31:0]M04_AXI_rdata;
  output M04_AXI_rready;
  input [1:0]M04_AXI_rresp;
  input M04_AXI_rvalid;
  output [31:0]M04_AXI_wdata;
  input M04_AXI_wready;
  output [3:0]M04_AXI_wstrb;
  output M04_AXI_wvalid;
  input S00_ACLK;
  input S00_ARESETN;
  input [31:0]S00_AXI_araddr;
  input [1:0]S00_AXI_arburst;
  input [3:0]S00_AXI_arcache;
  input [11:0]S00_AXI_arid;
  input [3:0]S00_AXI_arlen;
  input [1:0]S00_AXI_arlock;
  input [2:0]S00_AXI_arprot;
  input [3:0]S00_AXI_arqos;
  output S00_AXI_arready;
  input [2:0]S00_AXI_arsize;
  input S00_AXI_arvalid;
  input [31:0]S00_AXI_awaddr;
  input [1:0]S00_AXI_awburst;
  input [3:0]S00_AXI_awcache;
  input [11:0]S00_AXI_awid;
  input [3:0]S00_AXI_awlen;
  input [1:0]S00_AXI_awlock;
  input [2:0]S00_AXI_awprot;
  input [3:0]S00_AXI_awqos;
  output S00_AXI_awready;
  input [2:0]S00_AXI_awsize;
  input S00_AXI_awvalid;
  output [11:0]S00_AXI_bid;
  input S00_AXI_bready;
  output [1:0]S00_AXI_bresp;
  output S00_AXI_bvalid;
  output [31:0]S00_AXI_rdata;
  output [11:0]S00_AXI_rid;
  output S00_AXI_rlast;
  input S00_AXI_rready;
  output [1:0]S00_AXI_rresp;
  output S00_AXI_rvalid;
  input [31:0]S00_AXI_wdata;
  input [11:0]S00_AXI_wid;
  input S00_AXI_wlast;
  output S00_AXI_wready;
  input [3:0]S00_AXI_wstrb;
  input S00_AXI_wvalid;

  wire ACLK;
  wire ARESETN;
  wire M00_ACLK;
  wire M00_ARESETN;
  wire [31:0]M00_AXI_araddr;
  wire M00_AXI_arready;
  wire M00_AXI_arvalid;
  wire [31:0]M00_AXI_awaddr;
  wire M00_AXI_awready;
  wire M00_AXI_awvalid;
  wire M00_AXI_bready;
  wire [1:0]M00_AXI_bresp;
  wire M00_AXI_bvalid;
  wire [31:0]M00_AXI_rdata;
  wire M00_AXI_rready;
  wire [1:0]M00_AXI_rresp;
  wire M00_AXI_rvalid;
  wire [31:0]M00_AXI_wdata;
  wire M00_AXI_wready;
  wire [3:0]M00_AXI_wstrb;
  wire M00_AXI_wvalid;
  wire M01_ACLK;
  wire M01_ARESETN;
  wire [31:0]M01_AXI_araddr;
  wire M01_AXI_arready;
  wire M01_AXI_arvalid;
  wire [31:0]M01_AXI_awaddr;
  wire M01_AXI_awready;
  wire M01_AXI_awvalid;
  wire M01_AXI_bready;
  wire [1:0]M01_AXI_bresp;
  wire M01_AXI_bvalid;
  wire [31:0]M01_AXI_rdata;
  wire M01_AXI_rready;
  wire [1:0]M01_AXI_rresp;
  wire M01_AXI_rvalid;
  wire [31:0]M01_AXI_wdata;
  wire M01_AXI_wready;
  wire [3:0]M01_AXI_wstrb;
  wire M01_AXI_wvalid;
  wire M02_ACLK;
  wire M02_ARESETN;
  wire [31:0]M02_AXI_araddr;
  wire M02_AXI_arready;
  wire M02_AXI_arvalid;
  wire [31:0]M02_AXI_awaddr;
  wire M02_AXI_awready;
  wire M02_AXI_awvalid;
  wire M02_AXI_bready;
  wire [1:0]M02_AXI_bresp;
  wire M02_AXI_bvalid;
  wire [31:0]M02_AXI_rdata;
  wire M02_AXI_rready;
  wire [1:0]M02_AXI_rresp;
  wire M02_AXI_rvalid;
  wire [31:0]M02_AXI_wdata;
  wire M02_AXI_wready;
  wire [3:0]M02_AXI_wstrb;
  wire M02_AXI_wvalid;
  wire M03_ACLK;
  wire M03_ARESETN;
  wire [31:0]M03_AXI_araddr;
  wire M03_AXI_arready;
  wire M03_AXI_arvalid;
  wire [31:0]M03_AXI_awaddr;
  wire M03_AXI_awready;
  wire M03_AXI_awvalid;
  wire M03_AXI_bready;
  wire [1:0]M03_AXI_bresp;
  wire M03_AXI_bvalid;
  wire [31:0]M03_AXI_rdata;
  wire M03_AXI_rready;
  wire [1:0]M03_AXI_rresp;
  wire M03_AXI_rvalid;
  wire [31:0]M03_AXI_wdata;
  wire M03_AXI_wready;
  wire [3:0]M03_AXI_wstrb;
  wire M03_AXI_wvalid;
  wire M04_ACLK;
  wire M04_ARESETN;
  wire [31:0]M04_AXI_araddr;
  wire M04_AXI_arready;
  wire M04_AXI_arvalid;
  wire [31:0]M04_AXI_awaddr;
  wire M04_AXI_awready;
  wire M04_AXI_awvalid;
  wire M04_AXI_bready;
  wire [1:0]M04_AXI_bresp;
  wire M04_AXI_bvalid;
  wire [31:0]M04_AXI_rdata;
  wire M04_AXI_rready;
  wire [1:0]M04_AXI_rresp;
  wire M04_AXI_rvalid;
  wire [31:0]M04_AXI_wdata;
  wire M04_AXI_wready;
  wire [3:0]M04_AXI_wstrb;
  wire M04_AXI_wvalid;
  wire S00_ACLK;
  wire S00_ARESETN;
  wire [31:0]S00_AXI_araddr;
  wire [1:0]S00_AXI_arburst;
  wire [3:0]S00_AXI_arcache;
  wire [11:0]S00_AXI_arid;
  wire [3:0]S00_AXI_arlen;
  wire [1:0]S00_AXI_arlock;
  wire [2:0]S00_AXI_arprot;
  wire [3:0]S00_AXI_arqos;
  wire S00_AXI_arready;
  wire [2:0]S00_AXI_arsize;
  wire S00_AXI_arvalid;
  wire [31:0]S00_AXI_awaddr;
  wire [1:0]S00_AXI_awburst;
  wire [3:0]S00_AXI_awcache;
  wire [11:0]S00_AXI_awid;
  wire [3:0]S00_AXI_awlen;
  wire [1:0]S00_AXI_awlock;
  wire [2:0]S00_AXI_awprot;
  wire [3:0]S00_AXI_awqos;
  wire S00_AXI_awready;
  wire [2:0]S00_AXI_awsize;
  wire S00_AXI_awvalid;
  wire [11:0]S00_AXI_bid;
  wire S00_AXI_bready;
  wire [1:0]S00_AXI_bresp;
  wire S00_AXI_bvalid;
  wire [31:0]S00_AXI_rdata;
  wire [11:0]S00_AXI_rid;
  wire S00_AXI_rlast;
  wire S00_AXI_rready;
  wire [1:0]S00_AXI_rresp;
  wire S00_AXI_rvalid;
  wire [31:0]S00_AXI_wdata;
  wire [11:0]S00_AXI_wid;
  wire S00_AXI_wlast;
  wire S00_AXI_wready;
  wire [3:0]S00_AXI_wstrb;
  wire S00_AXI_wvalid;
  wire [31:0]s00_couplers_to_xbar_ARADDR;
  wire [2:0]s00_couplers_to_xbar_ARPROT;
  wire [0:0]s00_couplers_to_xbar_ARREADY;
  wire s00_couplers_to_xbar_ARVALID;
  wire [31:0]s00_couplers_to_xbar_AWADDR;
  wire [2:0]s00_couplers_to_xbar_AWPROT;
  wire [0:0]s00_couplers_to_xbar_AWREADY;
  wire s00_couplers_to_xbar_AWVALID;
  wire s00_couplers_to_xbar_BREADY;
  wire [1:0]s00_couplers_to_xbar_BRESP;
  wire [0:0]s00_couplers_to_xbar_BVALID;
  wire [31:0]s00_couplers_to_xbar_RDATA;
  wire s00_couplers_to_xbar_RREADY;
  wire [1:0]s00_couplers_to_xbar_RRESP;
  wire [0:0]s00_couplers_to_xbar_RVALID;
  wire [31:0]s00_couplers_to_xbar_WDATA;
  wire [0:0]s00_couplers_to_xbar_WREADY;
  wire [3:0]s00_couplers_to_xbar_WSTRB;
  wire s00_couplers_to_xbar_WVALID;
  wire [31:0]xbar_to_m00_couplers_ARADDR;
  wire xbar_to_m00_couplers_ARREADY;
  wire [0:0]xbar_to_m00_couplers_ARVALID;
  wire [31:0]xbar_to_m00_couplers_AWADDR;
  wire xbar_to_m00_couplers_AWREADY;
  wire [0:0]xbar_to_m00_couplers_AWVALID;
  wire [0:0]xbar_to_m00_couplers_BREADY;
  wire [1:0]xbar_to_m00_couplers_BRESP;
  wire xbar_to_m00_couplers_BVALID;
  wire [31:0]xbar_to_m00_couplers_RDATA;
  wire [0:0]xbar_to_m00_couplers_RREADY;
  wire [1:0]xbar_to_m00_couplers_RRESP;
  wire xbar_to_m00_couplers_RVALID;
  wire [31:0]xbar_to_m00_couplers_WDATA;
  wire xbar_to_m00_couplers_WREADY;
  wire [3:0]xbar_to_m00_couplers_WSTRB;
  wire [0:0]xbar_to_m00_couplers_WVALID;
  wire [63:32]xbar_to_m01_couplers_ARADDR;
  wire xbar_to_m01_couplers_ARREADY;
  wire [1:1]xbar_to_m01_couplers_ARVALID;
  wire [63:32]xbar_to_m01_couplers_AWADDR;
  wire xbar_to_m01_couplers_AWREADY;
  wire [1:1]xbar_to_m01_couplers_AWVALID;
  wire [1:1]xbar_to_m01_couplers_BREADY;
  wire [1:0]xbar_to_m01_couplers_BRESP;
  wire xbar_to_m01_couplers_BVALID;
  wire [31:0]xbar_to_m01_couplers_RDATA;
  wire [1:1]xbar_to_m01_couplers_RREADY;
  wire [1:0]xbar_to_m01_couplers_RRESP;
  wire xbar_to_m01_couplers_RVALID;
  wire [63:32]xbar_to_m01_couplers_WDATA;
  wire xbar_to_m01_couplers_WREADY;
  wire [7:4]xbar_to_m01_couplers_WSTRB;
  wire [1:1]xbar_to_m01_couplers_WVALID;
  wire [95:64]xbar_to_m02_couplers_ARADDR;
  wire xbar_to_m02_couplers_ARREADY;
  wire [2:2]xbar_to_m02_couplers_ARVALID;
  wire [95:64]xbar_to_m02_couplers_AWADDR;
  wire xbar_to_m02_couplers_AWREADY;
  wire [2:2]xbar_to_m02_couplers_AWVALID;
  wire [2:2]xbar_to_m02_couplers_BREADY;
  wire [1:0]xbar_to_m02_couplers_BRESP;
  wire xbar_to_m02_couplers_BVALID;
  wire [31:0]xbar_to_m02_couplers_RDATA;
  wire [2:2]xbar_to_m02_couplers_RREADY;
  wire [1:0]xbar_to_m02_couplers_RRESP;
  wire xbar_to_m02_couplers_RVALID;
  wire [95:64]xbar_to_m02_couplers_WDATA;
  wire xbar_to_m02_couplers_WREADY;
  wire [11:8]xbar_to_m02_couplers_WSTRB;
  wire [2:2]xbar_to_m02_couplers_WVALID;
  wire [127:96]xbar_to_m03_couplers_ARADDR;
  wire xbar_to_m03_couplers_ARREADY;
  wire [3:3]xbar_to_m03_couplers_ARVALID;
  wire [127:96]xbar_to_m03_couplers_AWADDR;
  wire xbar_to_m03_couplers_AWREADY;
  wire [3:3]xbar_to_m03_couplers_AWVALID;
  wire [3:3]xbar_to_m03_couplers_BREADY;
  wire [1:0]xbar_to_m03_couplers_BRESP;
  wire xbar_to_m03_couplers_BVALID;
  wire [31:0]xbar_to_m03_couplers_RDATA;
  wire [3:3]xbar_to_m03_couplers_RREADY;
  wire [1:0]xbar_to_m03_couplers_RRESP;
  wire xbar_to_m03_couplers_RVALID;
  wire [127:96]xbar_to_m03_couplers_WDATA;
  wire xbar_to_m03_couplers_WREADY;
  wire [15:12]xbar_to_m03_couplers_WSTRB;
  wire [3:3]xbar_to_m03_couplers_WVALID;
  wire [159:128]xbar_to_m04_couplers_ARADDR;
  wire xbar_to_m04_couplers_ARREADY;
  wire [4:4]xbar_to_m04_couplers_ARVALID;
  wire [159:128]xbar_to_m04_couplers_AWADDR;
  wire xbar_to_m04_couplers_AWREADY;
  wire [4:4]xbar_to_m04_couplers_AWVALID;
  wire [4:4]xbar_to_m04_couplers_BREADY;
  wire [1:0]xbar_to_m04_couplers_BRESP;
  wire xbar_to_m04_couplers_BVALID;
  wire [31:0]xbar_to_m04_couplers_RDATA;
  wire [4:4]xbar_to_m04_couplers_RREADY;
  wire [1:0]xbar_to_m04_couplers_RRESP;
  wire xbar_to_m04_couplers_RVALID;
  wire [159:128]xbar_to_m04_couplers_WDATA;
  wire xbar_to_m04_couplers_WREADY;
  wire [19:16]xbar_to_m04_couplers_WSTRB;
  wire [4:4]xbar_to_m04_couplers_WVALID;

  m00_couplers_imp_13VHS0A m00_couplers
       (.M_ACLK(M00_ACLK),
        .M_ARESETN(M00_ARESETN),
        .M_AXI_araddr(M00_AXI_araddr),
        .M_AXI_arready(M00_AXI_arready),
        .M_AXI_arvalid(M00_AXI_arvalid),
        .M_AXI_awaddr(M00_AXI_awaddr),
        .M_AXI_awready(M00_AXI_awready),
        .M_AXI_awvalid(M00_AXI_awvalid),
        .M_AXI_bready(M00_AXI_bready),
        .M_AXI_bresp(M00_AXI_bresp),
        .M_AXI_bvalid(M00_AXI_bvalid),
        .M_AXI_rdata(M00_AXI_rdata),
        .M_AXI_rready(M00_AXI_rready),
        .M_AXI_rresp(M00_AXI_rresp),
        .M_AXI_rvalid(M00_AXI_rvalid),
        .M_AXI_wdata(M00_AXI_wdata),
        .M_AXI_wready(M00_AXI_wready),
        .M_AXI_wstrb(M00_AXI_wstrb),
        .M_AXI_wvalid(M00_AXI_wvalid),
        .S_ACLK(ACLK),
        .S_ARESETN(ARESETN),
        .S_AXI_araddr(xbar_to_m00_couplers_ARADDR),
        .S_AXI_arready(xbar_to_m00_couplers_ARREADY),
        .S_AXI_arvalid(xbar_to_m00_couplers_ARVALID),
        .S_AXI_awaddr(xbar_to_m00_couplers_AWADDR),
        .S_AXI_awready(xbar_to_m00_couplers_AWREADY),
        .S_AXI_awvalid(xbar_to_m00_couplers_AWVALID),
        .S_AXI_bready(xbar_to_m00_couplers_BREADY),
        .S_AXI_bresp(xbar_to_m00_couplers_BRESP),
        .S_AXI_bvalid(xbar_to_m00_couplers_BVALID),
        .S_AXI_rdata(xbar_to_m00_couplers_RDATA),
        .S_AXI_rready(xbar_to_m00_couplers_RREADY),
        .S_AXI_rresp(xbar_to_m00_couplers_RRESP),
        .S_AXI_rvalid(xbar_to_m00_couplers_RVALID),
        .S_AXI_wdata(xbar_to_m00_couplers_WDATA),
        .S_AXI_wready(xbar_to_m00_couplers_WREADY),
        .S_AXI_wstrb(xbar_to_m00_couplers_WSTRB),
        .S_AXI_wvalid(xbar_to_m00_couplers_WVALID));
  m01_couplers_imp_Z2SR6O m01_couplers
       (.M_ACLK(M01_ACLK),
        .M_ARESETN(M01_ARESETN),
        .M_AXI_araddr(M01_AXI_araddr),
        .M_AXI_arready(M01_AXI_arready),
        .M_AXI_arvalid(M01_AXI_arvalid),
        .M_AXI_awaddr(M01_AXI_awaddr),
        .M_AXI_awready(M01_AXI_awready),
        .M_AXI_awvalid(M01_AXI_awvalid),
        .M_AXI_bready(M01_AXI_bready),
        .M_AXI_bresp(M01_AXI_bresp),
        .M_AXI_bvalid(M01_AXI_bvalid),
        .M_AXI_rdata(M01_AXI_rdata),
        .M_AXI_rready(M01_AXI_rready),
        .M_AXI_rresp(M01_AXI_rresp),
        .M_AXI_rvalid(M01_AXI_rvalid),
        .M_AXI_wdata(M01_AXI_wdata),
        .M_AXI_wready(M01_AXI_wready),
        .M_AXI_wstrb(M01_AXI_wstrb),
        .M_AXI_wvalid(M01_AXI_wvalid),
        .S_ACLK(ACLK),
        .S_ARESETN(ARESETN),
        .S_AXI_araddr(xbar_to_m01_couplers_ARADDR),
        .S_AXI_arready(xbar_to_m01_couplers_ARREADY),
        .S_AXI_arvalid(xbar_to_m01_couplers_ARVALID),
        .S_AXI_awaddr(xbar_to_m01_couplers_AWADDR),
        .S_AXI_awready(xbar_to_m01_couplers_AWREADY),
        .S_AXI_awvalid(xbar_to_m01_couplers_AWVALID),
        .S_AXI_bready(xbar_to_m01_couplers_BREADY),
        .S_AXI_bresp(xbar_to_m01_couplers_BRESP),
        .S_AXI_bvalid(xbar_to_m01_couplers_BVALID),
        .S_AXI_rdata(xbar_to_m01_couplers_RDATA),
        .S_AXI_rready(xbar_to_m01_couplers_RREADY),
        .S_AXI_rresp(xbar_to_m01_couplers_RRESP),
        .S_AXI_rvalid(xbar_to_m01_couplers_RVALID),
        .S_AXI_wdata(xbar_to_m01_couplers_WDATA),
        .S_AXI_wready(xbar_to_m01_couplers_WREADY),
        .S_AXI_wstrb(xbar_to_m01_couplers_WSTRB),
        .S_AXI_wvalid(xbar_to_m01_couplers_WVALID));
  m02_couplers_imp_1EWFHGF m02_couplers
       (.M_ACLK(M02_ACLK),
        .M_ARESETN(M02_ARESETN),
        .M_AXI_araddr(M02_AXI_araddr),
        .M_AXI_arready(M02_AXI_arready),
        .M_AXI_arvalid(M02_AXI_arvalid),
        .M_AXI_awaddr(M02_AXI_awaddr),
        .M_AXI_awready(M02_AXI_awready),
        .M_AXI_awvalid(M02_AXI_awvalid),
        .M_AXI_bready(M02_AXI_bready),
        .M_AXI_bresp(M02_AXI_bresp),
        .M_AXI_bvalid(M02_AXI_bvalid),
        .M_AXI_rdata(M02_AXI_rdata),
        .M_AXI_rready(M02_AXI_rready),
        .M_AXI_rresp(M02_AXI_rresp),
        .M_AXI_rvalid(M02_AXI_rvalid),
        .M_AXI_wdata(M02_AXI_wdata),
        .M_AXI_wready(M02_AXI_wready),
        .M_AXI_wstrb(M02_AXI_wstrb),
        .M_AXI_wvalid(M02_AXI_wvalid),
        .S_ACLK(ACLK),
        .S_ARESETN(ARESETN),
        .S_AXI_araddr(xbar_to_m02_couplers_ARADDR),
        .S_AXI_arready(xbar_to_m02_couplers_ARREADY),
        .S_AXI_arvalid(xbar_to_m02_couplers_ARVALID),
        .S_AXI_awaddr(xbar_to_m02_couplers_AWADDR),
        .S_AXI_awready(xbar_to_m02_couplers_AWREADY),
        .S_AXI_awvalid(xbar_to_m02_couplers_AWVALID),
        .S_AXI_bready(xbar_to_m02_couplers_BREADY),
        .S_AXI_bresp(xbar_to_m02_couplers_BRESP),
        .S_AXI_bvalid(xbar_to_m02_couplers_BVALID),
        .S_AXI_rdata(xbar_to_m02_couplers_RDATA),
        .S_AXI_rready(xbar_to_m02_couplers_RREADY),
        .S_AXI_rresp(xbar_to_m02_couplers_RRESP),
        .S_AXI_rvalid(xbar_to_m02_couplers_RVALID),
        .S_AXI_wdata(xbar_to_m02_couplers_WDATA),
        .S_AXI_wready(xbar_to_m02_couplers_WREADY),
        .S_AXI_wstrb(xbar_to_m02_couplers_WSTRB),
        .S_AXI_wvalid(xbar_to_m02_couplers_WVALID));
  m03_couplers_imp_JLT7ED m03_couplers
       (.M_ACLK(M03_ACLK),
        .M_ARESETN(M03_ARESETN),
        .M_AXI_araddr(M03_AXI_araddr),
        .M_AXI_arready(M03_AXI_arready),
        .M_AXI_arvalid(M03_AXI_arvalid),
        .M_AXI_awaddr(M03_AXI_awaddr),
        .M_AXI_awready(M03_AXI_awready),
        .M_AXI_awvalid(M03_AXI_awvalid),
        .M_AXI_bready(M03_AXI_bready),
        .M_AXI_bresp(M03_AXI_bresp),
        .M_AXI_bvalid(M03_AXI_bvalid),
        .M_AXI_rdata(M03_AXI_rdata),
        .M_AXI_rready(M03_AXI_rready),
        .M_AXI_rresp(M03_AXI_rresp),
        .M_AXI_rvalid(M03_AXI_rvalid),
        .M_AXI_wdata(M03_AXI_wdata),
        .M_AXI_wready(M03_AXI_wready),
        .M_AXI_wstrb(M03_AXI_wstrb),
        .M_AXI_wvalid(M03_AXI_wvalid),
        .S_ACLK(ACLK),
        .S_ARESETN(ARESETN),
        .S_AXI_araddr(xbar_to_m03_couplers_ARADDR),
        .S_AXI_arready(xbar_to_m03_couplers_ARREADY),
        .S_AXI_arvalid(xbar_to_m03_couplers_ARVALID),
        .S_AXI_awaddr(xbar_to_m03_couplers_AWADDR),
        .S_AXI_awready(xbar_to_m03_couplers_AWREADY),
        .S_AXI_awvalid(xbar_to_m03_couplers_AWVALID),
        .S_AXI_bready(xbar_to_m03_couplers_BREADY),
        .S_AXI_bresp(xbar_to_m03_couplers_BRESP),
        .S_AXI_bvalid(xbar_to_m03_couplers_BVALID),
        .S_AXI_rdata(xbar_to_m03_couplers_RDATA),
        .S_AXI_rready(xbar_to_m03_couplers_RREADY),
        .S_AXI_rresp(xbar_to_m03_couplers_RRESP),
        .S_AXI_rvalid(xbar_to_m03_couplers_RVALID),
        .S_AXI_wdata(xbar_to_m03_couplers_WDATA),
        .S_AXI_wready(xbar_to_m03_couplers_WREADY),
        .S_AXI_wstrb(xbar_to_m03_couplers_WSTRB),
        .S_AXI_wvalid(xbar_to_m03_couplers_WVALID));
  m04_couplers_imp_1YJHGKG m04_couplers
       (.M_ACLK(M04_ACLK),
        .M_ARESETN(M04_ARESETN),
        .M_AXI_araddr(M04_AXI_araddr),
        .M_AXI_arready(M04_AXI_arready),
        .M_AXI_arvalid(M04_AXI_arvalid),
        .M_AXI_awaddr(M04_AXI_awaddr),
        .M_AXI_awready(M04_AXI_awready),
        .M_AXI_awvalid(M04_AXI_awvalid),
        .M_AXI_bready(M04_AXI_bready),
        .M_AXI_bresp(M04_AXI_bresp),
        .M_AXI_bvalid(M04_AXI_bvalid),
        .M_AXI_rdata(M04_AXI_rdata),
        .M_AXI_rready(M04_AXI_rready),
        .M_AXI_rresp(M04_AXI_rresp),
        .M_AXI_rvalid(M04_AXI_rvalid),
        .M_AXI_wdata(M04_AXI_wdata),
        .M_AXI_wready(M04_AXI_wready),
        .M_AXI_wstrb(M04_AXI_wstrb),
        .M_AXI_wvalid(M04_AXI_wvalid),
        .S_ACLK(ACLK),
        .S_ARESETN(ARESETN),
        .S_AXI_araddr(xbar_to_m04_couplers_ARADDR),
        .S_AXI_arready(xbar_to_m04_couplers_ARREADY),
        .S_AXI_arvalid(xbar_to_m04_couplers_ARVALID),
        .S_AXI_awaddr(xbar_to_m04_couplers_AWADDR),
        .S_AXI_awready(xbar_to_m04_couplers_AWREADY),
        .S_AXI_awvalid(xbar_to_m04_couplers_AWVALID),
        .S_AXI_bready(xbar_to_m04_couplers_BREADY),
        .S_AXI_bresp(xbar_to_m04_couplers_BRESP),
        .S_AXI_bvalid(xbar_to_m04_couplers_BVALID),
        .S_AXI_rdata(xbar_to_m04_couplers_RDATA),
        .S_AXI_rready(xbar_to_m04_couplers_RREADY),
        .S_AXI_rresp(xbar_to_m04_couplers_RRESP),
        .S_AXI_rvalid(xbar_to_m04_couplers_RVALID),
        .S_AXI_wdata(xbar_to_m04_couplers_WDATA),
        .S_AXI_wready(xbar_to_m04_couplers_WREADY),
        .S_AXI_wstrb(xbar_to_m04_couplers_WSTRB),
        .S_AXI_wvalid(xbar_to_m04_couplers_WVALID));
  s00_couplers_imp_13IPBE4 s00_couplers
       (.M_ACLK(ACLK),
        .M_ARESETN(ARESETN),
        .M_AXI_araddr(s00_couplers_to_xbar_ARADDR),
        .M_AXI_arprot(s00_couplers_to_xbar_ARPROT),
        .M_AXI_arready(s00_couplers_to_xbar_ARREADY),
        .M_AXI_arvalid(s00_couplers_to_xbar_ARVALID),
        .M_AXI_awaddr(s00_couplers_to_xbar_AWADDR),
        .M_AXI_awprot(s00_couplers_to_xbar_AWPROT),
        .M_AXI_awready(s00_couplers_to_xbar_AWREADY),
        .M_AXI_awvalid(s00_couplers_to_xbar_AWVALID),
        .M_AXI_bready(s00_couplers_to_xbar_BREADY),
        .M_AXI_bresp(s00_couplers_to_xbar_BRESP),
        .M_AXI_bvalid(s00_couplers_to_xbar_BVALID),
        .M_AXI_rdata(s00_couplers_to_xbar_RDATA),
        .M_AXI_rready(s00_couplers_to_xbar_RREADY),
        .M_AXI_rresp(s00_couplers_to_xbar_RRESP),
        .M_AXI_rvalid(s00_couplers_to_xbar_RVALID),
        .M_AXI_wdata(s00_couplers_to_xbar_WDATA),
        .M_AXI_wready(s00_couplers_to_xbar_WREADY),
        .M_AXI_wstrb(s00_couplers_to_xbar_WSTRB),
        .M_AXI_wvalid(s00_couplers_to_xbar_WVALID),
        .S_ACLK(S00_ACLK),
        .S_ARESETN(S00_ARESETN),
        .S_AXI_araddr(S00_AXI_araddr),
        .S_AXI_arburst(S00_AXI_arburst),
        .S_AXI_arcache(S00_AXI_arcache),
        .S_AXI_arid(S00_AXI_arid),
        .S_AXI_arlen(S00_AXI_arlen),
        .S_AXI_arlock(S00_AXI_arlock),
        .S_AXI_arprot(S00_AXI_arprot),
        .S_AXI_arqos(S00_AXI_arqos),
        .S_AXI_arready(S00_AXI_arready),
        .S_AXI_arsize(S00_AXI_arsize),
        .S_AXI_arvalid(S00_AXI_arvalid),
        .S_AXI_awaddr(S00_AXI_awaddr),
        .S_AXI_awburst(S00_AXI_awburst),
        .S_AXI_awcache(S00_AXI_awcache),
        .S_AXI_awid(S00_AXI_awid),
        .S_AXI_awlen(S00_AXI_awlen),
        .S_AXI_awlock(S00_AXI_awlock),
        .S_AXI_awprot(S00_AXI_awprot),
        .S_AXI_awqos(S00_AXI_awqos),
        .S_AXI_awready(S00_AXI_awready),
        .S_AXI_awsize(S00_AXI_awsize),
        .S_AXI_awvalid(S00_AXI_awvalid),
        .S_AXI_bid(S00_AXI_bid),
        .S_AXI_bready(S00_AXI_bready),
        .S_AXI_bresp(S00_AXI_bresp),
        .S_AXI_bvalid(S00_AXI_bvalid),
        .S_AXI_rdata(S00_AXI_rdata),
        .S_AXI_rid(S00_AXI_rid),
        .S_AXI_rlast(S00_AXI_rlast),
        .S_AXI_rready(S00_AXI_rready),
        .S_AXI_rresp(S00_AXI_rresp),
        .S_AXI_rvalid(S00_AXI_rvalid),
        .S_AXI_wdata(S00_AXI_wdata),
        .S_AXI_wid(S00_AXI_wid),
        .S_AXI_wlast(S00_AXI_wlast),
        .S_AXI_wready(S00_AXI_wready),
        .S_AXI_wstrb(S00_AXI_wstrb),
        .S_AXI_wvalid(S00_AXI_wvalid));
  system_stage1_loopback_axi_ic_gp0_imp_xbar_0 xbar
       (.aclk(ACLK),
        .aresetn(ARESETN),
        .m_axi_araddr({xbar_to_m04_couplers_ARADDR,xbar_to_m03_couplers_ARADDR,xbar_to_m02_couplers_ARADDR,xbar_to_m01_couplers_ARADDR,xbar_to_m00_couplers_ARADDR}),
        .m_axi_arready({xbar_to_m04_couplers_ARREADY,xbar_to_m03_couplers_ARREADY,xbar_to_m02_couplers_ARREADY,xbar_to_m01_couplers_ARREADY,xbar_to_m00_couplers_ARREADY}),
        .m_axi_arvalid({xbar_to_m04_couplers_ARVALID,xbar_to_m03_couplers_ARVALID,xbar_to_m02_couplers_ARVALID,xbar_to_m01_couplers_ARVALID,xbar_to_m00_couplers_ARVALID}),
        .m_axi_awaddr({xbar_to_m04_couplers_AWADDR,xbar_to_m03_couplers_AWADDR,xbar_to_m02_couplers_AWADDR,xbar_to_m01_couplers_AWADDR,xbar_to_m00_couplers_AWADDR}),
        .m_axi_awready({xbar_to_m04_couplers_AWREADY,xbar_to_m03_couplers_AWREADY,xbar_to_m02_couplers_AWREADY,xbar_to_m01_couplers_AWREADY,xbar_to_m00_couplers_AWREADY}),
        .m_axi_awvalid({xbar_to_m04_couplers_AWVALID,xbar_to_m03_couplers_AWVALID,xbar_to_m02_couplers_AWVALID,xbar_to_m01_couplers_AWVALID,xbar_to_m00_couplers_AWVALID}),
        .m_axi_bready({xbar_to_m04_couplers_BREADY,xbar_to_m03_couplers_BREADY,xbar_to_m02_couplers_BREADY,xbar_to_m01_couplers_BREADY,xbar_to_m00_couplers_BREADY}),
        .m_axi_bresp({xbar_to_m04_couplers_BRESP,xbar_to_m03_couplers_BRESP,xbar_to_m02_couplers_BRESP,xbar_to_m01_couplers_BRESP,xbar_to_m00_couplers_BRESP}),
        .m_axi_bvalid({xbar_to_m04_couplers_BVALID,xbar_to_m03_couplers_BVALID,xbar_to_m02_couplers_BVALID,xbar_to_m01_couplers_BVALID,xbar_to_m00_couplers_BVALID}),
        .m_axi_rdata({xbar_to_m04_couplers_RDATA,xbar_to_m03_couplers_RDATA,xbar_to_m02_couplers_RDATA,xbar_to_m01_couplers_RDATA,xbar_to_m00_couplers_RDATA}),
        .m_axi_rready({xbar_to_m04_couplers_RREADY,xbar_to_m03_couplers_RREADY,xbar_to_m02_couplers_RREADY,xbar_to_m01_couplers_RREADY,xbar_to_m00_couplers_RREADY}),
        .m_axi_rresp({xbar_to_m04_couplers_RRESP,xbar_to_m03_couplers_RRESP,xbar_to_m02_couplers_RRESP,xbar_to_m01_couplers_RRESP,xbar_to_m00_couplers_RRESP}),
        .m_axi_rvalid({xbar_to_m04_couplers_RVALID,xbar_to_m03_couplers_RVALID,xbar_to_m02_couplers_RVALID,xbar_to_m01_couplers_RVALID,xbar_to_m00_couplers_RVALID}),
        .m_axi_wdata({xbar_to_m04_couplers_WDATA,xbar_to_m03_couplers_WDATA,xbar_to_m02_couplers_WDATA,xbar_to_m01_couplers_WDATA,xbar_to_m00_couplers_WDATA}),
        .m_axi_wready({xbar_to_m04_couplers_WREADY,xbar_to_m03_couplers_WREADY,xbar_to_m02_couplers_WREADY,xbar_to_m01_couplers_WREADY,xbar_to_m00_couplers_WREADY}),
        .m_axi_wstrb({xbar_to_m04_couplers_WSTRB,xbar_to_m03_couplers_WSTRB,xbar_to_m02_couplers_WSTRB,xbar_to_m01_couplers_WSTRB,xbar_to_m00_couplers_WSTRB}),
        .m_axi_wvalid({xbar_to_m04_couplers_WVALID,xbar_to_m03_couplers_WVALID,xbar_to_m02_couplers_WVALID,xbar_to_m01_couplers_WVALID,xbar_to_m00_couplers_WVALID}),
        .s_axi_araddr(s00_couplers_to_xbar_ARADDR),
        .s_axi_arprot(s00_couplers_to_xbar_ARPROT),
        .s_axi_arready(s00_couplers_to_xbar_ARREADY),
        .s_axi_arvalid(s00_couplers_to_xbar_ARVALID),
        .s_axi_awaddr(s00_couplers_to_xbar_AWADDR),
        .s_axi_awprot(s00_couplers_to_xbar_AWPROT),
        .s_axi_awready(s00_couplers_to_xbar_AWREADY),
        .s_axi_awvalid(s00_couplers_to_xbar_AWVALID),
        .s_axi_bready(s00_couplers_to_xbar_BREADY),
        .s_axi_bresp(s00_couplers_to_xbar_BRESP),
        .s_axi_bvalid(s00_couplers_to_xbar_BVALID),
        .s_axi_rdata(s00_couplers_to_xbar_RDATA),
        .s_axi_rready(s00_couplers_to_xbar_RREADY),
        .s_axi_rresp(s00_couplers_to_xbar_RRESP),
        .s_axi_rvalid(s00_couplers_to_xbar_RVALID),
        .s_axi_wdata(s00_couplers_to_xbar_WDATA),
        .s_axi_wready(s00_couplers_to_xbar_WREADY),
        .s_axi_wstrb(s00_couplers_to_xbar_WSTRB),
        .s_axi_wvalid(s00_couplers_to_xbar_WVALID));
endmodule
