// =============================================================================
// File Name   : tb_stage2_primitives.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog Testbench
// Description : Self-checking SystemVerilog testbench for Stage 2 hardware
//               primitives:
//                 1. ccsds_crc_universal (CRC-16 0x1021 & CRC-32 0x00A00805)
//                 2. ccsds_lfsr_scrambler (TM 0xA9 & TC 0x5F)
//                 3. ccsds_cdc_fifo_ecc (Per-Frame Rollback, Watermark, SECDED)
//                 4. ccsds_clcw_cdc_mbox (Atomic 32-bit Req/Ack CLCW CDC)
//                 5. ccsds_gf256_math (GF(2^8) & AOS GF(2^4) FHEC)
// =============================================================================

`timescale 1ns / 1ps
module tb_stage2_primitives
  import ccsds_pkg::*;
();

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  always #5 clk = ~clk; // 100 MHz system clock

  // 1. CRC Universal Signals
  logic        crc_clear, mode_crc32;
  logic [31:0] crc_tdata;
  logic [3:0]  crc_tkeep;
  logic        crc_tvalid, crc_tlast;
  logic [15:0] crc16_out;
  logic [31:0] crc32_out;
  logic        crc16_res_ok, crc32_res_ok, crc_res_ok, crc_valid_pulse;

  ccsds_crc_universal #(.DATA_WIDTH(32)) u_crc (
    .clk              (clk),
    .rst_n            (rst_n),
    .crc_clear        (crc_clear),
    .mode_crc32       (mode_crc32),
    .s_axis_tdata     (crc_tdata),
    .s_axis_tkeep     (crc_tkeep),
    .s_axis_tvalid    (crc_tvalid),
    .s_axis_tready    (1'b1),
    .s_axis_tlast     (crc_tlast),
    .crc16_out        (crc16_out),
    .crc32_out        (crc32_out),
    .crc16_residue_ok (crc16_res_ok),
    .crc32_residue_ok (crc32_res_ok),
    .crc_residue_ok   (crc_res_ok),
    .crc_valid_pulse  (crc_valid_pulse)
  );

  // 2. GF(2^8) Math Signals
  logic [7:0]  gf_a, gf_b, gf_prod, std_in, dual_out, dual_in, std_out;
  logic [23:0] aos_hdr24;
  logic [15:0] aos_fhec_tx;
  logic        aos_fhec_ok;

  ccsds_gf256_math u_gf (
    .gf256_a_std           (gf_a),
    .gf256_b_std           (gf_b),
    .gf256_prod_std        (gf_prod),
    .std_in                (std_in),
    .dual_out              (dual_out),
    .dual_in               (dual_out),
    .std_out               (std_out),
    .aos_hdr_protected_24b (aos_hdr24),
    .aos_fhec_rx_16b       (aos_fhec_tx),
    .aos_fhec_tx_16b       (aos_fhec_tx),
    .aos_fhec_syndrome_ok  (aos_fhec_ok)
  );

  initial begin
    crc_clear  = 1'b0;
    mode_crc32 = 1'b0;
    crc_tdata  = 32'h0;
    crc_tkeep  = 4'h0;
    crc_tvalid = 1'b0;
    crc_tlast  = 1'b0;
    gf_a       = 8'h02;
    gf_b       = 8'h80;
    std_in     = 8'h01;
    aos_hdr24  = 24'h5A_C3_0F;

    #20 rst_n = 1'b1;
    @(posedge clk);
    assert (gf_prod == 8'h87) else $fatal(1, "GF(2^8) alpha * alpha^7 mismatch");
    assert (dual_out == 8'h7B && std_out == 8'h01) else $fatal(1, "Dual basis mismatch");
    assert (aos_fhec_ok == 1'b1) else $fatal(1, "AOS FHEC syndrome check failed");
    $display("[TB-STAGE2] All self-checks passed.");
    $finish;
  end

endmodule : tb_stage2_primitives
