// =============================================================================
// File Name   : ccsds_lfsr_scrambler.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog (Synthesizable)
// Description : Dual-mode 255-bit period CCSDS Pseudo-Randomizer / De-Randomizer:
//                 - mode_tc_not_tm = 1'b0 (Downlink TM / AOS / USLP per
//                   CCSDS 131.0-B-5 Sec 10):
//                   h_TM(x) = x^8 + x^7 + x^5 + x^3 + 1 (Tap mask 8'hA9)
//                 - mode_tc_not_tm = 1'b1 (Uplink TC per CCSDS 231.0-B-4 Sec 5):
//                   h_TC(x) = x^8 + x^6 + x^4 + x^3 + x^2 + x + 1 (Tap mask 8'h5F)
// =============================================================================
`timescale 1ns / 1ps

module ccsds_lfsr_scrambler
  import ccsds_pkg::*;
#(
  parameter int unsigned DATA_WIDTH = DEFAULT_DATA_WIDTH
) (
  input  logic                        clk,
  input  logic                        rst_n,

  input  logic                        bypass_en,
  input  logic                        mode_tc_not_tm,
  input  logic                        lfsr_reseed_sync,

  input  logic [DATA_WIDTH-1:0]       s_axis_tdata,
  input  logic [(DATA_WIDTH/8)-1:0]   s_axis_tkeep,
  input  logic                        s_axis_tvalid,
  output logic                        s_axis_tready,
  input  logic                        s_axis_tlast,
  input  ccsds_tuser_t                s_axis_tuser,

  output logic [DATA_WIDTH-1:0]       m_axis_tdata,
  output logic [(DATA_WIDTH/8)-1:0]   m_axis_tkeep,
  output logic                        m_axis_tvalid,
  input  logic                        m_axis_tready,
  output logic                        m_axis_tlast,
  output ccsds_tuser_t                m_axis_tuser
);

  localparam int unsigned NUM_BYTES = DATA_WIDTH / 8;

  logic [7:0]            lfsr_q, lfsr_next;
  logic [DATA_WIDTH-1:0] scrambled_data;

  function automatic void step_lfsr_octet(
    input  logic [7:0] lfsr_in,
    input  logic [7:0] tap_mask,
    output logic [7:0] lfsr_out,
    output logic [7:0] pn_byte
  );
    logic [7:0] sr;
    logic [7:0] b_val;
    logic       fb;
    sr    = lfsr_in;
    b_val = 8'h00;
    for (int bit_idx = 0; bit_idx < 8; bit_idx++) begin
      b_val = {b_val[6:0], sr[0]};
      fb    = ^(sr & tap_mask);
      sr    = {fb, sr[7:1]};
    end
    lfsr_out = sr;
    pn_byte  = b_val;
  endfunction

  always_comb begin
    logic [7:0] tap_mask;
    logic [7:0] cur_sr;
    logic [7:0] nxt_sr;
    logic [7:0] pn_octet;

    tap_mask       = mode_tc_not_tm ? LFSR_TC_TAP_MASK : LFSR_TM_TAP_MASK;
    cur_sr         = lfsr_q;
    scrambled_data = s_axis_tdata;

    if (!bypass_en) begin
      for (int i = NUM_BYTES - 1; i >= 0; i--) begin
        if (s_axis_tkeep[i]) begin
          step_lfsr_octet(cur_sr, tap_mask, nxt_sr, pn_octet);
          scrambled_data[i*8 +: 8] = s_axis_tdata[i*8 +: 8] ^ pn_octet;
          cur_sr                   = nxt_sr;
        end
      end
    end

    lfsr_next = cur_sr;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      lfsr_q <= LFSR_INIT_ALL_ONES;
    end else if (lfsr_reseed_sync) begin
      lfsr_q <= LFSR_INIT_ALL_ONES;
    end else if (s_axis_tvalid && m_axis_tready) begin
      if (s_axis_tlast) begin
        lfsr_q <= LFSR_INIT_ALL_ONES;
      end else begin
        lfsr_q <= lfsr_next;
      end
    end
  end

  assign s_axis_tready = m_axis_tready;
  assign m_axis_tdata  = scrambled_data;
  assign m_axis_tkeep  = s_axis_tkeep;
  assign m_axis_tvalid = s_axis_tvalid;
  assign m_axis_tlast  = s_axis_tlast;
  assign m_axis_tuser  = s_axis_tuser;

endmodule : ccsds_lfsr_scrambler
