// =============================================================================
// File Name   : ccsds_prox1_plcw_ctrl.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog (Synthesizable)
// Description : CCSDS 211.0-B-6 Proximity-1 COP-P Receiver State Machine and
//               32-bit Proximity Link Control Word (PLCW) Generator:
//                 - Tracks 8-bit V(R) sequence number for QoS=0 (Sequence-
//                   Controlled) Proximity-1 transfer frames and 4-bit
//                   Expedited_Counter for QoS=1 frames.
//                 - Processes SPDU (PDU_Type_ID=1) supervisory directives
//                   (Set V(R) and Unlock/Reset).
//                 - Outputs bit-exact 32-bit ccsds_plcw_t (COP_in_Effect="10").
// =============================================================================
`timescale 1ns / 1ps

module ccsds_prox1_plcw_ctrl
  import ccsds_pkg::*;
(
  input  logic                  clk,
  input  logic                  rst_n,

  input  logic                  no_rf_avail,
  input  logic                  no_bit_lock,
  input  logic                  wait_flag_in,
  input  logic [7:0]            window_half_w,

  // Parsed Proximity-1 Header & SPDU Command Inputs from RX4 Deframer
  input  ccsds_prox1_prim_hdr_t prox1_hdr_in,
  input  logic [7:0]            spdu_cmd_byte0,
  input  logic [7:0]            spdu_cmd_byte1,
  input  logic                  frame_done_pulse,
  input  logic                  frame_crc_ok,

  // COP-P Decision & 32-bit PLCW Outputs
  output logic                  copp_accept_pulse,
  output logic                  copp_reject_pulse,
  output ccsds_plcw_t           plcw_out,
  output logic                  plcw_valid_pulse
);

  logic [7:0] v_r_q;
  logic [3:0] exp_cnt_q;
  logic       lockout_q;
  logic       retransmit_q;
  logic       pcid_q;
  logic [2:0] port_id_q;

  function automatic ccsds_plcw_t build_plcw(
    input logic       pcid,
    input logic [2:0] port_id,
    input logic       lockout,
    input logic       retransmit,
    input logic [3:0] exp_cnt,
    input logic [7:0] vr
  );
    ccsds_plcw_t p;
    p.ctrl_word_type = 1'b0;
    p.plcw_version   = 2'b00;
    p.status_field   = 3'b000;
    p.cop_in_effect  = 2'b10; // COP-P in effect
    p.pcid           = pcid;
    p.port_id        = port_id;
    p.rsvd_spare     = 3'b000;
    p.no_rf_avail    = no_rf_avail;
    p.no_bit_lock    = no_bit_lock;
    p.lockout        = lockout;
    p.wait_flag      = wait_flag_in;
    p.retransmit     = retransmit;
    p.expedited_cnt  = exp_cnt;
    p.report_value   = vr;
    return p;
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      v_r_q             <= 8'd0;
      exp_cnt_q         <= 4'd0;
      lockout_q         <= 1'b0;
      retransmit_q      <= 1'b0;
      pcid_q            <= 1'b0;
      port_id_q         <= 3'd0;
      copp_accept_pulse <= 1'b0;
      copp_reject_pulse <= 1'b0;
      plcw_out          <= '0;
      plcw_valid_pulse  <= 1'b0;
    end else begin
      copp_accept_pulse <= 1'b0;
      copp_reject_pulse <= 1'b0;
      plcw_valid_pulse  <= 1'b0;

      if (frame_done_pulse) begin
        logic [7:0] nxt_vr;
        logic [3:0] nxt_exp;
        logic       nxt_lock;
        logic       nxt_rx;
        logic       acc;

        nxt_vr   = v_r_q;
        nxt_exp  = exp_cnt_q;
        nxt_lock = lockout_q;
        nxt_rx   = retransmit_q;
        acc      = 1'b0;

        if (frame_crc_ok && (prox1_hdr_in.tfvn == 2'b10)) begin
          pcid_q    <= prox1_hdr_in.pcid;
          port_id_q <= prox1_hdr_in.port_id;

          if (prox1_hdr_in.pdu_type_id == 1'b1) begin
            // SPDU Control Directive (0x00 = Unlock, 0x82 = Set V(R))
            nxt_exp = exp_cnt_q + 4'd1;
            if (spdu_cmd_byte0 == COP1_CMD_UNLOCK) begin
              nxt_lock = 1'b0;
              nxt_rx   = 1'b0;
              acc      = 1'b1;
            end else if (spdu_cmd_byte0 == COP1_CMD_SET_VR_HDR) begin
              nxt_vr   = spdu_cmd_byte1;
              nxt_lock = 1'b0;
              nxt_rx   = 1'b0;
              acc      = 1'b1;
            end
          end else if (prox1_hdr_in.qos_ind == 1'b1) begin
            // Expedited User Data Frame (QoS=1)
            nxt_exp = exp_cnt_q + 4'd1;
            acc     = 1'b1;
          end else begin
            // Sequence-Controlled User Data Frame (QoS=0)
            logic [7:0] diff;
            diff = prox1_hdr_in.frame_seq_num - v_r_q;
            if (!lockout_q) begin
              if (diff == 8'd0) begin
                if (wait_flag_in) begin
                  nxt_rx = 1'b1;
                end else begin
                  nxt_vr = v_r_q + 8'd1;
                  nxt_rx = 1'b0;
                  acc    = 1'b1;
                end
              end else if ((diff >= 8'd1) && (diff < window_half_w)) begin
                nxt_rx = 1'b1;
              end else if (diff >= (8'd0 - window_half_w)) begin
                acc = 1'b0;
              end else begin
                nxt_lock = 1'b1;
              end
            end
          end
        end

        v_r_q             <= nxt_vr;
        exp_cnt_q         <= nxt_exp;
        lockout_q         <= nxt_lock;
        retransmit_q      <= nxt_rx;
        copp_accept_pulse <= acc;
        copp_reject_pulse <= !acc;
        plcw_out          <= build_plcw(prox1_hdr_in.pcid, prox1_hdr_in.port_id, nxt_lock, nxt_rx, nxt_exp, nxt_vr);
        plcw_valid_pulse  <= 1'b1;
      end
    end
  end

endmodule : ccsds_prox1_plcw_ctrl
