//=============================================================================
// File Name   : ccsds_sat_ttc_top.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Version     : v2.34.0 (Pre-Hardware Deployment Audit Release)
// Description : Top-Level Parameterized Spacecraft Flight Transceiver
//               (ROLE_MODE=0), Hardware Ground EGSE Transceiver (ROLE_MODE=1),
//               and Symmetric Crosslink / On-Orbit BIST Transceiver (ROLE_MODE=2).
//               Supports compile-time modular feature parameterization
//               (ENABLE_SDLS, ENABLE_UL_LDPC, IQ_BUS_WIDTH) for compact FPGA
//               targets (xc7z010) as well as full-featured deployment on
//               xc7z020 / Kintex UltraScale + Analog Devices axi_ad9361.
//               Includes:
//                 1. Internal 4-bit AD9361 I/Q Bus Slice/Pad (IQ_BUS_WIDTH=16/12)
//                 2. Uplink Rx CDC FIFO (`u_rx_phy_cdc_fifo`) + MSB-first
//                    bit-to-LLR serializer (`clk_adc_iq` -> `clk_tc_safe`)
//                 3. Standard 2-FF Asynchronous-Assert / Synchronous-Deassert
//                    Reset Synchronizer Bridges across all 4 clock domains
//                 4. Runtime SDLS 256-bit Master Key & Security Association
//                    Provisioning via AXI4-Lite CSR (`0x28..0x50`)
//                 5. External `pps_1hz_in` pin with 2-FF `ASYNC_REG` synchronizer,
//                    rising-edge detector, and 100 MHz internal 1 Hz fallback divider
//                 6. Programmable Downlink CADU Pseudo-Randomizer (`tm_rand_en_cfg`)
//=============================================================================
`timescale 1ns / 1ps

module ccsds_sat_ttc_top
  import ccsds_pkg::*;
#(
  parameter int unsigned ROLE_MODE      = 0,
  parameter bit          ENABLE_SDLS    = 1'b1,
  parameter bit          ENABLE_UL_LDPC = 1'b1,
  parameter int unsigned IQ_BUS_WIDTH   = 16
) (
  input  logic               clk_sys,
  input  logic               clk_tc_safe,
  input  logic               clk_tx_sym,
  input  logic               clk_adc_iq,
  input  logic               rst_n,
  input  logic               pps_1hz_in,

  // AXI4-Lite Control & Status Register Interface
  input  logic               s_axi_awvalid,
  output logic               s_axi_awready,
  input  logic [7:0]         s_axi_awaddr,
  input  logic               s_axi_wvalid,
  output logic               s_axi_wready,
  input  logic [31:0]        s_axi_wdata,
  input  logic [3:0]         s_axi_wstrb,
  output logic               s_axi_bvalid,
  input  logic               s_axi_bready,
  output logic [1:0]         s_axi_bresp,
  input  logic               s_axi_arvalid,
  output logic               s_axi_arready,
  input  logic [7:0]         s_axi_araddr,
  output logic               s_axi_rvalid,
  input  logic               s_axi_rready,
  output logic [31:0]        s_axi_rdata,
  output logic [1:0]         s_axi_rresp,

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
  input  logic signed [IQ_BUS_WIDTH-1:0] rx_i_adc_in,
  input  logic signed [IQ_BUS_WIDTH-1:0] rx_q_adc_in,
  input  logic                           rx_iq_valid_in,
  input  logic                           s_axis_ul_sym_tvalid,
  output logic                           s_axis_ul_sym_tready,
  input  logic [7:0]                     s_axis_ul_sym_tdata,
  input  logic                           s_axis_ul_sym_tlast,

  // Uplink Reassembled Space Packet / MAP SDU Output to OBC
  output logic               m_axis_rx_pkt_tvalid,
  input  logic               m_axis_rx_pkt_tready,
  output logic [7:0]         m_axis_rx_pkt_tdata,
  output logic               m_axis_rx_pkt_tlast,
  output ccsds_tuser_t       m_axis_rx_pkt_tuser,

  // Downlink Space Packet Ingress from OBC
  input  logic               s_axis_tx_pkt_tvalid,
  output logic               s_axis_tx_pkt_tready,
  input  logic [7:0]         s_axis_tx_pkt_tdata,
  input  logic               s_axis_tx_pkt_tlast,
  input  ccsds_tuser_t       s_axis_tx_pkt_tuser,

  // Downlink CADU / Baseband IQ DAC Outputs
  output logic                           m_axis_dl_cad_tvalid,
  input  logic                           m_axis_dl_cad_tready,
  output logic [7:0]                     m_axis_dl_cad_tdata,
  output logic                           m_axis_dl_cad_tlast,
  output logic signed [IQ_BUS_WIDTH-1:0] tx_i_dac_out,
  output logic signed [IQ_BUS_WIDTH-1:0] tx_q_dac_out,
  output logic                           tx_iq_valid_out,

  // Emergency HCPD & Fault Outputs
  output logic               hcpd_obc_reset_pulse,
  output logic               hcpd_safe_mode_force,
  output logic [1:0]         hcpd_rf_chain_select,
  output logic               pn_All_Locked_out,
  output logic               fault_irq_out,
  output logic               edac_scrub_req_out
);

  //---------------------------------------------------------------------------
  // 0A. Internal 4-Bit AD9361 I/Q Bus Adaptation (`IQ_BUS_WIDTH` 16 <-> 12-bit Q1.11)
  //     - Rx ADC (`axi_ad9361` sign-extends 12-bit two's complement in [11:0]):
  //       slices lower 12 bits `rx_i_adc_in[11:0]` / `rx_q_adc_in[11:0]`.
  //     - Tx DAC (`axi_ad9361` expects 12-bit sample MSB-aligned in [15:4]):
  //       pads 4 LSB zeros `{phy_tx_i_12b, 4'b0000}` / `{phy_tx_q_12b, 4'b0000}`.
  //---------------------------------------------------------------------------
  logic signed [11:0] phy_rx_i_12b, phy_rx_q_12b;
  logic signed [11:0] phy_tx_i_12b, phy_tx_q_12b;

  generate
    if (IQ_BUS_WIDTH == 16) begin : g_ad9361_16b_iq_slice_pad
      assign phy_rx_i_12b = rx_i_adc_in[11:0];
      assign phy_rx_q_12b = rx_q_adc_in[11:0];
      assign tx_i_dac_out = {phy_tx_i_12b, 4'b0000};
      assign tx_q_dac_out = {phy_tx_q_12b, 4'b0000};
    end else begin : g_direct_12b_iq
      assign phy_rx_i_12b = rx_i_adc_in[11:0];
      assign phy_rx_q_12b = rx_q_adc_in[11:0];
      assign tx_i_dac_out = phy_tx_i_12b;
      assign tx_q_dac_out = phy_tx_q_12b;
    end
  endgenerate

  //---------------------------------------------------------------------------
  // 0B. Per-Domain 2-FF Reset Synchronizer Bridges (Async-Assert, Sync-Deassert)
  //---------------------------------------------------------------------------
  (* ASYNC_REG = "TRUE" *) logic rst_sys_meta_q, rst_sys_sync_q;
  (* ASYNC_REG = "TRUE" *) logic rst_tc_meta_q,  rst_tc_sync_q;
  (* ASYNC_REG = "TRUE" *) logic rst_tx_meta_q,  rst_tx_sync_q;
  (* ASYNC_REG = "TRUE" *) logic rst_adc_meta_q, rst_adc_sync_q;

  logic rst_sys_n, rst_tc_n, rst_tx_n, rst_adc_n;

  always_ff @(posedge clk_sys or negedge rst_n) begin
    if (!rst_n) begin
      rst_sys_meta_q <= 1'b0;
      rst_sys_sync_q <= 1'b0;
    end else begin
      rst_sys_meta_q <= 1'b1;
      rst_sys_sync_q <= rst_sys_meta_q;
    end
  end
  assign rst_sys_n = rst_sys_sync_q;

  always_ff @(posedge clk_tc_safe or negedge rst_n) begin
    if (!rst_n) begin
      rst_tc_meta_q <= 1'b0;
      rst_tc_sync_q <= 1'b0;
    end else begin
      rst_tc_meta_q <= 1'b1;
      rst_tc_sync_q <= rst_tc_meta_q;
    end
  end
  assign rst_tc_n = rst_tc_sync_q;

  always_ff @(posedge clk_tx_sym or negedge rst_n) begin
    if (!rst_n) begin
      rst_tx_meta_q <= 1'b0;
      rst_tx_sync_q <= 1'b0;
    end else begin
      rst_tx_meta_q <= 1'b1;
      rst_tx_sync_q <= rst_tx_meta_q;
    end
  end
  assign rst_tx_n = rst_tx_sync_q;

  always_ff @(posedge clk_adc_iq or negedge rst_n) begin
    if (!rst_n) begin
      rst_adc_meta_q <= 1'b0;
      rst_adc_sync_q <= 1'b0;
    end else begin
      rst_adc_meta_q <= 1'b1;
      rst_adc_sync_q <= rst_adc_meta_q;
    end
  end
  assign rst_adc_n = rst_adc_sync_q;

  //---------------------------------------------------------------------------
  // 0C. 1 PPS Synchronization & Internal 100 MHz Fallback Timebase Divider
  //---------------------------------------------------------------------------
  (* ASYNC_REG = "TRUE" *) logic pps_meta_q, pps_sync_q;
  logic        pps_prev_q;
  logic        pps_ext_rising;
  logic [26:0] pps_fallback_cnt_q;
  logic        pps_1hz_pulse_sys;

  assign pps_ext_rising = pps_sync_q && !pps_prev_q;

  always_ff @(posedge clk_sys or negedge rst_sys_n) begin
    if (!rst_sys_n) begin
      pps_meta_q         <= 1'b0;
      pps_sync_q         <= 1'b0;
      pps_prev_q         <= 1'b0;
      pps_fallback_cnt_q <= 27'd0;
      pps_1hz_pulse_sys  <= 1'b0;
    end else begin
      pps_meta_q <= pps_1hz_in;
      pps_sync_q <= pps_meta_q;
      pps_prev_q <= pps_sync_q;

      if (pps_ext_rising) begin
        pps_fallback_cnt_q <= 27'd0;
        pps_1hz_pulse_sys  <= 1'b1;
      end else if (pps_fallback_cnt_q == 27'd99_999_999) begin
        pps_fallback_cnt_q <= 27'd0;
        pps_1hz_pulse_sys  <= 1'b1;
      end else begin
        pps_fallback_cnt_q <= pps_fallback_cnt_q + 27'd1;
        pps_1hz_pulse_sys  <= 1'b0;
      end
    end
  end

  //---------------------------------------------------------------------------
  // 1. CSR & Runtime Configuration Buses (clk_sys)
  //---------------------------------------------------------------------------
  logic [9:0]   csr_scid_10b;
  logic [15:0]  csr_scid_16b;
  logic [2:0]   csr_proto_mode;
  logic [3:0]   csr_fec_mode;
  logic         csr_ocf_en;
  logic         csr_fecf_en;
  logic         csr_fecf_crc32;
  logic         csr_aos_fhec_en;
  logic         csr_tc_seg_hdr_en;
  logic         csr_obt_sec_hdr_en;
  logic         csr_sdls_en;
  logic         csr_bc_req_sdls;
  logic         csr_srrc_4sps_en;
  logic         csr_gardner_ted_en;
  logic         csr_fll_assist_en;
  logic         csr_sdls_gcm_mode;
  logic         csr_tm_rand_en;
  logic [1:0]   csr_turnaround_kaband;
  logic [7:0]   csr_win_half_w;
  logic [3:0]   csr_rs_interleave;
  logic [7:0]   csr_rs_q_fill;
  logic [10:0]  csr_tfdf_len;
  logic [15:0]  csr_tx_default_spi;
  logic [255:0] csr_master_key;
  logic         csr_sa_wr_en;
  logic [5:0]   csr_sa_wr_addr;
  logic [15:0]  csr_sa_wr_spi;
  logic [31:0]  csr_sa_wr_seq_low;
  logic [47:0]  csr_obt_cuc_ts;
  logic         csr_tmr_seu_pulse;

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
  logic        rx_phy_fifo_secded_single;
  logic        rx_phy_fifo_secded_double;
  logic        tx_fifo_secded_single;
  logic        tx_fifo_secded_double;
  logic        tx_phy_fifo_secded_single;
  logic        tx_phy_fifo_secded_double;
  logic        rx_phy_fifo_ovf_pulse;
  logic        tx_phy_fifo_ovf_pulse;
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
  ccsds_plcw_t plcw_scheduled_sys_q;
  logic        plcw_valid_pulse_tc;

  // Runtime SDLS Provisioning CDC (clk_sys -> clk_tc_safe)
  logic         sa_wr_tog_sys_q;
  logic [5:0]   sa_wr_addr_hold_sys_q;
  logic [15:0]  sa_wr_spi_hold_sys_q;
  logic [31:0]  sa_wr_seq_hold_sys_q;

  always_ff @(posedge clk_sys or negedge rst_sys_n) begin
    if (!rst_sys_n) begin
      sa_wr_tog_sys_q       <= 1'b0;
      sa_wr_addr_hold_sys_q <= 6'd1;
      sa_wr_spi_hold_sys_q  <= 16'h0001;
      sa_wr_seq_hold_sys_q  <= 32'd0;
    end else if (csr_sa_wr_en) begin
      sa_wr_tog_sys_q       <= ~sa_wr_tog_sys_q;
      sa_wr_addr_hold_sys_q <= csr_sa_wr_addr;
      sa_wr_spi_hold_sys_q  <= csr_sa_wr_spi;
      sa_wr_seq_hold_sys_q  <= csr_sa_wr_seq_low;
    end
  end

  // 2-FF CDC Synchronizers for CSR control signals into clk_tc_safe
  (* ASYNC_REG = "TRUE" *) logic         sdls_en_tc_meta_q,    sdls_en_tc_sync_q;
  (* ASYNC_REG = "TRUE" *) logic         sdls_gcm_tc_meta_q,   sdls_gcm_tc_sync_q;
  (* ASYNC_REG = "TRUE" *) logic         bc_req_tc_meta_q,     bc_req_tc_sync_q;
  (* ASYNC_REG = "TRUE" *) logic         fecf_crc32_tc_meta_q, fecf_crc32_tc_sync_q;
  (* ASYNC_REG = "TRUE" *) logic         tc_seg_tc_meta_q,     tc_seg_tc_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [9:0]   scid_10b_tc_meta_q,   scid_10b_tc_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [15:0]  scid_16b_tc_meta_q,   scid_16b_tc_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [7:0]   win_half_w_tc_meta_q, win_half_w_tc_sync_q;
  (* ASYNC_REG = "TRUE" *) logic         tc_sa_wr_tog_meta_q,  tc_sa_wr_tog_sync_q;
  logic                                  tc_sa_wr_tog_prev_q;
  logic                                  tc_sa_wr_en_pulse;
  (* ASYNC_REG = "TRUE" *) logic [5:0]   tc_sa_wr_addr_meta_q, tc_sa_wr_addr_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [15:0]  tc_sa_wr_spi_meta_q,  tc_sa_wr_spi_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [31:0]  tc_sa_wr_seq_meta_q,  tc_sa_wr_seq_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [15:0]  tc_tx_spi_meta_q,     tc_tx_spi_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [255:0] tc_mkey_meta_q,       tc_mkey_sync_q;

  always_ff @(posedge clk_tc_safe or negedge rst_tc_n) begin
    if (!rst_tc_n) begin
      sdls_en_tc_meta_q    <= 1'b0;
      sdls_en_tc_sync_q    <= 1'b0;
      sdls_gcm_tc_meta_q   <= 1'b0;
      sdls_gcm_tc_sync_q   <= 1'b0;
      bc_req_tc_meta_q     <= 1'b0;
      bc_req_tc_sync_q     <= 1'b0;
      fecf_crc32_tc_meta_q <= 1'b0;
      fecf_crc32_tc_sync_q <= 1'b0;
      tc_seg_tc_meta_q     <= 1'b1;
      tc_seg_tc_sync_q     <= 1'b1;
      scid_10b_tc_meta_q   <= 10'h1AB;
      scid_10b_tc_sync_q   <= 10'h1AB;
      scid_16b_tc_meta_q   <= 16'h1AB0;
      scid_16b_tc_sync_q   <= 16'h1AB0;
      win_half_w_tc_meta_q <= 8'd16;
      win_half_w_tc_sync_q <= 8'd16;
      tc_sa_wr_tog_meta_q  <= 1'b0;
      tc_sa_wr_tog_sync_q  <= 1'b0;
      tc_sa_wr_tog_prev_q  <= 1'b0;
      tc_sa_wr_addr_meta_q <= 6'd1;
      tc_sa_wr_addr_sync_q <= 6'd1;
      tc_sa_wr_spi_meta_q  <= 16'h0001;
      tc_sa_wr_spi_sync_q  <= 16'h0001;
      tc_sa_wr_seq_meta_q  <= 32'd0;
      tc_sa_wr_seq_sync_q  <= 32'd0;
      tc_tx_spi_meta_q     <= 16'h0001;
      tc_tx_spi_sync_q     <= 16'h0001;
      tc_mkey_meta_q       <= 256'h00010203_04050607_08090A0B_0C0D0E0F_10111213_14151617_18191A1B_1C1D1E1F;
      tc_mkey_sync_q       <= 256'h00010203_04050607_08090A0B_0C0D0E0F_10111213_14151617_18191A1B_1C1D1E1F;
    end else begin
      sdls_en_tc_meta_q    <= active_sdls_en;
      sdls_en_tc_sync_q    <= sdls_en_tc_meta_q;
      sdls_gcm_tc_meta_q   <= csr_sdls_gcm_mode;
      sdls_gcm_tc_sync_q   <= sdls_gcm_tc_meta_q;
      bc_req_tc_meta_q     <= active_bc_req_sdls;
      bc_req_tc_sync_q     <= bc_req_tc_meta_q;
      fecf_crc32_tc_meta_q <= csr_fecf_crc32;
      fecf_crc32_tc_sync_q <= fecf_crc32_tc_meta_q;
      tc_seg_tc_meta_q     <= csr_tc_seg_hdr_en;
      tc_seg_tc_sync_q     <= tc_seg_tc_meta_q;
      scid_10b_tc_meta_q   <= csr_scid_10b;
      scid_10b_tc_sync_q   <= scid_10b_tc_meta_q;
      scid_16b_tc_meta_q   <= csr_scid_16b;
      scid_16b_tc_sync_q   <= scid_16b_tc_meta_q;
      win_half_w_tc_meta_q <= csr_win_half_w;
      win_half_w_tc_sync_q <= win_half_w_tc_meta_q;
      tc_sa_wr_tog_meta_q  <= sa_wr_tog_sys_q;
      tc_sa_wr_tog_sync_q  <= tc_sa_wr_tog_meta_q;
      tc_sa_wr_tog_prev_q  <= tc_sa_wr_tog_sync_q;
      tc_sa_wr_addr_meta_q <= sa_wr_addr_hold_sys_q;
      tc_sa_wr_addr_sync_q <= tc_sa_wr_addr_meta_q;
      tc_sa_wr_spi_meta_q  <= sa_wr_spi_hold_sys_q;
      tc_sa_wr_spi_sync_q  <= tc_sa_wr_spi_meta_q;
      tc_sa_wr_seq_meta_q  <= sa_wr_seq_hold_sys_q;
      tc_sa_wr_seq_sync_q  <= tc_sa_wr_seq_meta_q;
      tc_tx_spi_meta_q     <= csr_tx_default_spi;
      tc_tx_spi_sync_q     <= tc_tx_spi_meta_q;
      tc_mkey_meta_q       <= csr_master_key;
      tc_mkey_sync_q       <= tc_mkey_meta_q;
    end
  end
  assign tc_sa_wr_en_pulse = tc_sa_wr_tog_sync_q ^ tc_sa_wr_tog_prev_q;

  // Toggle-to-Pulse 2-FF ASYNC_REG Event Synchronizers into clk_sys for CSR counters
  logic [6:0] evt_tc_pulse_vec;
  logic [6:0] evt_tc_tog_q;
  logic [1:0] evt_tx_pulse_vec;
  logic [1:0] evt_tx_tog_q;
  logic [1:0] evt_adc_pulse_vec;
  logic [1:0] evt_adc_tog_q;

  assign evt_tc_pulse_vec = {
    sdls_auth_done_pulse & ~sdls_auth_ok,
    ul_fecf_crc_err_pulse,
    farm_tmr_seu_pulse | hcpd_tmr_seu_pulse,
    sa_secded_double_pulse | rx_phy_fifo_secded_double,
    sa_secded_single_pulse | rx_phy_fifo_secded_single,
    bch_double_err_pulse,
    bch_single_err_pulse
  };
  assign evt_tx_pulse_vec  = {tx_fifo_secded_double | tx_phy_fifo_ovf_pulse, tx_fifo_secded_single};
  assign evt_adc_pulse_vec = {tx_phy_fifo_secded_double | rx_phy_fifo_ovf_pulse, tx_phy_fifo_secded_single};

  always_ff @(posedge clk_tc_safe or negedge rst_tc_n) begin
    if (!rst_tc_n) begin
      evt_tc_tog_q <= 7'd0;
    end else begin
      evt_tc_tog_q <= evt_tc_tog_q ^ evt_tc_pulse_vec;
    end
  end

  always_ff @(posedge clk_tx_sym or negedge rst_tx_n) begin
    if (!rst_tx_n) begin
      evt_tx_tog_q <= 2'd0;
    end else begin
      evt_tx_tog_q <= evt_tx_tog_q ^ evt_tx_pulse_vec;
    end
  end

  always_ff @(posedge clk_adc_iq or negedge rst_adc_n) begin
    if (!rst_adc_n) begin
      evt_adc_tog_q <= 2'd0;
    end else begin
      evt_adc_tog_q <= evt_adc_tog_q ^ evt_adc_pulse_vec;
    end
  end

  (* ASYNC_REG = "TRUE" *) logic [10:0] evt_sys_meta_q, evt_sys_sync_q;
  logic [10:0] evt_sys_prev_q;
  logic [10:0] evt_sys_pulse;

  always_ff @(posedge clk_sys or negedge rst_sys_n) begin
    if (!rst_sys_n) begin
      evt_sys_meta_q <= 11'd0;
      evt_sys_sync_q <= 11'd0;
      evt_sys_prev_q <= 11'd0;
    end else begin
      evt_sys_meta_q <= {evt_adc_tog_q, evt_tx_tog_q, evt_tc_tog_q};
      evt_sys_sync_q <= evt_sys_meta_q;
      evt_sys_prev_q <= evt_sys_sync_q;
    end
  end

  assign evt_sys_pulse = evt_sys_sync_q ^ evt_sys_prev_q;

  ccsds_axi_lite_csr u_csr (
    .clk                         (clk_sys),
    .rst_n                       (rst_sys_n),
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
    .pps_1hz_pulse               (pps_1hz_pulse_sys),
    .csr_seu_inject_en           (1'b0),
    .csr_seu_xor_mask            (32'd0),
    .bch_single_err_pulse        (evt_sys_pulse[0]),
    .bch_double_abort_pulse      (evt_sys_pulse[1]),
    .fifo_secded_single_pulse    (evt_sys_pulse[2] | rx_fifo_secded_single | evt_sys_pulse[7] | evt_sys_pulse[9]),
    .fifo_secded_double_pulse    (evt_sys_pulse[3] | rx_fifo_secded_double | evt_sys_pulse[8] | evt_sys_pulse[10]),
    .farm1_tmr_seu_pulse         (evt_sys_pulse[4]),
    .frame_crc_err_pulse         (evt_sys_pulse[5]),
    .pkt_len_err_pulse           (vc_pkt_len_err | reasm_pkt_len_err),
    .sdls_mac_err_pulse          (evt_sys_pulse[6]),
    .latest_clcw_in              (clcw_scheduled_sys_q),
    .latest_plcw_in              (plcw_scheduled_sys_q),
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
    .srrc_4sps_en_cfg            (csr_srrc_4sps_en),
    .gardner_ted_en_cfg          (csr_gardner_ted_en),
    .fll_assist_en_cfg           (csr_fll_assist_en),
    .sdls_gcm_mode_cfg           (csr_sdls_gcm_mode),
    .tm_rand_en_cfg              (csr_tm_rand_en),
    .turnaround_kaband_cfg       (csr_turnaround_kaband),
    .window_half_w_cfg           (csr_win_half_w),
    .rs_interleave_i_cfg         (csr_rs_interleave),
    .rs_virt_fill_q_cfg          (csr_rs_q_fill),
    .tfdf_byte_len_cfg           (csr_tfdf_len),
    .tx_default_spi_cfg          (csr_tx_default_spi),
    .master_key_cfg              (csr_master_key),
    .sa_wr_en                    (csr_sa_wr_en),
    .sa_wr_addr                  (csr_sa_wr_addr),
    .sa_wr_spi                   (csr_sa_wr_spi),
    .sa_wr_seq_low               (csr_sa_wr_seq_low),
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
  logic [1:0]         gardner_phase_unused;
  (* ASYNC_REG = "TRUE" *) logic       srrc_en_meta_q,    srrc_en_sync_q;
  (* ASYNC_REG = "TRUE" *) logic       gardner_en_meta_q, gardner_en_sync_q;
  (* ASYNC_REG = "TRUE" *) logic       fll_en_meta_q,     fll_en_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] kaband_meta_q,     kaband_sync_q;

  always_ff @(posedge clk_adc_iq or negedge rst_adc_n) begin
    if (!rst_adc_n) begin
      srrc_en_meta_q    <= 1'b0;
      srrc_en_sync_q    <= 1'b0;
      gardner_en_meta_q <= 1'b0;
      gardner_en_sync_q <= 1'b0;
      fll_en_meta_q     <= 1'b0;
      fll_en_sync_q     <= 1'b0;
      kaband_meta_q     <= 2'd0;
      kaband_sync_q     <= 2'd0;
    end else begin
      srrc_en_meta_q    <= csr_srrc_4sps_en;
      srrc_en_sync_q    <= srrc_en_meta_q;
      gardner_en_meta_q <= csr_gardner_ted_en;
      gardner_en_sync_q <= gardner_en_meta_q;
      fll_en_meta_q     <= csr_fll_assist_en;
      fll_en_sync_q     <= fll_en_meta_q;
      kaband_meta_q     <= csr_turnaround_kaband;
      kaband_sync_q     <= kaband_meta_q;
    end
  end

  ccsds_phy_modem u_phy_modem (
    .clk                      (clk_adc_iq),
    .rst_n                    (rst_adc_n),
    .mod_mode_cfg             (mod_mode_cfg),
    .line_code_cfg            (line_code_cfg),
    .turnaround_xband_cfg     (turnaround_xband_cfg),
    .turnaround_kaband_cfg    (kaband_sync_q),
    .pn_ranging_en_cfg        (pn_ranging_en_cfg),
    .srrc_4sps_en_cfg         (srrc_en_sync_q),
    .gardner_ted_en_cfg       (gardner_en_sync_q),
    .fll_assist_en_cfg        (fll_en_sync_q),
    .tx_pn_chip_in            (tx_pn_chip),
    .rx_i_in                  (phy_rx_i_12b),
    .rx_q_in                  (phy_rx_q_12b),
    .rx_iq_valid_in           (rx_iq_valid_in),
    .rx_sym_valid_out         (phy_rx_sym_valid),
    .rx_sym_byte_out          (phy_rx_sym_byte),
    .wideband_pn_sample_out   (wideband_pn_sample),
    .carrier_lock_out         (phy_carrier_lock),
    .symbol_lock_out          (phy_symbol_lock),
    .gardner_strobe_phase_out (gardner_phase_unused),
    .tx_nco_fcw_out           (tx_nco_fcw_unused),
    .s_axis_tx_tvalid         (tx_phy_tvalid),
    .s_axis_tx_tready         (tx_phy_tready),
    .s_axis_tx_tdata          (tx_phy_tdata),
    .tx_i_out                 (phy_tx_i_12b),
    .tx_q_out                 (phy_tx_q_12b),
    .tx_iq_valid_out          (tx_iq_valid_out)
  );

  ccsds_pn_ranging u_pn_ranging (
    .clk                     (clk_adc_iq),
    .rst_n                   (rst_adc_n),
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
  (* ASYNC_REG = "TRUE" *) logic carrier_lock_meta_q, carrier_lock_sync_q;
  (* ASYNC_REG = "TRUE" *) logic symbol_lock_meta_q,  symbol_lock_sync_q;

  always_ff @(posedge clk_tc_safe or negedge rst_tc_n) begin
    if (!rst_tc_n) begin
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
  // 2B. Uplink Rx Asynchronous CDC FIFO (`u_rx_phy_cdc_fifo`) & MSB-First
  //     Bit-to-LLR Serializer (`clk_adc_iq` -> `clk_tc_safe`)
  //---------------------------------------------------------------------------
  logic [7:0]        rx_phy_fifo_tdata;
  logic [0:0]        rx_phy_fifo_tkeep_unused;
  logic              rx_phy_fifo_tvalid;
  logic              rx_phy_fifo_tready;
  logic              rx_phy_fifo_tlast_unused;
  ccsds_tuser_t      rx_phy_fifo_tuser_unused;
  logic              rx_phy_fifo_wr_ready_unused;
  logic [8:0]        rx_phy_fifo_comm_cnt_unused;
  logic [8:0]        rx_phy_fifo_spec_cnt_unused;

  logic              rx_phy_ser_busy_q;
  logic [7:0]        rx_phy_ser_byte_q;
  logic [2:0]        rx_phy_ser_bit_idx_q;
  logic              phy_tc_sym_valid;
  logic signed [3:0] phy_tc_sym_llr;

  ccsds_cdc_fifo_ecc #(
    .DATA_WIDTH    (8),
    .DEPTH_WORDS   (256),
    .ROLLBACK_MODE (1'b0),
    .WATERMARK_MODE(1'b0)
  ) u_rx_phy_cdc_fifo (
    .clk_wr                   (clk_adc_iq),
    .rst_wr_n                 (rst_adc_n),
    .clk_rd                   (clk_tc_safe),
    .rst_rd_n                 (rst_tc_n),
    .cut_through_en           (1'b1),
    .watermark_words          (9'd0),
    .frame_commit_pulse       (1'b0),
    .frame_rollback_pulse     (1'b0),
    .seu_inject_en            (1'b0),
    .seu_inject_addr          (8'd0),
    .seu_inject_bit           (6'd0),
    .s_axis_tdata             (phy_rx_sym_byte),
    .s_axis_tkeep             (1'b1),
    .s_axis_tvalid            (phy_rx_sym_valid && !pn_ranging_en_cfg),
    .s_axis_tready            (rx_phy_fifo_wr_ready_unused),
    .s_axis_tlast             (1'b0),
    .s_axis_tuser             ('0),
    .m_axis_tdata             (rx_phy_fifo_tdata),
    .m_axis_tkeep             (rx_phy_fifo_tkeep_unused),
    .m_axis_tvalid            (rx_phy_fifo_tvalid),
    .m_axis_tready            (rx_phy_fifo_tready),
    .m_axis_tlast             (rx_phy_fifo_tlast_unused),
    .m_axis_tuser             (rx_phy_fifo_tuser_unused),
    .committed_count          (rx_phy_fifo_comm_cnt_unused),
    .speculative_count        (rx_phy_fifo_spec_cnt_unused),
    .ecc_single_err_corrected (rx_phy_fifo_secded_single),
    .ecc_double_err_uncorr    (rx_phy_fifo_secded_double),
    .rollback_overflow_err    (rx_phy_fifo_ovf_pulse)
  );

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
  logic              ul_ldpc_mode_en;
  logic [6:0]        ldpc_ser_bit_cnt_q;
  logic [62:0]       ldpc_ser_hdr63_q;
  logic              ldpc_ser_wait_q;
  logic [3:0]        ldpc_ser_emit_cnt_q;
  logic [7:0]        ldpc_dec_tdata;
  logic              ldpc_dec_tvalid;
  logic              ldpc_dec_tready;
  logic              ldpc_dec_tlast;
  logic              ldpc_dec_tabort;

  assign ul_ldpc_mode_en    = (ul_fec_override_en == 2'd2) || (ul_fec_override_en == 2'd3);
  assign rx_phy_fifo_tready = (!rx_phy_ser_busy_q || (rx_phy_ser_bit_idx_q == 3'd0)) &&
                              !s_axis_ul_sym_tvalid && !ldpc_ser_wait_q;

  always_ff @(posedge clk_tc_safe or negedge rst_tc_n) begin
    if (!rst_tc_n) begin
      rx_phy_ser_busy_q    <= 1'b0;
      rx_phy_ser_byte_q    <= 8'd0;
      rx_phy_ser_bit_idx_q <= 3'd7;
      ldpc_ser_bit_cnt_q   <= 7'd0;
      ldpc_ser_hdr63_q     <= 63'd0;
      ldpc_ser_wait_q      <= 1'b0;
      ldpc_ser_emit_cnt_q  <= 4'd0;
    end else begin
      if (!ul_ldpc_mode_en || !asm_sync_locked || ldpc_tail_pulse || ldpc_abort_pulse) begin
        ldpc_ser_bit_cnt_q  <= 7'd0;
        ldpc_ser_hdr63_q    <= 63'd0;
        ldpc_ser_wait_q     <= 1'b0;
        ldpc_ser_emit_cnt_q <= 4'd0;
      end else if (ldpc_ser_wait_q) begin
        if (ldpc_ser_emit_cnt_q == 4'd8) begin
          if (!ldpc_dec_tvalid || ldpc_dec_tready) begin
            ldpc_ser_wait_q     <= 1'b0;
            ldpc_ser_emit_cnt_q <= 4'd0;
          end
        end else if (ldpc_dec_tvalid && ldpc_dec_tready) begin
          ldpc_ser_emit_cnt_q <= ldpc_ser_emit_cnt_q + 4'd1;
        end
      end else if (asm_cb_valid) begin
        if (ldpc_ser_bit_cnt_q < 7'd63) begin
          ldpc_ser_hdr63_q <= {ldpc_ser_hdr63_q[61:0], asm_cb_hard_bit};
        end
        if ((ldpc_ser_bit_cnt_q == 7'd63) && ({ldpc_ser_hdr63_q, asm_cb_hard_bit} == CLTU_TAIL_SEQ_LDPC_55)) begin
          ldpc_ser_bit_cnt_q <= 7'd0;
        end else if (ldpc_ser_bit_cnt_q == 7'd127) begin
          ldpc_ser_bit_cnt_q  <= 7'd0;
          ldpc_ser_wait_q     <= 1'b1;
          ldpc_ser_emit_cnt_q <= 4'd0;
        end else begin
          ldpc_ser_bit_cnt_q <= ldpc_ser_bit_cnt_q + 7'd1;
        end
      end

      if (s_axis_ul_sym_tvalid) begin
        rx_phy_ser_busy_q    <= 1'b0;
        rx_phy_ser_bit_idx_q <= 3'd7;
      end else if (!ldpc_ser_wait_q) begin
        if (!rx_phy_ser_busy_q) begin
          if (rx_phy_fifo_tvalid) begin
            rx_phy_ser_busy_q    <= 1'b1;
            rx_phy_ser_byte_q    <= rx_phy_fifo_tdata;
            rx_phy_ser_bit_idx_q <= 3'd7;
          end
        end else begin
          if (rx_phy_ser_bit_idx_q == 3'd0) begin
            if (rx_phy_fifo_tvalid) begin
              rx_phy_ser_busy_q    <= 1'b1;
              rx_phy_ser_byte_q    <= rx_phy_fifo_tdata;
              rx_phy_ser_bit_idx_q <= 3'd7;
            end else begin
              rx_phy_ser_busy_q    <= 1'b0;
              rx_phy_ser_bit_idx_q <= 3'd7;
            end
          end else begin
            rx_phy_ser_bit_idx_q <= rx_phy_ser_bit_idx_q - 3'd1;
          end
        end
      end
    end
  end

  assign phy_tc_sym_valid = rx_phy_ser_busy_q && !s_axis_ul_sym_tvalid && !ldpc_ser_wait_q;
  assign phy_tc_sym_llr   = rx_phy_ser_byte_q[rx_phy_ser_bit_idx_q] ? -4'sd7 : 4'sd7;

  //---------------------------------------------------------------------------
  // 3. Uplink ASM Correlator, BCH(63,56), Short-LDPC & TC Scrambler (clk_tc_safe)
  //---------------------------------------------------------------------------

  ccsds_asm_correlator u_asm_corr (
    .clk                 (clk_tc_safe),
    .rst_n               (rst_tc_n),
    .sync_mode           (ul_ldpc_mode_en ? 2'd1 : 2'd0),
    .hamming_thresh      (3'd2),
    .tail_or_abort_pulse (ul_ldpc_mode_en ? (ldpc_tail_pulse | ldpc_abort_pulse) : bch_cltu_ended_pulse),
    .sym_llr_in          (s_axis_ul_sym_tvalid ? s_axis_ul_sym_tdata[3:0] : phy_tc_sym_llr),
    .sym_valid_in        (s_axis_ul_sym_tvalid ? 1'b1 : phy_tc_sym_valid),
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
    .rst_n                  (rst_tc_n),
    .tc_derand_en           (1'b1),
    .cb_hard_bit_in         (asm_cb_hard_bit),
    .cb_start_pulse         (asm_cb_start_pulse && !ul_ldpc_mode_en),
    .cb_valid_in            (asm_cb_valid && !ul_ldpc_mode_en),
    .cltu_ended_pulse       (bch_cltu_ended_pulse),
    .bch_single_err_pulse   (bch_single_err_pulse),
    .bch_double_abort_pulse (bch_double_err_pulse),
    .m_axis_tdata           (bch_dec_tdata),
    .m_axis_tvalid          (bch_dec_tvalid),
    .m_axis_tready          (bch_dec_tready),
    .m_axis_tlast           (bch_dec_tlast),
    .m_axis_tabort          (bch_dec_tabort)
  );

  generate
    if (ENABLE_UL_LDPC) begin : g_ul_short_ldpc
      ccsds_ul_short_ldpc_dec u_short_ldpc_dec (
        .clk                      (clk_tc_safe),
        .rst_n                    (rst_tc_n),
        .ldpc_mode_512_en         (ul_fec_override_en == 2'd2),
        .tc_derand_en             (1'b1),
        .cb_llr_in                (asm_cb_llr),
        .cb_hard_bit_in           (asm_cb_hard_bit),
        .cb_start_pulse           (asm_cb_start_pulse && ul_ldpc_mode_en),
        .cb_valid_in              (asm_cb_valid && ul_ldpc_mode_en),
        .ldpc_tail_detected_pulse (ldpc_tail_pulse),
        .ldpc_converged_pulse     (ldpc_converged_pulse),
        .ldpc_uncorr_abort_pulse  (ldpc_abort_pulse),
        .m_axis_tdata             (ldpc_dec_tdata),
        .m_axis_tvalid            (ldpc_dec_tvalid),
        .m_axis_tready            (ldpc_dec_tready),
        .m_axis_tlast             (ldpc_dec_tlast),
        .m_axis_tabort            (ldpc_dec_tabort)
      );
    end else begin : g_no_ul_short_ldpc
      assign ldpc_tail_pulse      = 1'b0;
      assign ldpc_converged_pulse = 1'b0;
      assign ldpc_abort_pulse     = 1'b0;
      assign ldpc_dec_tdata       = 8'd0;
      assign ldpc_dec_tvalid      = 1'b0;
      assign ldpc_dec_tlast       = 1'b0;
      assign ldpc_dec_tabort      = 1'b0;
    end
  endgenerate

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
    .rst_n            (rst_tc_n),
    .bypass_en        (1'b1),
    .mode_tc_not_tm   (1'b1),
    .lfsr_reseed_sync (asm_cb_start_pulse),
    .s_axis_tdata     ((ul_fec_override_en == 2'd2 || ul_fec_override_en == 2'd3) ? ldpc_dec_tdata  :
                       (s_axis_ul_sym_tvalid && (ul_fec_override_en == 2'd0))     ? s_axis_ul_sym_tdata  : bch_dec_tdata),
    .s_axis_tkeep     (1'b1),
    .s_axis_tvalid    ((ul_fec_override_en == 2'd2 || ul_fec_override_en == 2'd3) ? ldpc_dec_tvalid :
                       (s_axis_ul_sym_tvalid && (ul_fec_override_en == 2'd0))     ? s_axis_ul_sym_tvalid : bch_dec_tvalid),
    .s_axis_tready    (s_axis_ul_sym_tready),
    .s_axis_tlast     ((ul_fec_override_en == 2'd2 || ul_fec_override_en == 2'd3) ? ldpc_dec_tlast  :
                       (s_axis_ul_sym_tvalid && (ul_fec_override_en == 2'd0))     ? s_axis_ul_sym_tlast  : bch_dec_tlast),
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
  // 4. Uplink Deframer, Proximity-1 PLCW, COP-1 FARM-1, SDLS & HCPD (clk_tc_safe)
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
    .rst_n                    (rst_tc_n),
    .spacecraft_id_cfg        (scid_10b_tc_sync_q),
    .uslp_scid_cfg            (scid_16b_tc_sync_q),
    .uslp_trunc_frame_len_cfg (16'd16),
    .uslp_tfdf_3byte_en_cfg   (1'b0),
    .fecf_crc32_cfg           (fecf_crc32_tc_sync_q),
    .tc_seg_hdr_present_cfg   (tc_seg_tc_sync_q),
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

  always_ff @(posedge clk_tc_safe or negedge rst_tc_n) begin
    if (!rst_tc_n) begin
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
    .rst_n             (rst_tc_n),
    .no_rf_avail       (~carrier_lock_sync_q),
    .no_bit_lock       (~symbol_lock_sync_q),
    .wait_flag_in      (1'b0),
    .window_half_w     (win_half_w_tc_sync_q),
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
  logic        dl_framer_tfdf_tready;
  logic [7:0]  egse_ul_sdls_in_tdata;
  logic        egse_ul_sdls_in_tvalid;
  logic        egse_ul_sdls_in_tlast;
  logic        egse_ul_sdls_out_tready;
  logic [7:0]  egse_dl_sdls_in_tdata;
  logic        egse_dl_sdls_in_tvalid;
  logic        egse_dl_sdls_in_tready;
  logic        egse_dl_sdls_in_tlast;
  logic        sdls_rx_in_tready;
  logic        rx_reasm_tready;

  assign ul_deframed_tready     = (ROLE_MODE == 1) ? 1'b1 : sdls_rx_in_tready;
  assign egse_dl_sdls_in_tready = (ROLE_MODE == 1) ? sdls_rx_in_tready : 1'b1;
  assign sdls_tx_tready         = (ROLE_MODE == 1) ? egse_ul_sdls_out_tready : dl_framer_tfdf_tready;

  generate
    if (ENABLE_SDLS) begin : g_sdls_engine
      ccsds_sdls_engine u_sdls (
        .clk                        ((ROLE_MODE == 1) ? clk_sys : clk_tc_safe),
        .rst_n                      ((ROLE_MODE == 1) ? rst_sys_n : rst_tc_n),
        .clk_tx                     (clk_sys),
        .rst_tx_n                   (rst_sys_n),
        .sdls_en_cfg                ((ROLE_MODE == 1) ? active_sdls_en : sdls_en_tc_sync_q),
        .sdls_gcm_mode_cfg          ((ROLE_MODE == 1) ? csr_sdls_gcm_mode : sdls_gcm_tc_sync_q),
        .bc_require_sdls_cfg        ((ROLE_MODE == 1) ? active_bc_req_sdls : bc_req_tc_sync_q),
        .tx_default_spi_cfg         ((ROLE_MODE == 1) ? csr_tx_default_spi : tc_tx_spi_sync_q),
        .master_key_cfg             ((ROLE_MODE == 1) ? csr_master_key : tc_mkey_sync_q),
        .sa_wr_en                   ((ROLE_MODE == 1) ? csr_sa_wr_en : tc_sa_wr_en_pulse),
        .sa_wr_addr                 ((ROLE_MODE == 1) ? csr_sa_wr_addr : tc_sa_wr_addr_sync_q),
        .sa_wr_spi                  ((ROLE_MODE == 1) ? csr_sa_wr_spi : tc_sa_wr_spi_sync_q),
        .sa_wr_seq_low              ((ROLE_MODE == 1) ? csr_sa_wr_seq_low : tc_sa_wr_seq_sync_q),
        .s_axis_rx_tvalid           ((ROLE_MODE == 1) ? egse_dl_sdls_in_tvalid : ul_deframed_tvalid),
        .s_axis_rx_tready           (sdls_rx_in_tready),
        .s_axis_rx_tdata            ((ROLE_MODE == 1) ? egse_dl_sdls_in_tdata : ul_deframed_tdata),
        .s_axis_rx_tlast            ((ROLE_MODE == 1) ? egse_dl_sdls_in_tlast : ul_deframed_tlast),
        .rx_frame_is_type_bc        ((ROLE_MODE == 1) ? 1'b0 : (parsed_tc_hdr.bypass_flag & parsed_tc_hdr.ctrl_cmd_flag)),
        .m_axis_rx_tvalid           (sdls_rx_tvalid),
        .m_axis_rx_tready           ((ROLE_MODE == 1) ? rx_reasm_tready : sdls_rx_tready),
        .m_axis_rx_tdata            (sdls_rx_tdata),
        .m_axis_rx_tlast            (sdls_rx_tlast),
        .sdls_auth_done_pulse       (sdls_auth_done_pulse),
        .sdls_auth_ok               (sdls_auth_ok),
        .rx_active_spi_out          (rx_active_spi_unused),
        .sa_secded_single_err_pulse (sa_secded_single_pulse),
        .sa_secded_double_err_pulse (sa_secded_double_pulse),
        .s_axis_tx_tvalid           ((ROLE_MODE == 1) ? egse_ul_sdls_in_tvalid : vc_tfdf_tvalid),
        .s_axis_tx_tready           (vc_tfdf_tready),
        .s_axis_tx_tdata            ((ROLE_MODE == 1) ? egse_ul_sdls_in_tdata : vc_tfdf_tdata),
        .s_axis_tx_tlast            ((ROLE_MODE == 1) ? egse_ul_sdls_in_tlast : vc_tfdf_tlast),
        .m_axis_tx_tvalid           (sdls_tx_tvalid),
        .m_axis_tx_tready           (sdls_tx_tready),
        .m_axis_tx_tdata            (sdls_tx_tdata),
        .m_axis_tx_tlast            (sdls_tx_tlast)
      );
    end else begin : g_no_sdls_engine
      assign sdls_rx_tvalid         = (ROLE_MODE == 1) ? egse_dl_sdls_in_tvalid : ul_deframed_tvalid;
      assign sdls_rx_in_tready      = (ROLE_MODE == 1) ? rx_reasm_tready : sdls_rx_tready;
      assign sdls_rx_tdata          = (ROLE_MODE == 1) ? egse_dl_sdls_in_tdata : ul_deframed_tdata;
      assign sdls_rx_tlast          = (ROLE_MODE == 1) ? egse_dl_sdls_in_tlast : ul_deframed_tlast;
      assign sdls_auth_done_pulse   = ul_frame_done_pulse;
      assign sdls_auth_ok           = 1'b1;
      assign rx_active_spi_unused   = 16'd0;
      assign sa_secded_single_pulse = 1'b0;
      assign sa_secded_double_pulse = 1'b0;
      assign sdls_tx_tvalid         = (ROLE_MODE == 1) ? egse_ul_sdls_in_tvalid : vc_tfdf_tvalid;
      assign vc_tfdf_tready         = sdls_tx_tready;
      assign sdls_tx_tdata          = (ROLE_MODE == 1) ? egse_ul_sdls_in_tdata : vc_tfdf_tdata;
      assign sdls_tx_tlast          = (ROLE_MODE == 1) ? egse_ul_sdls_in_tlast : vc_tfdf_tlast;
    end
  endgenerate

  logic farm_accept_pulse;
  logic farm_reject_pulse;

  ccsds_farm1_tmr u_farm1 (
    .clk                     (clk_tc_safe),
    .rst_n                   (rst_tc_n),
    .sdls_en                 (sdls_en_tc_sync_q),
    .bc_require_sdls         (bc_req_tc_sync_q),
    .window_half_w           (win_half_w_tc_sync_q),
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

  // Toggle CDC Synchronizer for CLCW & PLCW from clk_tc_safe into clk_sys
  ccsds_clcw_t clcw_hold_tc_q;
  logic        clcw_tog_tc_q;
  (* ASYNC_REG = "TRUE" *) logic clcw_tog_meta_q, clcw_tog_sync_q;
  logic        clcw_tog_prev_q;

  ccsds_plcw_t plcw_hold_tc_q;
  logic        plcw_tog_tc_q;
  (* ASYNC_REG = "TRUE" *) logic plcw_tog_meta_q, plcw_tog_sync_q;
  logic        plcw_tog_prev_q;
  logic        egse_rx_clcw_valid;
  ccsds_clcw_t egse_rx_clcw_word;

  always_ff @(posedge clk_tc_safe or negedge rst_tc_n) begin
    if (!rst_tc_n) begin
      clcw_hold_tc_q <= '0;
      clcw_tog_tc_q  <= 1'b0;
      plcw_hold_tc_q <= '0;
      plcw_tog_tc_q  <= 1'b0;
    end else begin
      if (clcw_valid_pulse_tc) begin
        if (((clcw_scheduled_tc.vcid == parsed_tc_hdr.vcid) || (clcw_hold_tc_q == '0)) &&
            (clcw_scheduled_tc != clcw_hold_tc_q)) begin
          clcw_hold_tc_q <= clcw_scheduled_tc;
          clcw_tog_tc_q  <= ~clcw_tog_tc_q;
        end
      end
      if (plcw_valid_pulse_tc && (plcw_scheduled_tc != plcw_hold_tc_q)) begin
        plcw_hold_tc_q <= plcw_scheduled_tc;
        plcw_tog_tc_q  <= ~plcw_tog_tc_q;
      end
    end
  end

  always_ff @(posedge clk_sys or negedge rst_sys_n) begin
    if (!rst_sys_n) begin
      clcw_tog_meta_q      <= 1'b0;
      clcw_tog_sync_q      <= 1'b0;
      clcw_tog_prev_q      <= 1'b0;
      clcw_scheduled_sys_q <= '0;
      plcw_tog_meta_q      <= 1'b0;
      plcw_tog_sync_q      <= 1'b0;
      plcw_tog_prev_q      <= 1'b0;
      plcw_scheduled_sys_q <= '0;
    end else begin
      clcw_tog_meta_q <= clcw_tog_tc_q;
      clcw_tog_sync_q <= clcw_tog_meta_q;
      clcw_tog_prev_q <= clcw_tog_sync_q;
      if ((ROLE_MODE == 1) && egse_rx_clcw_valid) begin
        clcw_scheduled_sys_q <= egse_rx_clcw_word;
      end else if (clcw_tog_sync_q ^ clcw_tog_prev_q) begin
        clcw_scheduled_sys_q <= clcw_hold_tc_q;
      end
      plcw_tog_meta_q <= plcw_tog_tc_q;
      plcw_tog_sync_q <= plcw_tog_meta_q;
      plcw_tog_prev_q <= plcw_tog_sync_q;
      if (plcw_tog_sync_q ^ plcw_tog_prev_q) begin
        plcw_scheduled_sys_q <= plcw_hold_tc_q;
      end
    end
  end

  logic [7:0] hcpd_pulse_bus;
  logic       hcpd_fired_unused;
  logic       hcpd_rejected_unused;

  ccsds_hcpd_ctrl u_hcpd (
    .clk                          (clk_tc_safe),
    .rst_n                        (rst_tc_n),
    .hcpd_en_cfg                  (1'b1),
    .hcpd_vcid_cfg                (EMERGENCY_VCID),
    .hcpd_magic_word_cfg          (MAGIC_OBC_HARD_RESET[63:32]),
    .sdls_en_cfg                  (sdls_en_tc_sync_q),
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

  // Store-and-Forward Dual-Clock Commit/Rollback FIFO (RX7: clk_tc_safe -> clk_sys)
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
    .clk_wr                   (clk_tc_safe),
    .rst_wr_n                 (rst_tc_n),
    .clk_rd                   (clk_sys),
    .rst_rd_n                 (rst_sys_n),
    .cut_through_en           (1'b0),
    .watermark_words          (10'd0),
    .frame_commit_pulse       (farm_accept_pulse),
    .frame_rollback_pulse     (farm_reject_pulse | ul_frame_rollback_pulse),
    .seu_inject_en            (1'b0),
    .seu_inject_addr          (9'd0),
    .seu_inject_bit           (6'd0),
    .s_axis_tdata             (sdls_rx_tdata),
    .s_axis_tkeep             (1'b1),
    .s_axis_tvalid            ((ROLE_MODE == 1) ? 1'b0 : sdls_rx_tvalid),
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

  // 1-Stage AXI4-Stream Pipeline Slice between u_rx_commit_cdc_fifo SECDED and u_reassembler
  logic [7:0]           rx_pipe_tdata_q;
  logic                 rx_pipe_tvalid_q;
  logic                 rx_pipe_tlast_q;

  assign rx_fifo_tready = !rx_pipe_tvalid_q || rx_reasm_tready;

  always_ff @(posedge clk_sys or negedge rst_sys_n) begin
    if (!rst_sys_n) begin
      rx_pipe_tvalid_q <= 1'b0;
      rx_pipe_tdata_q  <= 8'h00;
      rx_pipe_tlast_q  <= 1'b0;
    end else if (rx_fifo_tready) begin
      rx_pipe_tvalid_q <= rx_fifo_tvalid;
      rx_pipe_tdata_q  <= rx_fifo_tdata;
      rx_pipe_tlast_q  <= rx_fifo_tlast;
    end
  end

  ccsds_space_pkt_hdr_t parsed_pkt_hdr_unused;
  logic                 pkt_completed_unused;
  logic                 idle_pkt_stripped_unused;
  logic [7:0]           egse_dl_tfdf_tdata;
  logic                 egse_dl_tfdf_tvalid;
  logic                 egse_dl_tfdf_tlast;
  logic                 egse_ul_tx_tvalid;
  logic                 egse_ul_tx_tready;
  logic [7:0]           egse_ul_tx_tdata;
  logic                 egse_ul_tx_tlast;
  logic                 egse_pkt_in_tready;
  logic                 vc_arb_pkt_tready;
  logic                 tx_hwm_in_tready;

  ccsds_pkt_reassembler u_reassembler (
    .clk                     (clk_sys),
    .rst_n                   (rst_sys_n),
    .fhp_resync_en           (1'b0),
    .frame_fhp_in            (11'd0),
    .frame_start_pulse       (1'b0),
    .s_axis_tdata            (((ROLE_MODE == 1) && egse_dl_tfdf_tvalid) ? egse_dl_tfdf_tdata  : rx_pipe_tdata_q),
    .s_axis_tvalid           (((ROLE_MODE == 1) && egse_dl_tfdf_tvalid) ? egse_dl_tfdf_tvalid : rx_pipe_tvalid_q),
    .s_axis_tready           (rx_reasm_tready),
    .s_axis_tlast            (((ROLE_MODE == 1) && egse_dl_tfdf_tvalid) ? egse_dl_tfdf_tlast  : rx_pipe_tlast_q),
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
  logic tx_pkt_committed_q;
  always_ff @(posedge clk_sys or negedge rst_sys_n) begin
    if (!rst_sys_n) begin
      tx_pkt_committed_q <= 1'b0;
    end else begin
      tx_pkt_committed_q <= s_axis_tx_pkt_tvalid && s_axis_tx_pkt_tready && s_axis_tx_pkt_tlast;
    end
  end

  assign s_axis_tx_pkt_tready = (ROLE_MODE == 1) ? egse_pkt_in_tready : vc_arb_pkt_tready;

  ccsds_vc_arbiter_mux u_vc_arb (
    .clk                 (clk_sys),
    .rst_n               (rst_sys_n),
    .tfdf_byte_len_cfg   (csr_tfdf_len),
    .request_next_frame  (tx_pkt_committed_q),
    .s_axis_pkt_tdata    (s_axis_tx_pkt_tdata),
    .s_axis_pkt_vcid     (s_axis_tx_pkt_tuser.vcid[2:0]),
    .s_axis_pkt_tvalid   ((ROLE_MODE == 1) ? 1'b0 : s_axis_tx_pkt_tvalid),
    .s_axis_pkt_tready   (vc_arb_pkt_tready),
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
    .rst_n                 (rst_sys_n),
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
    .tfdf_byte_len_cfg     (csr_tfdf_len + (active_sdls_en ? (csr_sdls_gcm_mode ? 11'd22 : 11'd7) : 11'd0)),
    .obt_sec_hdr_en_cfg    (csr_obt_sec_hdr_en),
    .obt_cuc_timestamp_48b (csr_obt_cuc_ts),
    .s_axis_tfdf_tdata     (sdls_tx_tdata),
    .s_axis_tfdf_tvalid    ((ROLE_MODE == 1) ? 1'b0 : sdls_tx_tvalid),
    .s_axis_tfdf_tready    (dl_framer_tfdf_tready),
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
    .rst_n              (rst_sys_n),
    .interleave_depth_i (csr_rs_interleave),
    .tm_rand_en         (csr_tm_rand_en),
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
    .rst_n         (rst_sys_n),
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
    .rst_n            (rst_sys_n),
    .bypass_en        ((csr_fec_mode == 4'd0) ? 1'b1 : ~csr_tm_rand_en),
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

  // Downlink High-Watermark Dual-Clock FIFO (TX9: clk_sys -> clk_tx_sym)
  logic [0:0]   tx_hwm_tkeep_unused;
  ccsds_tuser_t tx_hwm_tuser_unused;
  logic [9:0]   tx_hwm_comm_cnt_unused;
  logic [9:0]   tx_hwm_spec_cnt_unused;
  logic         tx_hwm_ovf_unused;
  logic         tx_hwm_cad_tvalid;
  logic         tx_phy_fifo_wr_ready;
  logic         tx_hwm_rd_ready;

  // External parallel CADU monitor tap (unconditionally reflects CADU byte availability in clk_tx_sym;
  // internal RF path u_tx_hwm_cdc_fifo -> u_tx_phy_cdc_fifo is decoupled so tying m_axis_dl_cad_tready=0 cannot stall RF TX)
  assign m_axis_dl_cad_tvalid = tx_hwm_cad_tvalid;
  assign tx_hwm_rd_ready      = tx_phy_fifo_wr_ready && (m_axis_dl_cad_tready || 1'b1);

  ccsds_cdc_fifo_ecc #(
    .DATA_WIDTH    (8),
    .DEPTH_WORDS   (512),
    .ROLLBACK_MODE (1'b0),
    .WATERMARK_MODE(1'b1)
  ) u_tx_hwm_cdc_fifo (
    .clk_wr                   (clk_sys),
    .rst_wr_n                 (rst_sys_n),
    .clk_rd                   (clk_tx_sym),
    .rst_rd_n                 (rst_tx_n),
    .cut_through_en           (1'b1),
    .watermark_words          (10'd4),
    .frame_commit_pulse       (1'b0),
    .frame_rollback_pulse     (1'b0),
    .seu_inject_en            (1'b0),
    .seu_inject_addr          (9'd0),
    .seu_inject_bit           (6'd0),
    .s_axis_tdata             ((ROLE_MODE == 1) ? egse_ul_tx_tdata  : tm_scram_tdata),
    .s_axis_tkeep             (1'b1),
    .s_axis_tvalid            ((ROLE_MODE == 1) ? egse_ul_tx_tvalid : tm_scram_tvalid),
    .s_axis_tready            (tx_hwm_in_tready),
    .s_axis_tlast             ((ROLE_MODE == 1) ? egse_ul_tx_tlast  : tm_scram_tlast),
    .s_axis_tuser             ('0),
    .m_axis_tdata             (m_axis_dl_cad_tdata),
    .m_axis_tkeep             (tx_hwm_tkeep_unused),
    .m_axis_tvalid            (tx_hwm_cad_tvalid),
    .m_axis_tready            (tx_hwm_rd_ready),
    .m_axis_tlast             (m_axis_dl_cad_tlast),
    .m_axis_tuser             (tx_hwm_tuser_unused),
    .committed_count          (tx_hwm_comm_cnt_unused),
    .speculative_count        (tx_hwm_spec_cnt_unused),
    .ecc_single_err_corrected (tx_fifo_secded_single),
    .ecc_double_err_uncorr    (tx_fifo_secded_double),
    .rollback_overflow_err    (tx_hwm_ovf_unused)
  );

  assign tm_scram_tready   = (ROLE_MODE == 1) ? 1'b1 : tx_hwm_in_tready;
  assign egse_ul_tx_tready = (ROLE_MODE == 1) ? tx_hwm_in_tready : 1'b0;

  // 2-FF CDC Synchronizer for c2_invert_en from clk_sys into clk_tx_sym
  (* ASYNC_REG = "TRUE" *) logic c2_inv_tx_meta_q, c2_inv_tx_sync_q;
  always_ff @(posedge clk_tx_sym or negedge rst_tx_n) begin
    if (!rst_tx_n) begin
      c2_inv_tx_meta_q <= 1'b1;
      c2_inv_tx_sync_q <= 1'b1;
    end else begin
      c2_inv_tx_meta_q <= (active_proto_mode != 3'd2);
      c2_inv_tx_sync_q <= c2_inv_tx_meta_q;
    end
  end

  logic conv_c1_unused, conv_c2_unused, conv_valid_unused;
  logic conv_lc_c1_unused, conv_lc_c2_unused;
  logic vit_dec_bit_unused, vit_dec_valid_unused;

  ccsds_conv_viterbi_codec u_conv_viterbi (
    .clk                  (clk_tx_sym),
    .rst_n                (rst_tx_n),
    .c2_invert_en         (c2_inv_tx_sync_q),
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

  // Dedicated Dual-Clock Gray-Code SECDED CDC FIFO (TX10: clk_tx_sym -> clk_adc_iq)
  // Bridges Downlink CADU stream into Baseband PHY Modem IQ clock domain with zero CDC violations
  logic [7:0]   tx_phy_fifo_tdata;
  logic [0:0]   tx_phy_fifo_tkeep_unused;
  logic         tx_phy_fifo_tvalid;
  logic         tx_phy_fifo_tready;
  logic         tx_phy_fifo_tlast_unused;
  ccsds_tuser_t tx_phy_fifo_tuser_unused;
  logic [7:0]   tx_phy_fifo_comm_cnt_unused;
  logic [7:0]   tx_phy_fifo_spec_cnt_unused;

  ccsds_cdc_fifo_ecc #(
    .DATA_WIDTH    (8),
    .DEPTH_WORDS   (128),
    .ROLLBACK_MODE (1'b0),
    .WATERMARK_MODE(1'b0)
  ) u_tx_phy_cdc_fifo (
    .clk_wr                   (clk_tx_sym),
    .rst_wr_n                 (rst_tx_n),
    .clk_rd                   (clk_adc_iq),
    .rst_rd_n                 (rst_adc_n),
    .cut_through_en           (1'b1),
    .watermark_words          (8'd0),
    .frame_commit_pulse       (1'b0),
    .frame_rollback_pulse     (1'b0),
    .seu_inject_en            (1'b0),
    .seu_inject_addr          (7'd0),
    .seu_inject_bit           (6'd0),
    .s_axis_tdata             (m_axis_dl_cad_tdata),
    .s_axis_tkeep             (1'b1),
    .s_axis_tvalid            (tx_hwm_cad_tvalid),
    .s_axis_tready            (tx_phy_fifo_wr_ready),
    .s_axis_tlast             (m_axis_dl_cad_tlast),
    .s_axis_tuser             ('0),
    .m_axis_tdata             (tx_phy_fifo_tdata),
    .m_axis_tkeep             (tx_phy_fifo_tkeep_unused),
    .m_axis_tvalid            (tx_phy_fifo_tvalid),
    .m_axis_tready            (tx_phy_fifo_tready),
    .m_axis_tlast             (tx_phy_fifo_tlast_unused),
    .m_axis_tuser             (tx_phy_fifo_tuser_unused),
    .committed_count          (tx_phy_fifo_comm_cnt_unused),
    .speculative_count        (tx_phy_fifo_spec_cnt_unused),
    .ecc_single_err_corrected (tx_phy_fifo_secded_single),
    .ecc_double_err_uncorr    (tx_phy_fifo_secded_double),
    .rollback_overflow_err    (tx_phy_fifo_ovf_pulse)
  );

  // 1-Stage AXI4-Stream Pipeline Slice in clk_adc_iq feeding u_phy_modem
  logic [7:0] tx_phy_pipe_tdata_q;
  logic       tx_phy_pipe_tvalid_q;

  assign tx_phy_fifo_tready = !tx_phy_pipe_tvalid_q || tx_phy_tready;

  always_ff @(posedge clk_adc_iq or negedge rst_adc_n) begin
    if (!rst_adc_n) begin
      tx_phy_pipe_tvalid_q <= 1'b0;
      tx_phy_pipe_tdata_q  <= 8'h00;
    end else if (tx_phy_fifo_tready) begin
      tx_phy_pipe_tvalid_q <= tx_phy_fifo_tvalid;
      tx_phy_pipe_tdata_q  <= tx_phy_fifo_tdata;
    end
  end

  assign tx_phy_tvalid = tx_phy_pipe_tvalid_q;
  assign tx_phy_tdata  = tx_phy_pipe_tdata_q;

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
      logic              egse_cltu_tvalid, egse_cltu_tready, egse_cltu_tlast;
      logic [7:0]        egse_cltu_tdata;
      logic [15:0]       egse_cb_cnt;

      logic              egse_rs_dec_tvalid, egse_rs_dec_tready, egse_rs_dec_tlast;
      logic [7:0]        egse_rs_dec_tdata;
      logic              egse_rs_done, egse_rs_clean;
      logic [15:0]       egse_rs_corr_cnt;
      logic              egse_rs_in_ready;

      logic              egse_tfdf_tvalid, egse_tfdf_tlast;
      logic [7:0]        egse_tfdf_tdata;
      ccsds_tm_prim_hdr_t egse_rx_tm_hdr;
      logic [47:0]       egse_rx_obt;
      logic              egse_crc_ok, egse_crc_err;
      logic              egse_tc_in_ready;

      // Ground EGSE Telecommand Space Packet Store-and-Length Buffer (clk_sys)
      typedef enum logic [1:0] {
        EGSE_PKT_COLLECT   = 2'd0,
        EGSE_PKT_DRAIN     = 2'd1,
        EGSE_PKT_WAIT_CLTU = 2'd2
      } egse_pkt_state_e;

      egse_pkt_state_e egse_pkt_state_q;
      logic [7:0]      egse_pkt_buf_q [0:63];
      logic [6:0]      egse_pkt_wr_cnt_q;
      logic [6:0]      egse_pkt_rd_idx_q;
      logic [5:0]      egse_pkt_vcid_q;
      logic            egse_frm_in_tvalid;
      logic [7:0]      egse_frm_in_tdata;
      logic            egse_frm_in_tlast;
      logic            egse_type_ad_sent_pulse;

      assign egse_pkt_in_tready       = (egse_pkt_state_q == EGSE_PKT_COLLECT);
      assign egse_frm_in_tvalid       = (egse_pkt_state_q == EGSE_PKT_DRAIN);
      assign egse_frm_in_tdata        = egse_pkt_buf_q[egse_pkt_rd_idx_q[5:0]];
      assign egse_frm_in_tlast        = (egse_pkt_state_q == EGSE_PKT_DRAIN) &&
                                        ((egse_pkt_rd_idx_q + 7'd1) == egse_pkt_wr_cnt_q);
      assign egse_ul_sdls_in_tvalid   = egse_frm_in_tvalid;
      assign egse_ul_sdls_in_tdata    = egse_frm_in_tdata;
      assign egse_ul_sdls_in_tlast    = egse_frm_in_tlast;
      assign egse_ul_sdls_out_tready  = egse_tc_in_ready;
      assign egse_type_ad_sent_pulse  = sdls_tx_tvalid && egse_tc_in_ready && sdls_tx_tlast;

      always_ff @(posedge clk_sys or negedge rst_sys_n) begin
        if (!rst_sys_n) begin
          egse_pkt_state_q  <= EGSE_PKT_COLLECT;
          egse_pkt_wr_cnt_q <= 7'd0;
          egse_pkt_rd_idx_q <= 7'd0;
          egse_pkt_vcid_q   <= 6'd1;
          for (int k = 0; k < 64; k++) begin
            egse_pkt_buf_q[k] <= 8'd0;
          end
        end else begin
          unique case (egse_pkt_state_q)
            EGSE_PKT_COLLECT: begin
              if (s_axis_tx_pkt_tvalid && egse_pkt_in_tready) begin
                egse_pkt_buf_q[egse_pkt_wr_cnt_q[5:0]] <= s_axis_tx_pkt_tdata;
                if (egse_pkt_wr_cnt_q == 7'd0) begin
                  egse_pkt_vcid_q <= (s_axis_tx_pkt_tuser.vcid != 6'd0) ? s_axis_tx_pkt_tuser.vcid : 6'd1;
                end
                egse_pkt_wr_cnt_q <= egse_pkt_wr_cnt_q + 7'd1;
                if (s_axis_tx_pkt_tlast) begin
                  egse_pkt_rd_idx_q <= 7'd0;
                  egse_pkt_state_q  <= EGSE_PKT_DRAIN;
                end
              end
            end

            EGSE_PKT_DRAIN: begin
              if (vc_tfdf_tready) begin
                if (egse_frm_in_tlast) begin
                  egse_pkt_state_q <= EGSE_PKT_WAIT_CLTU;
                end else begin
                  egse_pkt_rd_idx_q <= egse_pkt_rd_idx_q + 7'd1;
                end
              end
            end

            EGSE_PKT_WAIT_CLTU: begin
              if (egse_cltu_tvalid && egse_cltu_tready && egse_cltu_tlast) begin
                egse_pkt_wr_cnt_q <= 7'd0;
                egse_pkt_state_q  <= EGSE_PKT_COLLECT;
              end
            end

            default: egse_pkt_state_q <= EGSE_PKT_COLLECT;
          endcase
        end
      end

      ccsds_fop1_engine u_egse_fop1 (
        .clk                       (clk_sys),
        .rst_n                     (rst_sys_n),
        .target_vcid_cfg           (6'd1),
        .sliding_win_k_cfg         (8'd16),
        .t1_timeout_cycles_cfg     (16'd2000),
        .tx_type_ad_req_pulse      (egse_type_ad_sent_pulse),
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
        .rst_n               (rst_sys_n),
        .scid_10b_cfg        (csr_scid_10b),
        .vcid_cfg            (egse_pkt_vcid_q),
        .bypass_flag_cfg     (1'b0),
        .ctrl_cmd_flag_cfg   (1'b0),
        .seg_hdr_en_cfg      (csr_tc_seg_hdr_en),
        .seq_flags_cfg       (2'b11),
        .map_id_cfg          (6'd0),
        .fop1_ns_in          (egse_vs),
        .payload_byte_len_in ({3'd0, egse_pkt_wr_cnt_q} + (active_sdls_en ? (csr_sdls_gcm_mode ? 10'd22 : 10'd7) : 10'd0)),
        .s_axis_tvalid       (sdls_tx_tvalid),
        .s_axis_tready       (egse_tc_in_ready),
        .s_axis_tdata        (sdls_tx_tdata),
        .s_axis_tlast        (sdls_tx_tlast),
        .m_axis_tvalid       (egse_tc_tvalid),
        .m_axis_tready       (egse_tc_tready),
        .m_axis_tdata        (egse_tc_tdata),
        .m_axis_tlast        (egse_tc_tlast)
      );

      logic        egse_bch_tc_tready;
      logic        egse_bch_cltu_tvalid;
      logic [7:0]  egse_bch_cltu_tdata;
      logic        egse_bch_cltu_tlast;

      ccsds_bch6356_enc u_egse_bch_enc (
        .clk                    (clk_sys),
        .rst_n                  (rst_sys_n),
        .tc_randomize_en_cfg    (1'b1),
        .s_axis_tvalid          (egse_tc_tvalid && !ul_ldpc_mode_en),
        .s_axis_tready          (egse_bch_tc_tready),
        .s_axis_tdata           (egse_tc_tdata),
        .s_axis_tlast           (egse_tc_tlast),
        .m_axis_tvalid          (egse_bch_cltu_tvalid),
        .m_axis_tready          (egse_cltu_tready),
        .m_axis_tdata           (egse_bch_cltu_tdata),
        .m_axis_tlast           (egse_bch_cltu_tlast),
        .cltu_codeblock_cnt_out (egse_cb_cnt)
      );

      // Official CCSDS 231.1-O-1 Table 2-1 Uplink Short-Block LDPC(128,64) CLTU Encoder (when ul_ldpc_mode_en == 1'b1)
      localparam logic [63:0] EGSE_LDPC128_W_ROW [0:63] = '{
        64'h0E69166BEF4C0BC2, 64'h87348B3577A605E1, 64'h439AC59A3BD382F0, 64'h21CD62CD9DE94178,
        64'h90E6B166CEF420BC, 64'h487358B3677A105E, 64'hA439AC5933BD082F, 64'hD21CD62C99DE8417,
        64'h690E6B164CEFC20B, 64'h3487358BA677E105, 64'h9A439AC5D33BF082, 64'hCD21CD62E99D7841,
        64'hE69066B1F4CEBC20, 64'h7348B3587A675E10, 64'h39A459ACBD332F08, 64'h1CD22CD6DE991784,
        64'h7766137EBB248418, 64'h3BB309BF5D92420C, 64'h9DD984DF2EC92106, 64'hCEECC26F97641083,
        64'h6776E1374BB28841, 64'h33BBF09B25D9C420, 64'h99DDF84D92EC6210, 64'hCCEEFC2649763108,
        64'h66777E1324BB1884, 64'hB33BBF09925D0C42, 64'hD99DDF84C92E0621, 64'hECCE6FC264978310,
        64'h766737E1B24B4188, 64'hBB339BF0D92520C4, 64'hDD994DF8EC921062, 64'hEECC26FC76490831,
        64'hC480FEB9CD53A713, 64'h6240FF5CE6A9D389, 64'h31207FAEF354E9C4, 64'h18903FD779AA74E2,
        64'h0C489FEB3CD53A71, 64'h0624CFF59E6A9D38, 64'h0312E7FA4F354E9C, 64'h018973FDA79A274E,
        64'h80C4B9FE53CD13A7, 64'h40625CFFA9E689D3, 64'h2031AE7F54F3C4E9, 64'h9018D73FAA79E274,
        64'h480CEB9FD53C713A, 64'h2406F5CF6A9E389D, 64'h1203FAE7354F9C4E, 64'h8901FD739AA74E27,
        64'h4EAA22FA465EEA11, 64'h2755117D232FF508, 64'h93AA88BE91977A84, 64'h49D5445FC8CB3D42,
        64'hA4EAA22FE4651EA1, 64'h5275D117F2328F50, 64'hA93AE88B791947A8, 64'h549DF445BC8C23D4,
        64'hAA4EFA225E4611EA, 64'h55277D112F2308F5, 64'hAA93BE889791847A, 64'hD5495F44CBC8423D,
        64'hEAA42FA265E4A11E, 64'h755217D132F2508F, 64'h3AA98BE81979A847, 64'h9D5445F48CBCD423
      };

      typedef enum logic [2:0] {
        EGSE_LDPC_IDLE    = 3'd0,
        EGSE_LDPC_START   = 3'd1,
        EGSE_LDPC_COLLECT = 3'd2,
        EGSE_LDPC_PAD     = 3'd3,
        EGSE_LDPC_PAR     = 3'd4,
        EGSE_LDPC_TAIL    = 3'd5
      } egse_ldpc_state_e;

      egse_ldpc_state_e egse_ldpc_state_q;
      logic [2:0]       egse_ldpc_idx_q;
      logic [63:0]      egse_ldpc_par64_q;
      logic [7:0]       egse_ldpc_lfsr_q;
      logic             egse_ldpc_done_pend_q;
      logic [7:0]       egse_ldpc_first_b_q;
      logic             egse_ldpc_first_last_q;
      logic             egse_ldpc_first_pend_q;
      logic             egse_ldpc_tc_tready;
      logic             egse_ldpc_cltu_tvalid;
      logic [7:0]       egse_ldpc_cltu_tdata;
      logic             egse_ldpc_cltu_tlast;

      assign egse_ldpc_tc_tready = (egse_ldpc_state_q == EGSE_LDPC_IDLE ||
                                   (egse_ldpc_state_q == EGSE_LDPC_COLLECT && !egse_ldpc_first_pend_q)) &&
                                   egse_cltu_tready;
      assign egse_tc_tready      = ul_ldpc_mode_en ? egse_ldpc_tc_tready   : egse_bch_tc_tready;
      assign egse_cltu_tvalid    = ul_ldpc_mode_en ? egse_ldpc_cltu_tvalid : egse_bch_cltu_tvalid;
      assign egse_cltu_tdata     = ul_ldpc_mode_en ? egse_ldpc_cltu_tdata  : egse_bch_cltu_tdata;
      assign egse_cltu_tlast     = ul_ldpc_mode_en ? egse_ldpc_cltu_tlast  : egse_bch_cltu_tlast;

      always_ff @(posedge clk_sys or negedge rst_sys_n) begin
        if (!rst_sys_n) begin
          egse_ldpc_state_q      <= EGSE_LDPC_IDLE;
          egse_ldpc_idx_q        <= 3'd0;
          egse_ldpc_par64_q      <= 64'd0;
          egse_ldpc_lfsr_q       <= 8'hFF;
          egse_ldpc_done_pend_q  <= 1'b0;
          egse_ldpc_first_b_q    <= 8'h00;
          egse_ldpc_first_last_q <= 1'b0;
          egse_ldpc_first_pend_q <= 1'b0;
          egse_ldpc_cltu_tvalid  <= 1'b0;
          egse_ldpc_cltu_tdata   <= 8'h00;
          egse_ldpc_cltu_tlast   <= 1'b0;
        end else begin
          if (egse_cltu_tready) begin
            egse_ldpc_cltu_tvalid <= 1'b0;
            egse_ldpc_cltu_tlast  <= 1'b0;
          end

          unique case (egse_ldpc_state_q)
            EGSE_LDPC_IDLE: begin
              if (egse_tc_tvalid && ul_ldpc_mode_en && egse_cltu_tready) begin
                egse_ldpc_first_b_q    <= egse_tc_tdata;
                egse_ldpc_first_last_q <= egse_tc_tlast;
                egse_ldpc_first_pend_q <= 1'b1;
                egse_ldpc_lfsr_q       <= 8'hFF;
                egse_ldpc_par64_q      <= 64'd0;
                egse_ldpc_done_pend_q  <= 1'b0;
                egse_ldpc_idx_q        <= 3'd1;
                egse_ldpc_cltu_tvalid  <= 1'b1;
                egse_ldpc_cltu_tdata   <= UL_LDPC_START_SEQ_64B[63:56];
                egse_ldpc_cltu_tlast   <= 1'b0;
                egse_ldpc_state_q      <= EGSE_LDPC_START;
              end
            end

            EGSE_LDPC_START: begin
              if (egse_cltu_tready) begin
                egse_ldpc_cltu_tvalid <= 1'b1;
                egse_ldpc_cltu_tdata  <= UL_LDPC_START_SEQ_64B[(7 - egse_ldpc_idx_q)*8 +: 8];
                egse_ldpc_cltu_tlast  <= 1'b0;
                if (egse_ldpc_idx_q == 3'd7) begin
                  egse_ldpc_idx_q   <= 3'd0;
                  egse_ldpc_state_q <= EGSE_LDPC_COLLECT;
                end else begin
                  egse_ldpc_idx_q <= egse_ldpc_idx_q + 3'd1;
                end
              end
            end

            EGSE_LDPC_COLLECT: begin
              if (egse_cltu_tready && (egse_ldpc_first_pend_q || (egse_tc_tvalid && ul_ldpc_mode_en))) begin
                logic [7:0]  in_b, cur_l, pn_b, scr_b;
                logic        in_last, fb_b;
                logic [63:0] nxt_p;
                in_b    = egse_ldpc_first_pend_q ? egse_ldpc_first_b_q    : egse_tc_tdata;
                in_last = egse_ldpc_first_pend_q ? egse_ldpc_first_last_q : egse_tc_tlast;
                cur_l   = egse_ldpc_lfsr_q;
                pn_b    = 8'h00;
                for (int i = 0; i < 8; i++) begin
                  pn_b = {pn_b[6:0], cur_l[0]};
                  fb_b = ^(cur_l & 8'h5F);
                  cur_l = {fb_b, cur_l[7:1]};
                end
                scr_b = in_b ^ pn_b;
                nxt_p = egse_ldpc_par64_q;
                for (int b = 0; b < 8; b++) begin
                  if (scr_b[7 - b]) begin
                    nxt_p = nxt_p ^ EGSE_LDPC128_W_ROW[{egse_ldpc_idx_q, 3'(b)}];
                  end
                end
                egse_ldpc_first_pend_q <= 1'b0;
                egse_ldpc_lfsr_q       <= cur_l;
                egse_ldpc_par64_q      <= nxt_p;
                egse_ldpc_cltu_tvalid  <= 1'b1;
                egse_ldpc_cltu_tdata   <= scr_b;
                egse_ldpc_cltu_tlast   <= 1'b0;
                if (egse_ldpc_idx_q == 3'd7) begin
                  egse_ldpc_idx_q       <= 3'd0;
                  egse_ldpc_done_pend_q <= in_last;
                  egse_ldpc_state_q     <= EGSE_LDPC_PAR;
                end else begin
                  egse_ldpc_idx_q <= egse_ldpc_idx_q + 3'd1;
                  if (in_last) begin
                    egse_ldpc_done_pend_q <= 1'b1;
                    egse_ldpc_state_q     <= EGSE_LDPC_PAD;
                  end
                end
              end
            end

            EGSE_LDPC_PAD: begin
              if (egse_cltu_tready) begin
                logic [7:0]  cur_l, pn_b, scr_b;
                logic        fb_b;
                logic [63:0] nxt_p;
                cur_l = egse_ldpc_lfsr_q;
                pn_b  = 8'h00;
                for (int i = 0; i < 8; i++) begin
                  pn_b = {pn_b[6:0], cur_l[0]};
                  fb_b = ^(cur_l & 8'h5F);
                  cur_l = {fb_b, cur_l[7:1]};
                end
                scr_b = 8'h55 ^ pn_b;
                nxt_p = egse_ldpc_par64_q;
                for (int b = 0; b < 8; b++) begin
                  if (scr_b[7 - b]) begin
                    nxt_p = nxt_p ^ EGSE_LDPC128_W_ROW[{egse_ldpc_idx_q, 3'(b)}];
                  end
                end
                egse_ldpc_lfsr_q      <= cur_l;
                egse_ldpc_par64_q     <= nxt_p;
                egse_ldpc_cltu_tvalid <= 1'b1;
                egse_ldpc_cltu_tdata  <= scr_b;
                egse_ldpc_cltu_tlast  <= 1'b0;
                if (egse_ldpc_idx_q == 3'd7) begin
                  egse_ldpc_idx_q   <= 3'd0;
                  egse_ldpc_state_q <= EGSE_LDPC_PAR;
                end else begin
                  egse_ldpc_idx_q <= egse_ldpc_idx_q + 3'd1;
                end
              end
            end

            EGSE_LDPC_PAR: begin
              if (egse_cltu_tready) begin
                egse_ldpc_cltu_tvalid <= 1'b1;
                egse_ldpc_cltu_tdata  <= egse_ldpc_par64_q[(7 - egse_ldpc_idx_q)*8 +: 8];
                egse_ldpc_cltu_tlast  <= 1'b0;
                if (egse_ldpc_idx_q == 3'd7) begin
                  egse_ldpc_idx_q   <= 3'd0;
                  egse_ldpc_par64_q <= 64'd0;
                  if (egse_ldpc_done_pend_q) begin
                    egse_ldpc_state_q <= EGSE_LDPC_TAIL;
                  end else begin
                    egse_ldpc_state_q <= EGSE_LDPC_COLLECT;
                  end
                end else begin
                  egse_ldpc_idx_q <= egse_ldpc_idx_q + 3'd1;
                end
              end
            end

            EGSE_LDPC_TAIL: begin
              if (egse_cltu_tready) begin
                egse_ldpc_cltu_tvalid <= 1'b1;
                egse_ldpc_cltu_tdata  <= CLTU_TAIL_SEQ_LDPC_55[(7 - egse_ldpc_idx_q)*8 +: 8];
                egse_ldpc_cltu_tlast  <= (egse_ldpc_idx_q == 3'd7);
                if (egse_ldpc_idx_q == 3'd7) begin
                  egse_ldpc_idx_q   <= 3'd0;
                  egse_ldpc_state_q <= EGSE_LDPC_IDLE;
                end else begin
                  egse_ldpc_idx_q <= egse_ldpc_idx_q + 3'd1;
                end
              end
            end

            default: egse_ldpc_state_q <= EGSE_LDPC_IDLE;
          endcase
        end
      end

      // Ground EGSE Uplink RF Acquisition Preamble (0x00, 0x55, 0xAA, 0x00) + CLTU + Postamble (0x55, 0x55) Wrapper
      typedef enum logic [1:0] {
        EGSE_TX_IDLE      = 2'd0,
        EGSE_TX_PREAMBLE  = 2'd1,
        EGSE_TX_CLTU      = 2'd2,
        EGSE_TX_POSTAMBLE = 2'd3
      } egse_tx_state_e;

      egse_tx_state_e egse_tx_state_q;
      logic [1:0]     egse_tx_cnt_q;

      always_comb begin
        egse_ul_tx_tvalid = 1'b0;
        egse_ul_tx_tdata  = 8'h55;
        egse_ul_tx_tlast  = 1'b0;
        egse_cltu_tready  = 1'b0;

        unique case (egse_tx_state_q)
          EGSE_TX_PREAMBLE: begin
            egse_ul_tx_tvalid = 1'b1;
            unique case (egse_tx_cnt_q)
              2'd0: egse_ul_tx_tdata = 8'h00;
              2'd1: egse_ul_tx_tdata = 8'h55;
              2'd2: egse_ul_tx_tdata = 8'hAA;
              default: egse_ul_tx_tdata = 8'h00;
            endcase
          end

          EGSE_TX_CLTU: begin
            egse_ul_tx_tvalid = egse_cltu_tvalid;
            egse_ul_tx_tdata  = egse_cltu_tdata;
            egse_cltu_tready  = egse_ul_tx_tready;
          end

          EGSE_TX_POSTAMBLE: begin
            egse_ul_tx_tvalid = 1'b1;
            egse_ul_tx_tdata  = 8'h55;
            egse_ul_tx_tlast  = (egse_tx_cnt_q == 2'd1);
          end

          default: begin
            egse_ul_tx_tvalid = 1'b0;
          end
        endcase
      end

      always_ff @(posedge clk_sys or negedge rst_sys_n) begin
        if (!rst_sys_n) begin
          egse_tx_state_q <= EGSE_TX_IDLE;
          egse_tx_cnt_q   <= 2'd0;
        end else begin
          unique case (egse_tx_state_q)
            EGSE_TX_IDLE: begin
              if (egse_pkt_state_q == EGSE_PKT_DRAIN) begin
                egse_tx_cnt_q   <= 2'd0;
                egse_tx_state_q <= EGSE_TX_PREAMBLE;
              end
            end

            EGSE_TX_PREAMBLE: begin
              if (egse_ul_tx_tready) begin
                if (egse_tx_cnt_q == 2'd3) begin
                  egse_tx_cnt_q   <= 2'd0;
                  egse_tx_state_q <= EGSE_TX_CLTU;
                end else begin
                  egse_tx_cnt_q <= egse_tx_cnt_q + 2'd1;
                end
              end
            end

            EGSE_TX_CLTU: begin
              if (egse_cltu_tvalid && egse_ul_tx_tready && egse_cltu_tlast) begin
                egse_tx_cnt_q   <= 2'd0;
                egse_tx_state_q <= EGSE_TX_POSTAMBLE;
              end
            end

            EGSE_TX_POSTAMBLE: begin
              if (egse_ul_tx_tready) begin
                if (egse_tx_cnt_q == 2'd1) begin
                  egse_tx_cnt_q   <= 2'd0;
                  egse_tx_state_q <= EGSE_TX_IDLE;
                end else begin
                  egse_tx_cnt_q <= egse_tx_cnt_q + 2'd1;
                end
              end
            end

            default: egse_tx_state_q <= EGSE_TX_IDLE;
          endcase
        end
      end

      // Ground EGSE Downlink RF Demodulator CDC FIFO (clk_adc_iq -> clk_sys) & 32-bit ASM (0x1ACFFC1D) Synchronizer
      logic [7:0]   egse_dl_fifo_tdata;
      logic [0:0]   egse_dl_fifo_tkeep_unused;
      logic         egse_dl_fifo_tvalid;
      logic         egse_dl_fifo_tready;
      logic         egse_dl_fifo_tlast_unused;
      ccsds_tuser_t egse_dl_fifo_tuser_unused;
      logic         egse_dl_fifo_wr_ready_unused;
      logic [7:0]   egse_dl_fifo_comm_cnt_unused;
      logic [7:0]   egse_dl_fifo_spec_cnt_unused;
      logic         egse_dl_fifo_single_unused;
      logic         egse_dl_fifo_double_unused;
      logic         egse_dl_fifo_ovf_unused;

      ccsds_cdc_fifo_ecc #(
        .DATA_WIDTH    (8),
        .DEPTH_WORDS   (128),
        .ROLLBACK_MODE (1'b0),
        .WATERMARK_MODE(1'b0)
      ) u_egse_dl_cdc_fifo (
        .clk_wr                   (clk_adc_iq),
        .rst_wr_n                 (rst_adc_n),
        .clk_rd                   (clk_sys),
        .rst_rd_n                 (rst_sys_n),
        .cut_through_en           (1'b1),
        .watermark_words          (8'd0),
        .frame_commit_pulse       (1'b0),
        .frame_rollback_pulse     (1'b0),
        .seu_inject_en            (1'b0),
        .seu_inject_addr          (7'd0),
        .seu_inject_bit           (6'd0),
        .s_axis_tdata             (phy_rx_sym_byte),
        .s_axis_tkeep             (1'b1),
        .s_axis_tvalid            (phy_rx_sym_valid && !pn_ranging_en_cfg),
        .s_axis_tready            (egse_dl_fifo_wr_ready_unused),
        .s_axis_tlast             (1'b0),
        .s_axis_tuser             ('0),
        .m_axis_tdata             (egse_dl_fifo_tdata),
        .m_axis_tkeep             (egse_dl_fifo_tkeep_unused),
        .m_axis_tvalid            (egse_dl_fifo_tvalid),
        .m_axis_tready            (egse_dl_fifo_tready),
        .m_axis_tlast             (egse_dl_fifo_tlast_unused),
        .m_axis_tuser             (egse_dl_fifo_tuser_unused),
        .committed_count          (egse_dl_fifo_comm_cnt_unused),
        .speculative_count        (egse_dl_fifo_spec_cnt_unused),
        .ecc_single_err_corrected (egse_dl_fifo_single_unused),
        .ecc_double_err_uncorr    (egse_dl_fifo_double_unused),
        .rollback_overflow_err    (egse_dl_fifo_ovf_unused)
      );

      logic [31:0] egse_dl_asm_sr_q;
      logic        egse_dl_sync_q;
      logic [15:0] egse_dl_rem_cnt_q;
      logic [7:0]  egse_dl_tm_lfsr_q;
      logic [7:0]  egse_dl_tm_nxt_sr;
      logic [7:0]  egse_dl_tm_pn_b;
      logic        egse_rs_in_tvalid;
      logic [7:0]  egse_rs_in_tdata;
      logic        egse_rs_in_tlast;

      assign egse_dl_fifo_tready = egse_rs_in_ready;

      always_comb begin
        logic [7:0] sr;
        logic [7:0] b_val;
        logic       fb;
        sr    = egse_dl_tm_lfsr_q;
        b_val = 8'h00;
        for (int b = 0; b < 8; b++) begin
          b_val = {b_val[6:0], sr[0]};
          fb    = ^(sr & LFSR_TM_TAP_MASK);
          sr    = {fb, sr[7:1]};
        end
        egse_dl_tm_nxt_sr = sr;
        egse_dl_tm_pn_b   = b_val;

        if (ROLE_MODE == 1) begin
          egse_rs_in_tvalid = egse_dl_sync_q && egse_dl_fifo_tvalid;
          egse_rs_in_tdata  = csr_tm_rand_en ? (egse_dl_fifo_tdata ^ egse_dl_tm_pn_b) : egse_dl_fifo_tdata;
          egse_rs_in_tlast  = (egse_dl_rem_cnt_q == 16'd1);
        end else begin
          egse_rs_in_tvalid = tm_scram_tvalid;
          egse_rs_in_tdata  = tm_scram_tdata;
          egse_rs_in_tlast  = tm_scram_tlast;
        end
      end

      always_ff @(posedge clk_sys or negedge rst_sys_n) begin
        if (!rst_sys_n) begin
          egse_dl_asm_sr_q  <= 32'd0;
          egse_dl_sync_q    <= 1'b0;
          egse_dl_rem_cnt_q <= 16'd0;
          egse_dl_tm_lfsr_q <= LFSR_INIT_ALL_ONES;
        end else if (egse_dl_fifo_tvalid && egse_rs_in_ready) begin
          if (!egse_dl_sync_q) begin
            logic [31:0] nxt_asm;
            nxt_asm          = {egse_dl_asm_sr_q[23:0], egse_dl_fifo_tdata};
            egse_dl_asm_sr_q <= nxt_asm;
            if (nxt_asm == DL_ASM_TM_RS_CONV_32B) begin
              egse_dl_sync_q    <= 1'b1;
              egse_dl_rem_cnt_q <= (16'd255 - {8'd0, csr_rs_q_fill}) * {12'd0, csr_rs_interleave};
              egse_dl_tm_lfsr_q <= LFSR_INIT_ALL_ONES;
            end
          end else begin
            egse_dl_tm_lfsr_q <= csr_tm_rand_en ? egse_dl_tm_nxt_sr : egse_dl_tm_lfsr_q;
            if (egse_dl_rem_cnt_q == 16'd1) begin
              egse_dl_sync_q    <= 1'b0;
              egse_dl_asm_sr_q  <= 32'd0;
              egse_dl_rem_cnt_q <= 16'd0;
            end else begin
              egse_dl_rem_cnt_q <= egse_dl_rem_cnt_q - 16'd1;
            end
          end
        end
      end

      ccsds_dl_rs255_223_dec u_egse_rs_dec (
        .clk                      (clk_sys),
        .rst_n                    (rst_sys_n),
        .interleave_depth_i_cfg   (csr_rs_interleave),
        .virtual_fill_q_cfg       (csr_rs_q_fill),
        .s_axis_tvalid            (egse_rs_in_tvalid),
        .s_axis_tready            (egse_rs_in_ready),
        .s_axis_tdata             (egse_rs_in_tdata),
        .s_axis_tlast             (egse_rs_in_tlast),
        .m_axis_tvalid            (egse_rs_dec_tvalid),
        .m_axis_tready            (egse_rs_dec_tready),
        .m_axis_tdata             (egse_rs_dec_tdata),
        .m_axis_tlast             (egse_rs_dec_tlast),
        .rs_cw_done_pulse         (egse_rs_done),
        .rs_syndrome_clean_out    (egse_rs_clean),
        .rs_corrected_sym_cnt_out (egse_rs_corr_cnt)
      );

      logic [15:0] egse_proto_extra_hdr;
      logic [15:0] egse_sdls_ovh_bytes;
      logic [3:0]  egse_hdr_strip_cnt_q;

      assign egse_proto_extra_hdr = (active_proto_mode == PROTO_AOS) ? 16'd2 :
                                    ((active_proto_mode == PROTO_USLP) ? 16'd5 : 16'd0);
      assign egse_sdls_ovh_bytes  = active_sdls_en ? (csr_sdls_gcm_mode ? 16'd22 : 16'd7) : 16'd0;

      ccsds_tm_aos_deframer u_egse_tm_deframer (
        .clk                      (clk_sys),
        .rst_n                    (rst_sys_n),
        .aos_mode_cfg             (active_proto_mode == PROTO_AOS),
        .aos_fhec_en_cfg          (csr_aos_fhec_en),
        .tm_sec_hdr_en_cfg        ((active_proto_mode == PROTO_TM) && csr_obt_sec_hdr_en),
        .ocf_en_cfg               (csr_ocf_en),
        .fecf_en_cfg              (csr_fecf_en),
        .tfdf_byte_len_cfg        ({5'd0, csr_tfdf_len} + egse_sdls_ovh_bytes + egse_proto_extra_hdr),
        .s_axis_tvalid            (egse_rs_dec_tvalid),
        .s_axis_tready            (egse_rs_dec_tready),
        .s_axis_tdata             (egse_rs_dec_tdata),
        .s_axis_tlast             (egse_rs_dec_tlast),
        .m_axis_tfdf_tvalid       (egse_tfdf_tvalid),
        .m_axis_tfdf_tready       (egse_dl_sdls_in_tready),
        .m_axis_tfdf_tdata        (egse_tfdf_tdata),
        .m_axis_tfdf_tlast        (egse_tfdf_tlast),
        .rx_tm_hdr_out            (egse_rx_tm_hdr),
        .rx_obt_cuc_timestamp_out (egse_rx_obt),
        .extracted_clcw_out       (egse_rx_clcw),
        .clcw_valid_pulse         (egse_clcw_valid),
        .frame_crc_ok_pulse       (egse_crc_ok),
        .frame_crc_err_pulse      (egse_crc_err)
      );

      always_ff @(posedge clk_sys or negedge rst_sys_n) begin
        if (!rst_sys_n) begin
          egse_hdr_strip_cnt_q <= 4'd0;
        end else if (egse_tfdf_tvalid && egse_dl_sdls_in_tready) begin
          if (egse_tfdf_tlast) begin
            egse_hdr_strip_cnt_q <= 4'd0;
          end else if (egse_hdr_strip_cnt_q < egse_proto_extra_hdr[3:0]) begin
            egse_hdr_strip_cnt_q <= egse_hdr_strip_cnt_q + 4'd1;
          end
        end
      end

      assign egse_dl_sdls_in_tvalid = egse_tfdf_tvalid && (egse_hdr_strip_cnt_q >= egse_proto_extra_hdr[3:0]);
      assign egse_dl_sdls_in_tdata  = egse_tfdf_tdata;
      assign egse_dl_sdls_in_tlast  = egse_tfdf_tlast;
      assign egse_dl_tfdf_tdata     = sdls_rx_tdata;
      assign egse_dl_tfdf_tvalid    = sdls_rx_tvalid;
      assign egse_dl_tfdf_tlast     = sdls_rx_tlast;
      assign egse_rx_clcw_valid     = egse_clcw_valid;
      assign egse_rx_clcw_word      = egse_rx_clcw;
    end else begin : g_no_ground_egse_endpoints
      assign egse_ul_sdls_in_tvalid  = 1'b0;
      assign egse_ul_sdls_in_tdata   = 8'd0;
      assign egse_ul_sdls_in_tlast   = 1'b0;
      assign egse_ul_sdls_out_tready = 1'b0;
      assign egse_dl_sdls_in_tvalid  = 1'b0;
      assign egse_dl_sdls_in_tdata   = 8'd0;
      assign egse_dl_sdls_in_tlast   = 1'b0;
      assign egse_dl_tfdf_tdata      = 8'd0;
      assign egse_dl_tfdf_tvalid     = 1'b0;
      assign egse_dl_tfdf_tlast      = 1'b0;
      assign egse_ul_tx_tvalid       = 1'b0;
      assign egse_ul_tx_tdata        = 8'd0;
      assign egse_ul_tx_tlast        = 1'b0;
      assign egse_pkt_in_tready      = 1'b0;
      assign egse_rx_clcw_valid      = 1'b0;
      assign egse_rx_clcw_word       = '0;
    end
  endgenerate

endmodule
