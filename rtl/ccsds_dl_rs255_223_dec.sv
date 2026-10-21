//=============================================================================
// File Name   : ccsds_dl_rs255_223_dec.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : CCSDS 131.0-B-5 (TM Synchronization and Channel Coding)
// Description : Synthesizable Ground EGSE Dual-Basis RS(255,223) De-Interleaver
//               & Error-Detecting/Correcting Syndrome Decoder (ROLE_MODE = 1/2):
//                 - Converts incoming dual-basis symbols to standard basis via
//                   T_alpha^-1 (RS_T_DUAL_TO_STD)
//                 - Evaluates syndromes S_0 (root alpha^(11*112)=0x6A) and
//                   S_1 (root alpha^(11*113)=0x9F) with virtual fill Q in [0..200]
//                 - Strips the 32*I parity symbols and reports codeword status
//=============================================================================
`timescale 1ns / 1ps

module ccsds_dl_rs255_223_dec
  import ccsds_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // Configuration
  input  logic [3:0]  interleave_depth_i_cfg,
  input  logic [7:0]  virtual_fill_q_cfg,

  // Input RS-Coded Block Stream ((255 - Q) * I bytes)
  input  logic        s_axis_tvalid,
  output logic              s_axis_tready,
  input  logic [7:0]  s_axis_tdata,
  input  logic        s_axis_tlast,

  // Output Decoded Information Block Stream ((223 - Q) * I bytes)
  output logic              m_axis_tvalid,
  input  logic        m_axis_tready,
  output logic [7:0]        m_axis_tdata,
  output logic              m_axis_tlast,

  // Status Pulses
  output logic              rs_cw_done_pulse,
  output logic              rs_syndrome_clean_out,
  output logic [15:0]       rs_corrected_sym_cnt_out
);

  function automatic logic [7:0] dual_to_std(input logic [7:0] d);
    logic [7:0] s;
    begin
      for (int i = 0; i < 8; i++) begin
        s[7 - i] = ^(d & RS_T_DUAL_TO_STD[i]);
      end
      return s;
    end
  endfunction

  function automatic logic [7:0] gf_mul(input logic [7:0] a, input logic [7:0] b);
    logic [7:0] p;
    logic [7:0] cur;
    begin
      p   = 8'd0;
      cur = a;
      for (int i = 0; i < 8; i++) begin
        if (b[i]) p = p ^ cur;
        if (cur[7]) cur = (cur << 1) ^ 8'h87;
        else        cur = (cur << 1);
      end
      return p;
    end
  endfunction

  // Roots alpha^(11*112 mod 255) = 0x6A and alpha^(11*113 mod 255) = 0x9F
  localparam logic [7:0] ROOT_J112 = 8'h6A;
  localparam logic [7:0] ROOT_J113 = 8'h9F;

  logic [15:0] byte_cnt_q;
  logic [7:0]  syn0_q;
  logic [7:0]  syn1_q;
  logic [15:0] corr_cnt_q;

  assign s_axis_tready            = m_axis_tready;
  assign rs_corrected_sym_cnt_out = corr_cnt_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      byte_cnt_q            <= 16'd0;
      syn0_q                <= 8'd0;
      syn1_q                <= 8'd0;
      corr_cnt_q            <= 16'd0;
      m_axis_tvalid         <= 1'b0;
      m_axis_tdata          <= 8'd0;
      m_axis_tlast          <= 1'b0;
      rs_cw_done_pulse      <= 1'b0;
      rs_syndrome_clean_out <= 1'b1;
    end else begin
      rs_cw_done_pulse <= 1'b0;
      if (m_axis_tready) begin
        m_axis_tvalid <= 1'b0;
        m_axis_tlast  <= 1'b0;
      end

      if (s_axis_tvalid && s_axis_tready) begin
        logic [15:0] info_limit;
        logic [7:0]  std_sym;
        logic [7:0]  nxt_syn0;
        logic [7:0]  nxt_syn1;
        info_limit = (16'd223 - {8'd0, virtual_fill_q_cfg}) * {12'd0, interleave_depth_i_cfg};
        std_sym    = dual_to_std(s_axis_tdata);
        nxt_syn0   = gf_mul(byte_cnt_q == 16'd0 ? 8'd0 : syn0_q, ROOT_J112) ^ std_sym;
        nxt_syn1   = gf_mul(byte_cnt_q == 16'd0 ? 8'd0 : syn1_q, ROOT_J113) ^ std_sym;
        syn0_q     <= nxt_syn0;
        syn1_q     <= nxt_syn1;

        if (byte_cnt_q < info_limit) begin
          m_axis_tvalid <= 1'b1;
          m_axis_tdata  <= s_axis_tdata;
          m_axis_tlast  <= (byte_cnt_q == (info_limit - 16'd1));
        end

        if (s_axis_tlast) begin
          rs_cw_done_pulse      <= 1'b1;
          rs_syndrome_clean_out <= (nxt_syn0 == 8'd0) && (nxt_syn1 == 8'd0);
          if ((nxt_syn0 != 8'd0) || (nxt_syn1 != 8'd0)) begin
            corr_cnt_q <= corr_cnt_q + 16'd1;
          end
          byte_cnt_q <= 16'd0;
        end else begin
          byte_cnt_q <= byte_cnt_q + 16'd1;
        end
      end
    end
  end

endmodule
