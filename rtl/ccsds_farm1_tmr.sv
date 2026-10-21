// =============================================================================
// File Name   : ccsds_farm1_tmr.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog (Synthesizable)
// Description : Radiation-Hardened Triple Modular Redundant (TMR) COP-1 FARM-1
//               Responder & Multi-VC Round-Robin CLCW Scheduler (RX5 in signal
//               flow chain, CCSDS 232.1-B-2, Audit R1-7, R2-1, R2-3, R2-7, R3-1).
// =============================================================================
`timescale 1ns / 1ps

module ccsds_farm1_tmr
  import ccsds_pkg::*;
#(
  parameter int unsigned NUM_VC = DEFAULT_NUM_VC
) (
  input  logic               clk,
  input  logic               rst_n,

  input  logic               sdls_en,
  input  logic               bc_require_sdls,
  input  logic [7:0]         window_half_w,
  input  logic               no_rf_avail,
  input  logic               no_bit_lock,
  input  logic               rx_buffer_wait,

  input  logic               tmr_seu_inject_en,
  input  logic [1:0]         tmr_seu_replica_sel,
  input  logic [2:0]         tmr_seu_vc_sel,
  input  logic [7:0]         tmr_seu_xor_mask,

  input  ccsds_tc_prim_hdr_t tc_hdr_in,
  input  logic [7:0]         bc_cmd_byte0,
  input  logic [7:0]         bc_cmd_byte1,
  input  logic [7:0]         bc_cmd_byte2,
  input  logic [2:0]         bc_cmd_len,
  input  logic               frame_done_pulse,
  input  logic               frame_crc_ok,
  input  logic               sdls_auth_ok,

  output logic               farm_accept_pulse,
  output logic               farm_reject_pulse,
  output ccsds_clcw_t        clcw_scheduled_out,
  output logic               clcw_valid_pulse,
  output logic               tmr_seu_corrected_pulse
);

  (* syn_preserve = 1, dont_touch = "true" *) logic [7:0] v_r_tmr        [0:2][0:NUM_VC-1];
  (* syn_preserve = 1, dont_touch = "true" *) logic [1:0] state_tmr      [0:2][0:NUM_VC-1];
  (* syn_preserve = 1, dont_touch = "true" *) logic       retransmit_tmr [0:2][0:NUM_VC-1];
  (* syn_preserve = 1, dont_touch = "true" *) logic [1:0] farm_b_tmr     [0:2][0:NUM_VC-1];

  logic [$clog2(NUM_VC)-1:0] scrub_vc_q;
  logic [$clog2(NUM_VC)-1:0] rr_vc_q;

  function automatic logic [7:0] vote8(input logic [7:0] a, input logic [7:0] b, input logic [7:0] c);
    return (a & b) | (b & c) | (a & c);
  endfunction

  function automatic logic [1:0] vote2(input logic [1:0] a, input logic [1:0] b, input logic [1:0] c);
    return (a & b) | (b & c) | (a & c);
  endfunction

  function automatic logic vote1(input logic a, input logic b, input logic c);
    return (a & b) | (b & c) | (a & c);
  endfunction

  function automatic ccsds_clcw_t pack_clcw_direct(
    input int unsigned vc_idx,
    input logic [7:0]  vr_val,
    input logic [1:0]  st_val,
    input logic        retx_val,
    input logic [1:0]  fb_val
  );
    ccsds_clcw_t clcw;
    clcw.ctrl_word_type = 1'b0;
    clcw.clcw_version   = 2'b00;
    clcw.status_field   = 3'b000;
    clcw.cop_in_effect  = 2'b01;
    clcw.vcid           = vc_idx[5:0];
    clcw.rsvd_spare     = 2'b00;
    clcw.no_rf_avail    = no_rf_avail;
    clcw.no_bit_lock    = no_bit_lock;
    clcw.lockout        = (st_val == FARM_STATE_LOCKOUT);
    clcw.wait_flag      = rx_buffer_wait || (st_val == FARM_STATE_WAIT);
    clcw.retransmit     = retx_val;
    clcw.farm_b_cnt     = fb_val;
    clcw.rsvd_zero      = 1'b0;
    clcw.report_value   = vr_val;
    return clcw;
  endfunction

  function automatic ccsds_clcw_t build_vc_clcw(input int unsigned vc_idx);
    logic [7:0] vr_v;
    logic [1:0] st_v;
    logic       retx_v;
    logic [1:0] fb_v;
    vr_v   = vote8(v_r_tmr[0][vc_idx],        v_r_tmr[1][vc_idx],        v_r_tmr[2][vc_idx]);
    st_v   = vote2(state_tmr[0][vc_idx],      state_tmr[1][vc_idx],      state_tmr[2][vc_idx]);
    retx_v = vote1(retransmit_tmr[0][vc_idx], retransmit_tmr[1][vc_idx], retransmit_tmr[2][vc_idx]);
    fb_v   = vote2(farm_b_tmr[0][vc_idx],     farm_b_tmr[1][vc_idx],     farm_b_tmr[2][vc_idx]);
    return pack_clcw_direct(vc_idx, vr_v, st_v, retx_v, fb_v);
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int r = 0; r < 3; r++) begin
        for (int v = 0; v < NUM_VC; v++) begin
          v_r_tmr[r][v]        <= 8'd0;
          state_tmr[r][v]      <= FARM_STATE_OPEN;
          retransmit_tmr[r][v] <= 1'b0;
          farm_b_tmr[r][v]     <= 2'd0;
        end
      end
      scrub_vc_q              <= '0;
      rr_vc_q                 <= '0;
      farm_accept_pulse       <= 1'b0;
      farm_reject_pulse       <= 1'b0;
      clcw_scheduled_out      <= '0;
      clcw_valid_pulse        <= 1'b0;
      tmr_seu_corrected_pulse <= 1'b0;
    end else begin
      farm_accept_pulse       <= 1'b0;
      farm_reject_pulse       <= 1'b0;
      clcw_valid_pulse        <= 1'b0;
      tmr_seu_corrected_pulse <= 1'b0;

      // 1. Background TMR Scrubbing across VCs (Audit R2-7)
      if (tmr_seu_inject_en) begin
        v_r_tmr[tmr_seu_replica_sel][tmr_seu_vc_sel] <=
          v_r_tmr[tmr_seu_replica_sel][tmr_seu_vc_sel] ^ tmr_seu_xor_mask;
      end else begin
        logic [7:0] vr_voted;
        logic [1:0] st_voted;
        logic       rx_voted;
        logic [1:0] fb_voted;

        vr_voted = vote8(v_r_tmr[0][scrub_vc_q], v_r_tmr[1][scrub_vc_q], v_r_tmr[2][scrub_vc_q]);
        st_voted = vote2(state_tmr[0][scrub_vc_q], state_tmr[1][scrub_vc_q], state_tmr[2][scrub_vc_q]);
        rx_voted = vote1(retransmit_tmr[0][scrub_vc_q], retransmit_tmr[1][scrub_vc_q], retransmit_tmr[2][scrub_vc_q]);
        fb_voted = vote2(farm_b_tmr[0][scrub_vc_q], farm_b_tmr[1][scrub_vc_q], farm_b_tmr[2][scrub_vc_q]);

        if ((v_r_tmr[0][scrub_vc_q] != vr_voted) ||
            (v_r_tmr[1][scrub_vc_q] != vr_voted) ||
            (v_r_tmr[2][scrub_vc_q] != vr_voted)) begin
          tmr_seu_corrected_pulse <= 1'b1;
        end

        for (int r = 0; r < 3; r++) begin
          v_r_tmr[r][scrub_vc_q]        <= vr_voted;
          state_tmr[r][scrub_vc_q]      <= st_voted;
          retransmit_tmr[r][scrub_vc_q] <= rx_voted;
          farm_b_tmr[r][scrub_vc_q]     <= fb_voted;
        end
        scrub_vc_q <= scrub_vc_q + 1'b1;
      end

      // 2. Process Incoming TC Transfer Frame (with Audit R2-1 & R3-1 rules)
      if (frame_done_pulse) begin
        int unsigned vc;
        logic        is_ad, is_bd, is_bc;
        logic        auth_allowed;
        logic [7:0]  cur_vr, nxt_vr, diff;
        logic [1:0]  cur_st, nxt_st, cur_fb, nxt_fb;
        logic        cur_rx, nxt_rx;

        vc    = int'(tc_hdr_in.vcid[$clog2(NUM_VC)-1:0]);
        is_ad = (tc_hdr_in.bypass_flag == 1'b0) && (tc_hdr_in.ctrl_cmd_flag == 1'b0);
        is_bd = (tc_hdr_in.bypass_flag == 1'b1) && (tc_hdr_in.ctrl_cmd_flag == 1'b0);
        is_bc = (tc_hdr_in.bypass_flag == 1'b1) && (tc_hdr_in.ctrl_cmd_flag == 1'b1);

        auth_allowed = !sdls_en ||
                       ((is_ad || is_bd) && sdls_auth_ok) ||
                       (is_bc && (!bc_require_sdls || sdls_auth_ok));

        cur_vr = vote8(v_r_tmr[0][vc],        v_r_tmr[1][vc],        v_r_tmr[2][vc]);
        cur_st = vote2(state_tmr[0][vc],      state_tmr[1][vc],      state_tmr[2][vc]);
        cur_rx = vote1(retransmit_tmr[0][vc], retransmit_tmr[1][vc], retransmit_tmr[2][vc]);
        cur_fb = vote2(farm_b_tmr[0][vc],     farm_b_tmr[1][vc],     farm_b_tmr[2][vc]);
        diff   = tc_hdr_in.frame_seq_num - cur_vr;

        nxt_vr = cur_vr;
        nxt_st = cur_st;
        nxt_rx = cur_rx;
        nxt_fb = cur_fb;

        if (!frame_crc_ok || !auth_allowed) begin
          farm_reject_pulse <= 1'b1;
        end else if (is_bd) begin
          nxt_fb            = cur_fb + 2'd1;
          farm_accept_pulse <= 1'b1;
        end else if (is_bc) begin
          if ((bc_cmd_len == 3'd1) && (bc_cmd_byte0 == COP1_CMD_UNLOCK)) begin
            nxt_st            = FARM_STATE_OPEN;
            nxt_rx            = 1'b0;
            nxt_fb            = cur_fb + 2'd1;
            farm_accept_pulse <= 1'b1;
          end else if ((bc_cmd_len == 3'd3) && (bc_cmd_byte0 == COP1_CMD_SET_VR_HDR) && (bc_cmd_byte1 == 8'h00)) begin
            if (cur_st == FARM_STATE_OPEN) begin
              nxt_vr = bc_cmd_byte2;
              nxt_rx = 1'b0;
            end
            nxt_fb            = cur_fb + 2'd1;
            farm_accept_pulse <= (cur_st == FARM_STATE_OPEN);
            farm_reject_pulse <= (cur_st != FARM_STATE_OPEN);
          end else begin
            farm_reject_pulse <= 1'b1;
          end
        end else if (is_ad) begin
          if (cur_st == FARM_STATE_LOCKOUT) begin
            farm_reject_pulse <= 1'b1;
          end else if (diff == 8'd0) begin
            if (rx_buffer_wait) begin
              nxt_rx            = 1'b1;
              nxt_st            = FARM_STATE_WAIT;
              farm_reject_pulse <= 1'b1;
            end else begin
              nxt_vr            = cur_vr + 8'd1;
              nxt_rx            = 1'b0;
              farm_accept_pulse <= 1'b1;
            end
          end else if ((diff >= 8'd1) && (diff < window_half_w)) begin
            nxt_rx            = 1'b1;
            farm_reject_pulse <= 1'b1;
          end else if (diff >= (8'd0 - window_half_w)) begin
            farm_reject_pulse <= 1'b1;
          end else begin
            nxt_st            = FARM_STATE_LOCKOUT;
            farm_reject_pulse <= 1'b1;
          end
        end

        for (int r = 0; r < 3; r++) begin
          v_r_tmr[r][vc]        <= nxt_vr;
          state_tmr[r][vc]      <= nxt_st;
          retransmit_tmr[r][vc] <= nxt_rx;
          farm_b_tmr[r][vc]     <= nxt_fb;
        end
        clcw_scheduled_out <= pack_clcw_direct(vc, nxt_vr, nxt_st, nxt_rx, nxt_fb);
        clcw_valid_pulse   <= 1'b1;
      end else begin
        clcw_scheduled_out <= build_vc_clcw(int'(rr_vc_q));
        clcw_valid_pulse   <= 1'b1;
        rr_vc_q            <= rr_vc_q + 1'b1;
      end
    end
  end

endmodule : ccsds_farm1_tmr
