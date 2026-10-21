//=============================================================================
// File Name   : ccsds_pn_ranging.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : CCSDS 414.1-B-3 (Pseudo-Noise (PN) Ranging Systems)
// Description : Wideband T2B / T4B Weighted-Voting Balanced PN Ranging
//               Correlator & Regenerative Turnaround Generator:
//                 - 6-Component PN Code Bank (Lengths L1=2, L2=7, L3=11,
//                   L4=15, L5=19, L6=23; Total Composite Period = 1,009,470 chips)
//                 - Selectable T4B (4*C1 + C2 + C3 + C4 + C5 + C6) or
//                   T2B (2*C1 + C2 + C3 + C4 + C5 + C6) weighted majority vote
//                 - Parallel component phase correlators with lock threshold
//                   detector and clean regenerative chip alignment onto Tx
//=============================================================================
`timescale 1ns / 1ps

module ccsds_pn_ranging
  import ccsds_pkg::*;
#(
  parameter logic [15:0] LOCK_THRESHOLD = 16'd64
) (
  input  logic               clk,
  input  logic               rst_n,

  // Control & Mode Configuration
  input  logic               pn_ranging_en_cfg,
  input  logic               t4b_mode_cfg,
  input  logic               chip_en_in,

  // Wideband Rx Phase-Error Input from Costas Loop (Bypasses Narrowband TC Path)
  input  logic signed [7:0]  rx_chip_sample_in,

  // Regenerated Clean PN Chip Output to Downlink Phase Modulator
  output logic                     tx_pn_chip_out,
  output logic                     pn_c1_locked_out,
  output logic                     pn_all_locked_out,
  output logic [19:0]              composite_epoch_idx_out
);

  localparam logic [1:0]  SEQ_C1 = 2'b10;
  localparam logic [6:0]  SEQ_C2 = 7'b1110010;
  localparam logic [10:0] SEQ_C3 = 11'b11100010110;
  localparam logic [14:0] SEQ_C4 = 15'b111100010011010;
  localparam logic [18:0] SEQ_C5 = 19'b1111010100001101100;
  localparam logic [22:0] SEQ_C6 = 23'b11111010110011001010000;

  logic [0:0]  idx_c1_q;
  logic [2:0]  idx_c2_q;
  logic [3:0]  idx_c3_q;
  logic [3:0]  idx_c4_q;
  logic [4:0]  idx_c5_q;
  logic [4:0]  idx_c6_q;
  logic [19:0] composite_idx_q;

  logic signed [15:0] corr_c1_q, corr_c2_q, corr_c3_q, corr_c4_q, corr_c5_q, corr_c6_q;
  logic               c1_lock_q, all_lock_q;

  logic c1_bit, c2_bit, c3_bit, c4_bit, c5_bit, c6_bit;
  assign c1_bit = SEQ_C1[1 - idx_c1_q];
  assign c2_bit = SEQ_C2[6 - idx_c2_q];
  assign c3_bit = SEQ_C3[10 - idx_c3_q];
  assign c4_bit = SEQ_C4[14 - idx_c4_q];
  assign c5_bit = SEQ_C5[18 - idx_c5_q];
  assign c6_bit = SEQ_C6[22 - idx_c6_q];

  always_comb begin
    int signed vote_sum;
    int signed w1;
    w1       = t4b_mode_cfg ? 4 : 2;
    vote_sum = (c1_bit ? w1 : -w1)
             + (c2_bit ? 1 : -1)
             + (c3_bit ? 1 : -1)
             + (c4_bit ? 1 : -1)
             + (c5_bit ? 1 : -1)
             + (c6_bit ? 1 : -1);
    tx_pn_chip_out = (vote_sum >= 0);
  end

  assign pn_c1_locked_out        = c1_lock_q;
  assign pn_all_locked_out       = all_lock_q;
  assign composite_epoch_idx_out = composite_idx_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      idx_c1_q        <= 1'd0;
      idx_c2_q        <= 3'd0;
      idx_c3_q        <= 4'd0;
      idx_c4_q        <= 4'd0;
      idx_c5_q        <= 5'd0;
      idx_c6_q        <= 5'd0;
      composite_idx_q <= 20'd0;
      corr_c1_q       <= 16'sd0;
      corr_c2_q       <= 16'sd0;
      corr_c3_q       <= 16'sd0;
      corr_c4_q       <= 16'sd0;
      corr_c5_q       <= 16'sd0;
      corr_c6_q       <= 16'sd0;
      c1_lock_q       <= 1'b0;
      all_lock_q      <= 1'b0;
    end else if (!pn_ranging_en_cfg) begin
      idx_c1_q        <= 1'd0;
      idx_c2_q        <= 3'd0;
      idx_c3_q        <= 4'd0;
      idx_c4_q        <= 4'd0;
      idx_c5_q        <= 5'd0;
      idx_c6_q        <= 5'd0;
      composite_idx_q <= 20'd0;
      corr_c1_q       <= 16'sd0;
      corr_c2_q       <= 16'sd0;
      corr_c3_q       <= 16'sd0;
      corr_c4_q       <= 16'sd0;
      corr_c5_q       <= 16'sd0;
      corr_c6_q       <= 16'sd0;
      c1_lock_q       <= 1'b0;
      all_lock_q      <= 1'b0;
    end else if (chip_en_in) begin
      logic signed [15:0] samp_ext;
      samp_ext = {{8{rx_chip_sample_in[7]}}, rx_chip_sample_in};

      idx_c1_q        <= (idx_c1_q == 1'd1)  ? 1'd0 : (idx_c1_q + 1'd1);
      idx_c2_q        <= (idx_c2_q == 3'd6)  ? 3'd0 : (idx_c2_q + 3'd1);
      idx_c3_q        <= (idx_c3_q == 4'd10) ? 4'd0 : (idx_c3_q + 4'd1);
      idx_c4_q        <= (idx_c4_q == 4'd14) ? 4'd0 : (idx_c4_q + 4'd1);
      idx_c5_q        <= (idx_c5_q == 5'd18) ? 5'd0 : (idx_c5_q + 5'd1);
      idx_c6_q        <= (idx_c6_q == 5'd22) ? 5'd0 : (idx_c6_q + 5'd1);
      composite_idx_q <= (composite_idx_q == 20'd1009469) ? 20'd0 : (composite_idx_q + 20'd1);

      corr_c1_q <= corr_c1_q + (c1_bit ? samp_ext : -samp_ext);
      corr_c2_q <= corr_c2_q + (c2_bit ? samp_ext : -samp_ext);
      corr_c3_q <= corr_c3_q + (c3_bit ? samp_ext : -samp_ext);
      corr_c4_q <= corr_c4_q + (c4_bit ? samp_ext : -samp_ext);
      corr_c5_q <= corr_c5_q + (c5_bit ? samp_ext : -samp_ext);
      corr_c6_q <= corr_c6_q + (c6_bit ? samp_ext : -samp_ext);

      if (corr_c1_q >= $signed(LOCK_THRESHOLD)) begin
        c1_lock_q <= 1'b1;
      end
      if ((corr_c1_q >= $signed(LOCK_THRESHOLD)) &&
          (corr_c2_q >= $signed(LOCK_THRESHOLD >> 2)) &&
          (corr_c3_q >= $signed(LOCK_THRESHOLD >> 2)) &&
          (corr_c4_q >= $signed(LOCK_THRESHOLD >> 2)) &&
          (corr_c5_q >= $signed(LOCK_THRESHOLD >> 2)) &&
          (corr_c6_q >= $signed(LOCK_THRESHOLD >> 2))) begin
        all_lock_q <= 1'b1;
      end
    end
  end

endmodule
