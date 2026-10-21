// =============================================================================
// File Name   : ccsds_hcpd_ctrl.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog (Synthesizable)
// Description : TMR-Protected Authenticated Emergency Hardware Command Pulse
//               Distribution (HCPD) Controller (RX6a in clk_tc_safe):
//                 - Operates in the independent clk_tc_safe oscillator domain
//                   to execute emergency hardware recovery pulses (OBC Cold
//                   Reset, Safe-Mode Beacon Enable, SSPC Power Cycle, RF Switch)
//                   even when the spacecraft OBC (clk_sys) is unresponsive.
//                 - Requires:
//                     1. Valid TC/USLP Type-B frame (bypass_flag=1, ctrl_cmd_flag=0)
//                        on dedicated emergency VCID (hcpd_vcid_cfg).
//                     2. Valid FECF CRC-16/32 (frame_crc_ok=1).
//                     3. Valid SDLS authentication MAC (sdls_auth_ok=1 when sdls_en=1).
//                     4. 64-bit Emergency Command Word matching:
//                        [63:32] == hcpd_magic_word_cfg (default 32'hC0DE_CAFE)
//                        [31:24] == chan_mask[7:0] (one-hot or multi-channel)
//                        [23:16] == ~chan_mask[7:0] (complementary anti-SEU check)
//                        [15:0]  == pulse_duration_cycles[15:0] (clamped 1..4095)
//                 - Stores active pulse timers in Triple-Modular Redundant (TMR)
//                   registers with continuous 1-cycle auto-scrubbing.
// =============================================================================
`timescale 1ns / 1ps

module ccsds_hcpd_ctrl
  import ccsds_pkg::*;
(
  input  logic               clk,
  input  logic               rst_n,

  // Configuration & Security Policy Inputs
  input  logic               hcpd_en_cfg,
  input  logic [5:0]         hcpd_vcid_cfg,
  input  logic [31:0]        hcpd_magic_word_cfg,
  input  logic               sdls_en_cfg,

  // SEU Fault-Injection Test Hook
  input  logic               hcpd_seu_inject_en,
  input  logic [7:0]         hcpd_seu_xor_mask,

  // Frame Header, Payload Byte Stream & Authentication Inputs from RX4/RX6
  input  ccsds_tc_prim_hdr_t tc_hdr_in,
  input  logic [7:0]         s_axis_tdata,
  input  logic               s_axis_tvalid,
  input  logic               frame_done_pulse,
  input  logic               frame_crc_ok,
  input  logic               sdls_auth_ok,

  // Glitch-Free TMR-Voted Hardware Discrete Pulse Outputs & Telemetry
  output logic [7:0]         hcpd_pulse_out,
  output logic               hcpd_fired_pulse,
  output logic               hcpd_rejected_pulse,
  output logic               hcpd_tmr_seu_corrected_pulse
);

  logic [63:0] cmd_shift_q;
  logic [3:0]  byte_cnt_q;

  // Triple-Modular Redundant (TMR) Active Pulse Mask & Countdown Timers
  logic [7:0]  mask_a_q, mask_b_q, mask_c_q;
  logic [15:0] timer_a_q, timer_b_q, timer_c_q;

  function automatic logic [7:0] vote8(input logic [7:0] a, input logic [7:0] b, input logic [7:0] c);
    return (a & b) | (b & c) | (a & c);
  endfunction

  function automatic logic [15:0] vote16(input logic [15:0] a, input logic [15:0] b, input logic [15:0] c);
    return (a & b) | (b & c) | (a & c);
  endfunction

  logic [7:0]  voted_mask;
  logic [15:0] voted_timer;

  always_comb begin
    voted_mask     = vote8(mask_a_q, mask_b_q, mask_c_q);
    voted_timer    = vote16(timer_a_q, timer_b_q, timer_c_q);
    hcpd_pulse_out = (voted_timer != 16'd0) ? voted_mask : 8'h00;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cmd_shift_q                  <= 64'd0;
      byte_cnt_q                   <= 4'd0;
      mask_a_q                     <= 8'h00;
      mask_b_q                     <= 8'h00;
      mask_c_q                     <= 8'h00;
      timer_a_q                    <= 16'd0;
      timer_b_q                    <= 16'd0;
      timer_c_q                    <= 16'd0;
      hcpd_fired_pulse             <= 1'b0;
      hcpd_rejected_pulse          <= 1'b0;
      hcpd_tmr_seu_corrected_pulse <= 1'b0;
    end else begin
      logic tmr_disagree;
      hcpd_fired_pulse             <= 1'b0;
      hcpd_rejected_pulse          <= 1'b0;
      hcpd_tmr_seu_corrected_pulse <= 1'b0;

      // 1. Continuous 1-Cycle TMR Auto-Scrubbing & Countdown
      tmr_disagree = (mask_a_q != mask_b_q) || (mask_b_q != mask_c_q) ||
                     (timer_a_q != timer_b_q) || (timer_b_q != timer_c_q);
      if (tmr_disagree) begin
        hcpd_tmr_seu_corrected_pulse <= 1'b1;
      end

      if (voted_timer != 16'd0) begin
        logic [15:0] nxt_t;
        logic [7:0]  nxt_m;
        nxt_t     = voted_timer - 16'd1;
        nxt_m     = (nxt_t == 16'd0) ? 8'h00 : voted_mask;
        mask_a_q  <= hcpd_seu_inject_en ? (nxt_m ^ hcpd_seu_xor_mask) : nxt_m;
        mask_b_q  <= nxt_m;
        mask_c_q  <= nxt_m;
        timer_a_q <= nxt_t;
        timer_b_q <= nxt_t;
        timer_c_q <= nxt_t;
      end else begin
        mask_a_q  <= hcpd_seu_inject_en ? hcpd_seu_xor_mask : 8'h00;
        mask_b_q  <= 8'h00;
        mask_c_q  <= 8'h00;
        timer_a_q <= 16'd0;
        timer_b_q <= 16'd0;
        timer_c_q <= 16'd0;
      end

      // 2. Collect First 8 Payload Bytes of Incoming Telecommand Frame
      if (s_axis_tvalid && (byte_cnt_q < 4'd8)) begin
        cmd_shift_q <= {cmd_shift_q[55:0], s_axis_tdata};
        byte_cnt_q  <= byte_cnt_q + 4'd1;
      end

      // 3. Evaluate Emergency HCPD Command on frame_done_pulse
      if (frame_done_pulse) begin
        byte_cnt_q <= 4'd0;
        if (hcpd_en_cfg && (tc_hdr_in.vcid == hcpd_vcid_cfg)) begin
          logic auth_pass;
          logic hdr_pass;
          logic magic_pass;
          logic comp_pass;
          logic len_pass;

          auth_pass  = frame_crc_ok && (!sdls_en_cfg || sdls_auth_ok);
          hdr_pass   = (tc_hdr_in.bypass_flag == 1'b1) && (tc_hdr_in.ctrl_cmd_flag == 1'b0);
          magic_pass = (cmd_shift_q[63:32] == hcpd_magic_word_cfg);
          comp_pass  = (cmd_shift_q[31:24] != 8'h00) && (cmd_shift_q[23:16] == ~cmd_shift_q[31:24]);
          len_pass   = (byte_cnt_q == 4'd8) && (cmd_shift_q[15:0] != 16'd0);

          if (auth_pass && hdr_pass && magic_pass && comp_pass && len_pass) begin
            logic [15:0] clamped_dur;
            clamped_dur      = (cmd_shift_q[15:0] > 16'd4095) ? 16'd4095 : cmd_shift_q[15:0];
            mask_a_q         <= cmd_shift_q[31:24];
            mask_b_q         <= cmd_shift_q[31:24];
            mask_c_q         <= cmd_shift_q[31:24];
            timer_a_q        <= clamped_dur;
            timer_b_q        <= clamped_dur;
            timer_c_q        <= clamped_dur;
            hcpd_fired_pulse <= 1'b1;
          end else begin
            hcpd_rejected_pulse <= 1'b1;
          end
        end
      end
    end
  end

endmodule : ccsds_hcpd_ctrl
