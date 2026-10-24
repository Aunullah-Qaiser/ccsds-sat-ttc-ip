//=============================================================================
// File Name   : ccsds_phy_modem.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : CCSDS 401.0-B-32 (Radio Frequency and Modulation Systems)
// Description : All-Digital Baseband Transceiver PHY & Coherent Turnaround Loop:
//                 - 2-Stage Pipelined 17-Tap (alpha = 0.35, 4 SPS) Square-Root
//                   Raised-Cosine (SRRC) LUT6 Polyphase Tx Pulse-Shaping FIR
//                   (Fix CR-28: <= 3 logic levels/stage) & 4-Stage Pipelined
//                   Canonical Signed-Digit (CSD) 17-Tap Symmetric Folded Rx
//                   Matched SRRC Filter (srrc_4sps_en_cfg, Fix CR-22 / CR-26)
//                 - 2-Stage Pipelined (Stage B1 Derotator -> Stage B2 Costas PI
//                   Loop) 64-Entry Q3 One's-Complement Wire-Mux Sin/Cos NCO
//                   Complex Derotator + Carry-Free XOR 2nd-Order PI Costas Loop
//                   tracking static phase offset and continuous Carrier
//                   Frequency Offset (CFO) / Doppler shift across BPSK, QPSK,
//                   OQPSK, and PCM/PM (Fix CR-21 / CR-25 / CR-26 / CR-27:
//                   <= 6 logic levels/stage for >160 MHz Kintex UltraScale Fmax)
//                 - Receiver NRZ-L, NRZ-M (differential), and Bi-Phi-L
//                   (Manchester) line decoder (Fix CR-20)
//                 - Single-DSP Fixed-Point Q32 Coherent Turnaround NCO scaling
//                   registered Rx carrier frequency by S-band (240/221) or
//                   X-band (880/749) with ZERO combinational division logic
//                 - Downlink BPSK / QPSK / OQPSK / PCM-PM Baseband Modulator
//                   with Regenerative PN Ranging Quadrature Overlay
//=============================================================================
`timescale 1ns / 1ps

module ccsds_phy_modem
  import ccsds_pkg::*;
(
  input  logic               clk,
  input  logic               rst_n,

  // Mode Configuration
  input  logic [1:0]         mod_mode_cfg,        // 0=BPSK, 1=QPSK, 2=OQPSK, 3=PCM/PM
  input  logic [1:0]         line_code_cfg,       // 0=NRZ-L, 1=NRZ-M, 2=BI_PHI_L
  input  logic               turnaround_xband_cfg,// 0=S-band (240/221), 1=X-band (880/749)
  input  logic               pn_ranging_en_cfg,
  input  logic               srrc_4sps_en_cfg,    // 1=Enable 17-tap 4-SPS SRRC (alpha=0.35) Tx/Rx FIR
  input  logic               tx_pn_chip_in,

  // Uplink Baseband IQ ADC Input
  input  logic signed [11:0] rx_i_in,
  input  logic signed [11:0] rx_q_in,
  input  logic               rx_iq_valid_in,

  // Recovered Uplink Soft Symbol Output & Status
  output logic               rx_sym_valid_out,
  output logic [7:0]         rx_sym_byte_out,
  output logic signed [7:0]  wideband_pn_sample_out,
  output logic               carrier_lock_out,
  output logic               symbol_lock_out,
  output logic [31:0]        tx_nco_fcw_out,

  // Downlink Byte Stream Input
  input  logic               s_axis_tx_tvalid,
  output logic               s_axis_tx_tready,
  input  logic [7:0]         s_axis_tx_tdata,

  // Downlink Baseband IQ DAC Output
  output logic signed [11:0] tx_i_out,
  output logic signed [11:0] tx_q_out,
  output logic               tx_iq_valid_out
);

  // Q32 Fixed-Point Turnaround Multipliers (Zero Combinational Division):
  //   round(2^32 * 240 / 221) = 64'h0000_0001_1602_5117
  //   round(2^32 * 880 / 749) = 64'h0000_0001_2CC6_3CD5
  localparam logic [63:0] TURNAROUND_SBAND_Q32 = 64'h0000_0001_1602_5117;
  localparam logic [63:0] TURNAROUND_XBAND_Q32 = 64'h0000_0001_2CC6_3CD5;

  // Pre-scaled Multiplier-Free Polyphase Tx SRRC Taps: round(1024 * SRRC_TAPS / 512)
  localparam logic signed [11:0] SRRC_TX_TAPS [0:16] = '{
    12'sd58,  -12'sd22,  -12'sd138, -12'sd194, -12'sd86,   12'sd212,  12'sd624,  12'sd982,
    12'sd1124, 12'sd982,  12'sd624,  12'sd106*2, -12'sd86, -12'sd194, -12'sd138, -12'sd22, 12'sd58
  };

  // 64-Entry Q3 CSD Sin/Cos NCO Lookup Tables (8 = +1.0)
  localparam logic signed [4:0] COS_LUT_Q3 [0:63] = '{
     5'sd8,  5'sd8,  5'sd8,  5'sd8,  5'sd7,  5'sd7,  5'sd7,  5'sd6,
     5'sd6,  5'sd5,  5'sd4,  5'sd4,  5'sd3,  5'sd2,  5'sd2,  5'sd1,
     5'sd0, -5'sd1, -5'sd2, -5'sd2, -5'sd3, -5'sd4, -5'sd4, -5'sd5,
    -5'sd6, -5'sd6, -5'sd7, -5'sd7, -5'sd7, -5'sd8, -5'sd8, -5'sd8,
    -5'sd8, -5'sd8, -5'sd8, -5'sd8, -5'sd7, -5'sd7, -5'sd7, -5'sd6,
    -5'sd6, -5'sd5, -5'sd4, -5'sd4, -5'sd3, -5'sd2, -5'sd2, -5'sd1,
     5'sd0,  5'sd1,  5'sd2,  5'sd2,  5'sd3,  5'sd4,  5'sd4,  5'sd5,
     5'sd6,  5'sd6,  5'sd7,  5'sd7,  5'sd7,  5'sd8,  5'sd8,  5'sd8
  };

  localparam logic signed [4:0] SIN_LUT_Q3 [0:63] = '{
     5'sd0,  5'sd1,  5'sd2,  5'sd2,  5'sd3,  5'sd4,  5'sd4,  5'sd5,
     5'sd6,  5'sd6,  5'sd7,  5'sd7,  5'sd7,  5'sd8,  5'sd8,  5'sd8,
     5'sd8,  5'sd8,  5'sd8,  5'sd8,  5'sd7,  5'sd7,  5'sd7,  5'sd6,
     5'sd6,  5'sd5,  5'sd4,  5'sd4,  5'sd3,  5'sd2,  5'sd2,  5'sd1,
     5'sd0, -5'sd1, -5'sd2, -5'sd2, -5'sd3, -5'sd4, -5'sd4, -5'sd5,
    -5'sd6, -5'sd6, -5'sd7, -5'sd7, -5'sd7, -5'sd8, -5'sd8, -5'sd8,
    -5'sd8, -5'sd8, -5'sd8, -5'sd8, -5'sd7, -5'sd7, -5'sd7, -5'sd6,
    -5'sd6, -5'sd5, -5'sd4, -5'sd4, -5'sd3, -5'sd2, -5'sd2, -5'sd1
  };

  // Carry-Free One's-Complement Wire-Mux Q3 CSD Product (1 LUT6 mux + 2 CARRY8 levels)
  function automatic logic signed [14:0] mul_q3_ones_comp_mux(
    input logic signed [10:0] x,
    input logic signed [4:0]  c
  );
    logic signed [14:0] x0, x1, x2, x3, ta, tb;
    begin
      x0 = $signed({{4{x[10]}}, x});
      x1 = x0 <<< 1;
      x2 = x0 <<< 2;
      x3 = x0 <<< 3;

      if (c <= -5'sd6) begin
        ta = ~x3;
      end else if (c <= -5'sd2) begin
        ta = ~x2;
      end else if (c <= 5'sd2) begin
        ta = 15'sd0;
      end else if (c <= 5'sd6) begin
        ta = x2;
      end else begin
        ta = x3;
      end

      unique case (c)
        -5'sd6, -5'sd2,  5'sd2,  5'sd6: tb = x1;
        -5'sd7, -5'sd3,  5'sd1,  5'sd5: tb = x0;
        -5'sd5, -5'sd1,  5'sd3,  5'sd7: tb = ~x0;
        default:                        tb = 15'sd0;
      endcase

      return ta + tb;
    end
  endfunction

  // Multiplier-Free Canonical Signed-Digit (CSD) 17-Tap Symmetric SRRC Tap Products
  function automatic logic signed [23:0] csd_srrc_tap(
    input logic signed [12:0] s,
    input int                 tap_idx
  );
    logic signed [23:0] x;
    begin
      x = $signed({{11{s[12]}}, s});
      unique case (tap_idx)
        0:       return ((x <<< 5) - (x <<< 2)) + x;                       // * +29
        1:       return ((x <<< 2) - (x <<< 4)) + x;                       // * -11
        2:       return (24'sd0 - (x <<< 6)) - ((x <<< 2) + x);            // * -69
        3:       return ((x <<< 5) - (x <<< 7)) - x;                       // * -97
        4:       return ((x <<< 2) - (x <<< 5)) - ((x <<< 4) - x);         // * -43
        5:       return ((x <<< 7) - (x <<< 4)) - ((x <<< 2) + (x <<< 1)); // * +106
        6:       return ((x <<< 8) + (x <<< 6)) - (x <<< 3);               // * +312
        7:       return ((x <<< 9) - (x <<< 4)) - ((x <<< 2) + x);         // * +491
        default: return ((x <<< 9) + (x <<< 5)) + ((x <<< 4) + (x <<< 1)); // * +562
      endcase
    end
  endfunction

  // Pure 4-bit LUT4 lookup for Tap 0 (ph in 0..3, s0 in 0=0, 1=+1, 2=-1): ZERO carry chains!
  function automatic logic signed [11:0] tx_tap0_lut4(
    input logic [1:0] ph,
    input logic [1:0] s0
  );
    begin
      unique case ({ph, s0})
        {2'd0, 2'd1}: return  12'sd58;
        {2'd0, 2'd2}: return -12'sd58;
        {2'd1, 2'd1}: return -12'sd22;
        {2'd1, 2'd2}: return  12'sd22;
        {2'd2, 2'd1}: return -12'sd138;
        {2'd2, 2'd2}: return  12'sd138;
        {2'd3, 2'd1}: return -12'sd194;
        {2'd3, 2'd2}: return  12'sd194;
        default:      return  12'sd0;
      endcase
    end
  endfunction

  // Pure 6-bit LUT6 lookup for Taps (4+ph) and (8+ph): ZERO carry chains!
  function automatic logic signed [11:0] tx_pair12_lut6(
    input logic [1:0] ph,
    input logic [1:0] s1,
    input logic [1:0] s2
  );
    logic signed [11:0] v1, v2;
    begin
      unique case ({ph, s1})
        {2'd0, 2'd1}: v1 = -12'sd86;
        {2'd0, 2'd2}: v1 =  12'sd86;
        {2'd1, 2'd1}: v1 =  12'sd212;
        {2'd1, 2'd2}: v1 = -12'sd212;
        {2'd2, 2'd1}: v1 =  12'sd624;
        {2'd2, 2'd2}: v1 = -12'sd624;
        {2'd3, 2'd1}: v1 =  12'sd982;
        {2'd3, 2'd2}: v1 = -12'sd982;
        default:      v1 =  12'sd0;
      endcase
      unique case ({ph, s2})
        {2'd0, 2'd1}: v2 =  12'sd1124;
        {2'd0, 2'd2}: v2 = -12'sd1124;
        {2'd1, 2'd1}: v2 =  12'sd982;
        {2'd1, 2'd2}: v2 = -12'sd982;
        {2'd2, 2'd1}: v2 =  12'sd624;
        {2'd2, 2'd2}: v2 = -12'sd624;
        {2'd3, 2'd1}: v2 =  12'sd212;
        {2'd3, 2'd2}: v2 = -12'sd212;
        default:      v2 =  12'sd0;
      endcase
      return v1 + v2;
    end
  endfunction

  // Pure 6-bit LUT6 lookup for Tap (12+ph) and Tap 16 (when ph==0): ZERO carry chains!
  function automatic logic signed [11:0] tx_pair34_lut6(
    input logic [1:0] ph,
    input logic [1:0] s3,
    input logic [1:0] s4
  );
    logic signed [11:0] v3, v4;
    begin
      unique case ({ph, s3})
        {2'd0, 2'd1}: v3 = -12'sd86;
        {2'd0, 2'd2}: v3 =  12'sd86;
        {2'd1, 2'd1}: v3 = -12'sd194;
        {2'd1, 2'd2}: v3 =  12'sd194;
        {2'd2, 2'd1}: v3 = -12'sd138;
        {2'd2, 2'd2}: v3 =  12'sd138;
        {2'd3, 2'd1}: v3 = -12'sd22;
        {2'd3, 2'd2}: v3 =  12'sd22;
        default:      v3 =  12'sd0;
      endcase
      unique case ({ph, s4})
        {2'd0, 2'd1}: v4 =  12'sd58;
        {2'd0, 2'd2}: v4 = -12'sd58;
        default:      v4 =  12'sd0;
      endcase
      return v3 + v4;
    end
  endfunction

  logic signed [11:0] rx_srrc_i_q  [0:15];
  logic signed [11:0] rx_srrc_q_q  [0:15];
  logic               s1_valid_q;
  logic signed [12:0] s1_sum_i_q   [0:8];
  logic signed [12:0] s1_sum_q_q   [0:8];
  logic               s2_valid_q;
  logic signed [23:0] s2_prod_i_q  [0:8];
  logic signed [23:0] s2_prod_q_q  [0:8];
  logic               s3_valid_q;
  logic signed [24:0] s3_grp_i_q   [0:2];
  logic signed [24:0] s3_grp_q_q   [0:2];
  logic signed [13:0] mf_i_q;
  logic signed [13:0] mf_q_q;
  logic               mf_strobe_q;
  logic               b1_valid_q;
  logic signed [14:0] i_derot_q;
  logic signed [14:0] q_derot_q;
  logic [7:0]         rx_samp_cnt_q;
  logic [15:0]        rx_phase_q16;
  logic signed [15:0] rx_freq_q16;
  logic [31:0]        rx_nco_fcw_q;
  logic [31:0]        tx_nco_fcw_q;
  logic               carrier_lock_q;
  logic               symbol_lock_q;
  logic [2:0]         rx_bit_cnt_q;
  logic [7:0]         rx_shift_byte_q;
  logic               rx_nrzm_prev_q;

  assign carrier_lock_out       = carrier_lock_q;
  assign symbol_lock_out        = symbol_lock_q;
  assign tx_nco_fcw_out         = tx_nco_fcw_q;
  assign wideband_pn_sample_out = rx_q_in[11:4];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int k = 0; k < 16; k++) begin
        rx_srrc_i_q[k] <= 12'sd0;
        rx_srrc_q_q[k] <= 12'sd0;
      end
      s1_valid_q       <= 1'b0;
      s2_valid_q       <= 1'b0;
      s3_valid_q       <= 1'b0;
      for (int k = 0; k < 9; k++) begin
        s1_sum_i_q[k]  <= 13'sd0;
        s1_sum_q_q[k]  <= 13'sd0;
        s2_prod_i_q[k] <= 24'sd0;
        s2_prod_q_q[k] <= 24'sd0;
      end
      for (int k = 0; k < 3; k++) begin
        s3_grp_i_q[k]  <= 25'sd0;
        s3_grp_q_q[k]  <= 25'sd0;
      end
      mf_i_q           <= 14'sd0;
      mf_q_q           <= 14'sd0;
      mf_strobe_q      <= 1'b0;
      b1_valid_q       <= 1'b0;
      i_derot_q        <= 15'sd0;
      q_derot_q        <= 15'sd0;
      rx_samp_cnt_q    <= 8'd0;
      rx_phase_q16     <= 16'd0;
      rx_freq_q16      <= 16'sd0;
      rx_nco_fcw_q     <= 32'h1000_0000;
      tx_nco_fcw_q     <= 32'h1160_2511;
      carrier_lock_q   <= 1'b0;
      symbol_lock_q    <= 1'b0;
      rx_bit_cnt_q     <= 3'd0;
      rx_shift_byte_q  <= 8'd0;
      rx_nrzm_prev_q   <= 1'b0;
      rx_sym_valid_out <= 1'b0;
      rx_sym_byte_out  <= 8'd0;
    end else begin
      logic [63:0]        prod_q32;
      logic               b1_strobe_now;
      logic [15:0]        base_phase_q16;
      logic signed [15:0] prop_step_s16, int_step_s16, nxt_freq_q16;

      rx_sym_valid_out <= 1'b0;
      s1_valid_q       <= 1'b0;
      s2_valid_q       <= 1'b0;
      s3_valid_q       <= 1'b0;
      mf_strobe_q      <= 1'b0;
      b1_valid_q       <= 1'b0;

      // Decoupled Single-Cycle Q32 Turnaround NCO Multiplier (from registered rx_nco_fcw_q)
      if (turnaround_xband_cfg) begin
        prod_q32     = 64'(rx_nco_fcw_q) * TURNAROUND_XBAND_Q32;
        tx_nco_fcw_q <= prod_q32[63:32];
      end else begin
        prod_q32     = 64'(rx_nco_fcw_q) * TURNAROUND_SBAND_Q32;
        tx_nco_fcw_q <= prod_q32[63:32];
      end

      if (rx_iq_valid_in) begin
        // Shift 17-tap Rx Matched SRRC delay line
        rx_srrc_i_q[0] <= rx_i_in;
        rx_srrc_q_q[0] <= rx_q_in;
        for (int k = 1; k < 16; k++) begin
          rx_srrc_i_q[k] <= rx_srrc_i_q[k - 1];
          rx_srrc_q_q[k] <= rx_srrc_q_q[k - 1];
        end

        if (!srrc_4sps_en_cfg) begin
          rx_samp_cnt_q <= 8'd0;
        end else begin
          logic signed [25:0] acc_mf_i, acc_mf_q;
          rx_samp_cnt_q <= (rx_samp_cnt_q == 8'd19) ? 8'd16 : (rx_samp_cnt_q + 8'd1);

          // Stage A1 (2 CARRY8 levels): Register 9 symmetric folded 13-bit pre-sums
          s1_valid_q    <= (rx_samp_cnt_q >= 8'd16) && (rx_samp_cnt_q[1:0] == 2'd0);
          s1_sum_i_q[0] <= $signed({rx_i_in[11], rx_i_in})               + $signed({rx_srrc_i_q[15][11], rx_srrc_i_q[15]});
          s1_sum_i_q[1] <= $signed({rx_srrc_i_q[0][11], rx_srrc_i_q[0]}) + $signed({rx_srrc_i_q[14][11], rx_srrc_i_q[14]});
          s1_sum_i_q[2] <= $signed({rx_srrc_i_q[1][11], rx_srrc_i_q[1]}) + $signed({rx_srrc_i_q[13][11], rx_srrc_i_q[13]});
          s1_sum_i_q[3] <= $signed({rx_srrc_i_q[2][11], rx_srrc_i_q[2]}) + $signed({rx_srrc_i_q[12][11], rx_srrc_i_q[12]});
          s1_sum_i_q[4] <= $signed({rx_srrc_i_q[3][11], rx_srrc_i_q[3]}) + $signed({rx_srrc_i_q[11][11], rx_srrc_i_q[11]});
          s1_sum_i_q[5] <= $signed({rx_srrc_i_q[4][11], rx_srrc_i_q[4]}) + $signed({rx_srrc_i_q[10][11], rx_srrc_i_q[10]});
          s1_sum_i_q[6] <= $signed({rx_srrc_i_q[5][11], rx_srrc_i_q[5]}) + $signed({rx_srrc_i_q[9][11],  rx_srrc_i_q[9]});
          s1_sum_i_q[7] <= $signed({rx_srrc_i_q[6][11], rx_srrc_i_q[6]}) + $signed({rx_srrc_i_q[8][11],  rx_srrc_i_q[8]});
          s1_sum_i_q[8] <= $signed({rx_srrc_i_q[7][11], rx_srrc_i_q[7]});

          s1_sum_q_q[0] <= $signed({rx_q_in[11], rx_q_in})               + $signed({rx_srrc_q_q[15][11], rx_srrc_q_q[15]});
          s1_sum_q_q[1] <= $signed({rx_srrc_q_q[0][11], rx_srrc_q_q[0]}) + $signed({rx_srrc_q_q[14][11], rx_srrc_q_q[14]});
          s1_sum_q_q[2] <= $signed({rx_srrc_q_q[1][11], rx_srrc_q_q[1]}) + $signed({rx_srrc_q_q[13][11], rx_srrc_q_q[13]});
          s1_sum_q_q[3] <= $signed({rx_srrc_q_q[2][11], rx_srrc_q_q[2]}) + $signed({rx_srrc_q_q[12][11], rx_srrc_q_q[12]});
          s1_sum_q_q[4] <= $signed({rx_srrc_q_q[3][11], rx_srrc_q_q[3]}) + $signed({rx_srrc_q_q[11][11], rx_srrc_q_q[11]});
          s1_sum_q_q[5] <= $signed({rx_srrc_q_q[4][11], rx_srrc_q_q[4]}) + $signed({rx_srrc_q_q[10][11], rx_srrc_q_q[10]});
          s1_sum_q_q[6] <= $signed({rx_srrc_q_q[5][11], rx_srrc_q_q[5]}) + $signed({rx_srrc_q_q[9][11],  rx_srrc_q_q[9]});
          s1_sum_q_q[7] <= $signed({rx_srrc_q_q[6][11], rx_srrc_q_q[6]}) + $signed({rx_srrc_q_q[8][11],  rx_srrc_q_q[8]});
          s1_sum_q_q[8] <= $signed({rx_srrc_q_q[7][11], rx_srrc_q_q[7]});

          // Stage A2 (<= 4 CARRY8 levels): Register 9 multiplier-free CSD shift-add products
          s2_valid_q <= s1_valid_q;
          for (int k = 0; k < 9; k++) begin
            s2_prod_i_q[k] <= csd_srrc_tap(s1_sum_i_q[k], k);
            s2_prod_q_q[k] <= csd_srrc_tap(s1_sum_q_q[k], k);
          end

          // Stage A3 (<= 4 CARRY8 levels): Register three 3-input partial group sums
          s3_valid_q    <= s2_valid_q;
          s3_grp_i_q[0] <= ($signed({s2_prod_i_q[0][23], s2_prod_i_q[0]}) + $signed({s2_prod_i_q[1][23], s2_prod_i_q[1]})) +
                            $signed({s2_prod_i_q[2][23], s2_prod_i_q[2]});
          s3_grp_i_q[1] <= ($signed({s2_prod_i_q[3][23], s2_prod_i_q[3]}) + $signed({s2_prod_i_q[4][23], s2_prod_i_q[4]})) +
                            $signed({s2_prod_i_q[5][23], s2_prod_i_q[5]});
          s3_grp_i_q[2] <= ($signed({s2_prod_i_q[6][23], s2_prod_i_q[6]}) + $signed({s2_prod_i_q[7][23], s2_prod_i_q[7]})) +
                            $signed({s2_prod_i_q[8][23], s2_prod_i_q[8]});

          s3_grp_q_q[0] <= ($signed({s2_prod_q_q[0][23], s2_prod_q_q[0]}) + $signed({s2_prod_q_q[1][23], s2_prod_q_q[1]})) +
                            $signed({s2_prod_q_q[2][23], s2_prod_q_q[2]});
          s3_grp_q_q[1] <= ($signed({s2_prod_q_q[3][23], s2_prod_q_q[3]}) + $signed({s2_prod_q_q[4][23], s2_prod_q_q[4]})) +
                            $signed({s2_prod_q_q[5][23], s2_prod_q_q[5]});
          s3_grp_q_q[2] <= ($signed({s2_prod_q_q[6][23], s2_prod_q_q[6]}) + $signed({s2_prod_q_q[7][23], s2_prod_q_q[7]})) +
                            $signed({s2_prod_q_q[8][23], s2_prod_q_q[8]});

          // Stage A4 (<= 4 CARRY8 levels): Final 3-input sum into mf_i_q / mf_q_q
          mf_strobe_q <= s3_valid_q;
          acc_mf_i    = ($signed({s3_grp_i_q[0][24], s3_grp_i_q[0]}) + $signed({s3_grp_i_q[1][24], s3_grp_i_q[1]})) +
                         $signed({s3_grp_i_q[2][24], s3_grp_i_q[2]});
          acc_mf_q    = ($signed({s3_grp_q_q[0][24], s3_grp_q_q[0]}) + $signed({s3_grp_q_q[1][24], s3_grp_q_q[1]})) +
                         $signed({s3_grp_q_q[2][24], s3_grp_q_q[2]});
          mf_i_q      <= $signed(acc_mf_i[24:11]);
          mf_q_q      <= $signed(acc_mf_q[24:11]);
        end
      end

      // Pipeline Stage B1 (<= 6 logic levels): One's-Complement Wire-Mux Q3 CSD Complex NCO Derotator
      b1_strobe_now = srrc_4sps_en_cfg ? mf_strobe_q : rx_iq_valid_in;
      if (b1_strobe_now) begin
        logic signed [13:0] raw_i, raw_q;
        logic signed [10:0] in_i11, in_q11;
        logic [5:0]         nco_idx;
        logic signed [4:0]  c_rx, s_rx;

        raw_i      = srrc_4sps_en_cfg ? mf_i_q : $signed({{2{rx_i_in[11]}}, rx_i_in});
        raw_q      = srrc_4sps_en_cfg ? mf_q_q : $signed({{2{rx_q_in[11]}}, rx_q_in});
        in_i11     = $signed(raw_i[13:3]);
        in_q11     = $signed(raw_q[13:3]);
        nco_idx    = rx_phase_q16[15:10];
        c_rx       = COS_LUT_Q3[nco_idx];
        s_rx       = SIN_LUT_Q3[nco_idx];
        i_derot_q  <= mul_q3_ones_comp_mux(in_i11, c_rx) + mul_q3_ones_comp_mux(in_q11, s_rx);
        q_derot_q  <= mul_q3_ones_comp_mux(in_q11, c_rx) - mul_q3_ones_comp_mux(in_i11, s_rx);
        b1_valid_q <= 1'b1;
      end

      // Pipeline Stage B2 (<= 5 logic levels): Carry-Free XOR Costas Phase Detector + PI Loop + Slicer
      base_phase_q16 = rx_phase_q16 + (b1_strobe_now ? 16'(rx_freq_q16) : 16'd0);
      if (b1_valid_q) begin
        logic signed [14:0] term_i, term_q, phase_err;
        logic signed [15:0] phase_err_s16;
        logic               sliced_bit;
        logic               decoded_bit;

        term_i = i_derot_q[14] ? ~q_derot_q : q_derot_q;
        term_q = q_derot_q[14] ? ~i_derot_q : i_derot_q;
        if ((mod_mode_cfg == 2'd0) && !pn_ranging_en_cfg) begin
          phase_err = term_i;
        end else begin
          phase_err = (term_i - term_q) >>> 1;
        end

        phase_err_s16 = $signed({phase_err[14], phase_err});
        int_step_s16  = phase_err_s16 >>> 2;
        prop_step_s16 = phase_err_s16 <<< 1;
        nxt_freq_q16  = rx_freq_q16 + int_step_s16;
        rx_freq_q16   <= nxt_freq_q16;
        rx_phase_q16  <= base_phase_q16 + 16'(prop_step_s16);
        rx_nco_fcw_q  <= 32'h1000_0000 + {{16{nxt_freq_q16[15]}}, nxt_freq_q16};

        if ((i_derot_q > 15'sd64) || (i_derot_q < -15'sd64)) begin
          carrier_lock_q <= 1'b1;
          symbol_lock_q  <= 1'b1;
        end

        sliced_bit = !i_derot_q[14];
        case (line_code_cfg)
          2'd1:    decoded_bit = sliced_bit ^ rx_nrzm_prev_q; // NRZ-M differential decode
          2'd2:    decoded_bit = ~sliced_bit;                 // Bi-Phi-L Manchester decode
          default: decoded_bit = sliced_bit;                  // NRZ-L decode
        endcase
        rx_nrzm_prev_q  <= sliced_bit;
        rx_shift_byte_q <= {rx_shift_byte_q[6:0], decoded_bit};

        if (rx_bit_cnt_q == 3'd7) begin
          rx_bit_cnt_q     <= 3'd0;
          rx_sym_valid_out <= 1'b1;
          rx_sym_byte_out  <= {rx_shift_byte_q[6:0], decoded_bit};
        end else begin
          rx_bit_cnt_q <= rx_bit_cnt_q + 3'd1;
        end
      end else if (b1_strobe_now) begin
        rx_phase_q16 <= base_phase_q16;
      end
    end
  end

  // ---------------------------------------------------------------------------
  // 2-Stage Pipelined Downlink Modulator & 17-Tap Polyphase SRRC Filter (CR-28)
  //   - Tx Stage 1 (<= 3 logic levels):
  //       * Path A (2 LUT levels): tx_cur_byte_q[tx_bit_idx_q] -> tx_sym_i_hist_q[0], tx_sym_q_hist_q[0]
  //       * Path B (1 LUT6 + 2 CARRY8 = 3 levels): tx_sym_i_hist_q[0..4] -> tx_hist_sum_i_q, tx_hist_sum_q_q
  //   - Tx Stage 2 (1 LUT4 + 2 CARRY8 = 3 logic levels):
  //       * tx_tap0_lut4(tx_pipe_phase_q, tx_sym_i_hist_q[0]) + tx_hist_sum_i_q -> tx_i_out, tx_q_out
  // ---------------------------------------------------------------------------
  logic [7:0]         tx_cur_byte_q;
  logic [2:0]         tx_bit_idx_q;
  logic [1:0]         tx_sps_phase_q;
  logic               tx_busy_q;
  logic               nrzm_prev_q;
  logic               oqpsk_q_delay_q;
  logic [1:0]         tx_sym_i_hist_q [0:4]; // 2'd0 = 0, 2'd1 = +1, 2'd2 = -1
  logic [1:0]         tx_sym_q_hist_q [0:4];
  logic               tx_pipe_valid_q;
  logic [1:0]         tx_pipe_phase_q;
  logic signed [11:0] tx_hist_sum_i_q;
  logic signed [11:0] tx_hist_sum_q_q;

  assign s_axis_tx_tready = !tx_busy_q && !tx_pipe_valid_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx_cur_byte_q   <= 8'd0;
      tx_bit_idx_q    <= 3'd0;
      tx_sps_phase_q  <= 2'd0;
      tx_busy_q       <= 1'b0;
      nrzm_prev_q     <= 1'b0;
      oqpsk_q_delay_q <= 1'b0;
      for (int k = 0; k < 5; k++) begin
        tx_sym_i_hist_q[k] <= 2'd0;
        tx_sym_q_hist_q[k] <= 2'd0;
      end
      tx_pipe_valid_q <= 1'b0;
      tx_pipe_phase_q <= 2'd0;
      tx_hist_sum_i_q <= 12'sd0;
      tx_hist_sum_q_q <= 12'sd0;
      tx_i_out        <= 12'sd0;
      tx_q_out        <= 12'sd0;
      tx_iq_valid_out <= 1'b0;
    end else begin
      tx_iq_valid_out <= 1'b0;
      tx_pipe_valid_q <= 1'b0;

      // Tx Stage 2 (3 logic levels: 1 LUT4 + 2 CARRY8): Add Tap 0 to pre-summed history taps 1..4
      if (tx_pipe_valid_q) begin
        tx_i_out        <= tx_tap0_lut4(tx_pipe_phase_q, tx_sym_i_hist_q[0]) + tx_hist_sum_i_q;
        tx_q_out        <= tx_tap0_lut4(tx_pipe_phase_q, tx_sym_q_hist_q[0]) + tx_hist_sum_q_q;
        tx_iq_valid_out <= 1'b1;
      end

      if (!tx_busy_q) begin
        if (s_axis_tx_tvalid && !tx_pipe_valid_q) begin
          tx_cur_byte_q  <= s_axis_tx_tdata;
          tx_bit_idx_q   <= 3'd7;
          tx_sps_phase_q <= 2'd0;
          tx_busy_q      <= 1'b1;
        end
      end else if (!srrc_4sps_en_cfg) begin
        // 1-SPS Rectangular Symbol Mode (2 LUT levels directly to tx_i_out / tx_q_out)
        logic raw_bit;
        logic coded_bit;
        logic q_bit;
        raw_bit = tx_cur_byte_q[tx_bit_idx_q];
        case (line_code_cfg)
          2'd1:    coded_bit = raw_bit ^ nrzm_prev_q;
          2'd2:    coded_bit = raw_bit ^ 1'b1;
          default: coded_bit = raw_bit;
        endcase
        nrzm_prev_q     <= coded_bit;
        q_bit           = pn_ranging_en_cfg ? tx_pn_chip_in : ((mod_mode_cfg == 2'd2) ? oqpsk_q_delay_q : coded_bit);
        oqpsk_q_delay_q <= coded_bit;

        tx_i_out        <= coded_bit ? 12'sd1024 : -12'sd1024;
        tx_q_out        <= (mod_mode_cfg == 2'd0 && !pn_ranging_en_cfg) ? 12'sd0 : (q_bit ? 12'sd1024 : -12'sd1024);
        tx_iq_valid_out <= 1'b1;

        if (tx_bit_idx_q == 3'd0) begin
          tx_busy_q <= 1'b0;
        end else begin
          tx_bit_idx_q <= tx_bit_idx_q - 3'd1;
        end
      end else begin
        // Tx Stage 1 (<= 3 logic levels):
        //   - Path A: Shift new symbol into tx_sym_i_hist_q[0], tx_sym_q_hist_q[0] (2 LUT levels)
        //   - Path B: Pre-sum history taps 1..4 from already-registered tx_sym_i_hist_q (1 LUT6 + 2 CARRY8)
        logic [1:0] h_i [1:4];
        logic [1:0] h_q [1:4];

        if (tx_sps_phase_q == 2'd0) begin
          logic raw_bit, coded_bit, q_bit;
          raw_bit = tx_cur_byte_q[tx_bit_idx_q];
          case (line_code_cfg)
            2'd1:    coded_bit = raw_bit ^ nrzm_prev_q;
            2'd2:    coded_bit = raw_bit ^ 1'b1;
            default: coded_bit = raw_bit;
          endcase
          nrzm_prev_q     <= coded_bit;
          q_bit           = pn_ranging_en_cfg ? tx_pn_chip_in : ((mod_mode_cfg == 2'd2) ? oqpsk_q_delay_q : coded_bit);
          oqpsk_q_delay_q <= coded_bit;

          tx_sym_i_hist_q[0] <= coded_bit ? 2'd1 : 2'd2;
          tx_sym_q_hist_q[0] <= (mod_mode_cfg == 2'd0 && !pn_ranging_en_cfg) ? 2'd0 : (q_bit ? 2'd1 : 2'd2);
          for (int k = 1; k < 5; k++) begin
            tx_sym_i_hist_q[k] <= tx_sym_i_hist_q[k - 1];
            tx_sym_q_hist_q[k] <= tx_sym_q_hist_q[k - 1];
            h_i[k]              = tx_sym_i_hist_q[k - 1];
            h_q[k]              = tx_sym_q_hist_q[k - 1];
          end
        end else begin
          for (int k = 1; k < 5; k++) begin
            h_i[k] = tx_sym_i_hist_q[k];
            h_q[k] = tx_sym_q_hist_q[k];
          end
        end

        tx_hist_sum_i_q <= tx_pair12_lut6(tx_sps_phase_q, h_i[1], h_i[2]) +
                           tx_pair34_lut6(tx_sps_phase_q, h_i[3], h_i[4]);
        tx_hist_sum_q_q <= tx_pair12_lut6(tx_sps_phase_q, h_q[1], h_q[2]) +
                           tx_pair34_lut6(tx_sps_phase_q, h_q[3], h_q[4]);
        tx_pipe_phase_q <= tx_sps_phase_q;
        tx_pipe_valid_q <= 1'b1;

        if (tx_sps_phase_q == 2'd3) begin
          tx_sps_phase_q <= 2'd0;
          if (tx_bit_idx_q == 3'd0) begin
            tx_busy_q <= 1'b0;
          end else begin
            tx_bit_idx_q <= tx_bit_idx_q - 3'd1;
          end
        end else begin
          tx_sps_phase_q <= tx_sps_phase_q + 2'd1;
        end
      end
    end
  end

endmodule : ccsds_phy_modem
