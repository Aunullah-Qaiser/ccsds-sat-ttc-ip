// =============================================================================
// File Name   : ccsds_hcpd_ctrl.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog (Synthesizable)
// Description : Authenticated Emergency Hardware Command Pulse Distribution
//               (HCPD) Controller (RX6 in signal flow chain):
//                 - Bypasses the Spacecraft On-Board Computer (OBC) to issue
//                   direct, deterministic hardware reset / safe-mode / RF-relay
//                   reconfiguration pulses when the OBC is hung or in latchup.
//                 - Protected by Triple Modular Redundancy (TMR) across both
//                   state registers and per-replica combinational next-state
//                   logic (`r = 0..2`, Fix P1-8) with syn_preserve / dont_touch
//                   attributes and continuous background SEU scrubbing.
//                 - Enforces 4-stage hardware safety interlock:
//                     1. Dedicated Emergency Virtual Channel (VCID == hcpd_vcid_cfg)
//                     2. Type-B Bypass Flag (bypass_flag == 1'b1)
//                     3. Valid Frame CRC (frame_crc_ok == 1'b1) & SDLS Auth
//                        (sdls_auth_ok == 1'b1 when sdls_en_cfg == 1'b1)
//                     4. 64-bit Emergency Command Word: 32-bit Magic Signature
//                        (0xC0DE_CAFE) + 8-bit Complementary Pulse Mask
//                        (cmd_mask ^ cmd_mask_inv == 8'hFF) + 16-bit Duration.
// =============================================================================
`timescale 1ns / 1ps

module ccsds_hcpd_ctrl
  import ccsds_pkg::*;
(
  input  logic               clk,
  input  logic               rst_n,

  // Mission Configuration
  input  logic               hcpd_en_cfg,
  input  logic [5:0]         hcpd_vcid_cfg,
  input  logic [31:0]        hcpd_magic_word_cfg,
  input  logic               sdls_en_cfg,

  // Radiation SEU Fault-Injection Port (For TMR Verification)
  input  logic               hcpd_seu_inject_en,
  input  logic [7:0]         hcpd_seu_xor_mask,

  // Incoming Frame Metadata & Payload Stream from Deframer / SDLS
  input  ccsds_tc_prim_hdr_t tc_hdr_in,
  input  logic [7:0]         s_axis_tdata,
  input  logic               s_axis_tvalid,
  input  logic               frame_done_pulse,
  input  logic               frame_crc_ok,
  input  logic               sdls_auth_ok,

  // Discrete Hardware Pulse Outputs & Telemetry
  output logic [7:0]         hcpd_pulse_out,
  output logic               hcpd_fired_pulse,
  output logic               hcpd_rejected_pulse,
  output logic               hcpd_tmr_seu_corrected_pulse
);

  logic [63:0] cmd_shift_q;
  logic [3:0]  byte_cnt_q;

  (* syn_preserve = 1, dont_touch = "true" *) logic [15:0] pulse_timer_tmr [0:2];
  (* syn_preserve = 1, dont_touch = "true" *) logic [7:0]  active_mask_tmr [0:2];

  function automatic logic [15:0] vote16(input logic [15:0] a, input logic [15:0] b, input logic [15:0] c);
    return (a & b) | (b & c) | (a & c);
  endfunction

  function automatic logic [7:0] vote8(input logic [7:0] a, input logic [7:0] b, input logic [7:0] c);
    return (a & b) | (b & c) | (a & c);
  endfunction

  logic [15:0] voted_timer;
  logic [7:0]  voted_mask;
  logic        seu_detected;

  // Triplicated per-replica combinational next-state signals (Fix P1-8)
  (* syn_preserve = 1, dont_touch = "true" *) logic [15:0] nxt_t_rep [0:2];
  (* syn_preserve = 1, dont_touch = "true" *) logic [7:0]  nxt_m_rep [0:2];

  always_comb begin
    voted_timer = vote16(pulse_timer_tmr[0], pulse_timer_tmr[1], pulse_timer_tmr[2]);
    voted_mask  = vote8(active_mask_tmr[0],  active_mask_tmr[1],  active_mask_tmr[2]);

    seu_detected = (pulse_timer_tmr[0] != voted_timer) ||
                   (pulse_timer_tmr[1] != voted_timer) ||
                   (pulse_timer_tmr[2] != voted_timer) ||
                   (active_mask_tmr[0] != voted_mask)  ||
                   (active_mask_tmr[1] != voted_mask)  ||
                   (active_mask_tmr[2] != voted_mask);

    for (int r = 0; r < 3; r++) begin
      logic [15:0] cur_t;
      logic [7:0]  cur_m;
      cur_t = vote16(pulse_timer_tmr[0], pulse_timer_tmr[1], pulse_timer_tmr[2]);
      cur_m = vote8(active_mask_tmr[0],  active_mask_tmr[1],  active_mask_tmr[2]);
      if (cur_t > 16'd0) begin
        nxt_t_rep[r] = cur_t - 16'd1;
        nxt_m_rep[r] = (cur_t == 16'd1) ? 8'h00 : cur_m;
      end else begin
        nxt_t_rep[r] = 16'd0;
        nxt_m_rep[r] = 8'h00;
      end
    end

    hcpd_pulse_out = (voted_timer != 16'd0) ? voted_mask : 8'h00;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cmd_shift_q                  <= 64'd0;
      byte_cnt_q                   <= 4'd0;
      for (int r = 0; r < 3; r++) begin
        pulse_timer_tmr[r] <= 16'd0;
        active_mask_tmr[r] <= 8'h00;
      end
      hcpd_fired_pulse             <= 1'b0;
      hcpd_rejected_pulse          <= 1'b0;
      hcpd_tmr_seu_corrected_pulse <= 1'b0;
    end else begin
      hcpd_fired_pulse             <= 1'b0;
      hcpd_rejected_pulse          <= 1'b0;
      hcpd_tmr_seu_corrected_pulse <= seu_detected;

      if (hcpd_seu_inject_en) begin
        active_mask_tmr[0] <= active_mask_tmr[0] ^ hcpd_seu_xor_mask;
      end else if (frame_done_pulse) begin
        byte_cnt_q <= 4'd0;
        if (hcpd_en_cfg && (tc_hdr_in.vcid == hcpd_vcid_cfg)) begin
          logic        auth_ok;
          logic        magic_ok;
          logic        comp_mask_ok;
          logic [7:0]  cmd_mask;
          logic [7:0]  cmd_mask_inv;
          logic [15:0] cmd_dur;

          auth_ok      = (!sdls_en_cfg) || sdls_auth_ok;
          magic_ok     = (cmd_shift_q[63:32] == hcpd_magic_word_cfg);
          cmd_mask     = cmd_shift_q[31:24];
          cmd_mask_inv = cmd_shift_q[23:16];
          cmd_dur      = cmd_shift_q[15:0];
          comp_mask_ok = ((cmd_mask ^ cmd_mask_inv) == 8'hFF) && (cmd_mask != 8'h00);

          if (tc_hdr_in.bypass_flag && frame_crc_ok && auth_ok &&
              (byte_cnt_q == 4'd8) && magic_ok && comp_mask_ok) begin
            for (int r = 0; r < 3; r++) begin
              active_mask_tmr[r] <= cmd_mask;
              pulse_timer_tmr[r] <= (cmd_dur == 16'd0) ? 16'd1 : cmd_dur;
            end
            hcpd_fired_pulse <= 1'b1;
          end else begin
            for (int r = 0; r < 3; r++) begin
              pulse_timer_tmr[r] <= nxt_t_rep[r];
              active_mask_tmr[r] <= nxt_m_rep[r];
            end
            hcpd_rejected_pulse <= 1'b1;
          end
        end else begin
          for (int r = 0; r < 3; r++) begin
            pulse_timer_tmr[r] <= nxt_t_rep[r];
            active_mask_tmr[r] <= nxt_m_rep[r];
          end
        end
      end else begin
        if (s_axis_tvalid && (byte_cnt_q < 4'd8)) begin
          cmd_shift_q <= {cmd_shift_q[55:0], s_axis_tdata};
          byte_cnt_q  <= byte_cnt_q + 4'd1;
        end
        for (int r = 0; r < 3; r++) begin
          pulse_timer_tmr[r] <= nxt_t_rep[r];
          active_mask_tmr[r] <= nxt_m_rep[r];
        end
      end
    end
  end

endmodule : ccsds_hcpd_ctrl
