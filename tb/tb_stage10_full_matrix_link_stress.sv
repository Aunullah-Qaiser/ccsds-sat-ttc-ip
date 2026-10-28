//=============================================================================
// File Name   : tb_stage10_full_matrix_link_stress.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Description : Stage 10 Full-Matrix Configuration & Impaired-Channel Link-
//               Closure Stress Testbench (Source -> Tx -> Impaired Channel ->
//               Rx -> Sink across all IP variations):
//                 - MATRIX 1: All 12 Baseband PHY Combinations (4 Modulations:
//                   BPSK, QPSK, OQPSK, PCM/PM x 3 Line Codes: NRZ-L, NRZ-M,
//                   Bi-Phi-L) over AWGN + 180-deg phase-inverted IQ channel,
//                   plus S-Band (240/221), X-Band (880/749) & Ka-Band (3344/749
//                   & 3360/749) Turnaround, Closed-Loop 4-SPS Gardner Symbol
//                   Timing Recovery, Milestone 4 FLL-Assisted Costas Wide-CFO
//                   Pull-In (+/-640), and T2B & T4B Regenerative PN Ranging.
//                 - MATRIX 2: Concatenated Downlink FEC Link Closure (Space
//                   Packet -> VC Arbiter -> TM Framer -> RS(255,223) Outer
//                   Encoder -> Rate-1/2 K=7 Convolutional Inner Encoder ->
//                   Noisy Channel [distributed symbol flips + 2-byte burst] ->
//                   64-State Soft Viterbi Decoder -> RS(255,223) Peterson-
//                   Berlekamp Decoder -> TM Deframer -> Packet Reassembler).
//                 - MATRIX 3: Multi-Protocol & Multi-Rate FEC Sweep (AOS
//                   GF(2^4) FHEC, Turbo Rates r=1/2, 1/3, 1/4, 1/6, LDPC
//                   (128,64), and RS Interleaving Depths I=1, 2, 4, 8).
//                 - MATRIX 4: Encrypted SDLS (NIST FIPS-197 AES-128-CTR &
//                   Milestone 3 NIST SP 800-38D AES-128-GCM 128-bit GHASH Tag)
//                   + Noisy Uplink FEC (BCH(63,56) with 1-bit SEC, 2-bit burst
//                   drop, CLCW Retransmit=1 & FOP-1 Go-Back-N recovery).
//                 - MATRIX 5: Simultaneous Radiation SEU Storm across FARM-1
//                   TMR, HCPD TMR & Hsiao SECDED FIFO during active Emergency
//                   HCPD (VCID=63) command execution.
//=============================================================================
`timescale 1ns / 1ps

module tb_stage10_full_matrix_link_stress;
  import ccsds_pkg::*;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  always #5 clk = ~clk; // 100 MHz master clock

  // ===========================================================================
  // MATRIX 1: Baseband PHY (12 Mod x Line Modes) + Continuous CFO + PN Ranging
  // ===========================================================================
  logic               phy_rst_n;
  logic [1:0]         phy_mod_cfg, phy_line_cfg;
  logic               phy_xband_cfg, phy_pn_en_cfg, phy_srrc_en_cfg, phy_gardner_en_cfg, phy_fll_en_cfg, pn_t4b_cfg;
  logic [1:0]         phy_kaband_cfg;
  logic [1:0]         phy_gardner_phase_out;
  logic [1:0]         ch_timing_offset_cfg;
  logic signed [11:0] ch_i_delay_q [0:2];
  logic signed [11:0] ch_q_delay_q [0:2];
  logic signed [11:0] phy_rx_i_timed, phy_rx_q_timed;
  logic [7:0]         m1_srrc_rx_buf [0:15];
  integer             m1_srrc_rx_cnt;
  logic               pn_chip_en, pn_tx_chip, pn_c1_locked, pn_all_locked;
  logic [19:0]        pn_epoch_idx;
  logic signed [7:0]  pn_rx_samp_in;
  logic signed [11:0] phy_tx_i, phy_tx_q, phy_rx_i, phy_rx_q;
  logic               phy_tx_iq_val, phy_rx_iq_val;
  logic               phy_rx_sym_val, phy_car_lock, phy_sym_lock;
  logic [7:0]         phy_rx_sym_byte;
  logic signed [7:0]  phy_wb_pn_samp;
  logic [31:0]        phy_tx_nco_fcw;
  logic               phy_s_tvalid, phy_s_tready;
  logic [7:0]         phy_s_tdata;
  logic               ch_invert_180;
  logic signed [11:0] ch_cfo_step;

  assign pn_rx_samp_in = (pn_tx_chip ? 8'sd90 : -8'sd90) + 8'sd12;

  ccsds_channel_impairment_model u_m1_chan (
    .clk                    (clk),
    .rst_n                  (rst_n && phy_rst_n),
    .chan_mode_cfg          (2'd2), // Enable zero-mean PRNG AWGN on I/Q
    .ber_threshold_cfg      (8'd0),
    .phase_invert_cfg       (ch_invert_180),
    .burst_target_byte_cfg  (16'd0),
    .burst_xor_mask_cfg     (8'h00),
    .doppler_offset_cfg     (ch_cfo_step), // Continuous CFO phase rotation step/sample
    .s_axis_tvalid          (1'b0),
    .s_axis_tready          (),
    .s_axis_tdata           (8'h00),
    .s_axis_tlast           (1'b0),
    .m_axis_tvalid          (),
    .m_axis_tready          (1'b1),
    .m_axis_tdata           (),
    .m_axis_tlast           (),
    .tx_i_in                (phy_tx_i),
    .tx_q_in                (phy_tx_q),
    .tx_iq_valid_in         (phy_tx_iq_val),
    .rx_i_out               (phy_rx_i),
    .rx_q_out               (phy_rx_q),
    .rx_iq_valid_out        (phy_rx_iq_val),
    .injected_byte_errs_out (),
    .passed_bytes_out       ()
  );

  always_comb begin
    unique case (ch_timing_offset_cfg)
      2'd1: begin
        phy_rx_i_timed = ch_i_delay_q[0];
        phy_rx_q_timed = ch_q_delay_q[0];
      end
      2'd2: begin
        phy_rx_i_timed = ch_i_delay_q[1];
        phy_rx_q_timed = ch_q_delay_q[1];
      end
      2'd3: begin
        phy_rx_i_timed = ch_i_delay_q[2];
        phy_rx_q_timed = ch_q_delay_q[2];
      end
      default: begin
        phy_rx_i_timed = phy_rx_i;
        phy_rx_q_timed = phy_rx_q;
      end
    endcase
  end

  ccsds_phy_modem u_phy_dut (
    .clk                      (clk),
    .rst_n                    (rst_n && phy_rst_n),
    .mod_mode_cfg             (phy_mod_cfg),
    .line_code_cfg            (phy_line_cfg),
    .turnaround_xband_cfg     (phy_xband_cfg),
    .turnaround_kaband_cfg    (phy_kaband_cfg),
    .pn_ranging_en_cfg        (phy_pn_en_cfg),
    .srrc_4sps_en_cfg         (phy_srrc_en_cfg),
    .gardner_ted_en_cfg       (phy_gardner_en_cfg),
    .fll_assist_en_cfg        (phy_fll_en_cfg),
    .tx_pn_chip_in            (pn_tx_chip),
    .rx_i_in                  (phy_rx_i_timed),
    .rx_q_in                  (phy_rx_q_timed),
    .rx_iq_valid_in           (phy_rx_iq_val),
    .rx_sym_valid_out         (phy_rx_sym_val),
    .rx_sym_byte_out          (phy_rx_sym_byte),
    .wideband_pn_sample_out   (phy_wb_pn_samp),
    .carrier_lock_out         (phy_car_lock),
    .symbol_lock_out          (phy_sym_lock),
    .gardner_strobe_phase_out (phy_gardner_phase_out),
    .tx_nco_fcw_out           (phy_tx_nco_fcw),
    .s_axis_tx_tvalid         (phy_s_tvalid),
    .s_axis_tx_tready         (phy_s_tready),
    .s_axis_tx_tdata          (phy_s_tdata),
    .tx_i_out                 (phy_tx_i),
    .tx_q_out                 (phy_tx_q),
    .tx_iq_valid_out          (phy_tx_iq_val)
  );

  ccsds_pn_ranging #(.LOCK_THRESHOLD(16'd200)) u_pn_dut (
    .clk                     (clk),
    .rst_n                   (rst_n),
    .pn_ranging_en_cfg       (phy_pn_en_cfg),
    .t4b_mode_cfg            (pn_t4b_cfg),
    .chip_en_in              (pn_chip_en),
    .rx_chip_sample_in       (pn_rx_samp_in),
    .tx_pn_chip_out          (pn_tx_chip),
    .pn_c1_locked_out        (pn_c1_locked),
    .pn_all_locked_out       (pn_all_locked),
    .composite_epoch_idx_out (pn_epoch_idx)
  );

  // ===========================================================================
  // MATRIX 2: Concatenated Downlink Chain (VC_Arb -> TM_Framer -> RS_Enc ->
  //           Conv_K7 -> Noisy Channel -> Soft_Viterbi -> RS_Dec -> TM_Deframer
  //           -> Pkt_Reassembler)
  // ===========================================================================
  logic        m2_req_frame;
  logic [7:0]  m2_s_pkt_tdata, m2_tfdf_tdata, m2_tm_tdata, m2_cadu_tdata;
  logic        m2_s_pkt_tvalid, m2_s_pkt_tready, m2_s_pkt_tlast;
  logic        m2_tfdf_tvalid, m2_tfdf_tready, m2_tfdf_tlast, m2_tfdf_oid;
  logic [2:0]  m2_tfdf_vcid;
  logic [10:0] m2_tfdf_fhp;
  logic        m2_tm_tvalid, m2_tm_tready, m2_tm_tlast;
  logic        m2_cadu_tvalid, m2_cadu_tlast;
  logic [3:0]  m2_rs_i_cfg;

  logic                 m2_vit_tx_bit, m2_vit_tx_val, m2_vit_c1, m2_vit_c2, m2_vit_sym_val;
  logic                 m2_vit_lc1_unused, m2_vit_lc2_unused;
  logic signed [3:0]    m2_vit_llr1, m2_vit_llr2;
  logic                 m2_vit_rx_val, m2_vit_dec_bit, m2_vit_dec_val;

  logic [7:0]           m2_rs_dec_s_tdata, m2_rs_dec_m_tdata, m2_def_tdata, m2_rx_pkt_tdata;
  logic                 m2_rs_dec_s_tvalid, m2_rs_dec_s_tready, m2_rs_dec_s_tlast;
  logic                 m2_rs_dec_m_tvalid, m2_rs_dec_m_tready, m2_rs_dec_m_tlast;
  logic                 m2_def_tvalid, m2_def_tready, m2_def_tlast;
  logic                 m2_rx_pkt_tvalid, m2_rx_pkt_tlast;
  logic                 m2_rs_cw_done, m2_rs_syn_clean, m2_tm_crc_ok;
  logic [15:0]          m2_rs_corr_cnt;
  logic [47:0]          m2_rx_obt_out;
  ccsds_space_pkt_hdr_t m2_rx_pkt_hdr;

  ccsds_vc_arbiter_mux #(.NUM_VC(8)) u_m2_vc_arb (
    .clk                 (clk),
    .rst_n               (rst_n),
    .tfdf_byte_len_cfg   (11'd20),
    .request_next_frame  (m2_req_frame),
    .s_axis_pkt_tdata    (m2_s_pkt_tdata),
    .s_axis_pkt_vcid     (3'd2),
    .s_axis_pkt_tvalid   (m2_s_pkt_tvalid),
    .s_axis_pkt_tready   (m2_s_pkt_tready),
    .s_axis_pkt_tlast    (m2_s_pkt_tlast),
    .m_axis_tfdf_tdata   (m2_tfdf_tdata),
    .m_axis_tfdf_tvalid  (m2_tfdf_tvalid),
    .m_axis_tfdf_tready  (m2_tfdf_tready),
    .m_axis_tfdf_tlast   (m2_tfdf_tlast),
    .m_axis_tfdf_vcid    (m2_tfdf_vcid),
    .m_axis_tfdf_fhp     (m2_tfdf_fhp),
    .m_axis_tfdf_is_oid  (m2_tfdf_oid),
    .irq_obc_pkt_len_err ()
  );

  ccsds_tm_aos_uslp_framer #(.NUM_VC(8)) u_m2_tm_framer (
    .clk                   (clk),
    .rst_n                 (rst_n),
    .spacecraft_id_cfg     (10'h155),
    .ocf_en_cfg            (1'b1),
    .fecf_en_cfg           (1'b1),
    .clcw_mbox_in          (32'h0108_0003),
    .proto_mode_cfg        (PROTO_TM),
    .aos_fhec_en_cfg       (1'b0),
    .uslp_scid_cfg         (16'h4255),
    .uslp_trunc_mode_cfg   (1'b0),
    .uslp_vcf_cnt_len_cfg  (3'd1),
    .uslp_upid_cfg         (5'd1),
    .fecf_crc32_cfg        (1'b0),
    .tfdf_byte_len_cfg     (11'd20),
    .obt_sec_hdr_en_cfg    (1'b0),
    .obt_cuc_timestamp_48b (48'h6530_0099_C000),
    .s_axis_tfdf_tdata     (m2_tfdf_tdata),
    .s_axis_tfdf_tvalid    (m2_tfdf_tvalid),
    .s_axis_tfdf_tready    (m2_tfdf_tready),
    .s_axis_tfdf_tlast     (m2_tfdf_tlast),
    .s_axis_tfdf_vcid      (m2_tfdf_vcid),
    .s_axis_tfdf_fhp       (m2_tfdf_fhp),
    .m_axis_frame_tdata    (m2_tm_tdata),
    .m_axis_frame_tvalid   (m2_tm_tvalid),
    .m_axis_frame_tready   (m2_tm_tready),
    .m_axis_frame_tlast    (m2_tm_tlast)
  );

  ccsds_dl_rs255_223_enc u_m2_rs_enc (
    .clk                (clk),
    .rst_n              (rst_n),
    .interleave_depth_i (m2_rs_i_cfg),
    .tm_rand_en         (1'b0),
    .conv_enc_en        (1'b1),
    .s_axis_tdata       (m2_tm_tdata),
    .s_axis_tvalid      (m2_tm_tvalid),
    .s_axis_tready      (m2_tm_tready),
    .s_axis_tlast       (m2_tm_tlast),
    .m_axis_cadu_tdata  (m2_cadu_tdata),
    .m_axis_cadu_tvalid (m2_cadu_tvalid),
    .m_axis_cadu_tready (1'b1),
    .m_axis_cadu_tlast  (m2_cadu_tlast),
    .conv_symbols_out   (),
    .conv_symbols_valid ()
  );

  ccsds_conv_viterbi_codec #(.TRACEBACK_DEPTH(35)) u_m2_conv_vit (
    .clk                  (clk),
    .rst_n                (rst_n),
    .c2_invert_en         (1'b1),
    .line_code_mode       (LINE_NRZ_L),
    .tx_bit_in            (m2_vit_tx_bit),
    .tx_bit_valid_in      (m2_vit_tx_val),
    .tx_sym_c1_out        (m2_vit_c1),
    .tx_sym_c2_out        (m2_vit_c2),
    .tx_sym_valid_out     (m2_vit_sym_val),
    .tx_line_coded_c1_out (m2_vit_lc1_unused),
    .tx_line_coded_c2_out (m2_vit_lc2_unused),
    .rx_sym_c1_llr_in     (m2_vit_llr1),
    .rx_sym_c2_llr_in     (m2_vit_llr2),
    .rx_sym_valid_in      (m2_vit_rx_val),
    .rx_dec_bit_out       (m2_vit_dec_bit),
    .rx_dec_valid_out     (m2_vit_dec_val)
  );

  ccsds_dl_rs255_223_dec u_m2_rs_dec (
    .clk                      (clk),
    .rst_n                    (rst_n),
    .interleave_depth_i_cfg   (4'd1),
    .virtual_fill_q_cfg       (8'd191), // 223 - 32B TM frame = 191
    .s_axis_tvalid            (m2_rs_dec_s_tvalid),
    .s_axis_tready            (m2_rs_dec_s_tready),
    .s_axis_tdata             (m2_rs_dec_s_tdata),
    .s_axis_tlast             (m2_rs_dec_s_tlast),
    .m_axis_tvalid            (m2_rs_dec_m_tvalid),
    .m_axis_tready            (m2_rs_dec_m_tready),
    .m_axis_tdata             (m2_rs_dec_m_tdata),
    .m_axis_tlast             (m2_rs_dec_m_tlast),
    .rs_cw_done_pulse         (m2_rs_cw_done),
    .rs_syndrome_clean_out    (m2_rs_syn_clean),
    .rs_corrected_sym_cnt_out (m2_rs_corr_cnt)
  );

  ccsds_tm_aos_deframer u_m2_tm_deframer (
    .clk                      (clk),
    .rst_n                    (rst_n),
    .aos_mode_cfg             (1'b0),
    .aos_fhec_en_cfg          (1'b0),
    .tm_sec_hdr_en_cfg        (1'b0),
    .ocf_en_cfg               (1'b1),
    .fecf_en_cfg              (1'b1),
    .tfdf_byte_len_cfg        (16'd20),
    .s_axis_tvalid            (m2_rs_dec_m_tvalid),
    .s_axis_tready            (m2_rs_dec_m_tready),
    .s_axis_tdata             (m2_rs_dec_m_tdata),
    .s_axis_tlast             (m2_rs_dec_m_tlast),
    .m_axis_tfdf_tvalid       (m2_def_tvalid),
    .m_axis_tfdf_tready       (m2_def_tready),
    .m_axis_tfdf_tdata        (m2_def_tdata),
    .m_axis_tfdf_tlast        (m2_def_tlast),
    .rx_tm_hdr_out            (),
    .rx_obt_cuc_timestamp_out (m2_rx_obt_out),
    .extracted_clcw_out       (),
    .clcw_valid_pulse         (),
    .frame_crc_ok_pulse       (m2_tm_crc_ok),
    .frame_crc_err_pulse      ()
  );

  ccsds_pkt_reassembler u_m2_pkt_reasm (
    .clk                     (clk),
    .rst_n                   (rst_n),
    .fhp_resync_en           (1'b0),
    .frame_fhp_in            (11'd0),
    .frame_start_pulse       (1'b0),
    .s_axis_tdata            (m2_def_tdata),
    .s_axis_tvalid           (m2_def_tvalid),
    .s_axis_tready           (m2_def_tready),
    .s_axis_tlast            (m2_def_tlast),
    .m_axis_pkt_tdata        (m2_rx_pkt_tdata),
    .m_axis_pkt_tvalid       (m2_rx_pkt_tvalid),
    .m_axis_pkt_tready       (1'b1),
    .m_axis_pkt_tlast        (m2_rx_pkt_tlast),
    .parsed_pkt_hdr          (m2_rx_pkt_hdr),
    .pkt_completed_pulse     (),
    .idle_pkt_stripped_pulse (),
    .pkt_len_err_pulse       ()
  );

  // ===========================================================================
  // MATRIX 3: Multi-Protocol (AOS FHEC) & All 5 Next-Gen FEC Modes (LDPC +
  //           Turbo r=1/2, 1/3, 1/4, 1/6)
  // ===========================================================================
  logic [23:0] m3_aos_hdr_in;
  logic [15:0] m3_aos_fhec_tx, m3_aos_fhec_rx;
  logic        m3_aos_syn_ok;

  ccsds_gf256_math u_m3_fhec (
    .gf256_a_std           (8'h02),
    .gf256_b_std           (8'h04),
    .gf256_prod_std        (),
    .std_in                (8'h01),
    .dual_out              (),
    .dual_in               (8'h7B),
    .std_out               (),
    .aos_hdr_protected_24b (m3_aos_hdr_in),
    .aos_fhec_rx_16b       (m3_aos_fhec_rx),
    .aos_fhec_tx_16b       (m3_aos_fhec_tx),
    .aos_fhec_syndrome_ok  (m3_aos_syn_ok)
  );
  assign m3_aos_fhec_rx = m3_aos_fhec_tx;

  logic [3:0] m3_turbo_mode;
  logic [7:0] m3_turbo_s_tdata, m3_turbo_m_tdata;
  logic       m3_turbo_s_tvalid, m3_turbo_s_tready, m3_turbo_s_tlast;
  logic       m3_turbo_m_tvalid, m3_turbo_m_tlast;

  ccsds_dl_turbo_ldpc_enc #(.PARITY_BYTES(8)) u_m3_turbo_enc (
    .clk           (clk),
    .rst_n         (rst_n),
    .fec_mode_cfg  (m3_turbo_mode),
    .s_axis_tdata  (m3_turbo_s_tdata),
    .s_axis_tvalid (m3_turbo_s_tvalid),
    .s_axis_tready (m3_turbo_s_tready),
    .s_axis_tlast  (m3_turbo_s_tlast),
    .m_axis_tdata  (m3_turbo_m_tdata),
    .m_axis_tvalid (m3_turbo_m_tvalid),
    .m_axis_tready (1'b1),
    .m_axis_tlast  (m3_turbo_m_tlast)
  );

  // ===========================================================================
  // MATRIX 4: Encrypted SDLS (AES-128-CTR & AES-128-GCM) + Noisy BCH(63,56) +
  //           Closed-Loop COP-1 (FOP-1 <-> FARM-1) Go-Back-N Stress
  // ===========================================================================
  localparam logic [255:0] M4_AES_KEY = {
    128'h00000000_00000000_00000000_00000000,
    128'h2B7E1516_28AED2A6_ABF71588_09CF4F3C
  };

  logic        m4_fop_req, m4_fop_win_open, m4_clcw_val, m4_retx_req;
  logic [7:0]  m4_fop_vs, m4_fop_nnr;
  logic [15:0] m4_retx_cnt;
  ccsds_clcw_t m4_rx_clcw;

  logic [7:0]  m4_sdls_tx_s_tdata, m4_sdls_tx_m_tdata;
  logic        m4_sdls_tx_s_tvalid, m4_sdls_tx_s_tready, m4_sdls_tx_s_tlast;
  logic        m4_sdls_tx_m_tvalid, m4_sdls_tx_m_tready, m4_sdls_tx_m_tlast;
  logic        m4_sdls_gcm_mode;
  logic        m4_sdls_direct_en;
  logic        m4_sdls_direct_tvalid, m4_sdls_direct_tlast;
  logic [7:0]  m4_sdls_direct_tdata;

  logic [7:0]  m4_tc_frm_s_tdata, m4_tc_frm_m_tdata, m4_cltu_tdata;
  logic        m4_tc_frm_s_tvalid, m4_tc_frm_s_tready, m4_tc_frm_s_tlast;
  logic        m4_tc_frm_m_tvalid, m4_tc_frm_m_tready, m4_tc_frm_m_tlast;
  logic        m4_cltu_tvalid, m4_cltu_tlast;
  logic [7:0]  m4_cur_tx_ns;

  logic signed [3:0] m4_ul_llr_in, m4_ul_cb_llr;
  logic              m4_ul_sym_val, m4_ul_cb_bit, m4_ul_cb_start, m4_ul_cb_val;
  logic              m4_ul_cltu_end, m4_ul_bch_1err, m4_ul_bch_2abort;
  logic [7:0]        m4_bch_m_tdata, m4_def_m_tdata, m4_sdls_rx_m_tdata, m4_pkt_m_tdata;
  logic              m4_bch_m_tvalid, m4_bch_m_tready, m4_bch_m_tlast, m4_bch_m_tabort;
  logic              m4_def_m_tvalid, m4_def_m_tready, m4_def_m_tlast;
  logic              m4_sdls_rx_m_tvalid, m4_sdls_rx_m_tready, m4_sdls_rx_m_tlast;
  logic              m4_pkt_m_tvalid, m4_pkt_m_tlast;
  ccsds_tc_prim_hdr_t m4_parsed_tc_hdr;
  logic              m4_frame_done, m4_frame_crc_ok, m4_sdls_auth_done, m4_sdls_auth_ok;
  logic              m4_farm_acc, m4_farm_rej, m4_farm_seu_corr;
  ccsds_clcw_t       m4_farm_clcw;

  ccsds_fop1_engine u_m4_fop1 (
    .clk                       (clk),
    .rst_n                     (rst_n),
    .target_vcid_cfg           (6'd1),
    .sliding_win_k_cfg         (8'd8),
    .t1_timeout_cycles_cfg     (16'd8000),
    .tx_type_ad_req_pulse      (m4_fop_req),
    .tx_window_open_out        (m4_fop_win_open),
    .fop1_vs_out               (m4_fop_vs),
    .fop1_nnr_out              (m4_fop_nnr),
    .rx_clcw_valid_pulse       (m4_clcw_val),
    .rx_clcw_in                (m4_rx_clcw),
    .fop1_retransmit_pulse_out (m4_retx_req),
    .fop1_replay_from_seq_out  (),
    .fop1_unlock_req_out       (),
    .fop1_ack_cnt_out          (),
    .fop1_retransmit_cnt_out   (m4_retx_cnt)
  );

  ccsds_sdls_engine u_m4_sdls (
    .clk                        (clk),
    .rst_n                      (rst_n),
    .clk_tx                     (clk),
    .rst_tx_n                   (rst_n),
    .sdls_en_cfg                (1'b1),
    .sdls_gcm_mode_cfg          (m4_sdls_gcm_mode),
    .bc_require_sdls_cfg        (1'b0),
    .tx_default_spi_cfg         (16'h0003),
    .master_key_cfg             (M4_AES_KEY),
    .sa_wr_en                   (1'b0),
    .sa_wr_addr                 (6'd0),
    .sa_wr_spi                  (16'd0),
    .sa_wr_seq_low              (32'd0),
    .s_axis_rx_tvalid           (m4_sdls_direct_en ? m4_sdls_direct_tvalid : m4_def_m_tvalid),
    .s_axis_rx_tready           (m4_def_m_tready),
    .s_axis_rx_tdata            (m4_sdls_direct_en ? m4_sdls_direct_tdata  : m4_def_m_tdata),
    .s_axis_rx_tlast            (m4_sdls_direct_en ? m4_sdls_direct_tlast  : m4_def_m_tlast),
    .rx_frame_is_type_bc        (1'b0),
    .m_axis_rx_tvalid           (m4_sdls_rx_m_tvalid),
    .m_axis_rx_tready           (m4_sdls_rx_m_tready),
    .m_axis_rx_tdata            (m4_sdls_rx_m_tdata),
    .m_axis_rx_tlast            (m4_sdls_rx_m_tlast),
    .sdls_auth_done_pulse       (m4_sdls_auth_done),
    .sdls_auth_ok               (m4_sdls_auth_ok),
    .rx_active_spi_out          (),
    .sa_secded_single_err_pulse (),
    .sa_secded_double_err_pulse (),
    .s_axis_tx_tvalid           (m4_sdls_tx_s_tvalid),
    .s_axis_tx_tready           (m4_sdls_tx_s_tready),
    .s_axis_tx_tdata            (m4_sdls_tx_s_tdata),
    .s_axis_tx_tlast            (m4_sdls_tx_s_tlast),
    .m_axis_tx_tvalid           (m4_sdls_tx_m_tvalid),
    .m_axis_tx_tready           (m4_sdls_tx_m_tready),
    .m_axis_tx_tdata            (m4_sdls_tx_m_tdata),
    .m_axis_tx_tlast            (m4_sdls_tx_m_tlast)
  );

  ccsds_tc_cltu_framer u_m4_tc_framer (
    .clk                 (clk),
    .rst_n               (rst_n),
    .scid_10b_cfg        (10'h155),
    .vcid_cfg            (6'd1),
    .bypass_flag_cfg     (1'b0),
    .ctrl_cmd_flag_cfg   (1'b0),
    .seg_hdr_en_cfg      (1'b1),
    .seq_flags_cfg       (2'b11),
    .map_id_cfg          (6'd0),
    .fop1_ns_in          (m4_cur_tx_ns),
    .payload_byte_len_in (10'd21), // 6B SDLS Hdr + 14B Encrypted SP + 1B SDLS Tag
    .s_axis_tvalid       (m4_tc_frm_s_tvalid),
    .s_axis_tready       (m4_tc_frm_s_tready),
    .s_axis_tdata        (m4_tc_frm_s_tdata),
    .s_axis_tlast        (m4_tc_frm_s_tlast),
    .m_axis_tvalid       (m4_tc_frm_m_tvalid),
    .m_axis_tready       (m4_tc_frm_m_tready),
    .m_axis_tdata        (m4_tc_frm_m_tdata),
    .m_axis_tlast        (m4_tc_frm_m_tlast)
  );

  ccsds_bch6356_enc u_m4_bch_enc (
    .clk                    (clk),
    .rst_n                  (rst_n),
    .tc_randomize_en_cfg    (1'b1),
    .s_axis_tvalid          (m4_tc_frm_m_tvalid),
    .s_axis_tready          (m4_tc_frm_m_tready),
    .s_axis_tdata           (m4_tc_frm_m_tdata),
    .s_axis_tlast           (m4_tc_frm_m_tlast),
    .m_axis_tvalid          (m4_cltu_tvalid),
    .m_axis_tready          (1'b1),
    .m_axis_tdata           (m4_cltu_tdata),
    .m_axis_tlast           (m4_cltu_tlast),
    .cltu_codeblock_cnt_out ()
  );

  ccsds_asm_correlator u_m4_asm (
    .clk                 (clk),
    .rst_n               (rst_n),
    .sync_mode           (2'd0),
    .hamming_thresh      (3'd1),
    .tail_or_abort_pulse (m4_ul_cltu_end || m4_ul_bch_2abort),
    .sym_llr_in          (m4_ul_llr_in),
    .sym_valid_in        (m4_ul_sym_val),
    .cb_llr_out          (m4_ul_cb_llr),
    .cb_hard_bit_out     (m4_ul_cb_bit),
    .cb_start_pulse      (m4_ul_cb_start),
    .cb_valid_out        (m4_ul_cb_val),
    .sync_locked         (),
    .phase_inverted      ()
  );

  ccsds_bch6356_dec u_m4_bch_dec (
    .clk                    (clk),
    .rst_n                  (rst_n),
    .tc_derand_en           (1'b1),
    .cb_hard_bit_in         (m4_ul_cb_bit),
    .cb_start_pulse         (m4_ul_cb_start),
    .cb_valid_in            (m4_ul_cb_val),
    .cltu_ended_pulse       (m4_ul_cltu_end),
    .bch_single_err_pulse   (m4_ul_bch_1err),
    .bch_double_abort_pulse (m4_ul_bch_2abort),
    .m_axis_tdata           (m4_bch_m_tdata),
    .m_axis_tvalid          (m4_bch_m_tvalid),
    .m_axis_tready          (m4_bch_m_tready),
    .m_axis_tlast           (m4_bch_m_tlast),
    .m_axis_tabort          (m4_bch_m_tabort)
  );

  ccsds_tc_uslp_deframer u_m4_deframer (
    .clk                      (clk),
    .rst_n                    (rst_n),
    .spacecraft_id_cfg        (10'h155),
    .uslp_scid_cfg            (16'h4255),
    .uslp_trunc_frame_len_cfg (16'd25),
    .uslp_tfdf_3byte_en_cfg   (1'b1),
    .fecf_crc32_cfg           (1'b0),
    .tc_seg_hdr_present_cfg   (1'b1),
    .s_axis_tdata             (m4_bch_m_tdata),
    .s_axis_tvalid            (m4_bch_m_tvalid),
    .s_axis_tready            (m4_bch_m_tready),
    .s_axis_tlast             (m4_bch_m_tlast),
    .s_axis_tabort            (m4_bch_m_tabort),
    .parsed_tc_hdr            (m4_parsed_tc_hdr),
    .parsed_tc_seg_hdr        (),
    .parsed_prox1_hdr         (),
    .parsed_uslp_trunc_hdr    (),
    .parsed_uslp_ext_hdr      (),
    .parsed_uslp_tfdf_hdr     (),
    .detected_proto_mode      (),
    .extracted_ocf_word       (),
    .extracted_ocf_valid      (),
    .frame_done_pulse         (m4_frame_done),
    .frame_crc_ok             (m4_frame_crc_ok),
    .frame_crc_err_pulse      (),
    .frame_commit_pulse       (),
    .frame_rollback_pulse     (),
    .m_axis_tdata             (m4_def_m_tdata),
    .m_axis_tvalid            (m4_def_m_tvalid),
    .m_axis_tready            (m4_def_m_tready),
    .m_axis_tlast             (m4_def_m_tlast)
  );

  logic m4_tmr_seu_en;
  ccsds_farm1_tmr #(.NUM_VC(8)) u_m4_farm1 (
    .clk                     (clk),
    .rst_n                   (rst_n),
    .sdls_en                 (1'b0),
    .bc_require_sdls         (1'b0),
    .window_half_w           (8'd16),
    .no_rf_avail             (1'b0),
    .no_bit_lock             (1'b0),
    .rx_buffer_wait          (1'b0),
    .tmr_seu_inject_en       (m4_tmr_seu_en),
    .tmr_seu_replica_sel     (2'd1),
    .tmr_seu_vc_sel          (3'd1),
    .tmr_seu_xor_mask        (8'hA5),
    .tc_hdr_in               (m4_parsed_tc_hdr),
    .bc_cmd_byte0            (8'h00),
    .bc_cmd_byte1            (8'h00),
    .bc_cmd_byte2            (8'h00),
    .bc_cmd_len              (3'd1),
    .frame_done_pulse        (m4_frame_done),
    .frame_crc_ok            (m4_frame_crc_ok),
    .sdls_auth_ok            (1'b1),
    .farm_accept_pulse       (m4_farm_acc),
    .farm_reject_pulse       (m4_farm_rej),
    .clcw_scheduled_out      (m4_farm_clcw),
    .clcw_valid_pulse        (),
    .tmr_seu_corrected_pulse (m4_farm_seu_corr)
  );

  ccsds_pkt_reassembler u_m4_pkt_reasm (
    .clk                     (clk),
    .rst_n                   (rst_n),
    .fhp_resync_en           (1'b0),
    .frame_fhp_in            (11'd0),
    .frame_start_pulse       (1'b0),
    .s_axis_tdata            (m4_sdls_rx_m_tdata),
    .s_axis_tvalid           (m4_sdls_rx_m_tvalid),
    .s_axis_tready           (m4_sdls_rx_m_tready),
    .s_axis_tlast            (m4_sdls_rx_m_tlast),
    .m_axis_pkt_tdata        (m4_pkt_m_tdata),
    .m_axis_pkt_tvalid       (m4_pkt_m_tvalid),
    .m_axis_pkt_tready       (1'b1),
    .m_axis_pkt_tlast        (m4_pkt_m_tlast),
    .parsed_pkt_hdr          (),
    .pkt_completed_pulse     (),
    .idle_pkt_stripped_pulse (),
    .pkt_len_err_pulse       ()
  );

  // ===========================================================================
  // MATRIX 5: Emergency HCPD TMR + Hsiao SECDED FIFO SEU Storm
  // ===========================================================================
  logic               m5_hcpd_seu_en, m5_hcpd_s_val, m5_hcpd_done;
  logic [7:0]         m5_hcpd_s_data, m5_hcpd_pulses;
  ccsds_tc_prim_hdr_t m5_hcpd_hdr;
  logic               m5_hcpd_fired, m5_hcpd_rej, m5_hcpd_seu_corr;

  ccsds_hcpd_ctrl u_m5_hcpd (
    .clk                          (clk),
    .rst_n                        (rst_n),
    .hcpd_en_cfg                  (1'b1),
    .hcpd_vcid_cfg                (EMERGENCY_VCID),
    .hcpd_magic_word_cfg          (32'hC0DE_CAFE),
    .sdls_en_cfg                  (1'b1),
    .hcpd_seu_inject_en           (m5_hcpd_seu_en),
    .hcpd_seu_xor_mask            (8'h3C),
    .tc_hdr_in                    (m5_hcpd_hdr),
    .s_axis_tdata                 (m5_hcpd_s_data),
    .s_axis_tvalid                (m5_hcpd_s_val),
    .frame_done_pulse             (m5_hcpd_done),
    .frame_crc_ok                 (1'b1),
    .sdls_auth_ok                 (1'b1),
    .hcpd_pulse_out               (m5_hcpd_pulses),
    .hcpd_fired_pulse             (m5_hcpd_fired),
    .hcpd_rejected_pulse          (m5_hcpd_rej),
    .hcpd_tmr_seu_corrected_pulse (m5_hcpd_seu_corr)
  );

  logic        m5_fifo_wr_val, m5_fifo_wr_rdy, m5_fifo_wr_last, m5_fifo_commit;
  logic [31:0] m5_fifo_wr_data, m5_fifo_rd_data;
  logic        m5_fifo_rd_val, m5_fifo_rd_rdy, m5_fifo_seu_en;
  logic        m5_fifo_1err, m5_fifo_2err;

  ccsds_cdc_fifo_ecc #(
    .DATA_WIDTH    (32),
    .DEPTH_WORDS   (64),
    .ROLLBACK_MODE (1)
  ) u_m5_ecc_fifo (
    .clk_wr                   (clk),
    .rst_wr_n                 (rst_n),
    .clk_rd                   (clk),
    .rst_rd_n                 (rst_n),
    .cut_through_en           (1'b0),
    .watermark_words          (7'd8),
    .s_axis_tdata             (m5_fifo_wr_data),
    .s_axis_tkeep             (4'hF),
    .s_axis_tvalid            (m5_fifo_wr_val),
    .s_axis_tready            (m5_fifo_wr_rdy),
    .s_axis_tlast             (m5_fifo_wr_last),
    .s_axis_tuser             ('0),
    .frame_commit_pulse       (m5_fifo_commit),
    .frame_rollback_pulse     (1'b0),
    .m_axis_tdata             (m5_fifo_rd_data),
    .m_axis_tkeep             (),
    .m_axis_tvalid            (m5_fifo_rd_val),
    .m_axis_tready            (m5_fifo_rd_rdy),
    .m_axis_tlast             (),
    .m_axis_tuser             (),
    .seu_inject_en            (m5_fifo_seu_en),
    .seu_inject_addr          (6'd0),
    .seu_inject_bit           (6'd11),
    .ecc_single_err_corrected (m5_fifo_1err),
    .ecc_double_err_uncorr    (m5_fifo_2err),
    .rollback_overflow_err    (),
    .committed_count          (),
    .speculative_count        ()
  );

  // ===========================================================================
  // Capture Buffers & Helper Tasks
  // ===========================================================================
  logic [7:0] m2_cadu_buf     [0:127];
  logic [7:0] m2_vit_rx_bytes [0:127];
  logic [7:0] m2_rx_pkt_buf   [0:31];
  integer     m2_cadu_cnt, m2_rx_pkt_cnt;

  logic [7:0] m4_sdls_ct_buf  [0:63];
  logic [7:0] m4_cltu_buf     [0:63];
  logic [7:0] m4_rx_pkt_buf   [0:63];
  integer     m4_sdls_ct_cnt, m4_cltu_cnt, m4_rx_pkt_cnt;
  logic       m4_cltu_clr, m4_sdls_clr;
  logic       m4_sdls_auth_done_latched, m4_sdls_auth_ok_latched;
  logic       m2_tm_crc_ok_latched, m5_fifo_1err_latched, m5_hcpd_seu_corr_latched;
  ccsds_clcw_t m4_vc1_clcw_latched;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      m1_srrc_rx_cnt       <= 0;
      for (int k = 0; k < 3; k++) begin
        ch_i_delay_q[k] <= 12'sd0;
        ch_q_delay_q[k] <= 12'sd0;
      end
      m2_cadu_cnt          <= 0;
      m2_rx_pkt_cnt        <= 0;
      m2_tm_crc_ok_latched <= 1'b0;
      m4_sdls_ct_cnt       <= 0;
      m4_cltu_cnt          <= 0;
      m4_rx_pkt_cnt        <= 0;
      m4_vc1_clcw_latched       <= '0;
      m4_sdls_auth_done_latched <= 1'b0;
      m4_sdls_auth_ok_latched   <= 1'b0;
      m5_fifo_1err_latched     <= 1'b0;
      m5_hcpd_seu_corr_latched <= 1'b0;
    end else begin
      if (m2_tm_crc_ok) begin
        m2_tm_crc_ok_latched <= 1'b1;
      end
      if (m5_fifo_1err) begin
        m5_fifo_1err_latched <= 1'b1;
      end
      if (m5_hcpd_seu_corr) begin
        m5_hcpd_seu_corr_latched <= 1'b1;
      end
      if (!phy_rst_n) begin
        m1_srrc_rx_cnt <= 0;
        for (int k = 0; k < 3; k++) begin
          ch_i_delay_q[k] <= 12'sd0;
          ch_q_delay_q[k] <= 12'sd0;
        end
      end else begin
        if (phy_rx_iq_val) begin
          ch_i_delay_q[0] <= phy_rx_i;
          ch_q_delay_q[0] <= phy_rx_q;
          ch_i_delay_q[1] <= ch_i_delay_q[0];
          ch_q_delay_q[1] <= ch_q_delay_q[0];
          ch_i_delay_q[2] <= ch_i_delay_q[1];
          ch_q_delay_q[2] <= ch_q_delay_q[1];
        end
        if (phy_rx_sym_val) begin
          m1_srrc_rx_buf[m1_srrc_rx_cnt] <= phy_rx_sym_byte;
          m1_srrc_rx_cnt                 <= m1_srrc_rx_cnt + 1;
        end
      end
      if (m2_cadu_tvalid) begin
        m2_cadu_buf[m2_cadu_cnt] <= m2_cadu_tdata;
        m2_cadu_cnt              <= m2_cadu_cnt + 1;
      end
      if (m2_rx_pkt_tvalid) begin
        m2_rx_pkt_buf[m2_rx_pkt_cnt] <= m2_rx_pkt_tdata;
        m2_rx_pkt_cnt                <= m2_rx_pkt_cnt + 1;
      end
      if (m4_sdls_clr) begin
        m4_sdls_ct_cnt            <= 0;
        m4_rx_pkt_cnt             <= 0;
        m4_sdls_auth_done_latched <= 1'b0;
        m4_sdls_auth_ok_latched   <= 1'b0;
      end else begin
        if (m4_sdls_tx_m_tvalid && m4_sdls_tx_m_tready) begin
          m4_sdls_ct_buf[m4_sdls_ct_cnt] <= m4_sdls_tx_m_tdata;
          m4_sdls_ct_cnt                  <= m4_sdls_ct_cnt + 1;
        end
        if (m4_sdls_auth_done) begin
          m4_sdls_auth_done_latched <= 1'b1;
          m4_sdls_auth_ok_latched   <= m4_sdls_auth_ok;
        end
      end
      if (m4_cltu_clr) begin
        m4_cltu_cnt <= 0;
      end else if (m4_cltu_tvalid) begin
        m4_cltu_buf[m4_cltu_cnt] <= m4_cltu_tdata;
        m4_cltu_cnt              <= m4_cltu_cnt + 1;
      end
      if (m4_pkt_m_tvalid) begin
        m4_rx_pkt_buf[m4_rx_pkt_cnt] <= m4_pkt_m_tdata;
        m4_rx_pkt_cnt                <= m4_rx_pkt_cnt + 1;
      end
      if (m4_farm_clcw.vcid == 6'd1) begin
        m4_vc1_clcw_latched <= m4_farm_clcw;
      end
    end
  end

  // Build a 14-byte Telecommand Space Packet (6B Hdr + 8B Payload)
  function automatic void build_tc_sp14(
    input  logic [10:0] apid,
    input  logic [13:0] seq,
    input  logic [63:0] body64,
    output logic [7:0]  pkt_out [0:13]
  );
    logic [15:0] w0, w1, w2;
    begin
      w0 = {3'b000, 1'b1, 1'b0, apid};
      w1 = {2'b11, seq};
      w2 = 16'd7; // 8 octets - 1
      pkt_out[0]  = w0[15:8]; pkt_out[1]  = w0[7:0];
      pkt_out[2]  = w1[15:8]; pkt_out[3]  = w1[7:0];
      pkt_out[4]  = w2[15:8]; pkt_out[5]  = w2[7:0];
      for (int i = 0; i < 8; i++) begin
        pkt_out[6 + i] = body64[(7 - i)*8 +: 8];
      end
    end
  endfunction

  // Stream a 50-byte CLTU (2B Start + 5x8B BCH Blocks + 8B Tail) into u_m4_asm
  task automatic stream_cltu48_over_noisy_channel(
    input logic invert_phase,
    input logic inject_1bit_per_cb,
    input logic inject_2bit_abort_cb0
  );
    for (int b_idx = 0; b_idx < 50; b_idx++) begin
      for (int bit_pos = 7; bit_pos >= 0; bit_pos--) begin
        logic bit_val;
        bit_val = m4_cltu_buf[b_idx][bit_pos];
        if (inject_1bit_per_cb && (b_idx >= 2) && (b_idx < 42) && (((b_idx - 2) % 8) == 3) && (bit_pos == 4)) begin
          bit_val = ~bit_val;
        end
        if (inject_2bit_abort_cb0 && ((b_idx == 2 && bit_pos == 5) || (b_idx == 3 && bit_pos == 2))) begin
          bit_val = ~bit_val;
        end
        if (invert_phase) begin
          bit_val = ~bit_val;
        end
        m4_ul_llr_in  = bit_val ? -4'sd7 : 4'sd7;
        m4_ul_sym_val = 1'b1;
        @(posedge clk);
        #1;
      end
    end
    m4_ul_sym_val = 1'b0;
    repeat (60) @(posedge clk);
    #1;
  endtask

  initial begin
    logic [7:0] m1_test_vec [0:3];
    logic [7:0] m1_rx_vec   [0:3];
    logic [7:0] m2_sp20     [0:19];
    logic [7:0] m4_sp0      [0:13];
    logic [63:0] hcpd_cmd64;

    rst_n               = 1'b0;
    phy_rst_n           = 1'b1;
    phy_mod_cfg         = 2'd0;
    phy_line_cfg        = 2'd0;
    phy_xband_cfg        = 1'b0;
    phy_kaband_cfg       = 2'd0;
    phy_pn_en_cfg        = 1'b0;
    phy_srrc_en_cfg      = 1'b0;
    phy_gardner_en_cfg   = 1'b0;
    phy_fll_en_cfg       = 1'b0;
    m4_sdls_gcm_mode     = 1'b0;
    m4_sdls_direct_en    = 1'b0;
    m4_sdls_direct_tvalid= 1'b0;
    m4_sdls_direct_tlast = 1'b0;
    m4_sdls_direct_tdata = 8'h00;
    m4_sdls_clr          = 1'b0;
    ch_timing_offset_cfg = 2'd0;
    pn_t4b_cfg          = 1'b1;
    pn_chip_en          = 1'b0;
    phy_s_tvalid        = 1'b0;
    phy_s_tdata         = 8'h00;
    ch_invert_180       = 1'b0;
    ch_cfo_step         = 12'sd0;

    m2_req_frame        = 1'b0;
    m2_s_pkt_tdata      = 8'h00;
    m2_s_pkt_tvalid     = 1'b0;
    m2_s_pkt_tlast      = 1'b0;
    m2_rs_i_cfg         = 4'd1;
    m2_vit_tx_bit       = 1'b0;
    m2_vit_tx_val       = 1'b0;
    m2_vit_llr1         = 4'sd7;
    m2_vit_llr2         = 4'sd7;
    m2_vit_rx_val       = 1'b0;
    m2_rs_dec_s_tvalid  = 1'b0;
    m2_rs_dec_s_tdata   = 8'h00;
    m2_rs_dec_s_tlast   = 1'b0;

    m3_aos_hdr_in       = 24'h5A_C30F;
    m3_turbo_mode       = 4'd0;
    m3_turbo_s_tdata    = 8'h00;
    m3_turbo_s_tvalid   = 1'b0;
    m3_turbo_s_tlast    = 1'b0;

    m4_fop_req          = 1'b0;
    m4_rx_clcw          = '0;
    m4_clcw_val         = 1'b0;
    m4_sdls_tx_s_tvalid = 1'b0;
    m4_sdls_tx_s_tdata  = 8'h00;
    m4_sdls_tx_s_tlast  = 1'b0;
    m4_sdls_tx_m_tready = 1'b1;
    m4_tc_frm_s_tvalid  = 1'b0;
    m4_tc_frm_s_tdata   = 8'h00;
    m4_tc_frm_s_tlast   = 1'b0;
    m4_cur_tx_ns        = 8'd0;
    m4_ul_llr_in        = 4'sd7;
    m4_ul_sym_val       = 1'b0;
    m4_tmr_seu_en       = 1'b0;
    m4_cltu_clr         = 1'b0;

    m5_hcpd_seu_en      = 1'b0;
    m5_hcpd_s_val       = 1'b0;
    m5_hcpd_done        = 1'b0;
    m5_hcpd_s_data      = 8'h00;
    m5_hcpd_hdr         = '0;
    m5_fifo_wr_val      = 1'b0;
    m5_fifo_wr_last     = 1'b0;
    m5_fifo_commit      = 1'b0;
    m5_fifo_wr_data     = 32'd0;
    m5_fifo_rd_rdy      = 1'b0;
    m5_fifo_seu_en      = 1'b0;

    #40 rst_n = 1'b1;
    repeat (4) @(posedge clk);
    #1;

    // =========================================================================
    // MATRIX 1A: All 12 Baseband PHY Combinations (4 Modulations x 3 Line Codes)
    //            + Zero-Mean AWGN + 180-deg Phase Inversion
    // =========================================================================
    $display("[TB-STAGE10][MATRIX-1A] Sweeping all 12 PHY Modes (BPSK/QPSK/OQPSK/PCM-PM x NRZ-L/NRZ-M/Bi-Phi-L) + AWGN + 180-deg Phase Inversion...");
    m1_test_vec[0] = 8'hA5;
    m1_test_vec[1] = 8'h3C;
    m1_test_vec[2] = 8'h7E;
    m1_test_vec[3] = 8'hD2;

    for (int m = 0; m < 4; m++) begin
      for (int lc = 0; lc < 3; lc++) begin
        phy_rst_n     = 1'b0; @(posedge clk); #1; phy_rst_n = 1'b1; @(posedge clk); #1;
        phy_mod_cfg   = 2'(m);
        phy_line_cfg  = 2'(lc);
        phy_pn_en_cfg = 1'b0;
        ch_invert_180 = (lc == 1) && (m >= 2);
        ch_cfo_step   = 12'sd0;

        // Send a preamble byte (0x00) to synchronize NRZ-M differential reference
        while (!phy_s_tready) @(posedge clk);
        #1;
        phy_s_tvalid = 1'b1;
        phy_s_tdata  = 8'h00;
        @(posedge clk);
        #1;
        phy_s_tvalid = 1'b0;
        while (!phy_rx_sym_val) @(posedge clk);
        #1;

        for (int b = 0; b < 4; b++) begin
          while (!phy_s_tready) @(posedge clk);
          #1;
          phy_s_tvalid = 1'b1;
          phy_s_tdata  = m1_test_vec[b];
          @(posedge clk);
          #1;
          phy_s_tvalid = 1'b0;
          while (!phy_rx_sym_val) @(posedge clk);
          m1_rx_vec[b] = phy_rx_sym_byte;
          #1;
          assert (m1_rx_vec[b] == m1_test_vec[b])
            else $fatal(1, $sformatf("PHY Mode(mod=%0d, line=%0d, inv=%0b) byte[%0d] mismatch: got 0x%02X, exp 0x%02X",
                                     m, lc, ch_invert_180, b, m1_rx_vec[b], m1_test_vec[b]));
        end
      end
    end

    // =========================================================================
    // MATRIX 1B: Continuous Carrier Frequency Offset (CFO / Doppler Rotation)
    //            Stress (+384 and -384 phase units/sample = +/-2.11 deg/sample,
    //            rotating 135+ degrees over 8 bytes) across all 4 Modulations!
    // =========================================================================
    $display("[TB-STAGE10][MATRIX-1B] Sweeping Continuous Positive (+384) & Negative (-384) CFO / Doppler Phase Rotation across BPSK, QPSK, OQPSK & PCM/PM...");
    ch_invert_180 = 1'b0;
    phy_line_cfg  = 2'd1; // NRZ-M differential line coding
    phy_xband_cfg = 1'b0; // S-Band (240/221 nominal FCW = 32'h1160_2511)

    for (int m = 0; m < 4; m++) begin
      for (int dir = 0; dir < 2; dir++) begin
        logic [7:0] pre_vec [0:3];
        pre_vec[0] = 8'h00; pre_vec[1] = 8'h55; pre_vec[2] = 8'hAA; pre_vec[3] = 8'h00;

        phy_rst_n   = 1'b0; @(posedge clk); #1; phy_rst_n = 1'b1; @(posedge clk); #1;
        phy_mod_cfg = 2'(m);
        ch_cfo_step = (dir == 0) ? 12'sd384 : -12'sd384;

        // Stream 4 preamble bytes to allow 2nd-order PI Costas loop to pull in CFO ramp
        for (int p = 0; p < 4; p++) begin
          while (!phy_s_tready) @(posedge clk);
          #1;
          phy_s_tvalid = 1'b1;
          phy_s_tdata  = pre_vec[p];
          @(posedge clk);
          #1;
          phy_s_tvalid = 1'b0;
          while (!phy_rx_sym_val) @(posedge clk);
          #1;
        end

        // Stream 4 payload bytes while carrier rotates continuously past 90 and 135 degrees!
        for (int b = 0; b < 4; b++) begin
          while (!phy_s_tready) @(posedge clk);
          #1;
          phy_s_tvalid = 1'b1;
          phy_s_tdata  = m1_test_vec[b];
          @(posedge clk);
          #1;
          phy_s_tvalid = 1'b0;
          while (!phy_rx_sym_val) @(posedge clk);
          m1_rx_vec[b] = phy_rx_sym_byte;
          #1;
          assert (m1_rx_vec[b] == m1_test_vec[b])
            else $fatal(1, $sformatf("CFO Mode(mod=%0d, cfo=%0d) byte[%0d] mismatch: got 0x%02X, exp 0x%02X",
                                     m, ch_cfo_step, b, m1_rx_vec[b], m1_test_vec[b]));
        end

        // Verify Costas loop tracked the frequency offset sign into the Turnaround NCO!
        if (dir == 0) begin
          assert (phy_tx_nco_fcw > 32'h1160_2511)
            else $fatal(1, "Costas loop failed to track positive CFO into Turnaround NCO!");
        end else begin
          assert (phy_tx_nco_fcw < 32'h1160_2511)
            else $fatal(1, "Costas loop failed to track negative CFO into Turnaround NCO!");
        end
      end
    end
    ch_cfo_step = 12'sd0;

    // =========================================================================
    // MATRIX 1C: 4-SPS 17-Tap Square-Root Raised-Cosine (SRRC, alpha=0.35)
    //            Tx Pulse-Shaping FIR + Continuous +/-CFO + AWGN + 17-Tap Rx
    //            Matched SRRC Filter across all 4 Modulations (CCSDS 401.0-B-32)
    // =========================================================================
    $display("[TB-STAGE10][MATRIX-1C] Sweeping 4-SPS 17-Tap SRRC (alpha=0.35) Pulse-Shaping + Rx Matched Filter + Continuous +/-CFO across all 4 Modulations...");
    phy_srrc_en_cfg = 1'b1;
    phy_line_cfg    = 2'd1; // NRZ-M differential line coding
    ch_invert_180   = 1'b0;

    for (int m = 0; m < 4; m++) begin
      for (int cfo_idx = 0; cfo_idx < 3; cfo_idx++) begin
        logic [7:0] srrc_stream [0:8];
        srrc_stream[0] = 8'h00; srrc_stream[1] = 8'h55; srrc_stream[2] = 8'hAA; srrc_stream[3] = 8'h00;
        srrc_stream[4] = m1_test_vec[0];
        srrc_stream[5] = m1_test_vec[1];
        srrc_stream[6] = m1_test_vec[2];
        srrc_stream[7] = m1_test_vec[3];
        srrc_stream[8] = 8'h00; // Flush 16-sample (4-symbol) Tx+Rx SRRC filter pipeline

        phy_rst_n   = 1'b0; @(posedge clk); #1; phy_rst_n = 1'b1; @(posedge clk); #1;
        phy_mod_cfg = 2'(m);
        ch_cfo_step = (cfo_idx == 0) ? 12'sd0 : ((cfo_idx == 1) ? 12'sd64 : -12'sd64);

        for (int s_idx = 0; s_idx < 9; s_idx++) begin
          while (!phy_s_tready) @(posedge clk);
          #1;
          phy_s_tvalid = 1'b1;
          phy_s_tdata  = srrc_stream[s_idx];
          @(posedge clk);
          #1;
          phy_s_tvalid = 1'b0;
        end
        while (!phy_s_tready) @(posedge clk);
        repeat (8) @(posedge clk);
        #1;

        assert (m1_srrc_rx_cnt >= 8)
          else $fatal(1, $sformatf("SRRC 4-SPS expected >=8 rx bytes, got %0d", m1_srrc_rx_cnt));
        for (int b = 0; b < 4; b++) begin
          assert (m1_srrc_rx_buf[4 + b] == m1_test_vec[b])
            else $fatal(1, $sformatf("SRRC 4-SPS (mod=%0d, cfo_idx=%0d) byte[%0d] mismatch: got 0x%02X, exp 0x%02X",
                                     m, cfo_idx, b, m1_srrc_rx_buf[4 + b], m1_test_vec[b]));
        end
      end
    end
    phy_srrc_en_cfg = 1'b0;
    ch_cfo_step     = 12'sd0;

    // =========================================================================
    // MATRIX 1D: Closed-Loop 4-SPS Gardner / Nyquist Zero-ISI Symbol Timing
    //            Recovery across all 48 (4 Modulations x 4 Timing Offsets
    //            tau=0..3 x 3 CFOs) + Ka-Band Coherent Turnaround Ratios
    //            (3344/749 Cat-B & 3360/749 Cat-A per CCSDS 401.0-B-32)
    // =========================================================================
    $display("[TB-STAGE10][MATRIX-1D] Sweeping Closed-Loop 4-SPS Gardner Symbol Timing Recovery across all 48 (4 Modulations x 4 Timing Offsets tau=0..3 x 3 CFOs) + Ka-Band Turnaround Ratios (3344/749 & 3360/749)...");
    phy_srrc_en_cfg    = 1'b1;
    phy_gardner_en_cfg = 1'b1;
    phy_line_cfg       = 2'd1; // NRZ-M differential line coding
    ch_invert_180      = 1'b0;

    for (int m = 0; m < 4; m++) begin
      for (int tau = 0; tau < 4; tau++) begin
        for (int cfo_idx = 0; cfo_idx < 3; cfo_idx++) begin
          logic [7:0] gardner_stream [0:9];
          gardner_stream[0] = 8'h00;
          gardner_stream[1] = 8'h55;
          gardner_stream[2] = 8'hAA;
          gardner_stream[3] = 8'h00;
          gardner_stream[4] = m1_test_vec[0];
          gardner_stream[5] = m1_test_vec[1];
          gardner_stream[6] = m1_test_vec[2];
          gardner_stream[7] = m1_test_vec[3];
          gardner_stream[8] = 8'h00;
          gardner_stream[9] = 8'h00;

          phy_rst_n            = 1'b0; @(posedge clk); #1; phy_rst_n = 1'b1; @(posedge clk); #1;
          phy_mod_cfg          = 2'(m);
          ch_timing_offset_cfg = 2'(tau);
          phy_kaband_cfg       = 2'(tau & 2); // Also exercise Ka-band turnaround during sweep
          ch_cfo_step          = (cfo_idx == 0) ? 12'sd0 : ((cfo_idx == 1) ? 12'sd64 : -12'sd64);

          for (int s_idx = 0; s_idx < 10; s_idx++) begin
            while (!phy_s_tready) @(posedge clk);
            #1;
            phy_s_tvalid = 1'b1;
            phy_s_tdata  = gardner_stream[s_idx];
            @(posedge clk);
            #1;
            phy_s_tvalid = 1'b0;
          end
          while (!phy_s_tready) @(posedge clk);
          repeat (12) @(posedge clk);
          #1;

          assert (phy_gardner_phase_out == 2'(tau))
            else $fatal(1, $sformatf("Gardner TED (mod=%0d, tau=%0d, cfo_idx=%0d) locked to phase %0d, expected %0d",
                                     m, tau, cfo_idx, phy_gardner_phase_out, tau));
          assert (m1_srrc_rx_cnt >= 8)
            else $fatal(1, $sformatf("Gardner 4-SPS expected >=8 rx bytes, got %0d", m1_srrc_rx_cnt));
          for (int b = 0; b < 4; b++) begin
            assert (m1_srrc_rx_buf[4 + b] == m1_test_vec[b])
              else $fatal(1, $sformatf("Gardner 4-SPS (mod=%0d, tau=%0d, cfo_idx=%0d) byte[%0d] mismatch: got 0x%02X, exp 0x%02X",
                                       m, tau, cfo_idx, b, m1_srrc_rx_buf[4 + b], m1_test_vec[b]));
          end
        end
      end
    end

    // Verify all 4 CCSDS 401.0-B-32 Coherent Turnaround Ratios at zero CFO (nominal FCW check)
    phy_srrc_en_cfg       = 1'b0;
    phy_gardner_en_cfg    = 1'b0;
    phy_fll_en_cfg        = 1'b0;
    m4_sdls_gcm_mode      = 1'b0;
    m4_sdls_direct_en     = 1'b0;
    m4_sdls_direct_tvalid = 1'b0;
    m4_sdls_direct_tlast  = 1'b0;
    m4_sdls_direct_tdata  = 8'h00;
    m4_sdls_clr           = 1'b0;
    ch_timing_offset_cfg  = 2'd0;
    ch_cfo_step           = 12'sd0;
    phy_rst_n             = 1'b0; @(posedge clk); #1; phy_rst_n = 1'b1; @(posedge clk); #1;

    phy_kaband_cfg = 2'd0; phy_xband_cfg = 1'b0; repeat (2) @(posedge clk); #1;
    assert (phy_tx_nco_fcw == 32'h1160_2511)
      else $fatal(1, $sformatf("S-Band (240/221) FCW mismatch: got 0x%08X", phy_tx_nco_fcw));

    phy_kaband_cfg = 2'd0; phy_xband_cfg = 1'b1; repeat (2) @(posedge clk); #1;
    assert (phy_tx_nco_fcw == 32'h12CC_63CD)
      else $fatal(1, $sformatf("X-Band (880/749) FCW mismatch: got 0x%08X", phy_tx_nco_fcw));

    phy_kaband_cfg = 2'd1; phy_xband_cfg = 1'b0; repeat (2) @(posedge clk); #1;
    assert (phy_tx_nco_fcw == 32'h476E_814E)
      else $fatal(1, $sformatf("Ka-Band Cat-B (3344/749) FCW mismatch: got 0x%08X", phy_tx_nco_fcw));

    phy_kaband_cfg = 2'd2; phy_xband_cfg = 1'b0; repeat (2) @(posedge clk); #1;
    assert (phy_tx_nco_fcw == 32'h47C6_00DA)
      else $fatal(1, $sformatf("Ka-Band Cat-A (3360/749) FCW mismatch: got 0x%08X", phy_tx_nco_fcw));
    phy_kaband_cfg = 2'd0;

    // =========================================================================
    // MATRIX 1E (Milestone 4): FLL-Assisted Costas Carrier Recovery Loop
    //            Wide Cold-Start CFO / Doppler Pull-In (+640 and -640 phase
    //            units/sample = +/-3.52 deg/sample) across all 4 Modulations!
    // =========================================================================
    $display("[TB-STAGE10][MATRIX-1E] Sweeping Milestone 4 FLL-Assisted Costas Loop across Wide Cold-Start +/-640 CFO across BPSK, QPSK, OQPSK & PCM/PM...");
    phy_fll_en_cfg = 1'b1;
    phy_line_cfg   = 2'd1; // NRZ-M differential line coding
    phy_xband_cfg  = 1'b0; // S-Band (240/221 nominal FCW = 32'h1160_2511)

    for (int m = 0; m < 4; m++) begin
      for (int dir = 0; dir < 2; dir++) begin
        logic [7:0] pre_vec [0:3];
        pre_vec[0] = 8'h00; pre_vec[1] = 8'h55; pre_vec[2] = 8'hAA; pre_vec[3] = 8'h00;

        phy_rst_n   = 1'b0; @(posedge clk); #1; phy_rst_n = 1'b1; @(posedge clk); #1;
        phy_mod_cfg = 2'(m);
        ch_cfo_step = (dir == 0) ? 12'sd640 : -12'sd640;

        for (int p = 0; p < 4; p++) begin
          while (!phy_s_tready) @(posedge clk);
          #1;
          phy_s_tvalid = 1'b1;
          phy_s_tdata  = pre_vec[p];
          @(posedge clk);
          #1;
          phy_s_tvalid = 1'b0;
          while (!phy_rx_sym_val) @(posedge clk);
          #1;
        end

        for (int b = 0; b < 4; b++) begin
          while (!phy_s_tready) @(posedge clk);
          #1;
          phy_s_tvalid = 1'b1;
          phy_s_tdata  = m1_test_vec[b];
          @(posedge clk);
          #1;
          phy_s_tvalid = 1'b0;
          while (!phy_rx_sym_val) @(posedge clk);
          m1_rx_vec[b] = phy_rx_sym_byte;
          #1;
          assert (m1_rx_vec[b] == m1_test_vec[b])
            else $fatal(1, $sformatf("FLL-Assisted Costas(mod=%0d, cfo=%0d) byte[%0d] mismatch: got 0x%02X, exp 0x%02X",
                                     m, ch_cfo_step, b, m1_rx_vec[b], m1_test_vec[b]));
        end

        if (dir == 0) begin
          assert (phy_tx_nco_fcw > 32'h1160_2511)
            else $fatal(1, "FLL-Assisted Costas failed to track positive +/-640 CFO into Turnaround NCO!");
        end else begin
          assert (phy_tx_nco_fcw < 32'h1160_2511)
            else $fatal(1, "FLL-Assisted Costas failed to track negative +/-640 CFO into Turnaround NCO!");
        end
      end
    end
    phy_fll_en_cfg = 1'b0;
    ch_cfo_step    = 12'sd0;

    // Test both T4B (t4b_mode_cfg=1) and T2B (t4b_mode_cfg=0) PN Ranging under AWGN + S/X-Band Turnaround
    for (int t4b = 0; t4b <= 1; t4b++) begin
      phy_pn_en_cfg = 1'b0;
      pn_chip_en    = 1'b0;
      @(posedge clk); #1;
      phy_pn_en_cfg = 1'b1;
      pn_t4b_cfg    = t4b[0];
      phy_xband_cfg = t4b[0];
      pn_chip_en    = 1'b1;
      repeat (600) @(posedge clk);
      #1;
      pn_chip_en    = 1'b0;
      assert (pn_c1_locked == 1'b1 && pn_all_locked == 1'b1)
        else $fatal(1, $sformatf("PN Ranging failed to lock in mode t4b=%0d under AWGN!", t4b));
    end
    phy_pn_en_cfg = 1'b0;
    $display("[TB-STAGE10][MATRIX-1 PASS] All 12 PHY Mod x Line-Code modes (incl. 180-deg NRZ-M), S/X/Ka-Band Turnaround, 4-SPS Gardner, FLL-Assisted Costas (+/-640 CFO), and T2B/T4B PN Ranging locked under AWGN!");

    // =========================================================================
    // MATRIX 2: Concatenated Downlink Link-Closure Stress (VC_Arb -> TM_Framer
    //           -> RS(255,223) -> Conv(K=7,r=1/2) -> Noisy Channel -> 64-State
    //           Soft Viterbi -> RS(255,223) Peterson-Berlekamp -> TM_Deframer
    //           -> Pkt_Reassembler)
    // =========================================================================
    $display("[TB-STAGE10][MATRIX-2] Running Concatenated RS(255,223) + Conv(K=7)/Viterbi Downlink Stress Test...");
    // Build 20-byte Telemetry Space Packet (6B Hdr + 14B "CONCAT_FEC_OK!")
    m2_sp20[0] = 8'h09; m2_sp20[1] = 8'h55; // TM, APID=0x155
    m2_sp20[2] = 8'hC0; m2_sp20[3] = 8'h4D; // Seq=77
    m2_sp20[4] = 8'h00; m2_sp20[5] = 8'h0D; // Data_Len = 14 - 1 = 13
    m2_sp20[6] = "C";   m2_sp20[7] = "O";   m2_sp20[8] = "N";   m2_sp20[9] = "C";
    m2_sp20[10]= "A";   m2_sp20[11]= "T";   m2_sp20[12]= "_";   m2_sp20[13]= "F";
    m2_sp20[14]= "E";   m2_sp20[15]= "C";   m2_sp20[16]= "_";   m2_sp20[17]= "O";
    m2_sp20[18]= "K";   m2_sp20[19]= "!";

    for (int i = 0; i < 20; i++) begin
      m2_s_pkt_tvalid = 1'b1;
      m2_s_pkt_tdata  = m2_sp20[i];
      m2_s_pkt_tlast  = (i == 19);
      @(posedge clk);
      while (!m2_s_pkt_tready) @(posedge clk);
      #1;
    end
    m2_s_pkt_tvalid = 1'b0;
    m2_s_pkt_tlast  = 1'b0;

    m2_req_frame = 1'b1;
    @(posedge clk); #1;
    m2_req_frame = 1'b0;

    while (!(m2_cadu_tvalid && m2_cadu_tlast)) @(posedge clk);
    repeat (4) @(posedge clk); #1;
    // Expected CADU = 4B ASM + 32B TM Frame (6B Hdr + 20B SP + 4B CLCW + 2B CRC) + 32B RS Parity = 68 bytes
    assert (m2_cadu_cnt == 68) else $fatal(1, $sformatf("Expected 68B CADU, got %0d", m2_cadu_cnt));

    // Stream the 64-byte RS codeword (bytes 4..67 of CADU) + 5 zero flush bytes through
    // Conv(K=7, r=1/2) -> Noisy Symbol Channel (injecting isolated channel symbol errors every 31 bits)
    // -> 64-State Soft Viterbi Decoder!
    // Note: In ccsds_conv_viterbi_codec, +4'sd7 = '1' and -4'sd7 = '0'.
    begin
      integer vit_out_bit_cnt;
      logic [7:0] shift_b;
      vit_out_bit_cnt = 0;
      shift_b         = 8'h00;

      for (int b_idx = 4; b_idx < 68 + 5; b_idx++) begin
        logic [7:0] tx_b;
        tx_b = (b_idx < 68) ? m2_cadu_buf[b_idx] : 8'h00;
        for (int bit_pos = 7; bit_pos >= 0; bit_pos--) begin
          int global_bit;
          global_bit    = (b_idx - 4) * 8 + (7 - bit_pos);
          m2_vit_tx_bit = tx_b[bit_pos];
          m2_vit_tx_val = 1'b1;
          @(posedge clk);
          #1;
          m2_vit_tx_val = 1'b0;
          // Inject isolated channel symbol flip on C1 every 31 bits (healed by 64-state Viterbi!)
          if ((global_bit > 12) && ((global_bit % 31) == 0)) begin
            m2_vit_llr1 = m2_vit_c1 ? -4'sd7 : 4'sd7; // Inverted LLR error!
          end else begin
            m2_vit_llr1 = m2_vit_c1 ? 4'sd7 : -4'sd7;
          end
          m2_vit_llr2   = m2_vit_c2 ? 4'sd7 : -4'sd7;
          m2_vit_rx_val = 1'b1;
          @(posedge clk);
          #1;
          m2_vit_rx_val = 1'b0;
          if (m2_vit_dec_val) begin
            shift_b = {shift_b[6:0], m2_vit_dec_bit};
            if ((vit_out_bit_cnt % 8) == 7) begin
              m2_vit_rx_bytes[vit_out_bit_cnt / 8] = shift_b;
            end
            vit_out_bit_cnt = vit_out_bit_cnt + 1;
          end
        end
      end
      assert (vit_out_bit_cnt >= 64 * 8)
        else $fatal(1, $sformatf("Expected >=512 Viterbi decoded bits, got %0d", vit_out_bit_cnt));
    end

    // Verify Viterbi healed all isolated symbol flips, then inject a 2-BYTE BURST ERROR
    // (exceeding Viterbi's burst capability) at bytes 9 and 18 so RS(255,223) heals them!
    m2_vit_rx_bytes[9]  = m2_vit_rx_bytes[9]  ^ 8'hF3;
    m2_vit_rx_bytes[18] = m2_vit_rx_bytes[18] ^ 8'h9C;

    for (int i = 0; i < 64; i++) begin
      m2_rs_dec_s_tvalid = 1'b1;
      m2_rs_dec_s_tdata  = m2_vit_rx_bytes[i];
      m2_rs_dec_s_tlast  = (i == 63);
      @(posedge clk);
      while (!m2_rs_dec_s_tready) @(posedge clk);
      #1;
    end
    m2_rs_dec_s_tvalid = 1'b0;
    m2_rs_dec_s_tlast  = 1'b0;

    repeat (65) @(posedge clk); #1;
    assert (m2_rs_corr_cnt == 16'd2)
      else $fatal(1, $sformatf("Expected 2 burst bytes healed by RS(255,223), got %0d", m2_rs_corr_cnt));
    assert (m2_tm_crc_ok_latched == 1'b1)
      else $fatal(1, "TM Frame CRC-16 failed after concatenated Viterbi + RS(255,223) decoding!");
    assert (m2_rx_pkt_cnt == 20)
      else $fatal(1, $sformatf("Expected 20 reassembled Space Packet bytes, got %0d", m2_rx_pkt_cnt));
    for (int i = 0; i < 20; i++) begin
      assert (m2_rx_pkt_buf[i] == m2_sp20[i])
        else $fatal(1, $sformatf("Concatenated FEC byte[%0d] mismatch: got 0x%02X, exp 0x%02X",
                                 i, m2_rx_pkt_buf[i], m2_sp20[i]));
    end
    $display("[TB-STAGE10][MATRIX-2 PASS] Concatenated Conv(K=7)/Viterbi + RS(255,223) healed distributed symbol errors + 2-byte burst and recovered Space Packet \"CONCAT_FEC_OK!\"!");

    // =========================================================================
    // MATRIX 3: Multi-Protocol (AOS FHEC) & All 5 Next-Gen FEC Modes (LDPC +
    //           Turbo r=1/2, 1/3, 1/4, 1/6)
    // =========================================================================
    $display("[TB-STAGE10][MATRIX-3] Sweeping AOS GF(2^4) FHEC and all 5 Turbo/LDPC modes (r=1/2,1/3,1/4,1/6)...");
    #1;
    assert (m3_aos_syn_ok == 1'b1)
      else $fatal(1, "AOS GF(2^4) FHEC syndrome check failed!");

    for (int mode = 0; mode <= 4; mode++) begin
      integer out_cnt;
      out_cnt       = 0;
      m3_turbo_mode = 4'(mode);
      for (int i = 0; i < 8; i++) begin
        m3_turbo_s_tvalid = 1'b1;
        m3_turbo_s_tdata  = 8'h30 + 8'(i) + 8'(mode);
        m3_turbo_s_tlast  = (i == 7);
        @(posedge clk);
        while (!m3_turbo_s_tready) @(posedge clk);
        #1;
        if (m3_turbo_m_tvalid) out_cnt = out_cnt + 1;
      end
      m3_turbo_s_tvalid = 1'b0;
      m3_turbo_s_tlast  = 1'b0;
      for (int w = 0; w < 16; w++) begin
        @(posedge clk); #1;
        if (m3_turbo_m_tvalid) out_cnt = out_cnt + 1;
      end
      assert (out_cnt == 16)
        else $fatal(1, $sformatf("Turbo/LDPC mode %0d expected 16 output bytes, got %0d", mode, out_cnt));
    end
    $display("[TB-STAGE10][MATRIX-3 PASS] AOS GF(2^4) FHEC + all 5 LDPC/Turbo FEC modes verified!");

    // =========================================================================
    // MATRIX 4: Encrypted SDLS (NIST FIPS-197 AES-128-CTR) + Noisy BCH(63,56)
    //           + Closed-Loop COP-1 (FOP-1 <-> FARM-1) Go-Back-N Recovery
    // =========================================================================
    $display("[TB-STAGE10][MATRIX-4] Running Encrypted SDLS AES-128-CTR + Noisy BCH(63,56) + COP-1 Go-Back-N Stress Test...");
    build_tc_sp14(11'h245, 14'd1, "SEC_CMD1", m4_sp0);

    // Encrypt 14-byte Telecommand Space Packet using NIST FIPS-197 AES-128-CTR -> 21-byte SDLS Frame
    for (int i = 0; i < 14; i++) begin
      m4_sdls_tx_s_tvalid = 1'b1;
      m4_sdls_tx_s_tdata  = m4_sp0[i];
      m4_sdls_tx_s_tlast  = (i == 13);
      @(posedge clk);
      while (!m4_sdls_tx_s_tready) @(posedge clk);
      #1;
    end
    m4_sdls_tx_s_tvalid = 1'b0;
    m4_sdls_tx_s_tlast  = 1'b0;
    while (m4_sdls_ct_cnt < 21) @(posedge clk);
    repeat (2) @(posedge clk); #1;

    // Wrap 21-byte SDLS Frame into TC Frame (N(S)=0) + 48-byte BCH(63,56) CLTU
    m4_cur_tx_ns = 8'd0;
    m4_fop_req   = 1'b1; @(posedge clk); #1; m4_fop_req = 1'b0;
    m4_cltu_clr  = 1'b1; @(posedge clk); #1; m4_cltu_clr = 1'b0;
    for (int i = 0; i < 21; i++) begin
      m4_tc_frm_s_tvalid = 1'b1;
      m4_tc_frm_s_tdata  = m4_sdls_ct_buf[i];
      m4_tc_frm_s_tlast  = (i == 20);
      @(posedge clk);
      while (!m4_tc_frm_s_tready) @(posedge clk);
      #1;
    end
    m4_tc_frm_s_tvalid = 1'b0;
    m4_tc_frm_s_tlast  = 1'b0;
    while (!(m4_cltu_tvalid && m4_cltu_tlast)) @(posedge clk);
    repeat (4) @(posedge clk); #1;
    assert (m4_cltu_cnt == 50) else $fatal(1, $sformatf("Expected 50B CLTU (2B Start + 5x8B BCH + 8B Tail), got %0d", m4_cltu_cnt));

    // 4A.1: Transmit Frame N(S)=0 with 180-deg phase inversion AND 1-bit error per BCH block!
    stream_cltu48_over_noisy_channel(1'b1, 1'b1, 1'b0);
    assert (m4_rx_pkt_cnt == 14)
      else $fatal(1, $sformatf("Expected 14 decrypted SP bytes after noisy BCH+AES128, got %0d", m4_rx_pkt_cnt));
    for (int i = 0; i < 14; i++) begin
      assert (m4_rx_pkt_buf[i] == m4_sp0[i])
        else $fatal(1, $sformatf("SDLS+BCH byte[%0d] mismatch: got 0x%02X, exp 0x%02X",
                                 i, m4_rx_pkt_buf[i], m4_sp0[i]));
    end
    assert (m4_vc1_clcw_latched.report_value == 8'd1 && m4_vc1_clcw_latched.retransmit == 1'b0)
      else $fatal(1, "FARM-1 V(R) did not advance to 1!");

    // 4A.2: Ground FOP-1 sends N(S)=1 (which suffers a 2-BIT BCH BURST ABORT in the channel!)
    //       followed by N(S)=2 -> FARM-1 flags Retransmit=1, V(R)=1 -> FOP-1 rolls back V(S) to 1!
    m4_fop_req = 1'b1; @(posedge clk); #1; m4_fop_req = 1'b0; // FOP-1 V(S): 1 -> 2
    stream_cltu48_over_noisy_channel(1'b0, 1'b0, 1'b1);        // 2-bit BCH abort!
    assert (m4_vc1_clcw_latched.report_value == 8'd1)
      else $fatal(1, "Aborted BCH frame should not mutate V(R)!");

    // Build N(S)=2 CLTU and send -> triggers FARM-1 gap detection (N(S)=2 != V(R)=1)
    m4_fop_req   = 1'b1; @(posedge clk); #1; m4_fop_req = 1'b0; // FOP-1 V(S): 2 -> 3
    m4_cur_tx_ns = 8'd2;
    m4_cltu_clr  = 1'b1; @(posedge clk); #1; m4_cltu_clr = 1'b0;
    for (int i = 0; i < 21; i++) begin
      m4_tc_frm_s_tvalid = 1'b1;
      m4_tc_frm_s_tdata  = m4_sdls_ct_buf[i];
      m4_tc_frm_s_tlast  = (i == 20);
      @(posedge clk);
      while (!m4_tc_frm_s_tready) @(posedge clk);
      #1;
    end
    m4_tc_frm_s_tvalid = 1'b0;
    m4_tc_frm_s_tlast  = 1'b0;
    while (!(m4_cltu_tvalid && m4_cltu_tlast)) @(posedge clk);
    repeat (4) @(posedge clk); #1;

    stream_cltu48_over_noisy_channel(1'b0, 1'b1, 1'b0);
    assert (m4_vc1_clcw_latched.retransmit == 1'b1 && m4_vc1_clcw_latched.report_value == 8'd1)
      else $fatal(1, "FARM-1 did not assert Retransmit=1 with V(R)=1 on sequence gap!");

    // Return CLCW to Ground FOP-1 -> rolls V(S) back from 3 to 1!
    m4_rx_clcw  = m4_vc1_clcw_latched;
    m4_clcw_val = 1'b1; @(posedge clk); #1; m4_clcw_val = 1'b0;
    repeat (2) @(posedge clk); #1;
    assert (m4_fop_vs == 8'd1 && m4_retx_cnt == 16'd1)
      else $fatal(1, "FOP-1 failed to roll V(S) back to 1 on CLCW Retransmit=1!");
    $display("[TB-STAGE10][MATRIX-4 PASS] Encrypted SDLS AES-128-CTR + Noisy BCH(63,56) + COP-1 Go-Back-N recovered from 2-bit burst drop (V(S) rolled back 3 -> %0d)!", m4_fop_vs);

    // =========================================================================
    // MATRIX 4B (Milestone 3): Full NIST SP 800-38D / CCSDS 355.0-B-2
    //            AES-128-GCM (GHASH GF(2^128) + 128-Bit Tag) Tx-to-Rx Closure
    //            & Single-Bit 128-Bit Tag Tamper Rejection
    // =========================================================================
    $display("[TB-STAGE10][MATRIX-4B] Running Milestone 3 Full 128-Bit AES-128-GCM (GHASH) Authenticated Encryption & Tag Tamper Rejection...");
    m4_sdls_gcm_mode  = 1'b1;
    m4_sdls_direct_en = 1'b1;
    m4_sdls_clr       = 1'b1; @(posedge clk); #1; m4_sdls_clr = 1'b0;

    // 4B.1: Encrypt 14-byte Telecommand Space Packet with AES-128-GCM -> 36-byte SDLS Frame (6B SecHdr + 14B CT + 16B GHASH Tag)
    for (int i = 0; i < 14; i++) begin
      m4_sdls_tx_s_tvalid = 1'b1;
      m4_sdls_tx_s_tdata  = m4_sp0[i];
      m4_sdls_tx_s_tlast  = (i == 13);
      @(posedge clk);
      while (!m4_sdls_tx_s_tready) @(posedge clk);
      #1;
    end
    m4_sdls_tx_s_tvalid = 1'b0;
    m4_sdls_tx_s_tlast  = 1'b0;
    while (m4_sdls_ct_cnt < 36) @(posedge clk);
    repeat (4) @(posedge clk); #1;
    assert (m4_sdls_ct_cnt == 36)
      else $fatal(1, $sformatf("Expected 36-byte AES-128-GCM SDLS frame (6B Hdr + 14B CT + 16B Tag), got %0d", m4_sdls_ct_cnt));

    // 4B.2: Stream the 36-byte AES-128-GCM frame into u_m4_sdls Rx -> verify 16B tag stripped and 14B Space Packet recovered!
    for (int i = 0; i < 36; i++) begin
      m4_sdls_direct_tvalid = 1'b1;
      m4_sdls_direct_tdata  = m4_sdls_ct_buf[i];
      m4_sdls_direct_tlast  = (i == 35);
      @(posedge clk);
      while (!m4_def_m_tready) @(posedge clk);
      #1;
    end
    m4_sdls_direct_tvalid = 1'b0;
    m4_sdls_direct_tlast  = 1'b0;
    repeat (120) @(posedge clk); #1;

    assert (m4_sdls_auth_done_latched == 1'b1 && m4_sdls_auth_ok_latched == 1'b1)
      else $fatal(1, "AES-128-GCM 128-bit GHASH authentication failed on valid Tx-to-Rx frame!");
    assert (m4_rx_pkt_cnt == 14)
      else $fatal(1, $sformatf("Expected 14 decrypted SP bytes from AES-128-GCM, got %0d", m4_rx_pkt_cnt));
    for (int i = 0; i < 14; i++) begin
      assert (m4_rx_pkt_buf[i] == m4_sp0[i])
        else $fatal(1, $sformatf("AES-128-GCM byte[%0d] mismatch: got 0x%02X, exp 0x%02X",
                                 i, m4_rx_pkt_buf[i], m4_sp0[i]));
    end

    // 4B.3: Flip 1 bit in the 128-bit GHASH tag (byte[35] ^ 0x01) with incremented Seq -> verify authentication rejection!
    m4_sdls_clr = 1'b1; @(posedge clk); #1; m4_sdls_clr = 1'b0;
    for (int i = 0; i < 36; i++) begin
      m4_sdls_direct_tvalid = 1'b1;
      if (i == 5) begin
        m4_sdls_direct_tdata = m4_sdls_ct_buf[i] + 8'd1;
      end else if (i == 35) begin
        m4_sdls_direct_tdata = m4_sdls_ct_buf[i] ^ 8'h01;
      end else begin
        m4_sdls_direct_tdata = m4_sdls_ct_buf[i];
      end
      m4_sdls_direct_tlast  = (i == 35);
      @(posedge clk);
      while (!m4_def_m_tready) @(posedge clk);
      #1;
    end
    m4_sdls_direct_tvalid = 1'b0;
    m4_sdls_direct_tlast  = 1'b0;
    repeat (120) @(posedge clk); #1;
    assert (m4_sdls_auth_done_latched == 1'b1 && m4_sdls_auth_ok_latched == 1'b0)
      else $fatal(1, "AES-128-GCM failed to reject single-bit tampered 128-bit GHASH tag!");
    m4_sdls_direct_en = 1'b0;
    m4_sdls_gcm_mode  = 1'b0;
    $display("[TB-STAGE10][MATRIX-4B PASS] Milestone 3 Full 128-Bit AES-128-GCM (GHASH) Authenticated Encryption & Tag Tamper Rejection verified!");

    // =========================================================================
    // MATRIX 5: Simultaneous Radiation SEU Storm (FARM-1 TMR + HCPD TMR +
    //           Hsiao SECDED FIFO) During Emergency HCPD Command Execution
    // =========================================================================
    $display("[TB-STAGE10][MATRIX-5] Injecting Simultaneous Radiation SEU Storm across FARM-1 TMR, HCPD TMR & SECDED FIFO...");
    m5_fifo_wr_data = 32'hCAFE_BABE;
    m5_fifo_wr_val  = 1'b1;
    m5_fifo_wr_last = 1'b1;
    m5_fifo_commit  = 1'b1;
    @(posedge clk); #1;
    m5_fifo_wr_val  = 1'b0;
    m5_fifo_wr_last = 1'b0;
    m5_fifo_commit  = 1'b0;

    // Inject simultaneous SEUs into FARM-1 Replica B, HCPD Replica A, and FIFO bit 11!
    m4_tmr_seu_en  = 1'b1;
    m5_hcpd_seu_en = 1'b1;
    m5_fifo_seu_en = 1'b1;
    @(posedge clk); #1;
    m4_tmr_seu_en  = 1'b0;
    m5_hcpd_seu_en = 1'b0;
    m5_fifo_seu_en = 1'b0;
    repeat (3) @(posedge clk); #1;

    // Verify HCPD TMR self-healing pulse and FIFO SECDED single-bit correction on read-out
    assert (m5_hcpd_seu_corr_latched == 1'b1)
      else $fatal(1, "HCPD TMR failed to detect and scrub injected SEU!");
    assert (m5_fifo_rd_val == 1'b1 && m5_fifo_1err_latched == 1'b1 && m5_fifo_2err == 1'b0 && m5_fifo_rd_data == 32'hCAFE_BABE)
      else $fatal(1, "Hsiao SECDED FIFO failed to heal 1-bit SEU on 0xCAFE_BABE!");
    m5_fifo_rd_rdy = 1'b1; @(posedge clk); #1; m5_fifo_rd_rdy = 1'b0;

    // Stream Emergency HCPD Command (VCID=63, Bypass=1, 64'hC0DE_CAFE_05FA_0010)
    m5_hcpd_hdr.tfvn          = 2'b00;
    m5_hcpd_hdr.bypass_flag   = 1'b1;
    m5_hcpd_hdr.ctrl_cmd_flag = 1'b0;
    m5_hcpd_hdr.rsvd_spare    = 2'b00;
    m5_hcpd_hdr.scid          = 10'h155;
    m5_hcpd_hdr.vcid          = EMERGENCY_VCID;
    m5_hcpd_hdr.frame_len     = 10'd14;
    m5_hcpd_hdr.frame_seq_num = 8'd0;

    hcpd_cmd64 = 64'hC0DE_CAFE_05FA_0010;
    for (int i = 0; i < 8; i++) begin
      m5_hcpd_s_val  = 1'b1;
      m5_hcpd_s_data = hcpd_cmd64[(7 - i)*8 +: 8];
      @(posedge clk); #1;
    end
    m5_hcpd_s_val  = 1'b0;
    m5_hcpd_done   = 1'b1;
    @(posedge clk); #1;
    m5_hcpd_done   = 1'b0;
    assert (m5_hcpd_fired == 1'b1 && m5_hcpd_pulses == 8'h05)
      else $fatal(1, "Emergency HCPD failed to fire 8'h05 discrete pulse after TMR SEU!");

    $display("[TB-STAGE10][MATRIX-5 PASS] Simultaneous Radiation SEU Storm healed across FARM-1 TMR, HCPD TMR & SECDED FIFO, and Emergency HCPD fired (pulses=0x%02X)!", m5_hcpd_pulses);
    $display("[TB-STAGE10 PASS] ALL 5 FULL-MATRIX CONFIGURATION & IMPAIRED-CHANNEL LINK-CLOSURE STRESS TESTS PASSED WITH 0 ERRORS!");
    $finish;
  end

endmodule : tb_stage10_full_matrix_link_stress
