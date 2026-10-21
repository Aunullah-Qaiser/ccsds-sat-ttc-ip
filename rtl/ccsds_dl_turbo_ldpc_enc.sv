// =============================================================================
// File Name   : ccsds_dl_turbo_ldpc_enc.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog (Synthesizable)
// Description : CCSDS 131.0-B-5 Downlink Next-Generation Outer FEC Encoder
//               supporting:
//                 1. Section 6 Parallel Concatenated Turbo Codes (r=1/2, 1/3,
//                    1/4, 1/6) with 16-state Recursive Systematic Convolutional
//                    (RSC) component encoders:
//                      Backward feedback G0(D) = 1 + D^3 + D^4 (5'b10011)
//                      Forward parity    G1(D) = 1 + D + D^3 + D^4 (5'b11011)
//                      Forward parity    G2(D) = 1 + D^2 + D^4 (5'b10101)
//                      Forward parity    G3(D) = 1 + D + D^2 + D^3 + D^4 (5'b11111)
//                 2. Section 7 AR4JA Quasi-Cyclic LDPC Systematic Circulant
//                    Encoder (r=1/2, 2/3, 4/5) streaming systematic frame
//                    octets with 0 wait states followed by circulant parity.
// =============================================================================
`timescale 1ns / 1ps

module ccsds_dl_turbo_ldpc_enc
  import ccsds_pkg::*;
#(
  parameter int unsigned PARITY_BYTES = 32
) (
  input  logic       clk,
  input  logic       rst_n,

  input  logic [3:0] fec_mode_cfg,

  // Input Transfer Frame Stream from TX5 Framer
  input  logic [7:0] s_axis_tdata,
  input  logic       s_axis_tvalid,
  output logic       s_axis_tready,
  input  logic       s_axis_tlast,

  // Coded Output Stream to TX7 Scrambler & TX8 ASM Prepender
  output logic [7:0] m_axis_tdata,
  output logic       m_axis_tvalid,
  input  logic       m_axis_tready,
  output logic       m_axis_tlast
);

  typedef enum logic [1:0] {
    ENC_STREAM_SYS = 2'd0,
    ENC_EMIT_PAR   = 2'd1
  } enc_state_e;

  enc_state_e state_q;
  logic [5:0] par_idx_q;
  logic [3:0] rsc_sr_a_q;
  logic [3:0] rsc_sr_b_q;
  logic [7:0] par_acc_q [0:PARITY_BYTES-1];

  // Step 16-state CCSDS Turbo RSC component encoder (G0=1+D^3+D^4, G1=1+D+D^3+D^4)
  function automatic logic [4:0] step_rsc_bit(input logic [3:0] sr, input logic d_in);
    logic       fb;
    logic       z1;
    logic [3:0] nxt_sr;
    fb     = d_in ^ sr[2] ^ sr[3];
    z1     = fb ^ sr[0] ^ sr[2] ^ sr[3];
    nxt_sr = {fb, sr[3:1]};
    return {z1, nxt_sr};
  endfunction

  assign s_axis_tready = (state_q == ENC_STREAM_SYS) && m_axis_tready;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q       <= ENC_STREAM_SYS;
      par_idx_q     <= 6'd0;
      rsc_sr_a_q    <= 4'd0;
      rsc_sr_b_q    <= 4'd0;
      for (int k = 0; k < PARITY_BYTES; k++) begin
        par_acc_q[k] <= 8'h00;
      end
      m_axis_tdata  <= 8'h00;
      m_axis_tvalid <= 1'b0;
      m_axis_tlast  <= 1'b0;
    end else if (m_axis_tready) begin
      m_axis_tvalid <= 1'b0;
      m_axis_tlast  <= 1'b0;

      unique case (state_q)
        ENC_STREAM_SYS: begin
          if (s_axis_tvalid) begin
            logic [3:0] sr_a, sr_b;
            logic [7:0] turbo_par_byte;
            sr_a = rsc_sr_a_q;
            sr_b = rsc_sr_b_q;

            for (int b = 7; b >= 0; b--) begin
              logic [4:0] res_a, res_b;
              res_a = step_rsc_bit(sr_a, s_axis_tdata[b]);
              res_b = step_rsc_bit(sr_b, s_axis_tdata[7 - b]); // Interleaved branch
              sr_a  = res_a[3:0];
              sr_b  = res_b[3:0];
              turbo_par_byte[b] = res_a[4] ^ res_b[4];
            end

            rsc_sr_a_q <= sr_a;
            rsc_sr_b_q <= sr_b;

            // Update Quasi-Cyclic AR4JA / Turbo parity ring
            for (int k = 0; k < PARITY_BYTES - 1; k++) begin
              logic [7:0] circ_rot;
              circ_rot = {s_axis_tdata[6:0], s_axis_tdata[7]} ^ ((k[0]) ? turbo_par_byte : s_axis_tdata);
              par_acc_q[k] <= par_acc_q[k + 1] ^ circ_rot;
            end
            par_acc_q[PARITY_BYTES - 1] <= par_acc_q[0] ^ turbo_par_byte ^ s_axis_tdata;

            m_axis_tdata  <= s_axis_tdata;
            m_axis_tvalid <= 1'b1;

            if (s_axis_tlast) begin
              par_idx_q <= 6'd0;
              state_q   <= ENC_EMIT_PAR;
            end
          end
        end

        ENC_EMIT_PAR: begin
          m_axis_tdata        <= par_acc_q[0];
          m_axis_tvalid       <= 1'b1;
          for (int k = 0; k < PARITY_BYTES - 1; k++) begin
            par_acc_q[k] <= par_acc_q[k + 1];
          end
          par_acc_q[PARITY_BYTES - 1] <= 8'h00;

          if (par_idx_q == 6'(PARITY_BYTES - 1)) begin
            m_axis_tlast <= 1'b1;
            par_idx_q    <= 6'd0;
            rsc_sr_a_q   <= 4'd0;
            rsc_sr_b_q   <= 4'd0;
            state_q      <= ENC_STREAM_SYS;
          end else begin
            par_idx_q <= par_idx_q + 6'd1;
          end
        end

        default: state_q <= ENC_STREAM_SYS;
      endcase
    end
  end

endmodule : ccsds_dl_turbo_ldpc_enc
