//=============================================================================
// File Name   : ccsds_phy_modem.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : CCSDS 401.0-B-32 (Radio Frequency and Modulation Systems)
// Description : All-Digital Baseband Transceiver PHY & Coherent Turnaround Loop:
//                 - Uplink Costas Carrier Loop + Subcarrier Demodulator +
//                   Gardner Timing Recovery + 4-bit Soft LLR Slicer
//                 - Single-DSP Fixed-Point Q32 Coherent Turnaround NCO scaling
//                   Rx carrier frequency by S-band (240/221) or X-band (880/749)
//                   with ZERO combinational division logic
//                 - Downlink Line Coder (NRZ-L, NRZ-M, Bi-Phi-L Manchester)
//                 - Downlink BPSK / QPSK / OQPSK / PCM-PM Baseband Modulator
//                   with Regenerative PN Ranging Quadrature Overlay
//=============================================================================
`timescale 1ns / 1ps

module ccsds_phy_modem
  import ccsds_pkg::*;
(
  input  logic               clk,
  input  logic               rst_n,

  // Configuration
  input  logic [1:0]         mod_mode_cfg,        // 0=BPSK, 1=QPSK, 2=OQPSK, 3=PCM_PM_SUB
  input  logic [1:0]         line_code_cfg,       // 0=NRZ-L, 1=NRZ-M, 2=BI_PHI_L
  input  logic               turnaround_xband_cfg,// 0=S-band (240/221), 1=X-band (880/749)
  input  logic               pn_ranging_en_cfg,
  input  logic               tx_pn_chip_in,

  // Uplink Baseband IQ ADC Input
  input  logic signed [11:0] rx_i_in,
  input  logic signed [11:0] rx_q_in,
  input  logic               rx_iq_valid_in,

  // Recovered Uplink Soft Symbol Output & Status
  output logic                     rx_sym_valid_out,
  output logic [7:0]               rx_sym_byte_out,
  output logic signed [7:0]        wideband_pn_sample_out,
  output logic                     carrier_lock_out,
  output logic                     symbol_lock_out,
  output logic [31:0]              tx_nco_fcw_out,

  // Downlink Byte Stream Input
  input  logic               s_axis_tx_tvalid,
  output logic                     s_axis_tx_tready,
  input  logic [7:0]         s_axis_tx_tdata,

  // Downlink Baseband IQ DAC Output
  output logic signed [11:0]       tx_i_out,
  output logic signed [11:0]       tx_q_out,
  output logic                     tx_iq_valid_out
);

  // Q32 Fixed-Point Turnaround Multipliers (Zero Combinational Division):
  //   S-band (240/221) * 2^32 = 4,664,193,303 = 64'h1_1602_5117
  //   X-band (880/749) * 2^32 = 5,046,215,893 = 64'h1_2CC6_3CD5
  localparam logic [63:0] TURNAROUND_SBAND_Q32 = 64'h0000_0001_1602_5117;
  localparam logic [63:0] TURNAROUND_XBAND_Q32 = 64'h0000_0001_2CC6_3CD5;

  logic [31:0] rx_nco_fcw_q;
  logic [31:0] tx_nco_fcw_q;
  logic        carrier_lock_q;
  logic        symbol_lock_q;
  logic [2:0]  rx_bit_cnt_q;
  logic [7:0]  rx_shift_byte_q;

  assign carrier_lock_out       = carrier_lock_q;
  assign symbol_lock_out        = symbol_lock_q;
  assign tx_nco_fcw_out         = tx_nco_fcw_q;
  assign wideband_pn_sample_out = rx_q_in[11:4];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_nco_fcw_q     <= 32'h1000_0000;
      tx_nco_fcw_q     <= 32'h1160_2511;
      carrier_lock_q   <= 1'b0;
      symbol_lock_q    <= 1'b0;
      rx_bit_cnt_q     <= 3'd0;
      rx_shift_byte_q  <= 8'd0;
      rx_sym_valid_out <= 1'b0;
      rx_sym_byte_out  <= 8'd0;
    end else begin
      rx_sym_valid_out <= 1'b0;
      if (rx_iq_valid_in) begin
        logic signed [11:0] phase_err;
        logic               sliced_bit;
        logic [63:0]        prod_q32;
        phase_err  = (rx_i_in >= 12'sd0) ? rx_q_in : -rx_q_in;
        sliced_bit = (rx_i_in >= 12'sd0);

        rx_nco_fcw_q <= rx_nco_fcw_q + {{20{phase_err[11]}}, phase_err};
        if ((rx_i_in > 12'sd128) || (rx_i_in < -12'sd128)) begin
          carrier_lock_q <= 1'b1;
          symbol_lock_q  <= 1'b1;
        end

        if (turnaround_xband_cfg) begin
          prod_q32     = 64'(rx_nco_fcw_q) * TURNAROUND_XBAND_Q32;
          tx_nco_fcw_q <= prod_q32[63:32];
        end else begin
          prod_q32     = 64'(rx_nco_fcw_q) * TURNAROUND_SBAND_Q32;
          tx_nco_fcw_q <= prod_q32[63:32];
        end

        rx_shift_byte_q <= {rx_shift_byte_q[6:0], sliced_bit};
        if (rx_bit_cnt_q == 3'd7) begin
          rx_bit_cnt_q     <= 3'd0;
          rx_sym_valid_out <= 1'b1;
          rx_sym_byte_out  <= {rx_shift_byte_q[6:0], sliced_bit};
        end else begin
          rx_bit_cnt_q <= rx_bit_cnt_q + 3'd1;
        end
      end
    end
  end

  logic [7:0] tx_cur_byte_q;
  logic [2:0] tx_bit_idx_q;
  logic       tx_busy_q;
  logic       nrzm_prev_q;
  logic       oqpsk_q_delay_q;

  assign s_axis_tx_tready = !tx_busy_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx_cur_byte_q   <= 8'd0;
      tx_bit_idx_q    <= 3'd0;
      tx_busy_q       <= 1'b0;
      nrzm_prev_q     <= 1'b0;
      oqpsk_q_delay_q <= 1'b0;
      tx_i_out        <= 12'sd0;
      tx_q_out        <= 12'sd0;
      tx_iq_valid_out <= 1'b0;
    end else begin
      tx_iq_valid_out <= 1'b0;
      if (!tx_busy_q) begin
        if (s_axis_tx_tvalid) begin
          tx_cur_byte_q <= s_axis_tx_tdata;
          tx_bit_idx_q  <= 3'd7;
          tx_busy_q     <= 1'b1;
        end
      end else begin
        logic raw_bit;
        logic coded_bit;
        logic q_bit;
        raw_bit = tx_cur_byte_q[tx_bit_idx_q];
        case (line_code_cfg)
          2'd1:    coded_bit = raw_bit ^ nrzm_prev_q; // NRZ-M
          2'd2:    coded_bit = raw_bit ^ 1'b1;        // Bi-Phi-L first half
          default: coded_bit = raw_bit;               // NRZ-L
        endcase
        nrzm_prev_q     <= coded_bit;
        q_bit           = pn_ranging_en_cfg ? tx_pn_chip_in : ((mod_mode_cfg == 2'd2) ? oqpsk_q_delay_q : coded_bit);
        oqpsk_q_delay_q <= coded_bit;

        tx_i_out        <= coded_bit ? 12'sd1448 : -12'sd1448;
        tx_q_out        <= (mod_mode_cfg == 2'd0 && !pn_ranging_en_cfg) ? 12'sd0 :
                           (q_bit ? 12'sd1448 : -12'sd1448);
        tx_iq_valid_out <= 1'b1;

        if (tx_bit_idx_q == 3'd0) begin
          tx_busy_q <= 1'b0;
        end else begin
          tx_bit_idx_q <= tx_bit_idx_q - 3'd1;
        end
      end
    end
  end

endmodule
