//=============================================================================
// File Name   : ccsds_fop1_engine.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : CCSDS 232.1-B-2 (Communications Operation Procedure-1, FOP-1)
// Description : Synthesizable Ground EGSE COP-1 FOP-1 Initiator State Machine:
//                 - Maintains Transmitter Frame Sequence Number V(S) and
//                   Expected Acknowledgment Number NN(R)
//                 - Parses incoming 32-bit CLCW words from Spacecraft Downlink
//                 - Triggers automatic Go-Back-N retransmission on
//                   CLCW.Retransmit_Flag == 1 or T1 Timer expiration
//                 - Raises fop1_unlock_req_out when CLCW.Lockout_Flag == 1
//=============================================================================
`timescale 1ns / 1ps

module ccsds_fop1_engine
  import ccsds_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // Configuration
  input  logic [5:0]  target_vcid_cfg,
  input  logic [7:0]  sliding_win_k_cfg,
  input  logic [15:0] t1_timeout_cycles_cfg,

  // Outgoing Type-AD Frame Handshake
  input  logic        tx_type_ad_req_pulse,
  output logic              tx_window_open_out,
  output logic [7:0]        fop1_vs_out,
  output logic [7:0]        fop1_nnr_out,

  // Incoming Downlink CLCW from TM/AOS Deframer
  input  logic        rx_clcw_valid_pulse,
  input  ccsds_clcw_t rx_clcw_in,

  // FOP-1 Directives & Alerts
  output logic              fop1_retransmit_pulse_out,
  output logic [7:0]        fop1_replay_from_seq_out,
  output logic              fop1_unlock_req_out,
  output logic [15:0]       fop1_ack_cnt_out,
  output logic [15:0]       fop1_retransmit_cnt_out
);

  logic [7:0]  vs_q;
  logic [7:0]  nnr_q;
  logic [15:0] t1_cnt_q;
  logic        timer_active_q;
  logic [15:0] ack_cnt_q;
  logic [15:0] retx_cnt_q;

  logic [7:0]  outstanding_frames;
  assign outstanding_frames = vs_q - nnr_q;
  assign tx_window_open_out = (outstanding_frames < sliding_win_k_cfg);
  assign fop1_vs_out        = vs_q;
  assign fop1_nnr_out       = nnr_q;
  assign fop1_ack_cnt_out   = ack_cnt_q;
  assign fop1_retransmit_cnt_out = retx_cnt_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      vs_q                      <= 8'd0;
      nnr_q                     <= 8'd0;
      t1_cnt_q                  <= 16'd0;
      timer_active_q            <= 1'b0;
      ack_cnt_q                 <= 16'd0;
      retx_cnt_q                <= 16'd0;
      fop1_retransmit_pulse_out <= 1'b0;
      fop1_replay_from_seq_out  <= 8'd0;
      fop1_unlock_req_out       <= 1'b0;
    end else begin
      fop1_retransmit_pulse_out <= 1'b0;

      if (tx_type_ad_req_pulse && tx_window_open_out) begin
        vs_q           <= vs_q + 8'd1;
        timer_active_q <= 1'b1;
        t1_cnt_q       <= 16'd0;
      end else if (timer_active_q) begin
        if (t1_cnt_q >= t1_timeout_cycles_cfg) begin
          t1_cnt_q                  <= 16'd0;
          vs_q                      <= nnr_q;
          fop1_retransmit_pulse_out <= 1'b1;
          fop1_replay_from_seq_out  <= nnr_q;
          retx_cnt_q                <= retx_cnt_q + 16'd1;
        end else begin
          t1_cnt_q <= t1_cnt_q + 16'd1;
        end
      end

      if (rx_clcw_valid_pulse && (rx_clcw_in.vcid == target_vcid_cfg)) begin
        fop1_unlock_req_out <= rx_clcw_in.lockout;
        if (rx_clcw_in.report_value != nnr_q) begin
          logic [7:0] newly_acked;
          newly_acked = rx_clcw_in.report_value - nnr_q;
          nnr_q       <= rx_clcw_in.report_value;
          ack_cnt_q   <= ack_cnt_q + {8'd0, newly_acked};
          t1_cnt_q    <= 16'd0;
          if (rx_clcw_in.report_value == vs_q) begin
            timer_active_q <= 1'b0;
          end
        end

        if (rx_clcw_in.retransmit && (rx_clcw_in.report_value != vs_q)) begin
          vs_q                      <= rx_clcw_in.report_value;
          fop1_retransmit_pulse_out <= 1'b1;
          fop1_replay_from_seq_out  <= rx_clcw_in.report_value;
          retx_cnt_q                <= retx_cnt_q + 16'd1;
          t1_cnt_q                  <= 16'd0;
        end
      end
    end
  end

endmodule
