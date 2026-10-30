// =============================================================================
// File Name   : ccsds_axi_lite_csr.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog (Synthesizable)
// Description : Memory-Mapped AXI4-Lite Configuration, Status, On-Board Time
//               (OBT CCSDS 301.0-B-4 48-bit CUC Timestamp), Runtime SDLS Key/SA
//               Provisioning, and Radiation EDAC Fault Aggregation Register File:
//                 - 32-bit AXI4-Lite slave interface (0x00..0x50 register map).
//                 - Triple-Modular Redundant (TMR) storage with continuous
//                   auto-scrubbing for mission-critical configuration registers
//                   (SCID, Role/Protocol/FEC modes, SDLS enable, AES-GCM mode,
//                   COP-1 window, 4-SPS SRRC, Closed-Loop Gardner TED, Ka-Band
//                   Turnaround, FLL-Assisted Costas Loop, and CADU Randomizer).
//                 - Runtime SDLS 256-bit Master Key (0x28..0x44) and Security
//                   Association (SA) Table Provisioning (0x48..0x50).
//                 - 48-bit CCSDS Unsegmented Time Code (CUC: 32b Coarse Seconds
//                   + 16b Fine Sub-seconds) synchronized to 1 PPS input for
//                   downlink TM/AOS/USLP Secondary Header OBT stamping.
//                 - Saturating 16-bit EDAC/fault telemetry counters and unified
//                   fault_irq_out / edac_scrub_req_out interrupt lines.
// =============================================================================
`timescale 1ns / 1ps

module ccsds_axi_lite_csr
  import ccsds_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // AXI4-Lite Slave Interface from Spacecraft OBC
  input  logic [7:0]  s_axi_awaddr,
  input  logic        s_axi_awvalid,
  output logic        s_axi_awready,
  input  logic [31:0] s_axi_wdata,
  input  logic [3:0]  s_axi_wstrb,
  input  logic        s_axi_wvalid,
  output logic        s_axi_wready,
  output logic [1:0]  s_axi_bresp,
  output logic        s_axi_bvalid,
  input  logic        s_axi_bready,
  input  logic [7:0]  s_axi_araddr,
  input  logic        s_axi_arvalid,
  output logic        s_axi_arready,
  output logic [31:0] s_axi_rdata,
  output logic [1:0]  s_axi_rresp,
  output logic        s_axi_rvalid,
  input  logic        s_axi_rready,

  // External 1 Hz PPS Synchronization & SEU Fault-Injection Test Port
  input  logic        pps_1hz_pulse,
  input  logic        csr_seu_inject_en,
  input  logic [31:0] csr_seu_xor_mask,

  // Hardware Fault & EDAC Event Pulses from Rx/Tx Subsystems
  input  logic        bch_single_err_pulse,
  input  logic        bch_double_abort_pulse,
  input  logic        fifo_secded_single_pulse,
  input  logic        fifo_secded_double_pulse,
  input  logic        farm1_tmr_seu_pulse,
  input  logic        frame_crc_err_pulse,
  input  logic        pkt_len_err_pulse,
  input  logic        sdls_mac_err_pulse,
  input  ccsds_clcw_t latest_clcw_in,
  input  ccsds_plcw_t latest_plcw_in,

  // Decoded TMR-Voted Runtime Configuration Outputs
  output logic [9:0]  spacecraft_id_cfg,
  output logic [15:0] uslp_scid_cfg,
  output logic [2:0]  proto_mode_cfg,
  output logic [3:0]  fec_mode_cfg,
  output logic        ocf_en_cfg,
  output logic        fecf_en_cfg,
  output logic        fecf_crc32_cfg,
  output logic        aos_fhec_en_cfg,
  output logic        tc_seg_hdr_present_cfg,
  output logic        obt_sec_hdr_en_cfg,
  output logic        sdls_en_cfg,
  output logic        bc_require_sdls_cfg,
  output logic        srrc_4sps_en_cfg,
  output logic        gardner_ted_en_cfg,
  output logic [1:0]  turnaround_kaband_cfg,
  output logic        sdls_gcm_mode_cfg,
  output logic        fll_assist_en_cfg,
  output logic        tm_rand_en_cfg,
  output logic [7:0]  window_half_w_cfg,
  output logic [3:0]  rs_interleave_i_cfg,
  output logic [7:0]  rs_virt_fill_q_cfg,
  output logic [10:0] tfdf_byte_len_cfg,

  // Runtime SDLS 256-Bit Master Key & Security Association (SA) Provisioning Outputs
  output logic [15:0]  tx_default_spi_cfg,
  output logic [255:0] master_key_cfg,
  output logic         sa_wr_en,
  output logic [5:0]   sa_wr_addr,
  output logic [15:0]  sa_wr_spi,
  output logic [31:0]  sa_wr_seq_low,

  // 48-bit CCSDS 301.0-B-4 CUC On-Board Time (OBT) Output
  output logic [47:0] obt_cuc_timestamp_48b,

  // Unified Fault Interrupt & FPGA Configuration Scrubber Trigger Outputs
  output logic        csr_tmr_seu_corrected_pulse,
  output logic        fault_irq_out,
  output logic        edac_scrub_req_out
);

  // Register Map Offsets (Byte Addresses):
  // 0x00 : CORE_ID_VER        (RO) 32'hCC5D_0230 (CCSDS-SAT-TTC-IP v2.3)
  // 0x04 : CTRL_SCID_PROTO    (RW, TMR) [9:0]=SCID, [15:12]=PROTO, [19:16]=FEC, [20]=OCF, [21]=FECF,
  //                                     [22]=CRC32, [23]=AOS_FHEC, [24]=TC_SEG_HDR, [25]=OBT_EN,
  //                                     [26]=SDLS_EN, [27]=BC_REQ_SDLS, [28]=SRRC_4SPS_EN,
  //                                     [29]=GARDNER_TED_EN, [31:30]=TURNAROUND_KABAND_CFG
  // 0x08 : CTRL_USLP_RS_CFG   (RW, TMR) [15:0]=USLP_SCID, [19:16]=RS_I, [27:20]=RS_Q,
  //                                     [28]=SDLS_GCM_MODE_CFG, [29]=FLL_ASSIST_EN_CFG,
  //                                     [30]=TM_RAND_EN_CFG
  // 0x0C : CTRL_COP1_TFDF_CFG (RW, TMR) [7:0]=WIN_W, [18:8]=TFDF_LEN, [24]=IRQ_EN
  // 0x10 : OBT_COARSE_SEC     (RW) 32-bit CUC Coarse Seconds
  // 0x14 : OBT_FINE_SUBSEC    (RW) [15:0] 16-bit CUC Fine Sub-seconds
  // 0x18 : EDAC_CORR_CNTS     (RO/W1C) [15:0]=SECDED/BCH 1b Corr Cnt, [31:16]=TMR SEU Corr Cnt
  // 0x1C : FAULT_ERR_CNTS     (RO/W1C) [15:0]=Uncorr FEC/CRC/Pkt Err Cnt, [31:16]=SDLS MAC Err Cnt
  // 0x20 : LATEST_CLCW_MON    (RO) Latest 32-bit COP-1 CLCW word
  // 0x24 : LATEST_PLCW_MON    (RO) Latest 32-bit Proximity-1 PLCW word
  // 0x28..0x44 : REG_SDLS_KEY_0..7 (RW) 256-bit SDLS Master Key (LSW at 0x28 .. MSW at 0x44)
  // 0x48 : REG_SDLS_SA_CTRL   (RW) [15:0]=TX_DEFAULT_SPI, [21:16]=SA_WR_ADDR, [31]=SA_WR_EN
  // 0x4C : REG_SDLS_SA_SPI    (RW) [15:0]=SA_WR_SPI
  // 0x50 : REG_SDLS_SA_SEQ    (RW) [31:0]=SA_WR_SEQ_LOW

  logic [31:0] reg_scid_proto_a_q, reg_scid_proto_b_q, reg_scid_proto_c_q;
  logic [31:0] reg_uslp_rs_a_q,    reg_uslp_rs_b_q,    reg_uslp_rs_c_q;
  logic [31:0] reg_cop1_tfdf_a_q,  reg_cop1_tfdf_b_q,  reg_cop1_tfdf_c_q;

  logic [31:0] obt_coarse_sec_q;
  logic [15:0] obt_fine_subsec_q;
  logic [15:0] cnt_secded_corr_q;
  logic [15:0] cnt_tmr_seu_corr_q;
  logic [15:0] cnt_uncorr_err_q;
  logic [15:0] cnt_sdls_mac_err_q;

  localparam logic [255:0] RESET_SDLS_MASTER_KEY =
    256'h00010203_04050607_08090A0B_0C0D0E0F_10111213_14151617_18191A1B_1C1D1E1F;

  logic [31:0] sdls_key_reg_q [0:7];
  logic [15:0] tx_default_spi_q;
  logic [5:0]  sa_wr_addr_q;
  logic        sa_wr_en_q;
  logic [15:0] sa_wr_spi_q;
  logic [31:0] sa_wr_seq_low_q;

  function automatic logic [31:0] vote32(
    input logic [31:0] a,
    input logic [31:0] b,
    input logic [31:0] c
  );
    return (a & b) | (b & c) | (a & c);
  endfunction

  logic [31:0] voted_scid_proto;
  logic [31:0] voted_uslp_rs;
  logic [31:0] voted_cop1_tfdf;

  always_comb begin
    voted_scid_proto       = vote32(reg_scid_proto_a_q, reg_scid_proto_b_q, reg_scid_proto_c_q);
    voted_uslp_rs          = vote32(reg_uslp_rs_a_q,    reg_uslp_rs_b_q,    reg_uslp_rs_c_q);
    voted_cop1_tfdf        = vote32(reg_cop1_tfdf_a_q,  reg_cop1_tfdf_b_q,  reg_cop1_tfdf_c_q);

    spacecraft_id_cfg      = voted_scid_proto[9:0];
    proto_mode_cfg         = voted_scid_proto[14:12];
    fec_mode_cfg           = voted_scid_proto[19:16];
    ocf_en_cfg             = voted_scid_proto[20];
    fecf_en_cfg            = voted_scid_proto[21];
    fecf_crc32_cfg         = voted_scid_proto[22];
    aos_fhec_en_cfg        = voted_scid_proto[23];
    tc_seg_hdr_present_cfg = voted_scid_proto[24];
    obt_sec_hdr_en_cfg     = voted_scid_proto[25];
    sdls_en_cfg            = voted_scid_proto[26];
    bc_require_sdls_cfg    = voted_scid_proto[27];
    srrc_4sps_en_cfg       = voted_scid_proto[28];
    gardner_ted_en_cfg     = voted_scid_proto[29];
    turnaround_kaband_cfg  = voted_scid_proto[31:30];

    uslp_scid_cfg          = voted_uslp_rs[15:0];
    rs_interleave_i_cfg    = voted_uslp_rs[19:16];
    rs_virt_fill_q_cfg     = voted_uslp_rs[27:20];
    sdls_gcm_mode_cfg      = voted_uslp_rs[28];
    fll_assist_en_cfg      = voted_uslp_rs[29];
    tm_rand_en_cfg         = voted_uslp_rs[30];

    window_half_w_cfg      = voted_cop1_tfdf[7:0];
    tfdf_byte_len_cfg      = voted_cop1_tfdf[18:8];

    tx_default_spi_cfg     = tx_default_spi_q;
    master_key_cfg         = {
      sdls_key_reg_q[7], sdls_key_reg_q[6], sdls_key_reg_q[5], sdls_key_reg_q[4],
      sdls_key_reg_q[3], sdls_key_reg_q[2], sdls_key_reg_q[1], sdls_key_reg_q[0]
    };
    sa_wr_en               = sa_wr_en_q;
    sa_wr_addr             = sa_wr_addr_q;
    sa_wr_spi              = sa_wr_spi_q;
    sa_wr_seq_low          = sa_wr_seq_low_q;

    obt_cuc_timestamp_48b  = {obt_coarse_sec_q, obt_fine_subsec_q};
    fault_irq_out          = voted_cop1_tfdf[24] && ((cnt_uncorr_err_q != 16'd0) || (cnt_sdls_mac_err_q != 16'd0));
  end

  localparam logic [31:0] RESET_SCID_PROTO = 32'h0131_5155; // SCID=0x155,FEC=RS,OCF=1,FECF=1,TC_SEG=1
  localparam logic [31:0] RESET_USLP_RS    = 32'h0001_4255; // USLP_SCID=0x4255, RS_I=1, RS_Q=0, TM_RAND=0
  localparam logic [31:0] RESET_COP1_TFDF  = 32'h010D_F010; // WIN_W=16, TFDF_LEN=223, IRQ_EN=1

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      reg_scid_proto_a_q          <= RESET_SCID_PROTO;
      reg_scid_proto_b_q          <= RESET_SCID_PROTO;
      reg_scid_proto_c_q          <= RESET_SCID_PROTO;
      reg_uslp_rs_a_q             <= RESET_USLP_RS;
      reg_uslp_rs_b_q             <= RESET_USLP_RS;
      reg_uslp_rs_c_q             <= RESET_USLP_RS;
      reg_cop1_tfdf_a_q           <= RESET_COP1_TFDF;
      reg_cop1_tfdf_b_q           <= RESET_COP1_TFDF;
      reg_cop1_tfdf_c_q           <= RESET_COP1_TFDF;
      for (int k = 0; k < 8; k++) begin
        sdls_key_reg_q[k]         <= RESET_SDLS_MASTER_KEY[k*32 +: 32];
      end
      tx_default_spi_q            <= 16'h0001;
      sa_wr_addr_q                <= 6'd1;
      sa_wr_en_q                  <= 1'b0;
      sa_wr_spi_q                 <= 16'h0001;
      sa_wr_seq_low_q             <= 32'd0;
      obt_coarse_sec_q            <= 32'h6530_0000;
      obt_fine_subsec_q           <= 16'h0000;
      cnt_secded_corr_q           <= 16'd0;
      cnt_tmr_seu_corr_q          <= 16'd0;
      cnt_uncorr_err_q            <= 16'd0;
      cnt_sdls_mac_err_q          <= 16'd0;
      s_axi_awready               <= 1'b0;
      s_axi_wready                <= 1'b0;
      s_axi_bresp                 <= 2'b00;
      s_axi_bvalid                <= 1'b0;
      s_axi_arready               <= 1'b0;
      s_axi_rdata                 <= 32'd0;
      s_axi_rresp                 <= 2'b00;
      s_axi_rvalid                <= 1'b0;
      csr_tmr_seu_corrected_pulse <= 1'b0;
      edac_scrub_req_out          <= 1'b0;
    end else begin
      logic csr_disagree;
      s_axi_awready               <= 1'b0;
      s_axi_wready                <= 1'b0;
      s_axi_arready               <= 1'b0;
      sa_wr_en_q                  <= 1'b0;
      csr_tmr_seu_corrected_pulse <= 1'b0;
      edac_scrub_req_out          <= 1'b0;

      // 1. Continuous TMR Self-Healing Scrubbing of Control Registers
      csr_disagree = (reg_scid_proto_a_q != reg_scid_proto_b_q) || (reg_scid_proto_b_q != reg_scid_proto_c_q) ||
                     (reg_uslp_rs_a_q    != reg_uslp_rs_b_q)    || (reg_uslp_rs_b_q    != reg_uslp_rs_c_q)    ||
                     (reg_cop1_tfdf_a_q  != reg_cop1_tfdf_b_q)  || (reg_cop1_tfdf_b_q  != reg_cop1_tfdf_c_q);
      if (csr_disagree) begin
        reg_scid_proto_a_q          <= voted_scid_proto;
        reg_scid_proto_b_q          <= voted_scid_proto;
        reg_scid_proto_c_q          <= voted_scid_proto;
        reg_uslp_rs_a_q             <= voted_uslp_rs;
        reg_uslp_rs_b_q             <= voted_uslp_rs;
        reg_uslp_rs_c_q             <= voted_uslp_rs;
        reg_cop1_tfdf_a_q           <= voted_cop1_tfdf;
        reg_cop1_tfdf_b_q           <= voted_cop1_tfdf;
        reg_cop1_tfdf_c_q           <= voted_cop1_tfdf;
        csr_tmr_seu_corrected_pulse <= 1'b1;
        edac_scrub_req_out          <= 1'b1;
      end else if (csr_seu_inject_en) begin
        // Fault-injection test hook: corrupt Replica A only
        reg_scid_proto_a_q <= reg_scid_proto_a_q ^ csr_seu_xor_mask;
      end

      // 2. On-Board Time (OBT CUC 48-bit) Increment
      if (pps_1hz_pulse) begin
        obt_coarse_sec_q  <= obt_coarse_sec_q + 32'd1;
        obt_fine_subsec_q <= 16'd0;
      end else begin
        obt_fine_subsec_q <= obt_fine_subsec_q + 16'd1;
      end

      // 3. Saturating Radiation EDAC & Protocol Fault Telemetry Counters
      if (bch_single_err_pulse || fifo_secded_single_pulse) begin
        if (cnt_secded_corr_q != 16'hFFFF) begin
          cnt_secded_corr_q <= cnt_secded_corr_q + 16'd1;
        end
      end
      if (farm1_tmr_seu_pulse || csr_disagree) begin
        if (cnt_tmr_seu_corr_q != 16'hFFFF) begin
          cnt_tmr_seu_corr_q <= cnt_tmr_seu_corr_q + 16'd1;
        end
        edac_scrub_req_out <= 1'b1;
      end
      if (bch_double_abort_pulse || fifo_secded_double_pulse || frame_crc_err_pulse || pkt_len_err_pulse) begin
        if (cnt_uncorr_err_q != 16'hFFFF) begin
          cnt_uncorr_err_q <= cnt_uncorr_err_q + 16'd1;
        end
        if (fifo_secded_double_pulse) begin
          edac_scrub_req_out <= 1'b1;
        end
      end
      if (sdls_mac_err_pulse) begin
        if (cnt_sdls_mac_err_q != 16'hFFFF) begin
          cnt_sdls_mac_err_q <= cnt_sdls_mac_err_q + 16'd1;
        end
      end

      // 4. AXI4-Lite Write Channel Handshake
      if (s_axi_awvalid && s_axi_wvalid && !s_axi_bvalid) begin
        s_axi_awready <= 1'b1;
        s_axi_wready  <= 1'b1;
        s_axi_bresp   <= 2'b00;
        s_axi_bvalid  <= 1'b1;
        unique case (s_axi_awaddr[7:2])
          6'h01: begin // 0x04 CTRL_SCID_PROTO
            if (s_axi_wstrb == 4'hF) begin
              reg_scid_proto_a_q <= s_axi_wdata;
              reg_scid_proto_b_q <= s_axi_wdata;
              reg_scid_proto_c_q <= s_axi_wdata;
            end
          end
          6'h02: begin // 0x08 CTRL_USLP_RS_CFG
            if (s_axi_wstrb == 4'hF) begin
              reg_uslp_rs_a_q <= s_axi_wdata;
              reg_uslp_rs_b_q <= s_axi_wdata;
              reg_uslp_rs_c_q <= s_axi_wdata;
            end
          end
          6'h03: begin // 0x0C CTRL_COP1_TFDF_CFG
            if (s_axi_wstrb == 4'hF) begin
              reg_cop1_tfdf_a_q <= s_axi_wdata;
              reg_cop1_tfdf_b_q <= s_axi_wdata;
              reg_cop1_tfdf_c_q <= s_axi_wdata;
            end
          end
          6'h04: obt_coarse_sec_q  <= s_axi_wdata;
          6'h05: obt_fine_subsec_q <= s_axi_wdata[15:0];
          6'h06: begin // Write-1-to-Clear EDAC counters
            if (s_axi_wdata[0])  cnt_secded_corr_q  <= 16'd0;
            if (s_axi_wdata[16]) cnt_tmr_seu_corr_q <= 16'd0;
          end
          6'h07: begin // Write-1-to-Clear Fault counters
            if (s_axi_wdata[0])  cnt_uncorr_err_q   <= 16'd0;
            if (s_axi_wdata[16]) cnt_sdls_mac_err_q <= 16'd0;
          end
          6'h0A: sdls_key_reg_q[0] <= s_axi_wdata;
          6'h0B: sdls_key_reg_q[1] <= s_axi_wdata;
          6'h0C: sdls_key_reg_q[2] <= s_axi_wdata;
          6'h0D: sdls_key_reg_q[3] <= s_axi_wdata;
          6'h0E: sdls_key_reg_q[4] <= s_axi_wdata;
          6'h0F: sdls_key_reg_q[5] <= s_axi_wdata;
          6'h10: sdls_key_reg_q[6] <= s_axi_wdata;
          6'h11: sdls_key_reg_q[7] <= s_axi_wdata;
          6'h12: begin // 0x48 REG_SDLS_SA_CTRL
            tx_default_spi_q <= s_axi_wdata[15:0];
            sa_wr_addr_q     <= s_axi_wdata[21:16];
            sa_wr_en_q       <= s_axi_wdata[31];
          end
          6'h13: sa_wr_spi_q     <= s_axi_wdata[15:0]; // 0x4C REG_SDLS_SA_SPI
          6'h14: sa_wr_seq_low_q <= s_axi_wdata;       // 0x50 REG_SDLS_SA_SEQ
          default: ;
        endcase
      end else if (s_axi_bvalid && s_axi_bready) begin
        s_axi_bvalid <= 1'b0;
      end

      // 5. AXI4-Lite Read Channel Handshake
      if (s_axi_arvalid && !s_axi_rvalid) begin
        s_axi_arready <= 1'b1;
        s_axi_rresp   <= 2'b00;
        s_axi_rvalid  <= 1'b1;
        unique case (s_axi_araddr[7:2])
          6'h00: s_axi_rdata <= 32'hCC5D_0230;
          6'h01: s_axi_rdata <= voted_scid_proto;
          6'h02: s_axi_rdata <= voted_uslp_rs;
          6'h03: s_axi_rdata <= voted_cop1_tfdf;
          6'h04: s_axi_rdata <= obt_coarse_sec_q;
          6'h05: s_axi_rdata <= {16'd0, obt_fine_subsec_q};
          6'h06: s_axi_rdata <= {cnt_tmr_seu_corr_q, cnt_secded_corr_q};
          6'h07: s_axi_rdata <= {cnt_sdls_mac_err_q, cnt_uncorr_err_q};
          6'h08: s_axi_rdata <= 32'(latest_clcw_in);
          6'h09: s_axi_rdata <= 32'(latest_plcw_in);
          6'h0A: s_axi_rdata <= sdls_key_reg_q[0];
          6'h0B: s_axi_rdata <= sdls_key_reg_q[1];
          6'h0C: s_axi_rdata <= sdls_key_reg_q[2];
          6'h0D: s_axi_rdata <= sdls_key_reg_q[3];
          6'h0E: s_axi_rdata <= sdls_key_reg_q[4];
          6'h0F: s_axi_rdata <= sdls_key_reg_q[5];
          6'h10: s_axi_rdata <= sdls_key_reg_q[6];
          6'h11: s_axi_rdata <= sdls_key_reg_q[7];
          6'h12: s_axi_rdata <= {10'd0, sa_wr_addr_q, tx_default_spi_q};
          6'h13: s_axi_rdata <= {16'd0, sa_wr_spi_q};
          6'h14: s_axi_rdata <= sa_wr_seq_low_q;
          default: s_axi_rdata <= 32'd0;
        endcase
      end else if (s_axi_rvalid && s_axi_rready) begin
        s_axi_rvalid <= 1'b0;
      end
    end
  end

endmodule : ccsds_axi_lite_csr
