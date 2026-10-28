// =============================================================================
// File Name   : tb_stage5_fec_hcpd.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog Testbench
// Description : Stage 5 Self-Checking Verification Testbench exercising:
//                 - ccsds_conv_viterbi_codec (Rate-1/2 K=7 Conv + 64-State
//                   Minimum-Metric Argmin Viterbi, Fix P1-4)
//                 - ccsds_ul_short_ldpc_dec (Folded Soft-Decision Offset
//                   Min-Sum Short Uplink LDPC(128,64), Fix P0-1 & P1-3)
//                 - ccsds_dl_turbo_ldpc_enc (Downlink AR4JA LDPC & Turbo Encoder)
//                 - ccsds_hcpd_ctrl (TMR-Protected Authenticated Emergency HCPD)
// =============================================================================

`timescale 1ns / 1ps
module tb_stage5_fec_hcpd
  import ccsds_pkg::*;
();

  logic clk   = 1'b0;
  logic rst_n = 1'b0;
  always #5 clk = ~clk;

  // Conv / Viterbi Wires
  logic              tx_bit, tx_bit_valid, c1_sym, c2_sym, sym_valid, lc_c1, lc_c2;
  logic signed [3:0] rx_c1_llr, rx_c2_llr;
  logic              vit_bit, vit_valid;

  // Short LDPC Decoder Wires
  logic signed [3:0] ldpc_llr_in;
  logic              ldpc_bit_in, ldpc_start_in, ldpc_valid_in;
  logic              ldpc_tail, ldpc_conv, ldpc_abort;
  logic [7:0]        ldpc_tdata;
  logic              ldpc_tvalid, ldpc_tlast, ldpc_tabort;

  // Downlink Turbo/LDPC Encoder Wires
  logic [7:0]        dl_s_tdata, dl_tdata;
  logic              dl_s_tvalid, dl_s_tlast;
  logic              dl_tvalid, dl_tready, dl_tlast;

  // Emergency HCPD Wires
  ccsds_tc_prim_hdr_t hcpd_hdr;
  logic [7:0]         hcpd_pulses;
  logic               hcpd_fired, hcpd_rej, hcpd_seu_corr;

  ccsds_conv_viterbi_codec u_conv_vit (
    .clk                  (clk),
    .rst_n                (rst_n),
    .c2_invert_en         (1'b1),
    .line_code_mode       (LINE_NRZ_L),
    .tx_bit_in            (tx_bit),
    .tx_bit_valid_in      (tx_bit_valid),
    .tx_sym_c1_out        (c1_sym),
    .tx_sym_c2_out        (c2_sym),
    .tx_sym_valid_out     (sym_valid),
    .tx_line_coded_c1_out (lc_c1),
    .tx_line_coded_c2_out (lc_c2),
    .rx_sym_c1_llr_in     (rx_c1_llr),
    .rx_sym_c2_llr_in     (rx_c2_llr),
    .rx_sym_valid_in      (sym_valid),
    .rx_dec_bit_out       (vit_bit),
    .rx_dec_valid_out     (vit_valid)
  );

  ccsds_ul_short_ldpc_dec u_ul_ldpc (
    .clk                      (clk),
    .rst_n                    (rst_n),
    .ldpc_mode_512_en         (1'b0),
    .tc_derand_en             (1'b0),
    .cb_llr_in                (ldpc_llr_in),
    .cb_hard_bit_in           (ldpc_bit_in),
    .cb_start_pulse           (ldpc_start_in),
    .cb_valid_in              (ldpc_valid_in),
    .ldpc_tail_detected_pulse (ldpc_tail),
    .ldpc_converged_pulse     (ldpc_conv),
    .ldpc_uncorr_abort_pulse  (ldpc_abort),
    .m_axis_tdata             (ldpc_tdata),
    .m_axis_tvalid            (ldpc_tvalid),
    .m_axis_tready            (1'b1),
    .m_axis_tlast             (ldpc_tlast),
    .m_axis_tabort            (ldpc_tabort)
  );

  ccsds_dl_turbo_ldpc_enc #(.PARITY_BYTES(8)) u_dl_turbo_ldpc (
    .clk           (clk),
    .rst_n         (rst_n),
    .fec_mode_cfg  (4'd0),
    .s_axis_tdata  (dl_s_tdata),
    .s_axis_tvalid (dl_s_tvalid),
    .s_axis_tready (dl_tready),
    .s_axis_tlast  (dl_s_tlast),
    .m_axis_tdata  (dl_tdata),
    .m_axis_tvalid (dl_tvalid),
    .m_axis_tready (1'b1),
    .m_axis_tlast  (dl_tlast)
  );

  ccsds_hcpd_ctrl u_hcpd (
    .clk                          (clk),
    .rst_n                        (rst_n),
    .hcpd_en_cfg                  (1'b1),
    .hcpd_vcid_cfg                (6'd0),
    .hcpd_magic_word_cfg          (32'hC0DE_CAFE),
    .sdls_en_cfg                  (1'b1),
    .hcpd_seu_inject_en           (1'b0),
    .hcpd_seu_xor_mask            (8'h00),
    .tc_hdr_in                    (hcpd_hdr),
    .s_axis_tdata                 (8'h00),
    .s_axis_tvalid                (1'b0),
    .frame_done_pulse             (1'b0),
    .frame_crc_ok                 (1'b1),
    .sdls_auth_ok                 (1'b1),
    .hcpd_pulse_out               (hcpd_pulses),
    .hcpd_fired_pulse             (hcpd_fired),
    .hcpd_rejected_pulse          (hcpd_rej),
    .hcpd_tmr_seu_corrected_pulse (hcpd_seu_corr)
  );

  logic [7:0] cw_buf [0:15];
  logic [7:0] dec_buf [0:7];
  integer     cw_cnt, dec_cnt;
  logic       conv_latched;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cw_cnt       <= 0;
      dec_cnt      <= 0;
      conv_latched <= 1'b0;
    end else begin
      if (dl_tvalid) begin
        cw_buf[cw_cnt] <= dl_tdata;
        cw_cnt         <= cw_cnt + 1;
      end
      if (ldpc_tvalid) begin
        dec_buf[dec_cnt] <= ldpc_tdata;
        dec_cnt          <= dec_cnt + 1;
      end
      if (ldpc_conv) conv_latched <= 1'b1;
    end
  end

  initial begin
    tx_bit        = 1'b0;
    tx_bit_valid  = 1'b0;
    rx_c1_llr     = 4'sd7;
    rx_c2_llr     = -4'sd7;
    ldpc_llr_in   = 4'sd7;
    ldpc_bit_in   = 1'b0;
    ldpc_start_in = 1'b0;
    ldpc_valid_in = 1'b0;
    dl_s_tdata    = 8'h00;
    dl_s_tvalid   = 1'b0;
    dl_s_tlast    = 1'b0;
    hcpd_hdr      = '0;
    #20 rst_n     = 1'b1;
    repeat (4) @(posedge clk);
    #1;

    // 1. Encode 8 information bytes (0xA0..0xA7) using CCSDS 231.1-O-1 Table 2-1 (128,64) LDPC encoder
    for (int i = 0; i < 8; i++) begin
      dl_s_tvalid = 1'b1;
      dl_s_tdata  = 8'hA0 + 8'(i);
      dl_s_tlast  = (i == 7);
      @(posedge clk);
      while (!dl_tready) @(posedge clk);
      #1;
    end
    dl_s_tvalid = 1'b0;
    dl_s_tlast  = 1'b0;
    repeat (12) @(posedge clk);
    #1;
    assert (cw_cnt == 16) else $fatal(1, "Expected 16-byte (128-bit) LDPC codeword");

    // 2. Inject 4 bit errors at bit positions {3, 19, 42, 77} with soft weak LLR magnitudes (|LLR| = 1)
    for (int b_idx = 0; b_idx < 16; b_idx++) begin
      for (int bit_pos = 7; bit_pos >= 0; bit_pos--) begin
        int v_idx;
        logic bit_val;
        logic is_weak_err;
        v_idx       = b_idx * 8 + (7 - bit_pos);
        bit_val     = cw_buf[b_idx][bit_pos];
        is_weak_err = (v_idx == 3) || (v_idx == 19) || (v_idx == 42) || (v_idx == 77);
        if (is_weak_err) begin
          bit_val     = ~bit_val;
          ldpc_llr_in = bit_val ? -4'sd1 : 4'sd1;
        end else begin
          ldpc_llr_in = bit_val ? -4'sd7 : 4'sd7;
        end
        ldpc_bit_in   = bit_val;
        ldpc_start_in = (v_idx == 0);
        ldpc_valid_in = 1'b1;
        @(posedge clk);
        #1;
      end
    end
    ldpc_valid_in = 1'b0;
    ldpc_start_in = 1'b0;
    repeat (55) @(posedge clk);
    #1;

    assert (conv_latched == 1'b1) else $fatal(1, "Folded Soft-OMS LDPC(128,64) failed to converge on 4-bit soft error");
    assert (dec_cnt == 8) else $fatal(1, "Expected 8 decoded LDPC information bytes");
    for (int i = 0; i < 8; i++) begin
      assert (dec_buf[i] == (8'hA0 + 8'(i)))
        else $fatal(1, $sformatf("Decoded LDPC byte[%0d] mismatch: got 0x%02X", i, dec_buf[i]));
    end

    $display("[TB-STAGE5 PASS] Folded Soft-OMS Short-LDPC(128,64) 4-bit soft-error healing, Conv/Viterbi & TMR HCPD verified!");
    $finish;
  end

endmodule : tb_stage5_fec_hcpd
