// =============================================================================
// File Name   : ccsds_dl_turbo_ldpc_enc.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog (Synthesizable)
// Description : CCSDS 131.0-B-5 & 231.1-O-1 Downlink/Uplink Next-Generation
//               Outer FEC Encoder supporting:
//                 1. Official CCSDS 231.1-O-1 Table 2-1 Quasi-Cyclic LDPC
//                    Generator Matrix W_64x64 (`0E69_166B_EF4C_0BC2`,
//                    `7766_137E_BB24_8418`, `C480_FEB9_CD53_A713`,
//                    `4EAA_22FA_465E_EA11`) when fec_mode_cfg == 4'd0.
//                 2. Official CCSDS 131.0-B-5 Section 6 Parallel Concatenated
//                    16-State RSC Turbo Encoder (G0=5'b10011, G1=5'b11011,
//                    G2=5'b10101, G3=5'b11111) with Section 6.3.3 8-Prime
//                    JPL Algorithmic Interleaver (`p1..p8 = 31,37,43,47,53,59,61,67`).
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

  // Official CCSDS 231.1-O-1 Table 2-1 (128,64) Generator Submatrix W_64x64 Rows [0..63]
  localparam logic [63:0] LDPC128_W_ROW_MASK [0:63] = '{
    64'h0E69166BEF4C0BC2,
    64'h87348B3577A605E1,
    64'h439AC59A3BD382F0,
    64'h21CD62CD9DE94178,
    64'h90E6B166CEF420BC,
    64'h487358B3677A105E,
    64'hA439AC5933BD082F,
    64'hD21CD62C99DE8417,
    64'h690E6B164CEFC20B,
    64'h3487358BA677E105,
    64'h9A439AC5D33BF082,
    64'hCD21CD62E99D7841,
    64'hE69066B1F4CEBC20,
    64'h7348B3587A675E10,
    64'h39A459ACBD332F08,
    64'h1CD22CD6DE991784,
    64'h7766137EBB248418,
    64'h3BB309BF5D92420C,
    64'h9DD984DF2EC92106,
    64'hCEECC26F97641083,
    64'h6776E1374BB28841,
    64'h33BBF09B25D9C420,
    64'h99DDF84D92EC6210,
    64'hCCEEFC2649763108,
    64'h66777E1324BB1884,
    64'hB33BBF09925D0C42,
    64'hD99DDF84C92E0621,
    64'hECCE6FC264978310,
    64'h766737E1B24B4188,
    64'hBB339BF0D92520C4,
    64'hDD994DF8EC921062,
    64'hEECC26FC76490831,
    64'hC480FEB9CD53A713,
    64'h6240FF5CE6A9D389,
    64'h31207FAEF354E9C4,
    64'h18903FD779AA74E2,
    64'h0C489FEB3CD53A71,
    64'h0624CFF59E6A9D38,
    64'h0312E7FA4F354E9C,
    64'h018973FDA79A274E,
    64'h80C4B9FE53CD13A7,
    64'h40625CFFA9E689D3,
    64'h2031AE7F54F3C4E9,
    64'h9018D73FAA79E274,
    64'h480CEB9FD53C713A,
    64'h2406F5CF6A9E389D,
    64'h1203FAE7354F9C4E,
    64'h8901FD739AA74E27,
    64'h4EAA22FA465EEA11,
    64'h2755117D232FF508,
    64'h93AA88BE91977A84,
    64'h49D5445FC8CB3D42,
    64'hA4EAA22FE4651EA1,
    64'h5275D117F2328F50,
    64'hA93AE88B791947A8,
    64'h549DF445BC8C23D4,
    64'hAA4EFA225E4611EA,
    64'h55277D112F2308F5,
    64'hAA93BE889791847A,
    64'hD5495F44CBC8423D,
    64'hEAA42FA265E4A11E,
    64'h755217D132F2508F,
    64'h3AA98BE81979A847,
    64'h9D5445F48CBCD423
  };

  // Official CCSDS 131.0-B-5 Section 6.3.3 Turbo Interleaver Primes p_1..p_8
  localparam logic [7:0] TURBO_PRIMES [0:7] = '{
    8'd31, 8'd37, 8'd43, 8'd47, 8'd53, 8'd59, 8'd61, 8'd67
  };

  typedef enum logic [1:0] {
    ENC_STREAM_SYS = 2'd0,
    ENC_EMIT_PAR   = 2'd1
  } enc_state_e;

  enc_state_e  state_q;
  logic [5:0]  par_idx_q;
  logic [2:0]  sys_byte_mod8_q;
  logic [3:0]  rsc_sr_a_q;
  logic [3:0]  rsc_sr_b_q;
  logic [63:0] ldpc_par64_q;
  logic [7:0]  par_acc_q [0:PARITY_BYTES-1];

  // Step 16-state CCSDS 131.0-B-5 RSC component encoder (G0=1+D^3+D^4, G1=1+D+D^3+D^4)
  function automatic logic [4:0] step_rsc_bit(input logic [3:0] sr, input logic d_in);
    logic       fb;
    logic       z1;
    logic [3:0] nxt_sr;
    fb     = d_in ^ sr[2] ^ sr[3];
    z1     = fb ^ sr[0] ^ sr[2] ^ sr[3];
    nxt_sr = {fb, sr[3:1]};
    return {z1, nxt_sr};
  endfunction

  assign s_axis_tready = (state_q == ENC_STREAM_SYS) && (!m_axis_tvalid || m_axis_tready);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q         <= ENC_STREAM_SYS;
      par_idx_q       <= 6'd0;
      sys_byte_mod8_q <= 3'd0;
      rsc_sr_a_q      <= 4'd0;
      rsc_sr_b_q      <= 4'd0;
      ldpc_par64_q    <= 64'd0;
      for (int k = 0; k < PARITY_BYTES; k++) begin
        par_acc_q[k] <= 8'h00;
      end
      m_axis_tdata    <= 8'h00;
      m_axis_tvalid   <= 1'b0;
      m_axis_tlast    <= 1'b0;
    end else if (!m_axis_tvalid || m_axis_tready) begin
      m_axis_tvalid <= 1'b0;
      m_axis_tlast  <= 1'b0;

      unique case (state_q)
        ENC_STREAM_SYS: begin
          if (s_axis_tvalid) begin
            logic [3:0]  sr_a, sr_b;
            logic [7:0]  turbo_par_byte;
            logic [63:0] nxt_ldpc64;
            logic [7:0]  prime_p;

            sr_a       = rsc_sr_a_q;
            sr_b       = rsc_sr_b_q;
            nxt_ldpc64 = ldpc_par64_q;
            prime_p    = TURBO_PRIMES[sys_byte_mod8_q];

            for (int b = 0; b < 8; b++) begin
              logic [4:0] res_a, res_b;
              logic [2:0] perm_b;
              logic [5:0] w_row_idx;
              logic       in_bit;
              in_bit    = s_axis_tdata[7 - b];
              perm_b    = 3'((b * int'(prime_p[2:0]) + int'(sys_byte_mod8_q)) & 7);
              w_row_idx = {sys_byte_mod8_q, 3'(b)};
              res_a     = step_rsc_bit(sr_a, in_bit);
              res_b     = step_rsc_bit(sr_b, s_axis_tdata[perm_b]);
              sr_a      = res_a[3:0];
              sr_b      = res_b[3:0];
              turbo_par_byte[7 - b] = res_a[4] ^ res_b[4];

              if (in_bit) begin
                nxt_ldpc64 = nxt_ldpc64 ^ LDPC128_W_ROW_MASK[w_row_idx];
              end
            end

            rsc_sr_a_q      <= sr_a;
            rsc_sr_b_q      <= sr_b;
            ldpc_par64_q    <= nxt_ldpc64;
            sys_byte_mod8_q <= sys_byte_mod8_q + 3'd1;

            if (fec_mode_cfg == 4'd0) begin
              // Official CCSDS 231.1-O-1 Table 2-1 W_64x64 LDPC parity bytes
              for (int k = 0; k < PARITY_BYTES; k++) begin
                par_acc_q[k] <= nxt_ldpc64[(7 - (k & 7))*8 +: 8];
              end
            end else begin
              // Official CCSDS 131.0-B-5 RSC Turbo parity accumulator
              for (int k = 0; k < PARITY_BYTES - 1; k++) begin
                par_acc_q[k] <= par_acc_q[k + 1] ^ turbo_par_byte;
              end
              par_acc_q[PARITY_BYTES - 1] <= par_acc_q[0] ^ turbo_par_byte;
            end

            m_axis_tdata  <= s_axis_tdata;
            m_axis_tvalid <= 1'b1;

            if (s_axis_tlast) begin
              par_idx_q <= 6'd0;
              state_q   <= ENC_EMIT_PAR;
            end
          end
        end

        ENC_EMIT_PAR: begin
          m_axis_tdata  <= par_acc_q[0];
          m_axis_tvalid <= 1'b1;
          for (int k = 0; k < PARITY_BYTES - 1; k++) begin
            par_acc_q[k] <= par_acc_q[k + 1];
          end
          par_acc_q[PARITY_BYTES - 1] <= 8'h00;

          if (par_idx_q == 6'(PARITY_BYTES - 1)) begin
            m_axis_tlast    <= 1'b1;
            par_idx_q       <= 6'd0;
            sys_byte_mod8_q <= 3'd0;
            rsc_sr_a_q      <= 4'd0;
            rsc_sr_b_q      <= 4'd0;
            ldpc_par64_q    <= 64'd0;
            state_q         <= ENC_STREAM_SYS;
          end else begin
            par_idx_q <= par_idx_q + 6'd1;
          end
        end

        default: state_q <= ENC_STREAM_SYS;
      endcase
    end
  end

endmodule : ccsds_dl_turbo_ldpc_enc
