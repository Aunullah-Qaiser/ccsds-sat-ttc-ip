// =============================================================================
// File Name   : ccsds_cdc_fifo_ecc.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog (Synthesizable)
// Description : Parameterized Dual-Clock Asynchronous AXI4-Stream Store-and-
//               Forward Packet FIFO with Speculative Write Pointer, Per-Frame
//               CRC/BCH/SDLS Commit & Rollback, High-Watermark Downlink
//               Underflow Guard, and (39,32) Hsiao SECDED ECC Protection:
//                 - True dual-clock CDC (clk_wr / clk_rd) using binary-to-Gray
//                   pointer conversion and 2-stage (* ASYNC_REG = "TRUE" *)
//                   synchronizer chains across write and read domains (Fix P0-3),
//                   with Gray-to-binary decoding pipelined into the 2nd sync
//                   stage (`wr_bin_sync2_rd_q`, `rd_bin_sync2_wr_q`) for high
//                   Fmax closure on clk_sys and clk_tx_sym.
//                 - Dedicated synchronous RAM write block (`always_ff @(posedge clk_wr)`
//                   without async reset sensitivity) guaranteeing true Xilinx
//                   RAM64M Distributed LUTRAM inference instead of FF arrays.
//                 - Generate-guarded width adaptation for DATA_WIDTH < 32,
//                   DATA_WIDTH == 32, and DATA_WIDTH > 32 with zero out-of-bounds
//                   part-select warnings during elaboration (Fix P2-1) and
//                   width-bounded SECDED syndrome trees (`ECC_DATA_BITS`).
// =============================================================================
`timescale 1ns / 1ps

module ccsds_cdc_fifo_ecc
  import ccsds_pkg::*;
#(
  parameter int unsigned DATA_WIDTH     = 32,
  parameter int unsigned DEPTH_WORDS    = 512,
  parameter bit          ROLLBACK_MODE  = 1'b1,
  parameter bit          WATERMARK_MODE = 1'b0,
  parameter int unsigned ADDR_W         = $clog2(DEPTH_WORDS)
) (
  input  logic                     clk_wr,
  input  logic                     rst_wr_n,
  input  logic                     clk_rd,
  input  logic                     rst_rd_n,

  // Runtime Configuration
  input  logic                     cut_through_en,
  input  logic [ADDR_W:0]          watermark_words,

  // AXI4-Stream Slave (Write / Ingress Domain: clk_wr)
  input  logic [DATA_WIDTH-1:0]    s_axis_tdata,
  input  logic [DATA_WIDTH/8-1:0]  s_axis_tkeep,
  input  logic                     s_axis_tvalid,
  output logic                     s_axis_tready,
  input  logic                     s_axis_tlast,
  input  ccsds_tuser_t             s_axis_tuser,

  // Per-Frame Two-Phase Commit / Rollback Strobes (Write Domain: clk_wr)
  input  logic                     frame_commit_pulse,
  input  logic                     frame_rollback_pulse,

  // AXI4-Stream Master (Read / Egress Domain: clk_rd)
  output logic [DATA_WIDTH-1:0]    m_axis_tdata,
  output logic [DATA_WIDTH/8-1:0]  m_axis_tkeep,
  output logic                     m_axis_tvalid,
  input  logic                     m_axis_tready,
  output logic                     m_axis_tlast,
  output ccsds_tuser_t             m_axis_tuser,

  // Radiation SEU Fault-Injection & EDAC Telemetry Port (Read Domain: clk_rd)
  input  logic                     seu_inject_en,
  input  logic [ADDR_W-1:0]        seu_inject_addr,
  input  logic [5:0]               seu_inject_bit,
  output logic                     ecc_single_err_corrected,
  output logic                     ecc_double_err_uncorr,
  output logic                     rollback_overflow_err,
  output logic [ADDR_W:0]          committed_count,
  output logic [ADDR_W:0]          speculative_count
);

  // ---------------------------------------------------------------------------
  // 1. (39,32) Hsiao SECDED Encoder / Decoder & Gray-Code Conversion Functions
  // ---------------------------------------------------------------------------
  localparam int unsigned ECC_DATA_BITS = (DATA_WIDTH < 32) ? DATA_WIDTH : 32;
  localparam logic [31:0] ECC_DATA_MASK = (DATA_WIDTH < 32) ? ((32'd1 << DATA_WIDTH) - 32'd1) : 32'hFFFF_FFFF;

  localparam logic [31:0] HSIAO_H_MASK [0:5] = '{
    32'h56AA_AD5B,
    32'h9B33_366D,
    32'hE3C3_C78E,
    32'h03FC_07F0,
    32'h03FF_F800,
    32'hFC00_0000
  };

  function automatic logic [6:0] hsiao_encode_32(input logic [31:0] d);
    logic [31:0] dm;
    logic [6:0]  p;
    dm = d & ECC_DATA_MASK;
    for (int i = 0; i < 6; i++) begin
      p[i] = ^(dm & (HSIAO_H_MASK[i] & ECC_DATA_MASK));
    end
    p[6] = ^{dm, p[5:0]};
    return p;
  endfunction

  function automatic logic [ADDR_W:0] bin2gray(input logic [ADDR_W:0] b);
    return (b >> 1) ^ b;
  endfunction

  function automatic logic [ADDR_W:0] gray2bin(input logic [ADDR_W:0] g);
    logic [ADDR_W:0] b;
    for (int i = 0; i <= ADDR_W; i++) begin
      b[i] = ^(g >> i);
    end
    return b;
  endfunction

  // ---------------------------------------------------------------------------
  // 2. Dual-Port Distributed RAM Storage & Dual-Clock Gray-Code Synchronizers
  // ---------------------------------------------------------------------------
  (* ram_style = "distributed" *) logic [DATA_WIDTH-1:0]   mem_data [0:DEPTH_WORDS-1];
  (* ram_style = "distributed" *) logic [DATA_WIDTH/8-1:0] mem_keep [0:DEPTH_WORDS-1];
  (* ram_style = "distributed" *) logic                    mem_last [0:DEPTH_WORDS-1];
  (* ram_style = "distributed" *) ccsds_tuser_t            mem_user [0:DEPTH_WORDS-1];
  (* ram_style = "distributed" *) logic [6:0]              mem_ecc  [0:DEPTH_WORDS-1];

  // Write-domain pointers & Gray-code launch register (clk_wr)
  logic [ADDR_W:0] wr_spec_ptr_q;
  logic [ADDR_W:0] wr_commit_ptr_q;
  logic [ADDR_W:0] frame_end_ptr_q;
  logic [ADDR_W:0] wr_eff_gray_q;
  (* ASYNC_REG = "TRUE" *) logic [ADDR_W:0] rd_gray_sync1_wr_q, rd_gray_sync2_wr_q;
  logic [ADDR_W:0] rd_bin_sync2_wr_q;

  // Read-domain pointers & Gray-code launch register (clk_rd)
  logic [ADDR_W:0] rd_ptr_q;
  logic [ADDR_W:0] rd_gray_q;
  logic            watermark_open_q;
  (* ASYNC_REG = "TRUE" *) logic [ADDR_W:0] wr_gray_sync1_rd_q, wr_gray_sync2_rd_q;
  logic [ADDR_W:0] wr_bin_sync2_rd_q;

  // Compact 1-entry non-destructive SEU shadow register in Read domain (clk_rd)
  logic              seu_valid_q;
  logic [ADDR_W-1:0] seu_addr_q;
  logic [5:0]        seu_bit_q;

  // ---------------------------------------------------------------------------
  // 3. Generate-Guarded 32-Bit SECDED Word Adaptation (Fix P2-1)
  // ---------------------------------------------------------------------------
  logic [31:0]             wr_data_32;
  logic [DATA_WIDTH-1:0]   rd_raw_data;
  logic [DATA_WIDTH/8-1:0] rd_raw_keep;
  logic                    rd_raw_last;
  ccsds_tuser_t            rd_raw_user;
  logic [6:0]              rd_raw_ecc;
  logic [31:0]             rd_data_32;
  logic [38:0]             rd_codeword_39;
  logic [31:0]             rd_corr_32;

  assign rd_raw_data = mem_data[rd_ptr_q[ADDR_W-1:0]];
  assign rd_raw_keep = mem_keep[rd_ptr_q[ADDR_W-1:0]];
  assign rd_raw_last = mem_last[rd_ptr_q[ADDR_W-1:0]];
  assign rd_raw_user = mem_user[rd_ptr_q[ADDR_W-1:0]];
  assign rd_raw_ecc  = mem_ecc[rd_ptr_q[ADDR_W-1:0]];

  generate
    if (DATA_WIDTH >= 32) begin : g_ecc_ge32
      assign wr_data_32 = s_axis_tdata[31:0];
      assign rd_data_32 = rd_raw_data[31:0];
      if (DATA_WIDTH > 32) begin : g_ecc_gt32
        assign m_axis_tdata = {rd_raw_data[DATA_WIDTH-1:32], rd_corr_32};
      end else begin : g_ecc_eq32
        assign m_axis_tdata = rd_corr_32;
      end
    end else begin : g_ecc_lt32
      assign wr_data_32   = {{(32 - DATA_WIDTH){1'b0}}, s_axis_tdata};
      assign rd_data_32   = {{(32 - DATA_WIDTH){1'b0}}, rd_raw_data};
      assign m_axis_tdata = rd_corr_32[DATA_WIDTH-1:0];
    end
  endgenerate

  // ---------------------------------------------------------------------------
  // 4. Write Domain Logic & Dedicated LUTRAM Inference Block (clk_wr)
  // ---------------------------------------------------------------------------
  logic [ADDR_W:0] rd_ptr_bin_wr;
  logic [ADDR_W:0] spec_used_wr;
  logic            fifo_full_spec;
  logic            wr_fire;
  logic [ADDR_W:0] wr_spec_ptr_nxt;
  logic [ADDR_W:0] wr_commit_ptr_nxt;
  logic [ADDR_W:0] eff_wr_ptr_nxt;

  assign rd_ptr_bin_wr         = rd_bin_sync2_wr_q;
  assign spec_used_wr          = wr_spec_ptr_q - rd_ptr_bin_wr;
  assign speculative_count     = spec_used_wr;
  assign fifo_full_spec        = (spec_used_wr >= DEPTH_WORDS[ADDR_W:0]);
  assign s_axis_tready         = !fifo_full_spec;
  assign wr_fire               = s_axis_tvalid && s_axis_tready;
  assign rollback_overflow_err = s_axis_tvalid && fifo_full_spec;

  // Dedicated Single-Write-Port Distributed LUTRAM Inference Block (No Async Reset Sensitivity)
  always_ff @(posedge clk_wr) begin
    if (wr_fire) begin
      mem_data[wr_spec_ptr_q[ADDR_W-1:0]] <= s_axis_tdata;
      mem_keep[wr_spec_ptr_q[ADDR_W-1:0]] <= s_axis_tkeep;
      mem_last[wr_spec_ptr_q[ADDR_W-1:0]] <= s_axis_tlast;
      mem_user[wr_spec_ptr_q[ADDR_W-1:0]] <= s_axis_tuser;
      mem_ecc [wr_spec_ptr_q[ADDR_W-1:0]] <= hsiao_encode_32(wr_data_32);
    end
  end

  always_comb begin
    wr_spec_ptr_nxt   = wr_spec_ptr_q;
    wr_commit_ptr_nxt = wr_commit_ptr_q;

    if (wr_fire) begin
      wr_spec_ptr_nxt = wr_spec_ptr_q + {{ADDR_W{1'b0}}, 1'b1};
    end

    if (ROLLBACK_MODE && !cut_through_en) begin
      if (frame_rollback_pulse) begin
        wr_spec_ptr_nxt = wr_commit_ptr_q;
      end else if (frame_commit_pulse) begin
        wr_commit_ptr_nxt = wr_fire ? (wr_spec_ptr_q + {{ADDR_W{1'b0}}, 1'b1}) : frame_end_ptr_q;
      end
    end else begin
      wr_commit_ptr_nxt = wr_spec_ptr_nxt;
    end

    eff_wr_ptr_nxt = (!ROLLBACK_MODE || cut_through_en) ? wr_spec_ptr_nxt : wr_commit_ptr_nxt;
  end

  always_ff @(posedge clk_wr or negedge rst_wr_n) begin
    if (!rst_wr_n) begin
      wr_spec_ptr_q      <= '0;
      wr_commit_ptr_q    <= '0;
      frame_end_ptr_q    <= '0;
      wr_eff_gray_q      <= '0;
      rd_gray_sync1_wr_q <= '0;
      rd_gray_sync2_wr_q <= '0;
      rd_bin_sync2_wr_q  <= '0;
    end else begin
      rd_gray_sync1_wr_q <= rd_gray_q;
      rd_gray_sync2_wr_q <= rd_gray_sync1_wr_q;
      rd_bin_sync2_wr_q  <= gray2bin(rd_gray_sync1_wr_q);

      if (wr_fire && s_axis_tlast) begin
        frame_end_ptr_q <= wr_spec_ptr_q + {{ADDR_W{1'b0}}, 1'b1};
      end

      wr_spec_ptr_q   <= wr_spec_ptr_nxt;
      wr_commit_ptr_q <= wr_commit_ptr_nxt;
      wr_eff_gray_q   <= bin2gray(eff_wr_ptr_nxt);
    end
  end

  // ---------------------------------------------------------------------------
  // 5. Read Domain Logic & Hsiao SECDED Syndrome Decoder (clk_rd)
  // ---------------------------------------------------------------------------
  logic [ADDR_W:0] wr_eff_bin_rd;
  logic [ADDR_W:0] comm_used_rd;
  logic            rd_fire;
  logic [ADDR_W:0] rd_ptr_nxt;
  logic            seu_hit;
  logic [6:0]      recalc_ecc;
  logic [5:0]      syndrome;
  logic            overall_par;

  assign wr_eff_bin_rd   = wr_bin_sync2_rd_q;
  assign comm_used_rd    = wr_eff_bin_rd - rd_ptr_q;
  assign committed_count = comm_used_rd;

  always_comb begin
    if (WATERMARK_MODE) begin
      m_axis_tvalid = (comm_used_rd != '0) &&
                      (watermark_open_q || (comm_used_rd >= watermark_words));
    end else begin
      m_axis_tvalid = (comm_used_rd != '0);
    end
  end

  assign rd_fire    = m_axis_tvalid && m_axis_tready;
  assign rd_ptr_nxt = rd_fire ? (rd_ptr_q + {{ADDR_W{1'b0}}, 1'b1}) : rd_ptr_q;
  assign seu_hit    = seu_valid_q && (rd_ptr_q[ADDR_W-1:0] == seu_addr_q);

  always_comb begin
    rd_codeword_39 = {rd_raw_ecc, rd_data_32};
    if (seu_hit) begin
      for (int b = 0; b < ECC_DATA_BITS; b++) begin
        if (seu_bit_q == 6'(b)) begin
          rd_codeword_39[b] = ~rd_codeword_39[b];
        end
      end
      for (int b = 32; b < 39; b++) begin
        if (seu_bit_q == 6'(b)) begin
          rd_codeword_39[b] = ~rd_codeword_39[b];
        end
      end
    end

    recalc_ecc  = hsiao_encode_32(rd_codeword_39[31:0]);
    syndrome    = rd_codeword_39[37:32] ^ recalc_ecc[5:0];
    overall_par = ^({rd_codeword_39[38:32], (rd_codeword_39[31:0] & ECC_DATA_MASK)});

    // Data correction computed directly from LUTRAM output (independent of m_axis_tvalid)
    rd_corr_32 = rd_codeword_39[31:0];
    if (overall_par) begin
      for (int b = 0; b < ECC_DATA_BITS; b++) begin
        logic [5:0] col_syn;
        for (int r = 0; r < 6; r++) begin
          col_syn[r] = HSIAO_H_MASK[r][b];
        end
        if (syndrome == col_syn) begin
          rd_corr_32[b] = ~rd_codeword_39[b];
        end
      end
    end

    ecc_single_err_corrected = m_axis_tvalid && overall_par;
    ecc_double_err_uncorr    = m_axis_tvalid && (syndrome != 6'd0) && !overall_par;

    m_axis_tkeep = rd_raw_keep;
    m_axis_tlast = rd_raw_last;
    m_axis_tuser = rd_raw_user;
    if (ecc_double_err_uncorr) begin
      m_axis_tuser.crc_err = 1'b1;
    end
  end

  always_ff @(posedge clk_rd or negedge rst_rd_n) begin
    if (!rst_rd_n) begin
      rd_ptr_q           <= '0;
      rd_gray_q          <= '0;
      watermark_open_q   <= 1'b0;
      wr_gray_sync1_rd_q <= '0;
      wr_gray_sync2_rd_q <= '0;
      wr_bin_sync2_rd_q  <= '0;
      seu_valid_q        <= 1'b0;
      seu_addr_q         <= '0;
      seu_bit_q          <= '0;
    end else begin
      wr_gray_sync1_rd_q <= wr_eff_gray_q;
      wr_gray_sync2_rd_q <= wr_gray_sync1_rd_q;
      wr_bin_sync2_rd_q  <= gray2bin(wr_gray_sync1_rd_q);

      if (seu_inject_en) begin
        seu_valid_q <= 1'b1;
        seu_addr_q  <= seu_inject_addr;
        seu_bit_q   <= seu_inject_bit;
      end else if (rd_fire && seu_hit) begin
        seu_valid_q <= 1'b0;
      end

      rd_ptr_q  <= rd_ptr_nxt;
      rd_gray_q <= bin2gray(rd_ptr_nxt);

      if (WATERMARK_MODE) begin
        if (comm_used_rd == '0 || (rd_fire && m_axis_tlast && comm_used_rd == {{ADDR_W{1'b0}}, 1'b1})) begin
          watermark_open_q <= 1'b0;
        end else if (comm_used_rd >= watermark_words) begin
          watermark_open_q <= 1'b1;
        end
      end
    end
  end

endmodule : ccsds_cdc_fifo_ecc
