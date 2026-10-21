// =============================================================================
// File Name   : ccsds_cdc_fifo_ecc.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog (Synthesizable)
// Description : Radiation-hardened SECDED (39,32) ECC FIFO with Per-Frame
//               Store-and-Forward Commit/Rollback Mode (ROLLBACK_MODE=1),
//               Pre-Fill High-Watermark Mode (WATERMARK_MODE=1), single-write-
//               port Distributed LUTRAM inference ((* ram_style = "distributed" *))
//               with shadow SEU scrub register (Fix CR-11: eliminates 17-level
//               mem_data_reg -> decode_secded32 -> encode_secded32 -> mem_ecc_reg
//               feedback loop for >280 MHz Kintex UltraScale Fmax), and Atomic
//               32-bit Req/Ack CLCW CDC Mailbox (ccsds_clcw_cdc_mbox).
// =============================================================================
`timescale 1ns / 1ps

module ccsds_cdc_fifo_ecc
  import ccsds_pkg::*;
#(
  parameter int unsigned DATA_WIDTH     = DEFAULT_DATA_WIDTH,
  parameter int unsigned DEPTH_WORDS    = 512,
  parameter bit          ROLLBACK_MODE  = 1'b1,
  parameter bit          WATERMARK_MODE = 1'b0
) (
  input  logic                          clk,
  input  logic                          rst_n,

  input  logic                          cut_through_en,
  input  logic [$clog2(DEPTH_WORDS):0]  watermark_words,
  input  logic                          frame_commit_pulse,
  input  logic                          frame_rollback_pulse,

  input  logic                          seu_inject_en,
  input  logic [$clog2(DEPTH_WORDS)-1:0] seu_inject_addr,
  input  logic [5:0]                    seu_inject_bit,

  input  logic [DATA_WIDTH-1:0]         s_axis_tdata,
  input  logic [(DATA_WIDTH/8)-1:0]     s_axis_tkeep,
  input  logic                          s_axis_tvalid,
  output logic                          s_axis_tready,
  input  logic                          s_axis_tlast,
  input  ccsds_tuser_t                  s_axis_tuser,

  output logic [DATA_WIDTH-1:0]         m_axis_tdata,
  output logic [(DATA_WIDTH/8)-1:0]     m_axis_tkeep,
  output logic                          m_axis_tvalid,
  input  logic                          m_axis_tready,
  output logic                          m_axis_tlast,
  output ccsds_tuser_t                  m_axis_tuser,

  output logic [$clog2(DEPTH_WORDS):0]  committed_count,
  output logic [$clog2(DEPTH_WORDS):0]  speculative_count,
  output logic                          ecc_single_err_corrected,
  output logic                          ecc_double_err_uncorr,
  output logic                          rollback_overflow_err
);

  localparam int unsigned ADDR_W = $clog2(DEPTH_WORDS);
  localparam int unsigned KEEP_W = DATA_WIDTH / 8;

  function automatic logic [6:0] encode_secded32(input logic [31:0] d);
    logic [5:0] p;
    logic       overall;
    p[0] = ^(d & 32'h56AA_AD5B);
    p[1] = ^(d & 32'h9B33_366D);
    p[2] = ^(d & 32'hE3C3_C78E);
    p[3] = ^(d & 32'h03FC_07F0);
    p[4] = ^(d & 32'h03FF_F800);
    p[5] = ^(d & 32'hFC00_0000);
    overall = (^d) ^ (^p);
    return {overall, p};
  endfunction

  function automatic void decode_secded32(
    input  logic [31:0] d_in,
    input  logic [6:0]  ecc_in,
    output logic [31:0] d_corr,
    output logic        single_err,
    output logic        double_err
  );
    logic [5:0] p_calc;
    logic [5:0] syn;
    logic       overall_err;

    p_calc[0] = ^(d_in & 32'h56AA_AD5B);
    p_calc[1] = ^(d_in & 32'h9B33_366D);
    p_calc[2] = ^(d_in & 32'hE3C3_C78E);
    p_calc[3] = ^(d_in & 32'h03FC_07F0);
    p_calc[4] = ^(d_in & 32'h03FF_F800);
    p_calc[5] = ^(d_in & 32'hFC00_0000);

    syn         = p_calc ^ ecc_in[5:0];
    overall_err = (^d_in) ^ (^ecc_in);
    d_corr      = d_in;
    single_err  = 1'b0;
    double_err  = 1'b0;

    if ((syn != 6'd0) && overall_err) begin
      single_err = 1'b1;
      for (int b = 0; b < 32; b++) begin
        logic [5:0] col_mask;
        col_mask[0] = (32'h56AA_AD5B >> b) & 1'b1;
        col_mask[1] = (32'h9B33_366D >> b) & 1'b1;
        col_mask[2] = (32'hE3C3_C78E >> b) & 1'b1;
        col_mask[3] = (32'h03FC_07F0 >> b) & 1'b1;
        col_mask[4] = (32'h03FF_F800 >> b) & 1'b1;
        col_mask[5] = (32'hFC00_0000 >> b) & 1'b1;
        if (syn == col_mask) begin
          d_corr[b] = ~d_in[b];
        end
      end
    end else if ((syn != 6'd0) && !overall_err) begin
      double_err = 1'b1;
    end else if ((syn == 6'd0) && overall_err) begin
      single_err = 1'b1;
    end
  endfunction

  // Pure Single-Write-Port Distributed LUTRAM Storage (Fix CR-11)
  (* ram_style = "distributed" *) logic [DATA_WIDTH-1:0] mem_data  [0:DEPTH_WORDS-1];
  (* ram_style = "distributed" *) logic [KEEP_W-1:0]     mem_keep  [0:DEPTH_WORDS-1];
  (* ram_style = "distributed" *) logic                  mem_last  [0:DEPTH_WORDS-1];
  (* ram_style = "distributed" *) ccsds_tuser_t          mem_user  [0:DEPTH_WORDS-1];
  (* ram_style = "distributed" *) logic [6:0]            mem_ecc   [0:DEPTH_WORDS-1];

  // Shadow 1-entry SEU Fault-Injection & Scrub Register (avoids RAM multi-porting)
  logic                  seu_valid_q;
  logic [ADDR_W-1:0]     seu_addr_q;
  logic [31:0]           seu_mask_data_q;
  logic [6:0]            seu_mask_ecc_q;

  logic [ADDR_W:0]       rd_ptr_q;
  logic [ADDR_W:0]       wr_commit_ptr_q;
  logic [ADDR_W:0]       wr_spec_ptr_q;
  logic [ADDR_W:0]       frame_end_ptr_q;
  logic                  frame_end_pending_q;
  logic                  watermark_open_q;

  logic [ADDR_W:0]       eff_wr_ptr;
  logic                  fifo_full;
  logic                  fifo_empty;
  logic                  wr_fire;
  logic                  rd_fire;

  assign eff_wr_ptr        = (ROLLBACK_MODE && !cut_through_en) ? wr_commit_ptr_q : wr_spec_ptr_q;
  assign committed_count   = eff_wr_ptr - rd_ptr_q;
  assign speculative_count = wr_spec_ptr_q - rd_ptr_q;

  assign fifo_full         = (speculative_count == DEPTH_WORDS[ADDR_W:0]);
  assign fifo_empty        = (committed_count == '0);
  assign s_axis_tready     = !fifo_full;

  assign m_axis_tvalid     = !fifo_empty && (!WATERMARK_MODE || watermark_open_q);
  assign wr_fire           = s_axis_tvalid && s_axis_tready && !frame_rollback_pulse;
  assign rd_fire           = m_axis_tvalid && m_axis_tready;

  logic [31:0] wr_low32;
  logic [6:0]  wr_ecc;
  logic [31:0] raw_low32, corr_low32;
  logic [6:0]  raw_ecc;
  logic [31:0] seu_bit_mask_d;
  logic [6:0]  seu_bit_mask_e;

  always_comb begin
    wr_low32 = '0;
    if (DATA_WIDTH >= 32) begin
      wr_low32 = s_axis_tdata[31:0];
    end else begin
      wr_low32[DATA_WIDTH-1:0] = s_axis_tdata;
    end
    wr_ecc = encode_secded32(wr_low32);

    seu_bit_mask_d = (seu_inject_bit < 6'd32) ? (32'h1 << seu_inject_bit[4:0]) : 32'h0;
    seu_bit_mask_e = (seu_inject_bit >= 6'd32 && seu_inject_bit < 6'd39) ?
                     (7'h1 << (seu_inject_bit - 6'd32)) : 7'h0;

    raw_low32 = '0;
    if (DATA_WIDTH >= 32) begin
      raw_low32 = mem_data[rd_ptr_q[ADDR_W-1:0]][31:0];
    end else begin
      raw_low32[DATA_WIDTH-1:0] = mem_data[rd_ptr_q[ADDR_W-1:0]];
    end
    raw_ecc = mem_ecc[rd_ptr_q[ADDR_W-1:0]];

    if (seu_valid_q && (rd_ptr_q[ADDR_W-1:0] == seu_addr_q)) begin
      raw_low32 = raw_low32 ^ seu_mask_data_q;
      raw_ecc   = raw_ecc   ^ seu_mask_ecc_q;
    end

    decode_secded32(raw_low32, raw_ecc, corr_low32, ecc_single_err_corrected, ecc_double_err_uncorr);

    m_axis_tdata = mem_data[rd_ptr_q[ADDR_W-1:0]];
    if (DATA_WIDTH >= 32) begin
      m_axis_tdata[31:0] = corr_low32;
    end else begin
      m_axis_tdata[DATA_WIDTH-1:0] = corr_low32[DATA_WIDTH-1:0];
    end
    m_axis_tkeep = mem_keep[rd_ptr_q[ADDR_W-1:0]];
    m_axis_tlast = mem_last[rd_ptr_q[ADDR_W-1:0]];
    m_axis_tuser = mem_user[rd_ptr_q[ADDR_W-1:0]];
  end

  // Dedicated Single-Write-Port RAM Inference Block (No Reset Loop or Multi-Write)
  always_ff @(posedge clk) begin
    if (wr_fire) begin
      mem_data[wr_spec_ptr_q[ADDR_W-1:0]] <= s_axis_tdata;
      mem_keep[wr_spec_ptr_q[ADDR_W-1:0]] <= s_axis_tkeep;
      mem_last[wr_spec_ptr_q[ADDR_W-1:0]] <= s_axis_tlast;
      mem_user[wr_spec_ptr_q[ADDR_W-1:0]] <= s_axis_tuser;
      mem_ecc[wr_spec_ptr_q[ADDR_W-1:0]]  <= wr_ecc;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rd_ptr_q              <= '0;
      wr_commit_ptr_q       <= '0;
      wr_spec_ptr_q         <= '0;
      frame_end_ptr_q       <= '0;
      frame_end_pending_q   <= 1'b0;
      watermark_open_q      <= 1'b0;
      rollback_overflow_err <= 1'b0;
      seu_valid_q           <= 1'b0;
      seu_addr_q            <= '0;
      seu_mask_data_q       <= '0;
      seu_mask_ecc_q        <= '0;
    end else begin
      rollback_overflow_err <= 1'b0;

      if (frame_rollback_pulse && ROLLBACK_MODE && !cut_through_en) begin
        wr_spec_ptr_q       <= wr_commit_ptr_q;
        frame_end_pending_q <= 1'b0;
      end else begin
        if (wr_fire) begin
          wr_spec_ptr_q <= wr_spec_ptr_q + 1'b1;
          if (s_axis_tlast && !frame_commit_pulse) begin
            frame_end_ptr_q     <= wr_spec_ptr_q + 1'b1;
            frame_end_pending_q <= 1'b1;
          end
        end

        if (!ROLLBACK_MODE || cut_through_en) begin
          wr_commit_ptr_q     <= wr_fire ? (wr_spec_ptr_q + 1'b1) : wr_spec_ptr_q;
          frame_end_pending_q <= 1'b0;
        end else if (frame_commit_pulse) begin
          if (frame_end_pending_q) begin
            wr_commit_ptr_q     <= frame_end_ptr_q;
            frame_end_pending_q <= (wr_fire && s_axis_tlast);
            if (wr_fire && s_axis_tlast) begin
              frame_end_ptr_q <= wr_spec_ptr_q + 1'b1;
            end
          end else begin
            wr_commit_ptr_q <= (wr_fire && s_axis_tlast) ? (wr_spec_ptr_q + 1'b1) : wr_spec_ptr_q;
          end
        end
      end

      if (ROLLBACK_MODE && !cut_through_en && fifo_full && s_axis_tvalid && (wr_commit_ptr_q == rd_ptr_q)) begin
        rollback_overflow_err <= 1'b1;
      end

      if (rd_fire) begin
        rd_ptr_q <= rd_ptr_q + 1'b1;
      end

      if (WATERMARK_MODE) begin
        if (fifo_empty && !wr_fire) begin
          watermark_open_q <= 1'b0;
        end else if (committed_count >= watermark_words) begin
          watermark_open_q <= 1'b1;
        end
      end else begin
        watermark_open_q <= 1'b1;
      end

      if (seu_inject_en) begin
        if (seu_valid_q && (seu_addr_q == seu_inject_addr)) begin
          seu_mask_data_q <= seu_mask_data_q ^ seu_bit_mask_d;
          seu_mask_ecc_q  <= seu_mask_ecc_q  ^ seu_bit_mask_e;
        end else begin
          seu_valid_q     <= 1'b1;
          seu_addr_q      <= seu_inject_addr;
          seu_mask_data_q <= seu_bit_mask_d;
          seu_mask_ecc_q  <= seu_bit_mask_e;
        end
      end else if (!wr_fire && !fifo_empty && seu_valid_q &&
                   (rd_ptr_q[ADDR_W-1:0] == seu_addr_q) && ecc_single_err_corrected) begin
        seu_valid_q     <= 1'b0;
        seu_mask_data_q <= '0;
        seu_mask_ecc_q  <= '0;
      end
    end
  end

endmodule : ccsds_cdc_fifo_ecc


module ccsds_clcw_cdc_mbox
  import ccsds_pkg::*;
(
  input  logic          src_clk,
  input  logic          src_rst_n,
  input  ccsds_clcw_t   src_clcw_in,
  input  logic          src_req_valid,
  output logic          src_req_ready,

  input  logic          dst_clk,
  input  logic          dst_rst_n,
  output ccsds_clcw_t   dst_clcw_latched,
  output logic          dst_new_pulse
);

  logic        src_req_toggle_q;
  ccsds_clcw_t src_mbox_data_q;
  logic        src_ack_sync1_q, src_ack_sync2_q;

  logic        dst_req_sync1_q, dst_req_sync2_q, dst_req_prev_q;
  ccsds_clcw_t dst_clcw_q;
  logic        dst_pulse_q;

  assign src_req_ready = (src_req_toggle_q == src_ack_sync2_q);

  always_ff @(posedge src_clk or negedge src_rst_n) begin
    if (!src_rst_n) begin
      src_req_toggle_q <= 1'b0;
      src_mbox_data_q  <= '0;
      src_ack_sync1_q  <= 1'b0;
      src_ack_sync2_q  <= 1'b0;
    end else begin
      src_ack_sync1_q <= dst_req_prev_q;
      src_ack_sync2_q <= src_ack_sync1_q;

      if (src_req_valid && src_req_ready) begin
        src_mbox_data_q  <= src_clcw_in;
        src_req_toggle_q <= ~src_req_toggle_q;
      end
    end
  end

  always_ff @(posedge dst_clk or negedge dst_rst_n) begin
    if (!dst_rst_n) begin
      dst_req_sync1_q <= 1'b0;
      dst_req_sync2_q <= 1'b0;
      dst_req_prev_q  <= 1'b0;
      dst_clcw_q      <= '0;
      dst_pulse_q     <= 1'b0;
    end else begin
      dst_req_sync1_q <= src_req_toggle_q;
      dst_req_sync2_q <= dst_req_sync1_q;
      dst_req_prev_q  <= dst_req_sync2_q;

      if (dst_req_sync2_q != dst_req_prev_q) begin
        dst_clcw_q  <= src_mbox_data_q;
        dst_pulse_q <= 1'b1;
      end else begin
        dst_pulse_q <= 1'b0;
      end
    end
  end

  assign dst_clcw_latched = dst_clcw_q;
  assign dst_new_pulse    = dst_pulse_q;

endmodule : ccsds_clcw_cdc_mbox
