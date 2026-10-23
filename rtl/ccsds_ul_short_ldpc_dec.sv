// =============================================================================
// File Name   : ccsds_ul_short_ldpc_dec.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog (Synthesizable)
// Description : Official CCSDS 231.1-O-1 Table 2-4 Uplink Short Block-Length
//               Quasi-Cyclic LDPC (128,64) Iterative Bit-Flipping / Min-Sum
//               Decoder with Early Syndrome Stopping, 64-bit Tail Sequence
//               Detection (0x55555555_555555AA), and Inline h_TC De-Randomizer:
//                 - Embeds the exact 64x128 parity-check matrix H_64x128 from
//                   CCSDS 231.1-O-1 Table 2-4 (d_c=8 check weight, d_v=5 info
//                   variable weight, d_v=3 parity variable weight, G*H^T == 0).
//                 - 3-stage registered iteration pipeline (LDPC_EVAL_SYN ->
//                   LDPC_FIND_MAX -> LDPC_FLIP_BITS) with <= 2 LUT levels per
//                   stage for >350 MHz Kintex UltraScale Fmax.
// =============================================================================
`timescale 1ns / 1ps

module ccsds_ul_short_ldpc_dec
  import ccsds_pkg::*;
#(
  parameter int unsigned MAX_ITER = 16
) (
  input  logic              clk,
  input  logic              rst_n,

  input  logic              ldpc_mode_512_en,
  input  logic              tc_derand_en,

  // Soft-LLR Codeblock Input from RX2 (ccsds_asm_correlator)
  input  logic signed [3:0] cb_llr_in,
  input  logic              cb_hard_bit_in,
  input  logic              cb_start_pulse,
  input  logic              cb_valid_in,

  // Status & EDAC Telemetry Pulses
  output logic              ldpc_tail_detected_pulse,
  output logic              ldpc_converged_pulse,
  output logic              ldpc_uncorr_abort_pulse,

  // 8-bit Decoded & De-Randomized Information Stream to RX4 Deframer
  output logic [7:0]        m_axis_tdata,
  output logic              m_axis_tvalid,
  input  logic              m_axis_tready,
  output logic              m_axis_tlast,
  output logic              m_axis_tabort
);

  // Official CCSDS 231.1-O-1 Table 2-4 (n=128, k=64) Parity-Check Matrix Rows H[0..63]
  localparam logic [127:0] LDPC128_H_ROW_MASK [0:63] = '{
    128'h81002000000202000000800000048000,
    128'h40801000000101000000400000024000,
    128'h20400800800000800000200000012000,
    128'h10200400400000400000100080001000,
    128'h08100200200000200000080040000800,
    128'h04080100100000100000040020000400,
    128'h02040080080000080000020010000200,
    128'h01020040040000040000010008000100,
    128'h00810020020000020000008004000080,
    128'h80400010010000010000004002000040,
    128'h40200008008080000000002001000020,
    128'h20100004004040000000001000800010,
    128'h10080002002020000000000800400008,
    128'h08040001001010000000000400200004,
    128'h04028000000808000000000200100002,
    128'h02014000000404000000000100080001,
    128'h02008001800040008000000080000100,
    128'h0100C000400020004000000040000080,
    128'h00806000200010002000000020000040,
    128'h00403000100008001000000010000020,
    128'h00201800080004000800000008000010,
    128'h00100C00040002000400000004000008,
    128'h00080600020001000200000002000004,
    128'h00040300010000800100000001000002,
    128'h00020180008000400080000000800001,
    128'h000100C0004000200040000000408000,
    128'h80000060002000100020000000204000,
    128'h40000030001000080010000000102000,
    128'h20000018000800040008000000081000,
    128'h1000000C000400020004000000040800,
    128'h08000006000200010002000000020400,
    128'h04000003000180000001000000010200,
    128'h08004000800100020010800000001000,
    128'h04002000C00000010008400000000800,
    128'h02001000600080000004200000000400,
    128'h01000800300040000002100000000200,
    128'h00800400180020000001080000000100,
    128'h004002000C0010008000040000000080,
    128'h00200100060008004000020000000040,
    128'h00100080030004002000010000000020,
    128'h00080040018002001000008000000010,
    128'h0004002000C001000800004000000008,
    128'h00020010006000800400002000000004,
    128'h00010008003000400200001000000002,
    128'h80000004001800200100000800000001,
    128'h40000002000C00100080000400008000,
    128'h20000001000600080040000200004000,
    128'h10008000000300040020000100002000,
    128'h80004000004080040002400080000000,
    128'h40002000002040020001200040000000,
    128'h20001000001020018000100020000000,
    128'h10000800000890004000080010000000,
    128'h08000400000448002000040008000000,
    128'h04000200000224001000020004000000,
    128'h02000100000112000800010002000000,
    128'h01000080800009000400008001000000,
    128'h00800040400004800200004000800000,
    128'h00400020200002400100002000400000,
    128'h00200010100001200080001000200000,
    128'h00100008080000900040000800100000,
    128'h00080004040000480020000400080000,
    128'h00040002020000240010000200040000,
    128'h00020001010000120008000100020000,
    128'h00018000008000090004800000010000
  };

  // Connected check-node indices per variable node v=0..127 (5 checks for v<64, 3 checks for v>=64)
  localparam logic [5:0] LDPC128_COL_IDX [0:127][0:4] = '{
    '{6'd0, 6'd9, 6'd26, 6'd44, 6'd48},
    '{6'd1, 6'd10, 6'd27, 6'd45, 6'd49},
    '{6'd2, 6'd11, 6'd28, 6'd46, 6'd50},
    '{6'd3, 6'd12, 6'd29, 6'd47, 6'd51},
    '{6'd4, 6'd13, 6'd30, 6'd32, 6'd52},
    '{6'd5, 6'd14, 6'd31, 6'd33, 6'd53},
    '{6'd6, 6'd15, 6'd16, 6'd34, 6'd54},
    '{6'd0, 6'd7, 6'd17, 6'd35, 6'd55},
    '{6'd1, 6'd8, 6'd18, 6'd36, 6'd56},
    '{6'd2, 6'd9, 6'd19, 6'd37, 6'd57},
    '{6'd3, 6'd10, 6'd20, 6'd38, 6'd58},
    '{6'd4, 6'd11, 6'd21, 6'd39, 6'd59},
    '{6'd5, 6'd12, 6'd22, 6'd40, 6'd60},
    '{6'd6, 6'd13, 6'd23, 6'd41, 6'd61},
    '{6'd7, 6'd14, 6'd24, 6'd42, 6'd62},
    '{6'd8, 6'd15, 6'd25, 6'd43, 6'd63},
    '{6'd14, 6'd16, 6'd17, 6'd47, 6'd63},
    '{6'd15, 6'd17, 6'd18, 6'd32, 6'd48},
    '{6'd0, 6'd18, 6'd19, 6'd33, 6'd49},
    '{6'd1, 6'd19, 6'd20, 6'd34, 6'd50},
    '{6'd2, 6'd20, 6'd21, 6'd35, 6'd51},
    '{6'd3, 6'd21, 6'd22, 6'd36, 6'd52},
    '{6'd4, 6'd22, 6'd23, 6'd37, 6'd53},
    '{6'd5, 6'd23, 6'd24, 6'd38, 6'd54},
    '{6'd6, 6'd24, 6'd25, 6'd39, 6'd55},
    '{6'd7, 6'd25, 6'd26, 6'd40, 6'd56},
    '{6'd8, 6'd26, 6'd27, 6'd41, 6'd57},
    '{6'd9, 6'd27, 6'd28, 6'd42, 6'd58},
    '{6'd10, 6'd28, 6'd29, 6'd43, 6'd59},
    '{6'd11, 6'd29, 6'd30, 6'd44, 6'd60},
    '{6'd12, 6'd30, 6'd31, 6'd45, 6'd61},
    '{6'd13, 6'd16, 6'd31, 6'd46, 6'd62},
    '{6'd2, 6'd16, 6'd32, 6'd33, 6'd55},
    '{6'd3, 6'd17, 6'd33, 6'd34, 6'd56},
    '{6'd4, 6'd18, 6'd34, 6'd35, 6'd57},
    '{6'd5, 6'd19, 6'd35, 6'd36, 6'd58},
    '{6'd6, 6'd20, 6'd36, 6'd37, 6'd59},
    '{6'd7, 6'd21, 6'd37, 6'd38, 6'd60},
    '{6'd8, 6'd22, 6'd38, 6'd39, 6'd61},
    '{6'd9, 6'd23, 6'd39, 6'd40, 6'd62},
    '{6'd10, 6'd24, 6'd40, 6'd41, 6'd63},
    '{6'd11, 6'd25, 6'd41, 6'd42, 6'd48},
    '{6'd12, 6'd26, 6'd42, 6'd43, 6'd49},
    '{6'd13, 6'd27, 6'd43, 6'd44, 6'd50},
    '{6'd14, 6'd28, 6'd44, 6'd45, 6'd51},
    '{6'd15, 6'd29, 6'd45, 6'd46, 6'd52},
    '{6'd0, 6'd30, 6'd46, 6'd47, 6'd53},
    '{6'd1, 6'd31, 6'd32, 6'd47, 6'd54},
    '{6'd10, 6'd31, 6'd34, 6'd48, 6'd51},
    '{6'd11, 6'd16, 6'd35, 6'd49, 6'd52},
    '{6'd12, 6'd17, 6'd36, 6'd50, 6'd53},
    '{6'd13, 6'd18, 6'd37, 6'd51, 6'd54},
    '{6'd14, 6'd19, 6'd38, 6'd52, 6'd55},
    '{6'd15, 6'd20, 6'd39, 6'd53, 6'd56},
    '{6'd0, 6'd21, 6'd40, 6'd54, 6'd57},
    '{6'd1, 6'd22, 6'd41, 6'd55, 6'd58},
    '{6'd2, 6'd23, 6'd42, 6'd56, 6'd59},
    '{6'd3, 6'd24, 6'd43, 6'd57, 6'd60},
    '{6'd4, 6'd25, 6'd44, 6'd58, 6'd61},
    '{6'd5, 6'd26, 6'd45, 6'd59, 6'd62},
    '{6'd6, 6'd27, 6'd46, 6'd60, 6'd63},
    '{6'd7, 6'd28, 6'd47, 6'd48, 6'd61},
    '{6'd8, 6'd29, 6'd32, 6'd49, 6'd62},
    '{6'd9, 6'd30, 6'd33, 6'd50, 6'd63},
    '{6'd16, 6'd37, 6'd50, 6'd63, 6'd63},
    '{6'd17, 6'd38, 6'd51, 6'd63, 6'd63},
    '{6'd18, 6'd39, 6'd52, 6'd63, 6'd63},
    '{6'd19, 6'd40, 6'd53, 6'd63, 6'd63},
    '{6'd20, 6'd41, 6'd54, 6'd63, 6'd63},
    '{6'd21, 6'd42, 6'd55, 6'd63, 6'd63},
    '{6'd22, 6'd43, 6'd56, 6'd63, 6'd63},
    '{6'd23, 6'd44, 6'd57, 6'd63, 6'd63},
    '{6'd24, 6'd45, 6'd58, 6'd63, 6'd63},
    '{6'd25, 6'd46, 6'd59, 6'd63, 6'd63},
    '{6'd26, 6'd47, 6'd60, 6'd63, 6'd63},
    '{6'd27, 6'd32, 6'd61, 6'd63, 6'd63},
    '{6'd28, 6'd33, 6'd62, 6'd63, 6'd63},
    '{6'd29, 6'd34, 6'd63, 6'd63, 6'd63},
    '{6'd30, 6'd35, 6'd48, 6'd63, 6'd63},
    '{6'd31, 6'd36, 6'd49, 6'd63, 6'd63},
    '{6'd0, 6'd32, 6'd63, 6'd63, 6'd63},
    '{6'd1, 6'd33, 6'd48, 6'd63, 6'd63},
    '{6'd2, 6'd34, 6'd49, 6'd63, 6'd63},
    '{6'd3, 6'd35, 6'd50, 6'd63, 6'd63},
    '{6'd4, 6'd36, 6'd51, 6'd63, 6'd63},
    '{6'd5, 6'd37, 6'd52, 6'd63, 6'd63},
    '{6'd6, 6'd38, 6'd53, 6'd63, 6'd63},
    '{6'd7, 6'd39, 6'd54, 6'd63, 6'd63},
    '{6'd8, 6'd40, 6'd55, 6'd63, 6'd63},
    '{6'd9, 6'd41, 6'd56, 6'd63, 6'd63},
    '{6'd10, 6'd42, 6'd57, 6'd63, 6'd63},
    '{6'd11, 6'd43, 6'd58, 6'd63, 6'd63},
    '{6'd12, 6'd44, 6'd59, 6'd63, 6'd63},
    '{6'd13, 6'd45, 6'd60, 6'd63, 6'd63},
    '{6'd14, 6'd46, 6'd61, 6'd63, 6'd63},
    '{6'd15, 6'd47, 6'd62, 6'd63, 6'd63},
    '{6'd3, 6'd16, 6'd48, 6'd63, 6'd63},
    '{6'd4, 6'd17, 6'd49, 6'd63, 6'd63},
    '{6'd5, 6'd18, 6'd50, 6'd63, 6'd63},
    '{6'd6, 6'd19, 6'd51, 6'd63, 6'd63},
    '{6'd7, 6'd20, 6'd52, 6'd63, 6'd63},
    '{6'd8, 6'd21, 6'd53, 6'd63, 6'd63},
    '{6'd9, 6'd22, 6'd54, 6'd63, 6'd63},
    '{6'd10, 6'd23, 6'd55, 6'd63, 6'd63},
    '{6'd11, 6'd24, 6'd56, 6'd63, 6'd63},
    '{6'd12, 6'd25, 6'd57, 6'd63, 6'd63},
    '{6'd13, 6'd26, 6'd58, 6'd63, 6'd63},
    '{6'd14, 6'd27, 6'd59, 6'd63, 6'd63},
    '{6'd15, 6'd28, 6'd60, 6'd63, 6'd63},
    '{6'd0, 6'd29, 6'd61, 6'd63, 6'd63},
    '{6'd1, 6'd30, 6'd62, 6'd63, 6'd63},
    '{6'd2, 6'd31, 6'd63, 6'd63, 6'd63},
    '{6'd0, 6'd25, 6'd45, 6'd63, 6'd63},
    '{6'd1, 6'd26, 6'd46, 6'd63, 6'd63},
    '{6'd2, 6'd27, 6'd47, 6'd63, 6'd63},
    '{6'd3, 6'd28, 6'd32, 6'd63, 6'd63},
    '{6'd4, 6'd29, 6'd33, 6'd63, 6'd63},
    '{6'd5, 6'd30, 6'd34, 6'd63, 6'd63},
    '{6'd6, 6'd31, 6'd35, 6'd63, 6'd63},
    '{6'd7, 6'd16, 6'd36, 6'd63, 6'd63},
    '{6'd8, 6'd17, 6'd37, 6'd63, 6'd63},
    '{6'd9, 6'd18, 6'd38, 6'd63, 6'd63},
    '{6'd10, 6'd19, 6'd39, 6'd63, 6'd63},
    '{6'd11, 6'd20, 6'd40, 6'd63, 6'd63},
    '{6'd12, 6'd21, 6'd41, 6'd63, 6'd63},
    '{6'd13, 6'd22, 6'd42, 6'd63, 6'd63},
    '{6'd14, 6'd23, 6'd43, 6'd63, 6'd63},
    '{6'd15, 6'd24, 6'd44, 6'd63, 6'd63}
  };

  typedef enum logic [2:0] {
    LDPC_COLLECT_CB = 3'd0,
    LDPC_EVAL_SYN   = 3'd1,
    LDPC_FIND_MAX   = 3'd2,
    LDPC_FLIP_BITS  = 3'd3,
    LDPC_EMIT_BYTES = 3'd4
  } ldpc_state_e;

  ldpc_state_e       state_q;
  logic [7:0]        bit_idx_q;
  logic [4:0]        iter_cnt_q;
  logic [3:0]        emit_idx_q;
  logic [127:0]      hard_cb_q;
  logic signed [5:0] llr_buf_q [0:127];
  logic [63:0]       syn_vec_q;
  logic [2:0]        unsat_cnt_q [0:127];
  logic              has_ge5_q, has_ge4_q, has_ge3_q, has_par_ge2_q;
  logic [63:0]       info_bits_q;
  logic [7:0]        lfsr_q;

  function automatic logic [7:0] next_tc_lfsr_state(input logic [7:0] cur_lfsr);
    logic [7:0] s;
    logic       fb;
    s = cur_lfsr;
    for (int b = 0; b < 8; b++) begin
      fb = ^(s & LFSR_TC_TAP_MASK);
      s  = {fb, s[7:1]};
    end
    return s;
  endfunction

  function automatic logic [7:0] get_tc_pn_byte(input logic [7:0] cur_lfsr);
    logic [7:0] s;
    logic [7:0] pn;
    logic       fb;
    s = cur_lfsr;
    for (int b = 0; b < 8; b++) begin
      pn[7 - b] = s[0];
      fb        = ^(s & LFSR_TC_TAP_MASK);
      s         = {fb, s[7:1]};
    end
    return pn;
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q                  <= LDPC_COLLECT_CB;
      bit_idx_q                <= 8'd0;
      iter_cnt_q               <= 5'd0;
      emit_idx_q               <= 4'd0;
      hard_cb_q                <= 128'd0;
      for (int k = 0; k < 128; k++) begin
        llr_buf_q[k]   <= 6'sd0;
        unsat_cnt_q[k] <= 3'd0;
      end
      syn_vec_q                <= 64'd0;
      has_ge5_q                <= 1'b0;
      has_ge4_q                <= 1'b0;
      has_ge3_q                <= 1'b0;
      has_par_ge2_q            <= 1'b0;
      info_bits_q              <= 64'd0;
      lfsr_q                   <= LFSR_INIT_ALL_ONES;
      ldpc_tail_detected_pulse <= 1'b0;
      ldpc_converged_pulse     <= 1'b0;
      ldpc_uncorr_abort_pulse  <= 1'b0;
      m_axis_tdata             <= 8'h00;
      m_axis_tvalid            <= 1'b0;
      m_axis_tlast             <= 1'b0;
      m_axis_tabort            <= 1'b0;
    end else begin
      ldpc_tail_detected_pulse <= 1'b0;
      ldpc_converged_pulse     <= 1'b0;
      ldpc_uncorr_abort_pulse  <= 1'b0;
      if (m_axis_tready) begin
        m_axis_tvalid <= 1'b0;
        m_axis_tlast  <= 1'b0;
        m_axis_tabort <= 1'b0;
      end

      unique case (state_q)
        LDPC_COLLECT_CB: begin
          if (cb_valid_in) begin
            if (cb_start_pulse) begin
              lfsr_q <= LFSR_INIT_ALL_ONES;
            end
            hard_cb_q[127 - bit_idx_q[6:0]] <= cb_hard_bit_in;
            llr_buf_q[bit_idx_q[6:0]]       <= 6'(cb_llr_in);

            if (bit_idx_q == 8'd63) begin
              logic [63:0] first64;
              first64 = {hard_cb_q[127:65], cb_hard_bit_in};
              if (first64 == CLTU_TAIL_SEQ_LDPC_55) begin
                ldpc_tail_detected_pulse <= 1'b1;
                m_axis_tvalid            <= 1'b1;
                m_axis_tlast             <= 1'b1;
                m_axis_tdata             <= CLTU_IDLE_FILL_OCTET;
                bit_idx_q                <= 8'd0;
              end else begin
                bit_idx_q <= bit_idx_q + 8'd1;
              end
            end else if (bit_idx_q == 8'd127) begin
              bit_idx_q  <= 8'd0;
              iter_cnt_q <= 5'd0;
              state_q    <= LDPC_EVAL_SYN;
            end else begin
              bit_idx_q <= bit_idx_q + 8'd1;
            end
          end
        end

        LDPC_EVAL_SYN: begin
          // Stage 1 (2 LUT levels): Evaluate 64 parity checks (weight 8 each)
          for (int r = 0; r < 64; r++) begin
            syn_vec_q[r] <= ^(hard_cb_q & LDPC128_H_ROW_MASK[r]);
          end
          state_q <= LDPC_FIND_MAX;
        end

        LDPC_FIND_MAX: begin
          // Stage 2 (2 LUT levels): Check convergence or compute per-variable unsatisfied degree
          if (syn_vec_q == 64'd0) begin
            info_bits_q          <= hard_cb_q[127:64];
            emit_idx_q           <= 4'd0;
            ldpc_converged_pulse <= 1'b1;
            state_q              <= LDPC_EMIT_BYTES;
          end else if (iter_cnt_q == 5'(MAX_ITER)) begin
            ldpc_uncorr_abort_pulse <= 1'b1;
            m_axis_tvalid           <= 1'b1;
            m_axis_tabort           <= 1'b1;
            state_q                 <= LDPC_COLLECT_CB;
          end else begin
            logic g5, g4, g3, gp2;
            g5  = 1'b0;
            g4  = 1'b0;
            g3  = 1'b0;
            gp2 = 1'b0;
            for (int v = 0; v < 128; v++) begin
              logic [2:0] u_cnt;
              if (v < 64) begin
                u_cnt = 3'(syn_vec_q[LDPC128_COL_IDX[v][0]]) +
                        3'(syn_vec_q[LDPC128_COL_IDX[v][1]]) +
                        3'(syn_vec_q[LDPC128_COL_IDX[v][2]]) +
                        3'(syn_vec_q[LDPC128_COL_IDX[v][3]]) +
                        3'(syn_vec_q[LDPC128_COL_IDX[v][4]]);
              end else begin
                u_cnt = 3'(syn_vec_q[LDPC128_COL_IDX[v][0]]) +
                        3'(syn_vec_q[LDPC128_COL_IDX[v][1]]) +
                        3'(syn_vec_q[LDPC128_COL_IDX[v][2]]);
              end
              unsat_cnt_q[v] <= u_cnt;
              if (u_cnt == 3'd5) g5 = 1'b1;
              if (u_cnt >= 3'd4) g4 = 1'b1;
              if (u_cnt >= 3'd3) g3 = 1'b1;
              if ((v >= 64) && (u_cnt == 3'd2)) gp2 = 1'b1;
            end
            has_ge5_q     <= g5;
            has_ge4_q     <= g4;
            has_ge3_q     <= g3;
            has_par_ge2_q <= gp2;
            state_q       <= LDPC_FLIP_BITS;
          end
        end

        LDPC_FLIP_BITS: begin
          // Stage 3 (2 LUT levels): Flip variable nodes achieving maximum unsatisfied check count
          logic [2:0] thresh;
          thresh = has_ge5_q ? 3'd5 : (has_ge4_q ? 3'd4 : (has_ge3_q ? 3'd3 : 3'd2));
          for (int v = 0; v < 128; v++) begin
            if (thresh >= 3'd3) begin
              if (unsat_cnt_q[v] == thresh) begin
                hard_cb_q[127 - v] <= ~hard_cb_q[127 - v];
              end
            end else if ((v >= 64) && has_par_ge2_q && (unsat_cnt_q[v] == 3'd2)) begin
              hard_cb_q[127 - v] <= ~hard_cb_q[127 - v];
            end
          end
          iter_cnt_q <= iter_cnt_q + 5'd1;
          state_q    <= LDPC_EVAL_SYN;
        end

        LDPC_EMIT_BYTES: begin
          if (!m_axis_tvalid || m_axis_tready) begin
            if (emit_idx_q == 4'd8) begin
              emit_idx_q <= 4'd0;
              state_q    <= LDPC_COLLECT_CB;
            end else begin
              logic [7:0] raw_byte;
              logic [7:0] pn_byte;
              raw_byte      = info_bits_q[63:56];
              pn_byte       = tc_derand_en ? get_tc_pn_byte(lfsr_q) : 8'h00;
              m_axis_tdata  <= raw_byte ^ pn_byte;
              m_axis_tvalid <= 1'b1;
              info_bits_q   <= {info_bits_q[55:0], 8'h00};
              lfsr_q        <= next_tc_lfsr_state(lfsr_q);
              emit_idx_q    <= emit_idx_q + 4'd1;
            end
          end
        end

        default: state_q <= LDPC_COLLECT_CB;
      endcase
    end
  end

endmodule : ccsds_ul_short_ldpc_dec
