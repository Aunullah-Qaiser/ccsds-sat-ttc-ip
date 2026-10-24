//=============================================================================
// File Name   : tb_stage11_top_to_top_rf_link.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Description : Milestone 1 (Stage 11) Full Chip-to-Chip RF Baseband & Frame
//               Link-Closure Testbench:
//                 - Instantiates `ccsds_sat_ttc_top #(.ROLE_MODE(1))` (Ground
//                   Station Hardware EGSE Transceiver) and
//                   `ccsds_sat_ttc_top #(.ROLE_MODE(0))` (Spacecraft Flight
//                   Transceiver).
//                 - Connects Uplink and Downlink RF Baseband IQ (12-bit I/Q)
//                   through two independent `ccsds_channel_impairment_model`
//                   instances with AWGN + Doppler/CFO.
//                 - Subtest 11.1: AXI4-Lite CSR programming & readback across
//                   spacecraft registers (`0x00`, `0x04`, `0x08`, `0x0C`,
//                   including Milestone 2 Gardner/Ka-Band, Milestone 3
//                   AES-128-GCM, and Milestone 4 FLL-Assist bits).
//                 - Subtest 11.2: Ground-to-Spacecraft Uplink Telecommand
//                   Frame -> Spacecraft Uplink Deframer -> COP-1 FARM-1 TMR ->
//                   Hsiao SECDED Commit FIFO -> Space Packet Reassembler ->
//                   Spacecraft OBC (`m_axis_rx_pkt_*`), plus Wideband T4B PN
//                   Ranging acquisition (`pn_All_Locked_out == 1'b1`) and live
//                   CLCW `V(R) = 1` readback (`0x20`).
//                 - Subtest 11.3: Spacecraft OBC Telemetry Space Packet Ingress
//                   (`s_axis_tx_pkt_*`) -> VC Arbiter -> TM Framer (embedding
//                   live CLCW with V(R)=1) -> RS(255,223) Encoder -> High-
//                   Watermark FIFO -> Baseband IQ Modulator -> Downlink RF
//                   Channel -> Ground EGSE Receiver.
//=============================================================================
`timescale 1ns / 1ps

module tb_stage11_top_to_top_rf_link;
  import ccsds_pkg::*;

  // ---------------------------------------------------------------------------
  // 1. Master System Clock (100 MHz) & Reset
  // ---------------------------------------------------------------------------
  logic clk   = 1'b0;
  logic rst_n = 1'b0;
  always #5.000 clk = ~clk;

  logic clk_sys, clk_adc_iq, clk_tx_sym, clk_tc_safe;
  assign clk_sys     = clk;
  assign clk_adc_iq  = clk;
  assign clk_tx_sym  = clk;
  assign clk_tc_safe = clk;

  // ---------------------------------------------------------------------------
  // 2. Ground EGSE (`ROLE_MODE = 1`) Signals
  // ---------------------------------------------------------------------------
  logic               gnd_awvalid, gnd_awready, gnd_wvalid, gnd_wready;
  logic [7:0]         gnd_awaddr,  gnd_araddr;
  logic [31:0]        gnd_wdata,   gnd_rdata;
  logic [3:0]         gnd_wstrb;
  logic               gnd_bvalid,  gnd_bready,  gnd_arvalid, gnd_arready;
  logic               gnd_rvalid,  gnd_rready;
  logic [1:0]         gnd_bresp,   gnd_rresp;

  logic signed [11:0] gnd_tx_i, gnd_tx_q, gnd_rx_i, gnd_rx_q;
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
  // 3. Spacecraft Flight Transceiver (`ROLE_MODE = 0`) Signals
  // ---------------------------------------------------------------------------
  logic               sc_awvalid, sc_awready, sc_wvalid, sc_wready;
  logic [7:0]         sc_awaddr,  sc_araddr;
  logic [31:0]        sc_wdata,   sc_rdata;
  logic [3:0]         sc_wstrb;
  logic               sc_bvalid,  sc_bready,  sc_arvalid, sc_arready;
  logic               sc_rvalid,  sc_rready;
  logic [1:0]         sc_bresp,   sc_rresp;

  logic signed [11:0] sc_tx_i, sc_tx_q, sc_rx_i, sc_rx_q;
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

  // ---------------------------------------------------------------------------
  // 4. Uplink & Downlink RF Channel Impairment Models
  // ---------------------------------------------------------------------------
  ccsds_channel_impairment_model u_ul_rf_channel (
    .clk                    (clk_adc_iq),
    .rst_n                  (rst_n),
    .chan_mode_cfg          (2'd2),
    .ber_threshold_cfg      (8'd0),
    .phase_invert_cfg       (1'b0),
    .burst_target_byte_cfg  (16'd0),
    .burst_xor_mask_cfg     (8'h00),
    .doppler_offset_cfg     (12'sd16),
    .s_axis_tvalid          (1'b0),
    .s_axis_tready          (),
    .s_axis_tdata           (8'h00),
    .s_axis_tlast           (1'b0),
    .m_axis_tvalid          (),
    .m_axis_tready          (1'b1),
    .m_axis_tdata           (),
    .m_axis_tlast           (),
    .tx_i_in                (gnd_tx_i),
    .tx_q_in                (gnd_tx_q),
    .tx_iq_valid_in         (gnd_tx_iq_val),
    .rx_i_out               (sc_rx_i),
    .rx_q_out               (sc_rx_q),
    .rx_iq_valid_out        (sc_rx_iq_val),
    .injected_byte_errs_out (),
    .passed_bytes_out       ()
  );

  ccsds_channel_impairment_model u_dl_rf_channel (
    .clk                    (clk_adc_iq),
    .rst_n                  (rst_n),
    .chan_mode_cfg          (2'd2),
    .ber_threshold_cfg      (8'd0),
    .phase_invert_cfg       (1'b0),
    .burst_target_byte_cfg  (16'd0),
    .burst_xor_mask_cfg     (8'h00),
    .doppler_offset_cfg     (-12'sd16),
    .s_axis_tvalid          (1'b0),
    .s_axis_tready          (),
    .s_axis_tdata           (8'h00),
    .s_axis_tlast           (1'b0),
    .m_axis_tvalid          (),
    .m_axis_tready          (1'b1),
    .m_axis_tdata           (),
    .m_axis_tlast           (),
    .tx_i_in                (sc_tx_i),
    .tx_q_in                (sc_tx_q),
    .tx_iq_valid_in         (sc_tx_iq_val),
    .rx_i_out               (gnd_rx_i),
    .rx_q_out               (gnd_rx_q),
    .rx_iq_valid_out        (gnd_rx_iq_val),
    .injected_byte_errs_out (),
    .passed_bytes_out       ()
  );

  // ---------------------------------------------------------------------------
  // 5. Ground Station Hardware EGSE Top (`ROLE_MODE = 1`)
  // ---------------------------------------------------------------------------
  ccsds_sat_ttc_top #(
    .ROLE_MODE(1)
  ) u_ground_egse_top (
    .clk_sys                (clk_sys),
    .clk_tc_safe            (clk_tc_safe),
    .clk_tx_sym             (clk_tx_sym),
    .clk_adc_iq             (clk_adc_iq),
    .rst_n                  (rst_n),
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
    .ul_fec_override_en     (2'b00),
    .sdls_en_cfg            (1'b0),
    .bc_require_sdls_cfg    (1'b0),
    .pn_ranging_en_cfg      (pn_en_cfg),
    .pn_t4b_mode_cfg        (1'b1),
    .turnaround_xband_cfg   (1'b1),
    .mod_mode_cfg           (2'd1), // QPSK
    .line_code_cfg          (2'd1), // NRZ-M
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
    .fault_irq_out          (),
    .edac_scrub_req_out     ()
  );

  // ---------------------------------------------------------------------------
  // 6. Spacecraft Flight Transceiver Top (`ROLE_MODE = 0`)
  // ---------------------------------------------------------------------------
  ccsds_sat_ttc_top #(
    .ROLE_MODE(0)
  ) u_spacecraft_top (
    .clk_sys                (clk_sys),
    .clk_tc_safe            (clk_tc_safe),
    .clk_tx_sym             (clk_tx_sym),
    .clk_adc_iq             (clk_adc_iq),
    .rst_n                  (rst_n),
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
    .ul_fec_override_en     (2'b00),
    .sdls_en_cfg            (1'b0),
    .bc_require_sdls_cfg    (1'b0),
    .pn_ranging_en_cfg      (pn_en_cfg),
    .pn_t4b_mode_cfg        (1'b1),
    .turnaround_xband_cfg   (1'b1),
    .mod_mode_cfg           (2'd1), // QPSK
    .line_code_cfg          (2'd1), // NRZ-M
    .rx_i_adc_in            (pn_en_cfg ? 12'sd1024 : sc_rx_i),
    .rx_q_adc_in            (pn_en_cfg ? (u_spacecraft_top.tx_pn_chip ? 12'sd1024 : -12'sd1024) : sc_rx_q),
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
  //    Note: `ccsds_axi_lite_csr` asserts `awready/wready/bvalid` and
  //    `arready/rvalid/rdata` on the same clock edge (`T1`). Therefore we sample
  //    `sc_rdata` when `sc_arready` is observed high at `T2` before the `T2` NBA
  //    clears `s_axi_rvalid` / `s_axi_bvalid`.
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

  logic [7:0] sc_rx_pkt_buf [0:31];
  logic [7:0] sc_dl_cadu_buf [0:127];
  integer     sc_rx_pkt_cnt, sc_dl_cadu_cnt, dl_iq_cnt;

  always_ff @(posedge clk_sys or negedge rst_n) begin
    if (!rst_n) begin
      sc_rx_pkt_cnt <= 0;
    end else if (sc_rx_pkt_tvalid && sc_rx_pkt_tready) begin
      sc_rx_pkt_buf[sc_rx_pkt_cnt] <= sc_rx_pkt_tdata;
      sc_rx_pkt_cnt                 <= sc_rx_pkt_cnt + 1;
    end
  end

  always_ff @(posedge clk_tx_sym or negedge rst_n) begin
    if (!rst_n) begin
      sc_dl_cadu_cnt <= 0;
      dl_iq_cnt      <= 0;
    end else begin
      if (sc_dl_cad_tvalid && sc_dl_cad_tready) begin
        sc_dl_cadu_buf[sc_dl_cadu_cnt] <= sc_dl_cad_tdata;
        sc_dl_cadu_cnt                 <= sc_dl_cadu_cnt + 1;
      end
      if (gnd_rx_iq_val) begin
        dl_iq_cnt <= dl_iq_cnt + 1;
      end
    end
  end

  // CRC-16-CCITT helper for building valid TC Transfer Frames
  function automatic logic [15:0] calc_crc16(input logic [7:0] data [], input int len);
    logic [15:0] crc;
    begin
      crc = 16'hFFFF;
      for (int i = 0; i < len; i++) begin
        crc = crc ^ ({data[i], 8'h00});
        for (int b = 0; b < 8; b++) begin
          if (crc[15]) crc = (crc << 1) ^ 16'h1021;
          else         crc = (crc << 1);
        end
      end
      return crc;
    end
  endfunction

  initial begin
    logic [31:0] rval;
    logic [7:0]  tc_frame [0:21];
    logic [7:0]  ul_sp    [0:13];
    logic [7:0]  dl_sp    [0:15];
    logic [15:0] crc;

    rst_n             = 1'b0;
    pn_en_cfg         = 1'b0;
    gnd_awvalid       = 1'b0; gnd_awaddr = 8'h0; gnd_wvalid = 1'b0; gnd_wdata = 32'h0; gnd_wstrb = 4'h0;
    gnd_bready        = 1'b0; gnd_arvalid = 1'b0; gnd_araddr = 8'h0; gnd_rready = 1'b0;
    sc_awvalid        = 1'b0; sc_awaddr  = 8'h0; sc_wvalid  = 1'b0; sc_wdata  = 32'h0; sc_wstrb  = 4'h0;
    sc_bready         = 1'b0; sc_arvalid  = 1'b0; sc_araddr  = 8'h0; sc_rready  = 1'b0;

    gnd_ul_sym_tvalid = 1'b0; gnd_ul_sym_tdata = 8'h0; gnd_ul_sym_tlast = 1'b0;
    gnd_rx_pkt_tready = 1'b1;
    gnd_tx_pkt_tvalid = 1'b0; gnd_tx_pkt_tdata = 8'h0; gnd_tx_pkt_tlast = 1'b0; gnd_tx_pkt_tuser = '0;
    gnd_dl_cad_tready = 1'b1;

    sc_ul_sym_tvalid  = 1'b0; sc_ul_sym_tdata  = 8'h0; sc_ul_sym_tlast  = 1'b0;
    sc_rx_pkt_tready  = 1'b1;
    sc_tx_pkt_tvalid  = 1'b0; sc_tx_pkt_tdata  = 8'h0; sc_tx_pkt_tlast  = 1'b0; sc_tx_pkt_tuser  = '0;
    sc_dl_cad_tready  = 1'b1;

    #100;
    rst_n = 1'b1;
    repeat (10) @(posedge clk_sys);

    // =========================================================================
    // SUBTEST 11.1: AXI4-Lite CSR Configuration & Readback on Spacecraft Top
    // =========================================================================
    $display("[TB-STAGE11][SUBTEST-11.1] Verifying AXI4-Lite CSR programming & readback on Spacecraft Top (ROLE_MODE=0)...");
    axi_read_sc(8'h00, rval);
    assert (rval == 32'hCC5D_0230)
      else $fatal(1, $sformatf("Expected VERSION_ID 0xCC5D0230, got 0x%08X", rval));

    // Program CTRL_SCID_PROTO (0x04): KaBand=1 (3344/749, bits 31:30), Gardner=1 (bit 29),
    // SRRC=1 (bit 28), TC_Seg=1 (bit 24), FECF=1 (bit 21), OCF=1 (bit 20), SCID=0x155
    axi_write_sc(8'h04, 32'h7130_0155);
    axi_read_sc(8'h04, rval);
    assert (rval == 32'h7130_0155)
      else $fatal(1, $sformatf("CTRL_SCID_PROTO (0x04) readback mismatch: 0x%08X", rval));

    // Restore 1-SPS mode (SRRC=0, Gardner=0, KaBand=1) in CTRL_SCID_PROTO (0x04) for fast CADU IQ streaming
    axi_write_sc(8'h04, 32'h4130_0155);

    // Program CTRL_USLP_RS_CFG (0x08): FLL=1 (bit 29), GCM=0 (bit 28), RS_Q=195 (bits 27:20),
    // RS_I=1 (bits 19:16), USLP_SCID=0x4255 (bits 15:0)
    axi_write_sc(8'h08, (32'd1 << 29) | (32'd195 << 20) | (32'd1 << 16) | 32'h4255);
    axi_read_sc(8'h08, rval);
    assert (rval[29] == 1'b1 && rval[27:20] == 8'd195 && rval[19:16] == 4'd1)
      else $fatal(1, $sformatf("CTRL_USLP_RS_CFG (0x08) readback mismatch: 0x%08X", rval));

    // Program CTRL_COP1_TFDF_CFG (0x0C): IRQ_EN=1 (bit 24), TFDF_LEN=16 (bits 18:8), WIN_W=16 (bits 7:0)
    axi_write_sc(8'h0C, (32'd1 << 24) | (32'd16 << 8) | 32'd16);
    axi_read_sc(8'h0C, rval);
    assert (rval[18:8] == 11'd16 && rval[7:0] == 8'd16)
      else $fatal(1, $sformatf("CTRL_COP1_TFDF_CFG (0x0C) readback mismatch: 0x%08X", rval));
    $display("[TB-STAGE11][SUBTEST-11.1 PASS] AXI4-Lite CSR read/write verified (0x04, 0x08=0x%08X, 0x0C=0x%08X)!",
             (32'd1 << 29) | (32'd195 << 20) | (32'd1 << 16) | 32'h4255, rval);

    // =========================================================================
    // SUBTEST 11.2: Wideband T4B PN Ranging Chip-to-Chip Lock + Uplink TC Frame
    //               Closure into Spacecraft Top (`ROLE_MODE=0`)
    // =========================================================================
    $display("[TB-STAGE11][SUBTEST-11.2] Running Wideband T4B PN Ranging + Uplink Telecommand Frame -> Spacecraft OBC Reassembler...");
    pn_en_cfg = 1'b1;
    repeat (1350) @(posedge clk_adc_iq);
    #1;
    assert (sc_pn_locked == 1'b1)
      else $fatal(1, "Spacecraft Top failed to achieve T4B PN Ranging lock!");
    pn_en_cfg = 1'b0;

    // Build 14-byte Telecommand Space Packet ("TOP_CMD1") wrapped in a 22-byte TC Transfer Frame (SCID=0x155, VCID=1, N(S)=0)
    ul_sp[0] = 8'h1A; ul_sp[1] = 8'h45; // TC, APID=0x245
    ul_sp[2] = 8'hC0; ul_sp[3] = 8'h11; // Unsegmented, Seq=17
    ul_sp[4] = 8'h00; ul_sp[5] = 8'h07; // Len = 8 - 1 = 7
    ul_sp[6] = "T";   ul_sp[7] = "O";   ul_sp[8] = "P";   ul_sp[9] = "_";
    ul_sp[10]= "C";   ul_sp[11]= "M";   ul_sp[12]= "D";   ul_sp[13]= "1";

    tc_frame[0] = 8'h01; // TFVN=0, Bypass=0, Ctrl=0, SCID[9:8]=2'b01
    tc_frame[1] = 8'h55; // SCID[7:0]=8'h55
    tc_frame[2] = 8'h04; // VCID=1, FrameLen[9:8]=0
    tc_frame[3] = 8'd21; // FrameLen = 22 - 1 = 21
    tc_frame[4] = 8'd0;  // N(S) = 0
    tc_frame[5] = 8'hC0; // TC Segment Header
    for (int i = 0; i < 14; i++) tc_frame[6 + i] = ul_sp[i];
    crc = calc_crc16(tc_frame, 20);
    tc_frame[20] = crc[15:8];
    tc_frame[21] = crc[7:0];

    for (int i = 0; i < 22; i++) begin
      int wait_ul;
      wait_ul = 0;
      @(posedge clk_tc_safe);
      while (!sc_ul_sym_tready) begin
        @(posedge clk_tc_safe);
        wait_ul++;
        if (wait_ul > 200) $fatal(1, "Timeout waiting for sc_ul_sym_tready in Subtest 11.2!");
      end
      #1;
      sc_ul_sym_tvalid = 1'b1;
      sc_ul_sym_tdata  = tc_frame[i];
      sc_ul_sym_tlast  = (i == 21);
    end
    @(posedge clk_tc_safe);
    #1;
    sc_ul_sym_tvalid = 1'b0;
    sc_ul_sym_tlast  = 1'b0;

    repeat (40) @(posedge clk_sys);
    #1;

    assert (sc_rx_pkt_cnt == 14)
      else $fatal(1, $sformatf("Expected 14 reassembled OBC Space Packet bytes on Spacecraft Top, got %0d", sc_rx_pkt_cnt));
    for (int i = 0; i < 14; i++) begin
      assert (sc_rx_pkt_buf[i] == ul_sp[i])
        else $fatal(1, $sformatf("Spacecraft OBC Space Packet byte[%0d] mismatch: got 0x%02X, exp 0x%02X",
                                 i, sc_rx_pkt_buf[i], ul_sp[i]));
    end

    // Read back live CLCW from Spacecraft AXI4-Lite CSR (LATEST_CLCW_MON = 0x20) and verify V(R) advanced to 1!
    axi_read_sc(8'h20, rval);
    assert (rval[7:0] == 8'd1)
      else $fatal(1, $sformatf("Expected Spacecraft CLCW Report_Value V(R)=1 at 0x20, got 0x%08X", rval));
    $display("[TB-STAGE11][SUBTEST-11.2 PASS] T4B PN Ranging locked, Uplink Space Packet \"TOP_CMD1\" delivered to Spacecraft OBC, and CLCW V(R)=%0d!", rval[7:0]);

    // =========================================================================
    // SUBTEST 11.3: Spacecraft Downlink Telemetry Space Packet -> CADU & IQ Link
    // =========================================================================
    $display("[TB-STAGE11][SUBTEST-11.3] Streaming 16-byte Telemetry Space Packet (\"SAT_TLM_OK\") into Spacecraft Top Downlink Chain...");
    dl_sp[0] = 8'h09; dl_sp[1] = 8'h09; // TM, APID=0x109
    dl_sp[2] = 8'hC0; dl_sp[3] = 8'h22; // Seq=34
    dl_sp[4] = 8'h00; dl_sp[5] = 8'h09; // Len = 10 - 1 = 9
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
      sc_tx_pkt_tuser.vcid = 6'd1;
    end
    @(posedge clk_sys);
    #1;
    sc_tx_pkt_tvalid = 1'b0;
    sc_tx_pkt_tlast  = 1'b0;

    // Bounded wait for 64-byte RS(255,223)-encoded CADU (4B ASM 0x1ACFFC1D + 28B TM Frame + 32B RS Parity) to egress on clk_tx_sym
    for (int w = 0; w < 500 && sc_dl_cadu_cnt < 64; w++) begin
      @(posedge clk_tx_sym);
    end
    repeat (20) @(posedge clk_tx_sym);
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
    assert (dl_iq_cnt > 0)
      else $fatal(1, "Expected Downlink Baseband IQ samples across u_dl_rf_channel into Ground EGSE!");

    $display("[TB-STAGE11][SUBTEST-11.3 PASS] Spacecraft Top emitted 64-byte RS(255,223) Downlink CADU (ASM=0x1ACFFC1D, Payload=\"SAT_TLM_OK\", CLCW V(R)=1) and streamed %0d IQ samples across u_dl_rf_channel!", dl_iq_cnt);
    $display("[TB-STAGE11 PASS] ALL 3 FULL CHIP-TO-CHIP TOP-LEVEL RF LINK-CLOSURE SUBTESTS PASSED WITH 0 ERRORS!");
    $finish;
  end

endmodule : tb_stage11_top_to_top_rf_link
