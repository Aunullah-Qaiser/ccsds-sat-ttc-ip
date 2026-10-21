// =============================================================================
// File Name   : ccsds_gf256_math.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog (Synthesizable)
// Description : GF(2^8) Standard/Dual-Basis Multiplier & Converters + AOS
//               GF(2^4) Frame Header Error Control (FHEC) RS(10,6) Codec per
//               CCSDS 732.0-B-4 Annex B (g(x) = (x+alpha^6)(x+alpha^7)(x+alpha^8)(x+alpha^9)
//               = x^4 + alpha^3 x^3 + alpha^1 x^2 + alpha^3 x + 1
//               = x^4 + 4'h8 x^3 + 4'h2 x^2 + 4'h8 x + 4'h1 over p(x) = x^4 + x + 1).
// =============================================================================
`timescale 1ns / 1ps

module ccsds_gf256_math
  import ccsds_pkg::*;
(
  input  logic [7:0]  gf256_a_std,
  input  logic [7:0]  gf256_b_std,
  output logic [7:0]  gf256_prod_std,

  input  logic [7:0]  std_in,
  output logic [7:0]  dual_out,

  input  logic [7:0]  dual_in,
  output logic [7:0]  std_out,

  input  logic [23:0] aos_hdr_protected_24b,
  input  logic [15:0] aos_fhec_rx_16b,
  output logic [15:0] aos_fhec_tx_16b,
  output logic        aos_fhec_syndrome_ok
);

  function automatic logic [7:0] mul_gf256_std(
    input logic [7:0] a,
    input logic [7:0] b
  );
    logic [7:0] p;
    logic [7:0] cur;
    logic       hi;
    p   = 8'h00;
    cur = a;
    for (int i = 0; i < 8; i++) begin
      if (b[i]) begin
        p = p ^ cur;
      end
      hi  = cur[7];
      cur = {cur[6:0], 1'b0};
      if (hi) begin
        cur = cur ^ 8'h87;
      end
    end
    return p;
  endfunction

  function automatic logic [3:0] mul_gf16(
    input logic [3:0] a,
    input logic [3:0] b
  );
    logic [3:0] p;
    logic [3:0] cur;
    logic       hi;
    p   = 4'h0;
    cur = a;
    for (int i = 0; i < 4; i++) begin
      if (b[i]) begin
        p = p ^ cur;
      end
      hi  = cur[3];
      cur = {cur[2:0], 1'b0};
      if (hi) begin
        cur = cur ^ 4'h3;
      end
    end
    return p;
  endfunction

  function automatic logic [15:0] compute_aos_fhec(input logic [23:0] hdr24);
    logic [3:0] r [0:3];
    logic [3:0] fb;
    logic [3:0] sym;
    r[0] = 4'h0;
    r[1] = 4'h0;
    r[2] = 4'h0;
    r[3] = 4'h0;
    for (int k = 5; k >= 0; k--) begin
      sym  = hdr24[k*4 +: 4];
      fb   = sym ^ r[0];
      r[0] = r[1] ^ mul_gf16(fb, 4'h8);
      r[1] = r[2] ^ mul_gf16(fb, 4'h2);
      r[2] = r[3] ^ mul_gf16(fb, 4'h8);
      r[3] =        mul_gf16(fb, 4'h1);
    end
    return {r[0], r[1], r[2], r[3]};
  endfunction

  always_comb begin
    gf256_prod_std       = mul_gf256_std(gf256_a_std, gf256_b_std);
    dual_out             = gf256_std_to_dual(std_in);
    std_out              = gf256_dual_to_std(dual_in);
    aos_fhec_tx_16b      = compute_aos_fhec(aos_hdr_protected_24b);
    aos_fhec_syndrome_ok = (aos_fhec_tx_16b == aos_fhec_rx_16b);
  end

endmodule : ccsds_gf256_math
