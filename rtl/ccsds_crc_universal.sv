// =============================================================================
// File Name   : ccsds_crc_universal.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog (Synthesizable)
// Description : Universal byte-wide / multi-byte AXI4-Stream Frame Error Control
//               Field (FECF) generator and residue checker supporting:
//                 1. CCSDS 16-bit CRC-16-CCITT (G(x) = x^16 + x^12 + x^5 + 1,
//                    poly = 16'h1021, seed = 16'hFFFF, valid residue = 16'h0000)
//                    per CCSDS 132.0-B-3, 232.0-B-4, 732.0-B-4, and 732.1-B-3.
//                 2. CCSDS 32-bit Proximity-1 / USLP CRC-32 (G(x) = x^32 + x^23
//                    + x^21 + x^11 + x^2 + 1, poly = 32'h00A0_0805,
//                    seed = 32'hFFFF_FFFF, valid residue = 32'h0000_0000)
//                    per CCSDS 211.0-B-6 and 732.1-B-3.
//               Supports arbitrary DATA_WIDTH (8, 32, 64) and partial final-word
//               byte enables via s_axis_tkeep.
// =============================================================================
`timescale 1ns / 1ps

module ccsds_crc_universal
  import ccsds_pkg::*;
#(
  parameter int unsigned DATA_WIDTH = DEFAULT_DATA_WIDTH
) (
  input  logic                        clk,
  input  logic                        rst_n,

  input  logic                        crc_clear,
  input  logic                        mode_crc32,

  input  logic [DATA_WIDTH-1:0]       s_axis_tdata,
  input  logic [(DATA_WIDTH/8)-1:0]   s_axis_tkeep,
  input  logic                        s_axis_tvalid,
  input  logic                        s_axis_tready,
  input  logic                        s_axis_tlast,

  output logic [15:0]                 crc16_out,
  output logic [31:0]                 crc32_out,
  output logic                        crc16_residue_ok,
  output logic                        crc32_residue_ok,
  output logic                        crc_residue_ok,
  output logic                        crc_valid_pulse
);

  localparam int unsigned NUM_BYTES = DATA_WIDTH / 8;

  logic [15:0] crc16_q, crc16_next;
  logic [31:0] crc32_q, crc32_next;

  function automatic logic [15:0] step_crc16_byte(
    input logic [15:0] crc_in,
    input logic [7:0]  data_byte
  );
    logic [15:0] c;
    c = crc_in ^ {data_byte, 8'h00};
    for (int b = 0; b < 8; b++) begin
      if (c[15]) begin
        c = (c << 1) ^ POLY_CRC16_CCITT;
      end else begin
        c = (c << 1);
      end
    end
    return c;
  endfunction

  function automatic logic [31:0] step_crc32_byte(
    input logic [31:0] crc_in,
    input logic [7:0]  data_byte
  );
    logic [31:0] c;
    c = crc_in ^ {data_byte, 24'h00_0000};
    for (int b = 0; b < 8; b++) begin
      if (c[31]) begin
        c = (c << 1) ^ POLY_CRC32_PROX1;
      end else begin
        c = (c << 1);
      end
    end
    return c;
  endfunction

  always_comb begin
    crc16_next = crc16_q;
    crc32_next = crc32_q;

    if (s_axis_tvalid && s_axis_tready) begin
      for (int i = NUM_BYTES - 1; i >= 0; i--) begin
        if (s_axis_tkeep[i]) begin
          crc16_next = step_crc16_byte(crc16_next, s_axis_tdata[i*8 +: 8]);
          crc32_next = step_crc32_byte(crc32_next, s_axis_tdata[i*8 +: 8]);
        end
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      crc16_q <= INIT_CRC16_CCITT;
      crc32_q <= INIT_CRC32_PROX1;
    end else if (crc_clear) begin
      crc16_q <= INIT_CRC16_CCITT;
      crc32_q <= INIT_CRC32_PROX1;
    end else if (s_axis_tvalid && s_axis_tready) begin
      if (s_axis_tlast) begin
        crc16_q <= INIT_CRC16_CCITT;
        crc32_q <= INIT_CRC32_PROX1;
      end else begin
        crc16_q <= crc16_next;
        crc32_q <= crc32_next;
      end
    end
  end

  assign crc16_out        = (s_axis_tvalid && s_axis_tready) ? crc16_next : crc16_q;
  assign crc32_out        = (s_axis_tvalid && s_axis_tready) ? crc32_next : crc32_q;
  assign crc16_residue_ok = (crc16_out == RESIDUE_CRC16_VALID);
  assign crc32_residue_ok = (crc32_out == RESIDUE_CRC32_VALID);
  assign crc_residue_ok   = mode_crc32 ? crc32_residue_ok : crc16_residue_ok;
  assign crc_valid_pulse  = s_axis_tvalid && s_axis_tready && s_axis_tlast;

endmodule : ccsds_crc_universal
