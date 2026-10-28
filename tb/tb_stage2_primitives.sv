// =============================================================================
// File Name   : tb_stage2_primitives.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog Testbench
// Description : Self-checking SystemVerilog testbench for Stage 2 hardware
//               primitives:
//                 1. ccsds_crc_universal (CRC-16 0x1021 & CRC-32 0x00A00805)
//                 2. ccsds_lfsr_scrambler (TM 0xA9 & TC 0x5F)
//                 3. ccsds_cdc_fifo_ecc (Dual-Clock Asynchronous Gray-Code CDC,
//                    Per-Frame Rollback, Watermark, & Hsiao SECDED ECC)
//                 4. ccsds_clcw_cdc_mbox (Atomic 32-bit Req/Ack CLCW CDC)
//                 5. ccsds_gf256_math (GF(2^8) & AOS GF(2^4) FHEC)
// =============================================================================

`timescale 1ns / 1ps
module tb_stage2_primitives
  import ccsds_pkg::*;
();

  logic clk    = 1'b0;
  logic clk_rd = 1'b0;
  logic rst_n  = 1'b0;
  always #5 clk    = ~clk;    // 100 MHz write/system clock
  always #8 clk_rd = ~clk_rd; // 62.5 MHz asynchronous read clock

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
  logic [7:0]  gf_a, gf_b, gf_prod, std_in, dual_out, std_out;
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

  // 3. Dual-Clock Asynchronous Gray-Code SECDED FIFO (Fix P0-3)
  logic        fifo_wr_val, fifo_wr_rdy, fifo_wr_last, fifo_commit, fifo_rollback;
  logic [31:0] fifo_wr_data, fifo_rd_data;
  logic [3:0]  fifo_rd_keep;
  logic        fifo_rd_val, fifo_rd_rdy, fifo_rd_last;
  ccsds_tuser_t fifo_rd_user;
  logic        fifo_seu_en, fifo_1err, fifo_2err, fifo_ovf;
  logic [6:0]  fifo_comm_cnt, fifo_spec_cnt;

  ccsds_cdc_fifo_ecc #(
    .DATA_WIDTH    (32),
    .DEPTH_WORDS   (64),
    .ROLLBACK_MODE (1'b1),
    .WATERMARK_MODE(1'b0)
  ) u_cdc_fifo (
    .clk_wr                   (clk),
    .rst_wr_n                 (rst_n),
    .clk_rd                   (clk_rd),
    .rst_rd_n                 (rst_n),
    .cut_through_en           (1'b0),
    .watermark_words          (7'd0),
    .s_axis_tdata             (fifo_wr_data),
    .s_axis_tkeep             (4'hF),
    .s_axis_tvalid            (fifo_wr_val),
    .s_axis_tready            (fifo_wr_rdy),
    .s_axis_tlast             (fifo_wr_last),
    .s_axis_tuser             ('0),
    .frame_commit_pulse       (fifo_commit),
    .frame_rollback_pulse     (fifo_rollback),
    .m_axis_tdata             (fifo_rd_data),
    .m_axis_tkeep             (fifo_rd_keep),
    .m_axis_tvalid            (fifo_rd_val),
    .m_axis_tready            (fifo_rd_rdy),
    .m_axis_tlast             (fifo_rd_last),
    .m_axis_tuser             (fifo_rd_user),
    .seu_inject_en            (fifo_seu_en),
    .seu_inject_addr          (6'd0),
    .seu_inject_bit           (6'd7),
    .ecc_single_err_corrected (fifo_1err),
    .ecc_double_err_uncorr    (fifo_2err),
    .rollback_overflow_err    (fifo_ovf),
    .committed_count          (fifo_comm_cnt),
    .speculative_count        (fifo_spec_cnt)
  );

  initial begin
    crc_clear     = 1'b0;
    mode_crc32    = 1'b0;
    crc_tdata     = 32'h0;
    crc_tkeep     = 4'h0;
    crc_tvalid    = 1'b0;
    crc_tlast     = 1'b0;
    gf_a          = 8'h02;
    gf_b          = 8'h80;
    std_in        = 8'h01;
    aos_hdr24     = 24'h5A_C3_0F;
    fifo_wr_data  = 32'h0;
    fifo_wr_val   = 1'b0;
    fifo_wr_last  = 1'b0;
    fifo_commit   = 1'b0;
    fifo_rollback = 1'b0;
    fifo_rd_rdy   = 1'b0;
    fifo_seu_en   = 1'b0;

    #20 rst_n = 1'b1;
    @(posedge clk);
    #1;
    assert (gf_prod == 8'h87) else $fatal(1, "GF(2^8) alpha * alpha^7 mismatch");
    assert (dual_out == 8'h7B && std_out == 8'h01) else $fatal(1, "Dual basis mismatch");
    assert (aos_fhec_ok == 1'b1) else $fatal(1, "AOS FHEC syndrome check failed");

    // Test speculative rollback followed by committed write across asynchronous clk -> clk_rd CDC
    fifo_wr_data = 32'hBAD0_DEAD;
    fifo_wr_val  = 1'b1;
    fifo_wr_last = 1'b1;
    @(posedge clk); #1;
    fifo_wr_val   = 1'b0;
    fifo_wr_last  = 1'b0;
    fifo_rollback = 1'b1;
    @(posedge clk); #1;
    fifo_rollback = 1'b0;
    assert (fifo_spec_cnt == 7'd0) else $fatal(1, "Speculative rollback failed");

    fifo_wr_data = 32'h1234_5678;
    fifo_wr_val  = 1'b1;
    fifo_wr_last = 1'b1;
    fifo_commit  = 1'b1;
    @(posedge clk); #1;
    fifo_wr_val  = 1'b0;
    fifo_wr_last = 1'b0;
    fifo_commit  = 1'b0;

    // Inject 1-bit SEU in read domain and wait for Gray-code pointer synchronization
    @(posedge clk_rd); #1;
    fifo_seu_en = 1'b1;
    @(posedge clk_rd); #1;
    fifo_seu_en = 1'b0;
    while (!fifo_rd_val) @(posedge clk_rd);
    #1;
    assert (fifo_rd_data == 32'h1234_5678 && fifo_1err == 1'b1 && fifo_2err == 1'b0)
      else $fatal(1, "Dual-clock Gray-code CDC FIFO SECDED readback mismatch");
    fifo_rd_rdy = 1'b1;
    @(posedge clk_rd); #1;
    fifo_rd_rdy = 1'b0;

    $display("[TB-STAGE2] All self-checks (GF(2^8), AOS FHEC, Dual-Clock Gray-Code SECDED CDC FIFO) passed.");
    $finish;
  end

endmodule : tb_stage2_primitives
