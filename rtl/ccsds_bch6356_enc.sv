//=============================================================================
// File Name   : ccsds_bch6356_enc.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : CCSDS 231.0-B-4 (TC Synchronization and Channel Coding)
// Description : Synthesizable Ground EGSE Expurgated BCH(63,56) Encoder &
//               CLTU Wrapper (ROLE_MODE = 1 / 2):
//                 - Prepends 16-bit CLTU Start Sequence (16'hEB90)
//                 - Optional TC LFSR Pseudo-Randomizer (h_TC = x^8+x^6+x^4+x^3+x^2+x+1)
//                 - Automatic 0x55 fill-octet padding to 7-octet codeblock boundary
//                 - Computes 7 parity bits over g(x) = x^7 + x^6 + x^2 + 1 (0xC5),
//                   inverts parity on transmission, and appends LSB filler '0'
//                 - Appends 64-bit CLTU Tail Sequence (64'hC5C5_C5C5_C5C5_C579)
//=============================================================================
`timescale 1ns / 1ps

module ccsds_bch6356_enc
  import ccsds_pkg::*;
(
  input  logic       clk,
  input  logic       rst_n,

  // Configuration
  input  logic       tc_randomize_en_cfg,

  // Input TC Transfer Frame Stream
  input  logic       s_axis_tvalid,
  output logic             s_axis_tready,
  input  logic [7:0] s_axis_tdata,
  input  logic       s_axis_tlast,

  // Output CLTU Codeblock Stream (Start 0xEB90 + N*8B BCH Codeblocks + 8B Tail)
  output logic             m_axis_tvalid,
  input  logic       m_axis_tready,
  output logic [7:0]       m_axis_tdata,
  output logic             m_axis_tlast,
  output logic [15:0]      cltu_codeblock_cnt_out
);

  function automatic logic [6:0] calc_bch_parity_inv(input logic [55:0] info56);
    logic [6:0] rem;
    logic       fb;
    begin
      rem = 7'd0;
      for (int i = 55; i >= 0; i--) begin
        fb  = rem[6] ^ info56[i];
        rem = {rem[5:0], 1'b0};
        if (fb) begin
          rem = rem ^ 7'h45; // x^6 + x^2 + 1
        end
      end
      return ~rem;
    end
  endfunction

  function automatic logic [7:0] next_tc_lfsr_byte(
    input  logic [7:0] lfsr_in,
    output logic [7:0] lfsr_out
  );
    logic [7:0] cur;
    logic [7:0] bval;
    logic       fb;
    begin
      cur  = lfsr_in;
      bval = 8'd0;
      for (int i = 0; i < 8; i++) begin
        bval = {bval[6:0], cur[0]};
        fb   = ^(cur & 8'h5F);
        cur  = {fb, cur[7:1]};
      end
      lfsr_out = cur;
      return bval;
    end
  endfunction

  localparam logic [63:0] CLTU_TAIL_SEQ = 64'hC5C5_C5C5_C5C5_C579;

  typedef enum logic [2:0] {
    ST_IDLE     = 3'd0,
    ST_START_1  = 3'd1,
    ST_COLLECT  = 3'd2,
    ST_PAD_FILL = 3'd3,
    ST_EMIT_PAR = 3'd4,
    ST_TAIL     = 3'd5
  } state_e;

  state_e      state_q;
  logic [2:0]  blk_idx_q;
  logic [55:0] info_shift_q;
  logic [7:0]  lfsr_q;
  logic        frame_done_pending_q;
  logic [2:0]  tail_idx_q;
  logic [7:0]  first_byte_q;
  logic        first_last_q;
  logic [15:0] cb_cnt_q;

  assign cltu_codeblock_cnt_out = cb_cnt_q;
  logic consuming_first_byte;
  assign consuming_first_byte = (state_q == ST_COLLECT && blk_idx_q == 3'd0 && !frame_done_pending_q && cb_cnt_q == 16'd0 && lfsr_q == 8'hFF);
  assign s_axis_tready = (state_q == ST_IDLE || (state_q == ST_COLLECT && !consuming_first_byte)) && m_axis_tready;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q              <= ST_IDLE;
      blk_idx_q            <= 3'd0;
      info_shift_q         <= 56'd0;
      lfsr_q               <= 8'hFF;
      frame_done_pending_q <= 1'b0;
      tail_idx_q           <= 3'd0;
      first_byte_q         <= 8'd0;
      first_last_q         <= 1'b0;
      cb_cnt_q             <= 16'd0;
      m_axis_tvalid        <= 1'b0;
      m_axis_tdata         <= 8'd0;
      m_axis_tlast         <= 1'b0;
    end else begin
      if (m_axis_tready) begin
        m_axis_tvalid <= 1'b0;
        m_axis_tlast  <= 1'b0;
      end

      case (state_q)
        ST_IDLE: begin
          if (s_axis_tvalid && m_axis_tready) begin
            first_byte_q         <= s_axis_tdata;
            first_last_q         <= s_axis_tlast;
            lfsr_q               <= 8'hFF;
            cb_cnt_q             <= 16'd0;
            frame_done_pending_q <= 1'b0;
            m_axis_tvalid        <= 1'b1;
            m_axis_tdata         <= 8'hEB;
            m_axis_tlast         <= 1'b0;
            state_q              <= ST_START_1;
          end
        end

        ST_START_1: begin
          if (m_axis_tready) begin
            m_axis_tvalid <= 1'b1;
            m_axis_tdata  <= 8'h90;
            m_axis_tlast  <= 1'b0;
            blk_idx_q     <= 3'd0;
            state_q       <= ST_COLLECT;
          end
        end

        ST_COLLECT: begin
          if (m_axis_tready) begin
            if (blk_idx_q == 3'd0 && !frame_done_pending_q && cb_cnt_q == 16'd0 && lfsr_q == 8'hFF) begin
              logic [7:0] pn_b;
              logic [7:0] nxt_l;
              logic [7:0] scr_b;
              pn_b  = next_tc_lfsr_byte(lfsr_q, nxt_l);
              scr_b = tc_randomize_en_cfg ? (first_byte_q ^ pn_b) : first_byte_q;
              lfsr_q               <= nxt_l;
              info_shift_q         <= {info_shift_q[47:0], scr_b};
              m_axis_tvalid        <= 1'b1;
              m_axis_tdata         <= scr_b;
              m_axis_tlast         <= 1'b0;
              blk_idx_q            <= 3'd1;
              if (first_last_q) begin
                frame_done_pending_q <= 1'b1;
                state_q              <= ST_PAD_FILL;
              end
            end else if (s_axis_tvalid) begin
              logic [7:0] pn_b;
              logic [7:0] nxt_l;
              logic [7:0] scr_b;
              pn_b  = next_tc_lfsr_byte(lfsr_q, nxt_l);
              scr_b = tc_randomize_en_cfg ? (s_axis_tdata ^ pn_b) : s_axis_tdata;
              lfsr_q        <= nxt_l;
              info_shift_q  <= {info_shift_q[47:0], scr_b};
              m_axis_tvalid <= 1'b1;
              m_axis_tdata  <= scr_b;
              m_axis_tlast  <= 1'b0;
              if (blk_idx_q == 3'd6) begin
                blk_idx_q            <= 3'd0;
                frame_done_pending_q <= s_axis_tlast;
                state_q              <= ST_EMIT_PAR;
              end else begin
                blk_idx_q <= blk_idx_q + 3'd1;
                if (s_axis_tlast) begin
                  frame_done_pending_q <= 1'b1;
                  state_q              <= ST_PAD_FILL;
                end
              end
            end
          end
        end

        ST_PAD_FILL: begin
          if (m_axis_tready) begin
            logic [7:0] pn_b;
            logic [7:0] nxt_l;
            logic [7:0] scr_b;
            pn_b  = next_tc_lfsr_byte(lfsr_q, nxt_l);
            scr_b = tc_randomize_en_cfg ? (8'h55 ^ pn_b) : 8'h55;
            lfsr_q        <= nxt_l;
            info_shift_q  <= {info_shift_q[47:0], scr_b};
            m_axis_tvalid <= 1'b1;
            m_axis_tdata  <= scr_b;
            m_axis_tlast  <= 1'b0;
            if (blk_idx_q == 3'd6) begin
              blk_idx_q <= 3'd0;
              state_q   <= ST_EMIT_PAR;
            end else begin
              blk_idx_q <= blk_idx_q + 3'd1;
            end
          end
        end

        ST_EMIT_PAR: begin
          if (m_axis_tready) begin
            logic [6:0] par_inv;
            par_inv       = calc_bch_parity_inv(info_shift_q);
            m_axis_tvalid <= 1'b1;
            m_axis_tdata  <= {par_inv, 1'b0};
            m_axis_tlast  <= 1'b0;
            cb_cnt_q      <= cb_cnt_q + 16'd1;
            if (frame_done_pending_q) begin
              tail_idx_q <= 3'd0;
              state_q    <= ST_TAIL;
            end else begin
              state_q <= ST_COLLECT;
            end
          end
        end

        ST_TAIL: begin
          if (m_axis_tready) begin
            m_axis_tvalid <= 1'b1;
            m_axis_tdata  <= CLTU_TAIL_SEQ[(7 - tail_idx_q) * 8 +: 8];
            m_axis_tlast  <= (tail_idx_q == 3'd7);
            if (tail_idx_q == 3'd7) begin
              state_q <= ST_IDLE;
            end else begin
              tail_idx_q <= tail_idx_q + 3'd1;
            end
          end
        end

        default: state_q <= ST_IDLE;
      endcase
    end
  end

endmodule
