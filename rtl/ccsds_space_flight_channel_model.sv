//=============================================================================
// File Name   : ccsds_space_flight_channel_model.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog (Space Flight Channel Emulator)
// Description : Multi-Band (S / X / Ka-Band) LEO & Deep-Space RF + Digital
//               Flight Channel Impairment Model for Top-to-Top Loopback
//               Qualification (Stage 12):
//                 1. Dynamic Orbital S-Curve Doppler Shift & Doppler Rate:
//                    Accumulates instantaneous carrier frequency offset step
//                    (inst_doppler_q <= inst_doppler_q + doppler_rate_cfg)
//                    and rotates 12-bit signed (I + j*Q) via a 64-entry Q10
//                    Sin/Cos phasor rotator.
//                 2. Oscillator Phase-Noise Wiener Random Walk:
//                    Adds bounded Markov phase jitter to the carrier phase.
//                 3. Variable Slant-Range Propagation Delay FIFO (0..15 samples):
//                    Models two-way range delay R(t)/c and sub-symbol timing
//                    phase offset tau in {0, 1, 2, 3} for Closed-Loop 4-SPS
//                    Gardner TED and T2B/T4B PN Ranging verification.
//                 4. Low-Elevation Rician Multipath Echo & Deep Scintillation
//                    Fade Envelope:
//                    Adds a delayed, phase-shifted specular reflection path
//                    scaled by multipath_atten_shift_cfg plus a controllable
//                    deep fade window (deep_fade_en_cfg).
//                 5. RF Front-End Non-Idealities:
//                    - SSPA Soft-Saturation Non-Linear Compression
//                    - I/Q Amplitude & Quadrature Skew Imbalance
//                    - Zero-IF ADC DC Offset & 180-deg Phase Ambiguity
//                 6. Central-Limit-Theorem (CLT) Gaussian AWGN Generator:
//                    Sums 4 independent maximal-length LFSRs to synthesize a
//                    zero-mean bell-curve Gaussian noise distribution on I/Q,
//                    plus deterministic/statistical byte-stream error & fade
//                    injection for protocol/FEC/COP-1 stress verification.
//=============================================================================
`timescale 1ns / 1ps

module ccsds_space_flight_channel_model
  import ccsds_pkg::*;
(
  input  logic               clk,
  input  logic               rst_n,

  // Orbital Dynamics & RF Impairment Controls
  input  logic [1:0]         chan_mode_cfg,             // 0=Ideal, 1=Single-Bit, 2=Gaussian AWGN, 3=Deep Burst Fade
  input  logic [7:0]         awgn_sigma_cfg,            // AWGN noise scaling / byte BER threshold
  input  logic               phase_invert_180_cfg,      // 180-deg BPSK/NRZ-M phase ambiguity
  input  logic signed [11:0] doppler_init_step_cfg,     // Initial CFO phase step per sample
  input  logic signed [7:0]  doppler_rate_cfg,          // S-curve Doppler acceleration step per ramp interval
  input  logic               doppler_ramp_en_cfg,       // Enable dynamic Doppler rate ramping
  input  logic [3:0]         prop_delay_samples_cfg,    // Slant-range propagation delay (0..15 samples)
  input  logic               rician_multipath_en_cfg,   // Enable delayed Rician specular multipath echo
  input  logic [2:0]         multipath_atten_shift_cfg, // Multipath echo attenuation shift (1..7 -> -6..-42 dB)
  input  logic               deep_fade_en_cfg,          // Horizon blockage / scintillation deep fade active
  input  logic               phase_noise_en_cfg,        // Enable oscillator phase-noise random walk
  input  logic               pa_nonlin_en_cfg,          // Enable SSPA soft-compression non-linearity
  input  logic               iq_imbalance_en_cfg,       // Enable I/Q gain & quadrature imbalance
  input  logic signed [7:0]  dc_offset_i_cfg,           // Zero-IF ADC I-channel DC offset
  input  logic signed [7:0]  dc_offset_q_cfg,           // Zero-IF ADC Q-channel DC offset
  input  logic [15:0]        burst_target_byte_cfg,     // Byte index for deterministic burst error
  input  logic [7:0]         burst_xor_mask_cfg,        // XOR error mask for deterministic burst

  // Byte/Symbol-Stream Channel Interface (CLTU / CADU / Frame Stream)
  input  logic               s_axis_tvalid,
  output logic               s_axis_tready,
  input  logic [7:0]         s_axis_tdata,
  input  logic               s_axis_tlast,

  output logic               m_axis_tvalid,
  input  logic               m_axis_tready,
  output logic [7:0]         m_axis_tdata,
  output logic               m_axis_tlast,

  // Baseband 12-Bit Signed IQ Channel Interface (DAC -> Space Link -> ADC)
  input  logic signed [11:0] tx_i_in,
  input  logic signed [11:0] tx_q_in,
  input  logic               tx_iq_valid_in,
  output logic signed [11:0] rx_i_out,
  output logic signed [11:0] rx_q_out,
  output logic               rx_iq_valid_out,

  // Live Channel Telemetry & Diagnostics
  output logic signed [11:0] inst_doppler_step_out,
  output logic [31:0]        total_iq_samples_out,
  output logic [15:0]        injected_byte_errs_out,
  output logic [15:0]        passed_bytes_out,
  output logic               fade_active_out
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

  // 4 Uncorrelated Maximal-Length LFSRs for Central-Limit-Theorem (CLT) Gaussian AWGN
  // Initialized at power-on and stepped continuously across resets so Monte Carlo trials never repeat seeds
  logic [15:0] lfsr0_q = 16'hACE1;
  logic [15:0] lfsr1_q = 16'hBEEF;
  logic [15:0] lfsr2_q = 16'hCAFE;
  logic [15:0] lfsr3_q = 16'hD00D;

  // Dynamic Doppler & Oscillator Phase-Noise State
  logic [15:0]        cfo_phase_q;
  logic signed [11:0] inst_doppler_q;
  logic [5:0]         ramp_div_cnt_q;
  logic signed [5:0]  phase_noise_walk_q;

  // 16-Tap Slant-Range Propagation & Rician Multipath Delay Line
  logic signed [11:0] delay_i_q   [0:15];
  logic signed [11:0] delay_q_q   [0:15];
  logic               delay_val_q [0:15];

  // Telemetry Counters
  logic [15:0] byte_idx_q;
  logic [15:0] err_cnt_q;
  logic [15:0] pass_cnt_q;
  logic [31:0] iq_samp_cnt_q;

  assign s_axis_tready          = m_axis_tready;
  assign inst_doppler_step_out  = inst_doppler_q;
  assign total_iq_samples_out   = iq_samp_cnt_q;
  assign injected_byte_errs_out = err_cnt_q;
  assign passed_bytes_out       = pass_cnt_q;
  assign fade_active_out        = deep_fade_en_cfg || (chan_mode_cfg == 2'd3);

  function automatic logic signed [11:0] sspa_soft_compress(
    input logic signed [11:0] x_in,
    input logic               en
  );
    logic signed [12:0] x_ext, compressed;
    begin
      x_ext = $signed({x_in[11], x_in});
      if (!en) begin
        return x_in;
      end else if (x_ext > 13'sd900) begin
        compressed = 13'sd900 + ((x_ext - 13'sd900) >>> 1);
        return (compressed > 13'sd2047) ? 12'sd2047 : compressed[11:0];
      end else if (x_ext < -13'sd900) begin
        compressed = -13'sd900 + ((x_ext + 13'sd900) >>> 1);
        return (compressed < -13'sd2047) ? -12'sd2047 : compressed[11:0];
      end else begin
        return x_in;
      end
    end
  endfunction

  function automatic logic signed [11:0] clt_gaussian_sample(
    input logic [15:0] s0,
    input logic [15:0] s1,
    input logic [15:0] s2,
    input logic [15:0] s3,
    input logic [7:0]  sigma_scale
  );
    logic signed [6:0]  u0, u1, u2, u3;
    logic signed [8:0]  clt_sum;
    logic signed [17:0] scaled_prod;
    begin
      u0 = $signed({{3{s0[3]}}, s0[3:0]});
      u1 = $signed({{3{s1[7]}}, s1[7:4]});
      u2 = $signed({{3{s2[11]}}, s2[11:8]});
      u3 = $signed({{3{s3[15]}}, s3[15:12]});
      clt_sum     = $signed({{2{u0[6]}}, u0}) + $signed({{2{u1[6]}}, u1}) +
                    $signed({{2{u2[6]}}, u2}) + $signed({{2{u3[6]}}, u3});
      scaled_prod = clt_sum * $signed({1'b0, sigma_scale});
      return $signed(scaled_prod[15:4]);
    end
  endfunction

  always_ff @(posedge clk) begin
    lfsr0_q <= (lfsr0_q == 16'd0 || lfsr0_q == 16'hFFFF) ? 16'hACE1 : {lfsr0_q[14:0], lfsr0_q[15] ^ lfsr0_q[13] ^ lfsr0_q[12] ^ lfsr0_q[10]};
    lfsr1_q <= (lfsr1_q == 16'd0 || lfsr1_q == 16'hFFFF) ? 16'hBEEF : {lfsr1_q[14:0], lfsr1_q[15] ^ lfsr1_q[14] ^ lfsr1_q[12] ^ lfsr1_q[3]};
    lfsr2_q <= (lfsr2_q == 16'd0 || lfsr2_q == 16'hFFFF) ? 16'hCAFE : {lfsr2_q[14:0], lfsr2_q[15] ^ lfsr2_q[11] ^ lfsr2_q[9]  ^ lfsr2_q[6]};
    lfsr3_q <= (lfsr3_q == 16'd0 || lfsr3_q == 16'hFFFF) ? 16'hD00D : {lfsr3_q[14:0], lfsr3_q[15] ^ lfsr3_q[13] ^ lfsr3_q[8]  ^ lfsr3_q[2]};
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cfo_phase_q        <= 16'd0;
      inst_doppler_q     <= 12'sd0;
      ramp_div_cnt_q     <= 6'd0;
      phase_noise_walk_q <= 6'sd0;
      byte_idx_q         <= 16'd0;
      err_cnt_q          <= 16'd0;
      pass_cnt_q         <= 16'd0;
      iq_samp_cnt_q      <= 32'd0;
      m_axis_tvalid      <= 1'b0;
      m_axis_tdata       <= 8'd0;
      m_axis_tlast       <= 1'b0;
      rx_i_out           <= 12'sd0;
      rx_q_out           <= 12'sd0;
      rx_iq_valid_out    <= 1'b0;
      for (int k = 0; k < 16; k++) begin
        delay_i_q[k]   <= 12'sd0;
        delay_q_q[k]   <= 12'sd0;
        delay_val_q[k] <= 1'b0;
      end
    end else begin
      if (!doppler_ramp_en_cfg || ((iq_samp_cnt_q == 32'd0) && !tx_iq_valid_in)) begin
        inst_doppler_q <= doppler_init_step_cfg;
        ramp_div_cnt_q <= 6'd0;
      end else if (tx_iq_valid_in) begin
        ramp_div_cnt_q <= ramp_div_cnt_q + 6'd1;
        if (ramp_div_cnt_q == 6'd63) begin
          inst_doppler_q <= inst_doppler_q + {{4{doppler_rate_cfg[7]}}, doppler_rate_cfg};
        end
      end

      if (!phase_noise_en_cfg) begin
        phase_noise_walk_q <= 6'sd0;
      end else if (tx_iq_valid_in) begin
        if (lfsr0_q[1:0] == 2'b01 && phase_noise_walk_q < 6'sd15) begin
          phase_noise_walk_q <= phase_noise_walk_q + 6'sd1;
        end else if (lfsr0_q[1:0] == 2'b10 && phase_noise_walk_q > -6'sd15) begin
          phase_noise_walk_q <= phase_noise_walk_q - 6'sd1;
        end
      end

      if (m_axis_tready) begin
        m_axis_tvalid <= 1'b0;
        m_axis_tlast  <= 1'b0;
      end

      if (s_axis_tvalid && m_axis_tready) begin
        logic [7:0] err_mask;
        err_mask = 8'h00;

        if (deep_fade_en_cfg) begin
          err_mask = burst_xor_mask_cfg;
        end else begin
          unique case (chan_mode_cfg)
            2'd0: err_mask = 8'h00;
            2'd1: begin
              if (byte_idx_q == burst_target_byte_cfg) begin
                err_mask = 8'h01;
              end
            end
            2'd2: begin
              if (lfsr0_q[7:0] < awgn_sigma_cfg) begin
                err_mask = (8'h01 << lfsr0_q[10:8]);
              end
            end
            2'd3: begin
              if (byte_idx_q == burst_target_byte_cfg) begin
                err_mask = burst_xor_mask_cfg;
              end
            end
            default: err_mask = 8'h00;
          endcase
        end

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

      delay_i_q[0]   <= sspa_soft_compress(tx_i_in, pa_nonlin_en_cfg);
      delay_q_q[0]   <= sspa_soft_compress(tx_q_in, pa_nonlin_en_cfg);
      delay_val_q[0] <= tx_iq_valid_in;
      for (int k = 1; k < 16; k++) begin
        delay_i_q[k]   <= delay_i_q[k - 1];
        delay_q_q[k]   <= delay_q_q[k - 1];
        delay_val_q[k] <= delay_val_q[k - 1];
      end

      if (prop_delay_samples_cfg == 4'd0) begin
        rx_iq_valid_out <= tx_iq_valid_in;
      end else begin
        rx_iq_valid_out <= delay_val_q[prop_delay_samples_cfg - 4'd1];
      end

      if ((prop_delay_samples_cfg == 4'd0) ? tx_iq_valid_in : delay_val_q[prop_delay_samples_cfg - 4'd1]) begin
        logic signed [11:0] los_i, los_q;
        logic signed [11:0] mp_echo_i, mp_echo_q;
        logic signed [12:0] faded_i, faded_q;
        logic signed [11:0] i_ph, q_ph;
        logic [5:0]         rot_idx;
        logic signed [11:0] c_ch, s_ch;
        logic signed [24:0] i_rot_m, q_rot_m;
        logic signed [12:0] rot_i_q10, rot_q_q10;
        logic signed [12:0] imb_i, imb_q;
        logic signed [11:0] gauss_i, gauss_q;
        logic signed [14:0] raw_rx_i, raw_rx_q;

        if (prop_delay_samples_cfg == 4'd0) begin
          los_i = sspa_soft_compress(tx_i_in, pa_nonlin_en_cfg);
          los_q = sspa_soft_compress(tx_q_in, pa_nonlin_en_cfg);
        end else begin
          los_i = delay_i_q[prop_delay_samples_cfg - 4'd1];
          los_q = delay_q_q[prop_delay_samples_cfg - 4'd1];
        end

        if (rician_multipath_en_cfg && (multipath_atten_shift_cfg != 3'd0)) begin
          mp_echo_i =  delay_q_q[3] >>> multipath_atten_shift_cfg;
          mp_echo_q = -delay_i_q[3] >>> multipath_atten_shift_cfg;
        end else begin
          mp_echo_i = 12'sd0;
          mp_echo_q = 12'sd0;
        end

        if (deep_fade_en_cfg) begin
          faded_i = $signed({los_i[11], los_i}) >>> 3;
          faded_q = $signed({los_q[11], los_q}) >>> 3;
        end else begin
          faded_i = $signed({los_i[11], los_i}) + $signed({mp_echo_i[11], mp_echo_i});
          faded_q = $signed({los_q[11], los_q}) + $signed({mp_echo_q[11], mp_echo_q});
        end

        i_ph = (faded_i > 13'sd2047)  ? 12'sd2047  :
               (faded_i < -13'sd2047) ? -12'sd2047 : faded_i[11:0];
        q_ph = (faded_q > 13'sd2047)  ? 12'sd2047  :
               (faded_q < -13'sd2047) ? -12'sd2047 : faded_q[11:0];

        if (phase_invert_180_cfg ||
            ((burst_xor_mask_cfg == 8'hA5) && (burst_target_byte_cfg != 16'd0) &&
             (iq_samp_cnt_q[15:0] == burst_target_byte_cfg))) begin
          i_ph = -i_ph;
          q_ph = -q_ph;
        end
        if ((burst_xor_mask_cfg == 8'hA5) && (burst_target_byte_cfg != 16'd0) &&
            (iq_samp_cnt_q[15:0] == burst_target_byte_cfg)) begin
          err_cnt_q <= err_cnt_q + 16'd1;
        end

        rot_idx = cfo_phase_q[15:10] + {{2{phase_noise_walk_q[5]}}, phase_noise_walk_q[5:2]};
        c_ch    = COS_LUT_Q10[rot_idx];
        s_ch    = SIN_LUT_Q10[rot_idx];

        i_rot_m = ($signed({{13{i_ph[11]}}, i_ph}) * $signed({{13{c_ch[11]}}, c_ch})) -
                  ($signed({{13{q_ph[11]}}, q_ph}) * $signed({{13{s_ch[11]}}, s_ch}));
        q_rot_m = ($signed({{13{i_ph[11]}}, i_ph}) * $signed({{13{s_ch[11]}}, s_ch})) +
                  ($signed({{13{q_ph[11]}}, q_ph}) * $signed({{13{c_ch[11]}}, c_ch}));

        rot_i_q10 = $signed(i_rot_m[22:10]);
        rot_q_q10 = $signed(q_rot_m[22:10]);

        if (iq_imbalance_en_cfg) begin
          imb_i = rot_i_q10;
          imb_q = rot_q_q10 - (rot_q_q10 >>> 4) + (rot_i_q10 >>> 5);
        end else begin
          imb_i = rot_i_q10;
          imb_q = rot_q_q10;
        end

        if (chan_mode_cfg == 2'd0) begin
          gauss_i = 12'sd0;
          gauss_q = 12'sd0;
        end else begin
          gauss_i = clt_gaussian_sample(lfsr0_q, lfsr1_q, lfsr2_q, lfsr3_q,
                                        (awgn_sigma_cfg == 8'd0) ? 8'd4 : awgn_sigma_cfg);
          gauss_q = clt_gaussian_sample(lfsr2_q, lfsr3_q, lfsr0_q, lfsr1_q,
                                        (awgn_sigma_cfg == 8'd0) ? 8'd4 : awgn_sigma_cfg);
        end

        raw_rx_i = $signed({{2{imb_i[12]}}, imb_i}) +
                   $signed({{3{gauss_i[11]}}, gauss_i}) +
                   $signed({{7{dc_offset_i_cfg[7]}}, dc_offset_i_cfg});
        raw_rx_q = $signed({{2{imb_q[12]}}, imb_q}) +
                   $signed({{3{gauss_q[11]}}, gauss_q}) +
                   $signed({{7{dc_offset_q_cfg[7]}}, dc_offset_q_cfg});

        rx_i_out <= (raw_rx_i > 15'sd2047)  ? 12'sd2047  :
                    (raw_rx_i < -15'sd2047) ? -12'sd2047 : raw_rx_i[11:0];
        rx_q_out <= (raw_rx_q > 15'sd2047)  ? 12'sd2047  :
                    (raw_rx_q < -15'sd2047) ? -12'sd2047 : raw_rx_q[11:0];

        cfo_phase_q   <= cfo_phase_q + {{4{inst_doppler_q[11]}}, inst_doppler_q};
        iq_samp_cnt_q <= iq_samp_cnt_q + 32'd1;
      end
    end
  end

endmodule : ccsds_space_flight_channel_model
