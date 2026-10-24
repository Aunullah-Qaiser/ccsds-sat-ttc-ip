//=============================================================================
// File Name   : ccsds_channel_impairment_model.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog (Synthesizable / HIL Channel Emulator)
// Description : Parameterizable RF & Digital Space Link Channel Impairment
//               Emulator for Hardware-in-the-Loop (HIL) & RTL Regression:
//                 - Mode 0 (CHAN_BEST_CASE)   : 0-noise ideal pass-through
//                 - Mode 1 (CHAN_SINGLE_ERR)  : Deterministic 1-bit flip per
//                                               codeblock + 180-deg phase inv
//                 - Mode 2 (CHAN_AWGN_SWEEP)  : Galois LFSR pseudo-Gaussian
//                                               AWGN / bit-error rate injector
//                 - Mode 3 (CHAN_BURST_DROP)  : Multi-bit burst fade on target
//                                               frame index (forces BCH abort
//                                               & COP-1 Go-Back-N replay)
//                 - Baseband IQ Complex Phasor Rotator (Fix CR-21): Rotates
//                   (tx_i_in + j*tx_q_in) by exp(j * cfo_phase_q) where
//                   cfo_phase_q accumulates doppler_offset_cfg on every sample
//                   (true Carrier Frequency Offset / Doppler shift + AWGN).
//=============================================================================
`timescale 1ns / 1ps

module ccsds_channel_impairment_model
  import ccsds_pkg::*;
(
  input  logic               clk,
  input  logic               rst_n,

  // Channel Impairment Configuration
  input  logic [1:0]         chan_mode_cfg,
  input  logic [7:0]         ber_threshold_cfg,
  input  logic               phase_invert_cfg,
  input  logic [15:0]        burst_target_byte_cfg,
  input  logic [7:0]         burst_xor_mask_cfg,
  input  logic signed [11:0] doppler_offset_cfg, // Continuous CFO phase step per sample

  // Byte-Stream Channel Interface (CLTU / CADU / Frame Stream)
  input  logic               s_axis_tvalid,
  output logic               s_axis_tready,
  input  logic [7:0]         s_axis_tdata,
  input  logic               s_axis_tlast,

  output logic               m_axis_tvalid,
  input  logic               m_axis_tready,
  output logic [7:0]         m_axis_tdata,
  output logic               m_axis_tlast,

  // Baseband IQ Channel Interface (12-bit Signed ADC/DAC Loopback)
  input  logic signed [11:0] tx_i_in,
  input  logic signed [11:0] tx_q_in,
  input  logic               tx_iq_valid_in,
  output logic signed [11:0] rx_i_out,
  output logic signed [11:0] rx_q_out,
  output logic               rx_iq_valid_out,

  // Telemetry Counters
  output logic [15:0]        injected_byte_errs_out,
  output logic [15:0]        passed_bytes_out
);

  localparam logic signed [11:0] COS_LUT_Q10 [0:63] = '{
     12'sd1024,  12'sd1019,  12'sd1004,   12'sd980,   12'sd946,   12'sd903,   12'sd851,   12'sd792,
      12'sd724,   12'sd650,   12'sd569,   12'sd483,   12'sd392,   12'sd297,   12'sd200,   12'sd100,
        12'sd0,  -12'sd100,  -12'sd200,  -12'sd297,  -12'sd392,  -12'sd483,  -12'sd569,  -12'sd650,
     -12'sd724,  -12'sd792,  -12'sd851,  -12'sd903,  -12'sd946,  -12'sd980, -12'sd1004, -12'sd1019,
    -12'sd1024, -12'sd1019, -12'sd1004,  -12'sd980,  -12'sd946,  -12'sd903,  -12'sd851,  -12'sd792,
     -12'sd724,  -12'sd650,  -12'sd569,  -12'sd483,  -12'sd392,  -12'sd297,  -12'sd200,  -12'sd100,
        12'sd0,   12'sd100,   12'sd200,   12'sd297,   12'sd392,   12'sd483,   12'sd569,   12'sd650,
      12'sd724,   12'sd792,   12'sd851,   12'sd903,   12'sd946,   12'sd980,  12'sd1004,  12'sd1019
  };

  localparam logic signed [11:0] SIN_LUT_Q10 [0:63] = '{
        12'sd0,   12'sd100,   12'sd200,   12'sd297,   12'sd392,   12'sd483,   12'sd569,   12'sd650,
      12'sd724,   12'sd792,   12'sd851,   12'sd903,   12'sd946,   12'sd980,  12'sd1004,  12'sd1019,
     12'sd1024,  12'sd1019,  12'sd1004,   12'sd980,   12'sd946,   12'sd903,   12'sd851,   12'sd792,
      12'sd724,   12'sd650,   12'sd569,   12'sd483,   12'sd392,   12'sd297,   12'sd200,   12'sd100,
        12'sd0,  -12'sd100,  -12'sd200,  -12'sd297,  -12'sd392,  -12'sd483,  -12'sd569,  -12'sd650,
     -12'sd724,  -12'sd792,  -12'sd851,  -12'sd903,  -12'sd946,  -12'sd980, -12'sd1004, -12'sd1019,
    -12'sd1024, -12'sd1019, -12'sd1004,  -12'sd980,  -12'sd946,  -12'sd903,  -12'sd851,  -12'sd792,
     -12'sd724,  -12'sd650,  -12'sd569,  -12'sd483,  -12'sd392,  -12'sd297,  -12'sd200,  -12'sd100
  };

  logic [15:0] prng_lfsr_q;
  logic [15:0] cfo_phase_q;
  logic [15:0] byte_idx_q;
  logic [15:0] err_cnt_q;
  logic [15:0] pass_cnt_q;

  assign s_axis_tready          = m_axis_tready;
  assign injected_byte_errs_out = err_cnt_q;
  assign passed_bytes_out       = pass_cnt_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      prng_lfsr_q     <= 16'hACE1;
      cfo_phase_q     <= 16'd0;
      byte_idx_q      <= 16'd0;
      err_cnt_q       <= 16'd0;
      pass_cnt_q      <= 16'd0;
      m_axis_tvalid   <= 1'b0;
      m_axis_tdata    <= 8'd0;
      m_axis_tlast    <= 1'b0;
      rx_i_out        <= 12'sd0;
      rx_q_out        <= 12'sd0;
      rx_iq_valid_out <= 1'b0;
    end else begin
      // Advance 16-bit maximal-length Fibonacci LFSR (x^16 + x^14 + x^13 + x^11 + 1)
      prng_lfsr_q <= {prng_lfsr_q[14:0], prng_lfsr_q[15] ^ prng_lfsr_q[13] ^ prng_lfsr_q[12] ^ prng_lfsr_q[10]};

      if (m_axis_tready) begin
        m_axis_tvalid <= 1'b0;
        m_axis_tlast  <= 1'b0;
      end

      if (s_axis_tvalid && m_axis_tready) begin
        logic [7:0] err_mask;
        err_mask = 8'h00;

        unique case (chan_mode_cfg)
          2'd0: err_mask = 8'h00;
          2'd1: begin
            if (byte_idx_q == burst_target_byte_cfg) begin
              err_mask = 8'h01;
            end
          end
          2'd2: begin
            if (prng_lfsr_q[7:0] < ber_threshold_cfg) begin
              err_mask = (8'h01 << prng_lfsr_q[10:8]);
            end
          end
          2'd3: begin
            if (byte_idx_q == burst_target_byte_cfg) begin
              err_mask = burst_xor_mask_cfg;
            end
          end
          default: err_mask = 8'h00;
        endcase

        m_axis_tvalid <= 1'b1;
        m_axis_tdata  <= s_axis_tdata ^ err_mask;
        m_axis_tlast  <= s_axis_tlast;
        pass_cnt_q    <= pass_cnt_q + 16'd1;

        if (err_mask != 8'h00) begin
          err_cnt_q <= err_cnt_q + 16'd1;
        end

        if (s_axis_tlast) begin
          byte_idx_q <= 16'd0;
        end else begin
          byte_idx_q <= byte_idx_q + 16'd1;
        end
      end

      // Baseband IQ Impairment Path: 180-deg Phase Inversion + Continuous CFO Rotation + Zero-Mean AWGN
      rx_iq_valid_out <= tx_iq_valid_in;
      if (tx_iq_valid_in) begin
        logic signed [11:0] i_ph, q_ph;
        logic [5:0]         rot_idx;
        logic signed [11:0] c_ch, s_ch;
        logic signed [24:0] i_rot_m, q_rot_m;
        logic signed [11:0] noise_i, noise_q;
        logic signed [13:0] raw_rx_i, raw_rx_q;

        i_ph    = phase_invert_cfg ? -tx_i_in : tx_i_in;
        q_ph    = phase_invert_cfg ? -tx_q_in : tx_q_in;
        rot_idx = cfo_phase_q[15:10];
        c_ch    = COS_LUT_Q10[rot_idx];
        s_ch    = SIN_LUT_Q10[rot_idx];

        i_rot_m = ($signed({{13{i_ph[11]}}, i_ph}) * $signed({{13{c_ch[11]}}, c_ch})) -
                  ($signed({{13{q_ph[11]}}, q_ph}) * $signed({{13{s_ch[11]}}, s_ch}));
        q_rot_m = ($signed({{13{i_ph[11]}}, i_ph}) * $signed({{13{s_ch[11]}}, s_ch})) +
                  ($signed({{13{q_ph[11]}}, q_ph}) * $signed({{13{c_ch[11]}}, c_ch}));

        noise_i = (chan_mode_cfg == 2'd0) ? 12'sd0 : $signed({{8{prng_lfsr_q[3]}}, prng_lfsr_q[3:0]});
        noise_q = (chan_mode_cfg == 2'd0) ? 12'sd0 : $signed({{8{prng_lfsr_q[7]}}, prng_lfsr_q[7:4]});

        raw_rx_i = $signed(i_rot_m[23:10]) + $signed({{2{noise_i[11]}}, noise_i});
        raw_rx_q = $signed(q_rot_m[23:10]) + $signed({{2{noise_q[11]}}, noise_q});

        // 12-bit signed ADC saturation clamp [-2047..+2047] (Fix CR-24: prevents 2's complement wrap at 45-deg QPSK peaks)
        rx_i_out <= (raw_rx_i > 14'sd2047) ? 12'sd2047 : ((raw_rx_i < -14'sd2047) ? -12'sd2047 : raw_rx_i[11:0]);
        rx_q_out <= (raw_rx_q > 14'sd2047) ? 12'sd2047 : ((raw_rx_q < -14'sd2047) ? -12'sd2047 : raw_rx_q[11:0]);
        cfo_phase_q <= cfo_phase_q + {{4{doppler_offset_cfg[11]}}, doppler_offset_cfg};
      end
    end
  end

endmodule : ccsds_channel_impairment_model
