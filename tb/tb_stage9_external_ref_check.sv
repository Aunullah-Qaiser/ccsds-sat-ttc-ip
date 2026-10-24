//=============================================================================
// File Name   : tb_stage9_external_ref_check.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Description : Stage 9 External Reference Interoperability Testbench
//               (Verified against University of Stuttgart `spacepackets-py`,
//               PyCA `cryptography` NIST FIPS-197 AES-128, Dual-Basis RS(255,223),
//               and Official CCSDS 231.1-O-1 Table 2-1/2-4 (128,64) LDPC):
//                 - NO self-loopback (our Tx never talks to our Rx!).
//                 - Subtest 1: 42B External CLTU -> Spacecraft Flight Rx Chain.
//                 - Subtest 2: 31B External USLP Frame -> Spacecraft Flight Rx.
//                 - Subtest 3: 16B Telemetry Space Packet -> Spacecraft Tx CADU.
//                 - Subtest 4 (Step 3A): External PyCA `cryptography` AES-128-CTR
//                   <-> `ccsds_sdls_engine.sv` Uplink Decrypt, Anti-Replay &
//                   Downlink Encrypt.
//                 - Subtest 5 (Step 3B): Corrupted 60B Dual-Basis RS(255,223)
//                   Codeword (2 corrupted bytes) -> `ccsds_dl_rs255_223_dec`
//                   -> `ccsds_tm_aos_deframer` -> `ccsds_pkt_reassembler`.
//                 - Subtest 6 (Step 3C): Two Noisy 128-bit CCSDS 231.1-O-1
//                   Table 2-1/2-4 (128,64) LDPC Codeblocks (2 corrupted bits
//                   injected into EACH codeblock = 4 bit errors total) ->
//                   `ccsds_ul_short_ldpc_dec` -> `ccsds_pkt_reassembler`, plus
//                   `ccsds_dl_turbo_ldpc_enc` Table 2-1 W_64x64 encoder check.
//=============================================================================
`timescale 1ns / 1ps

module tb_stage9_external_ref_check;
  import ccsds_pkg::*;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  always #5 clk = ~clk; // 100 MHz clock

  // ===========================================================================
  // 1. Spacecraft Uplink Receiver Chain Under Test (CLTU -> BCH -> TC -> Reasm)
  // ===========================================================================
  logic signed [3:0] ul_sym_llr_in, ul_cb_llr;
  logic              ul_sym_valid_in, ul_cb_bit, ul_cb_start, ul_cb_valid;
  logic              ul_sync_locked, ul_phase_inv;
  logic              ul_cltu_ended, ul_bch_1err, ul_bch_2abort;
  logic [7:0]        ul_bch_tdata, ul_def_tdata, ul_pkt_tdata;
  logic              ul_bch_tvalid, ul_bch_tready, ul_bch_tlast, ul_bch_tabort;
  logic              ul_def_tvalid, ul_def_tready, ul_def_tlast;
  logic              ul_pkt_tvalid, ul_pkt_tlast;
  ccsds_tc_prim_hdr_t   ul_parsed_tc_hdr;
  ccsds_space_pkt_hdr_t ul_parsed_pkt_hdr;
  logic              ul_frame_done, ul_frame_crc_ok, ul_frame_commit, ul_frame_rollback;
  logic              ul_farm_accept, ul_farm_reject, ul_clcw_valid, ul_tmr_seu_corr;
  ccsds_clcw_t       ul_clcw_sched;
  logic              ul_pkt_done, ul_idle_stripped, ul_pkt_len_err;

  ccsds_asm_correlator u_ul_sync (
    .clk                 (clk),
    .rst_n               (rst_n),
    .sync_mode           (2'd0),
    .hamming_thresh      (3'd1),
    .tail_or_abort_pulse (ul_cltu_ended),
    .sym_llr_in          (ul_sym_llr_in),
    .sym_valid_in        (ul_sym_valid_in),
    .cb_llr_out          (ul_cb_llr),
    .cb_hard_bit_out     (ul_cb_bit),
    .cb_start_pulse      (ul_cb_start),
    .cb_valid_out        (ul_cb_valid),
    .sync_locked         (ul_sync_locked),
    .phase_inverted      (ul_phase_inv)
  );

  ccsds_bch6356_dec u_ul_bch_dec (
    .clk                    (clk),
    .rst_n                  (rst_n),
    .tc_derand_en           (1'b1),
    .cb_hard_bit_in         (ul_cb_bit),
    .cb_start_pulse         (ul_cb_start),
    .cb_valid_in            (ul_cb_valid),
    .cltu_ended_pulse       (ul_cltu_ended),
    .bch_single_err_pulse   (ul_bch_1err),
    .bch_double_abort_pulse (ul_bch_2abort),
    .m_axis_tdata           (ul_bch_tdata),
    .m_axis_tvalid          (ul_bch_tvalid),
    .m_axis_tready          (ul_bch_tready),
    .m_axis_tlast           (ul_bch_tlast),
    .m_axis_tabort          (ul_bch_tabort)
  );

  ccsds_tc_uslp_deframer u_ul_tc_deframer (
    .clk                      (clk),
    .rst_n                    (rst_n),
    .spacecraft_id_cfg        (10'h155),
    .uslp_scid_cfg            (16'h4255),
    .uslp_trunc_frame_len_cfg (16'd25),
    .uslp_tfdf_3byte_en_cfg   (1'b1),
    .fecf_crc32_cfg           (1'b0),
    .tc_seg_hdr_present_cfg   (1'b1),
    .s_axis_tdata             (ul_bch_tdata),
    .s_axis_tvalid            (ul_bch_tvalid),
    .s_axis_tready            (ul_bch_tready),
    .s_axis_tlast             (ul_bch_tlast),
    .s_axis_tabort            (ul_bch_tabort),
    .parsed_tc_hdr            (ul_parsed_tc_hdr),
    .parsed_tc_seg_hdr        (),
    .parsed_prox1_hdr         (),
    .parsed_uslp_trunc_hdr    (),
    .parsed_uslp_ext_hdr      (),
    .parsed_uslp_tfdf_hdr     (),
    .detected_proto_mode      (),
    .extracted_ocf_word       (),
    .extracted_ocf_valid      (),
    .frame_done_pulse         (ul_frame_done),
    .frame_crc_ok             (ul_frame_crc_ok),
    .frame_crc_err_pulse      (),
    .frame_commit_pulse       (ul_frame_commit),
    .frame_rollback_pulse     (ul_frame_rollback),
    .m_axis_tdata             (ul_def_tdata),
    .m_axis_tvalid            (ul_def_tvalid),
    .m_axis_tready            (ul_def_tready),
    .m_axis_tlast             (ul_def_tlast)
  );

  ccsds_farm1_tmr #(.NUM_VC(8)) u_ul_farm1 (
    .clk                     (clk),
    .rst_n                   (rst_n),
    .sdls_en                 (1'b0),
    .bc_require_sdls         (1'b0),
    .window_half_w           (8'd16),
    .no_rf_avail             (1'b0),
    .no_bit_lock             (1'b0),
    .rx_buffer_wait          (1'b0),
    .tmr_seu_inject_en       (1'b0),
    .tmr_seu_replica_sel     (2'd0),
    .tmr_seu_vc_sel          (3'd1),
    .tmr_seu_xor_mask        (8'h00),
    .tc_hdr_in               (ul_parsed_tc_hdr),
    .bc_cmd_byte0            (8'h00),
    .bc_cmd_byte1            (8'h00),
    .bc_cmd_byte2            (8'h00),
    .bc_cmd_len              (3'd1),
    .frame_done_pulse        (ul_frame_done),
    .frame_crc_ok            (ul_frame_crc_ok),
    .sdls_auth_ok            (1'b1),
    .farm_accept_pulse       (ul_farm_accept),
    .farm_reject_pulse       (ul_farm_reject),
    .clcw_scheduled_out      (ul_clcw_sched),
    .clcw_valid_pulse        (ul_clcw_valid),
    .tmr_seu_corrected_pulse (ul_tmr_seu_corr)
  );

  ccsds_pkt_reassembler u_ul_pkt_reasm (
    .clk                     (clk),
    .rst_n                   (rst_n),
    .fhp_resync_en           (1'b0),
    .frame_fhp_in            (11'd0),
    .frame_start_pulse       (1'b0),
    .s_axis_tdata            (ul_def_tdata),
    .s_axis_tvalid           (ul_def_tvalid),
    .s_axis_tready           (ul_def_tready),
    .s_axis_tlast            (ul_def_tlast),
    .m_axis_pkt_tdata        (ul_pkt_tdata),
    .m_axis_pkt_tvalid       (ul_pkt_tvalid),
    .m_axis_pkt_tready       (1'b1),
    .m_axis_pkt_tlast        (ul_pkt_tlast),
    .parsed_pkt_hdr          (ul_parsed_pkt_hdr),
    .pkt_completed_pulse     (ul_pkt_done),
    .idle_pkt_stripped_pulse (ul_idle_stripped),
    .pkt_len_err_pulse       (ul_pkt_len_err)
  );

  // ===========================================================================
  // 2. Spacecraft USLP Receiver Chain Under Test (USLP Deframer -> Reassembler)
  // ===========================================================================
  logic [7:0]           uslp_s_tdata, uslp_def_tdata, uslp_pkt_tdata;
  logic                 uslp_s_tvalid, uslp_s_tready;
  logic                 uslp_def_tvalid, uslp_def_tready, uslp_def_tlast;
  logic                 uslp_pkt_tvalid, uslp_pkt_tlast;
  logic [2:0]           uslp_det_proto;
  logic [31:0]          uslp_ext_ocf, uslp_ocf_latched;
  logic                 uslp_ext_ocf_valid, uslp_frame_done, uslp_frame_crc_ok;
  ccsds_space_pkt_hdr_t uslp_parsed_pkt_hdr;

  ccsds_tc_uslp_deframer u_uslp_deframer (
    .clk                      (clk),
    .rst_n                    (rst_n),
    .spacecraft_id_cfg        (10'h155),
    .uslp_scid_cfg            (16'h4255),
    .uslp_trunc_frame_len_cfg (16'd25),
    .uslp_tfdf_3byte_en_cfg   (1'b1),
    .fecf_crc32_cfg           (1'b0),
    .tc_seg_hdr_present_cfg   (1'b1),
    .s_axis_tdata             (uslp_s_tdata),
    .s_axis_tvalid            (uslp_s_tvalid),
    .s_axis_tready            (uslp_s_tready),
    .s_axis_tlast             (1'b0),
    .s_axis_tabort            (1'b0),
    .parsed_tc_hdr            (),
    .parsed_tc_seg_hdr        (),
    .parsed_prox1_hdr         (),
    .parsed_uslp_trunc_hdr    (),
    .parsed_uslp_ext_hdr      (),
    .parsed_uslp_tfdf_hdr     (),
    .detected_proto_mode      (uslp_det_proto),
    .extracted_ocf_word       (uslp_ext_ocf),
    .extracted_ocf_valid      (uslp_ext_ocf_valid),
    .frame_done_pulse         (uslp_frame_done),
    .frame_crc_ok             (uslp_frame_crc_ok),
    .frame_crc_err_pulse      (),
    .frame_commit_pulse       (),
    .frame_rollback_pulse     (),
    .m_axis_tdata             (uslp_def_tdata),
    .m_axis_tvalid            (uslp_def_tvalid),
    .m_axis_tready            (uslp_def_tready),
    .m_axis_tlast             (uslp_def_tlast)
  );

  ccsds_pkt_reassembler u_uslp_pkt_reasm (
    .clk                     (clk),
    .rst_n                   (rst_n),
    .fhp_resync_en           (1'b0),
    .frame_fhp_in            (11'd0),
    .frame_start_pulse       (1'b0),
    .s_axis_tdata            (uslp_def_tdata),
    .s_axis_tvalid           (uslp_def_tvalid),
    .s_axis_tready           (uslp_def_tready),
    .s_axis_tlast            (uslp_def_tlast),
    .m_axis_pkt_tdata        (uslp_pkt_tdata),
    .m_axis_pkt_tvalid       (uslp_pkt_tvalid),
    .m_axis_pkt_tready       (1'b1),
    .m_axis_pkt_tlast        (uslp_pkt_tlast),
    .parsed_pkt_hdr          (uslp_parsed_pkt_hdr),
    .pkt_completed_pulse     (),
    .idle_pkt_stripped_pulse (),
    .pkt_len_err_pulse       ()
  );

  // ===========================================================================
  // 3. Spacecraft Downlink Transmitter Chain Under Test (VC_Arb -> TM -> RS)
  // ===========================================================================
  logic        dl_req_next_frame;
  logic [7:0]  dl_s_pkt_tdata, dl_tfdf_tdata, dl_tm_frm_tdata, dl_cadu_tdata;
  logic        dl_s_pkt_tvalid, dl_s_pkt_tready, dl_s_pkt_tlast;
  logic        dl_tfdf_tvalid, dl_tfdf_tready, dl_tfdf_tlast, dl_tfdf_is_oid;
  logic [2:0]  dl_tfdf_vcid;
  logic [10:0] dl_tfdf_fhp;
  logic        dl_tm_frm_tvalid, dl_tm_frm_tready, dl_tm_frm_tlast;
  logic        dl_cadu_tvalid, dl_cadu_tlast;
  logic        dl_pkt_len_err;
  logic [15:0] dl_conv_sym_unused;
  logic        dl_conv_val_unused;

  ccsds_vc_arbiter_mux #(.NUM_VC(8)) u_dl_vc_arb (
    .clk                 (clk),
    .rst_n               (rst_n),
    .tfdf_byte_len_cfg   (11'd16),
    .request_next_frame  (dl_req_next_frame),
    .s_axis_pkt_tdata    (dl_s_pkt_tdata),
    .s_axis_pkt_vcid     (3'd1),
    .s_axis_pkt_tvalid   (dl_s_pkt_tvalid),
    .s_axis_pkt_tready   (dl_s_pkt_tready),
    .s_axis_pkt_tlast    (dl_s_pkt_tlast),
    .m_axis_tfdf_tdata   (dl_tfdf_tdata),
    .m_axis_tfdf_tvalid  (dl_tfdf_tvalid),
    .m_axis_tfdf_tready  (dl_tfdf_tready),
    .m_axis_tfdf_tlast   (dl_tfdf_tlast),
    .m_axis_tfdf_vcid    (dl_tfdf_vcid),
    .m_axis_tfdf_fhp     (dl_tfdf_fhp),
    .m_axis_tfdf_is_oid  (dl_tfdf_is_oid),
    .irq_obc_pkt_len_err (dl_pkt_len_err)
  );

  ccsds_tm_aos_uslp_framer #(.NUM_VC(8)) u_dl_tm_framer (
    .clk                   (clk),
    .rst_n                 (rst_n),
    .spacecraft_id_cfg     (10'h155),
    .ocf_en_cfg            (1'b1),
    .fecf_en_cfg           (1'b1),
    .clcw_mbox_in          (32'h0104_0001),
    .proto_mode_cfg        (PROTO_TM),
    .aos_fhec_en_cfg       (1'b0),
    .uslp_scid_cfg         (16'h4255),
    .uslp_trunc_mode_cfg   (1'b0),
    .uslp_vcf_cnt_len_cfg  (3'd1),
    .uslp_upid_cfg         (5'd1),
    .fecf_crc32_cfg        (1'b0),
    .tfdf_byte_len_cfg     (11'd16),
    .obt_sec_hdr_en_cfg    (1'b0),
    .obt_cuc_timestamp_48b (48'h6530_0042_8000),
    .s_axis_tfdf_tdata     (dl_tfdf_tdata),
    .s_axis_tfdf_tvalid    (dl_tfdf_tvalid),
    .s_axis_tfdf_tready    (dl_tfdf_tready),
    .s_axis_tfdf_tlast     (dl_tfdf_tlast),
    .s_axis_tfdf_vcid      (dl_tfdf_vcid),
    .s_axis_tfdf_fhp       (dl_tfdf_fhp),
    .m_axis_frame_tdata    (dl_tm_frm_tdata),
    .m_axis_frame_tvalid   (dl_tm_frm_tvalid),
    .m_axis_frame_tready   (dl_tm_frm_tready),
    .m_axis_frame_tlast    (dl_tm_frm_tlast)
  );

  ccsds_dl_rs255_223_enc u_dl_rs_enc (
    .clk                (clk),
    .rst_n              (rst_n),
    .interleave_depth_i (4'd1),
    .tm_rand_en         (1'b1),
    .conv_enc_en        (1'b0),
    .s_axis_tdata       (dl_tm_frm_tdata),
    .s_axis_tvalid      (dl_tm_frm_tvalid),
    .s_axis_tready      (dl_tm_frm_tready),
    .s_axis_tlast       (dl_tm_frm_tlast),
    .m_axis_cadu_tdata  (dl_cadu_tdata),
    .m_axis_cadu_tvalid (dl_cadu_tvalid),
    .m_axis_cadu_tready (1'b1),
    .m_axis_cadu_tlast  (dl_cadu_tlast),
    .conv_symbols_out   (dl_conv_sym_unused),
    .conv_symbols_valid (dl_conv_val_unused)
  );

  // ===========================================================================
  // 4. Step 3A: NIST FIPS-197 AES-128-CTR SDLS Engine Under Test (`u_sdls_dut`)
  // ===========================================================================
  localparam logic [255:0] NIST_FIPS197_KEY256 = {
    128'h00000000_00000000_00000000_00000000,
    128'h2B7E1516_28AED2A6_ABF71588_09CF4F3C
  };

  logic [7:0]           sdls_s_rx_tdata, sdls_m_rx_tdata, sdls_pkt_tdata;
  logic                 sdls_s_rx_tvalid, sdls_s_rx_tready, sdls_s_rx_tlast;
  logic                 sdls_m_rx_tvalid, sdls_m_rx_tready, sdls_m_rx_tlast;
  logic                 sdls_pkt_tvalid, sdls_pkt_tlast;
  logic                 sdls_auth_done, sdls_auth_ok;
  logic                 sdls_gcm_mode_in;
  logic [15:0]          sdls_active_spi;
  logic                 sdls_s_tx_tvalid, sdls_s_tx_tready, sdls_s_tx_tlast;
  logic [7:0]           sdls_s_tx_tdata, sdls_m_tx_tdata;
  logic                 sdls_m_tx_tvalid, sdls_m_tx_tlast;
  ccsds_space_pkt_hdr_t sdls_parsed_pkt_hdr;

  ccsds_sdls_engine u_sdls_dut (
    .clk                        (clk),
    .rst_n                      (rst_n),
    .sdls_en_cfg                (1'b1),
    .sdls_gcm_mode_cfg          (sdls_gcm_mode_in),
    .bc_require_sdls_cfg        (1'b0),
    .tx_default_spi_cfg         (16'h0007),
    .master_key_cfg             (NIST_FIPS197_KEY256),
    .sa_wr_en                   (1'b0),
    .sa_wr_addr                 (6'd0),
    .sa_wr_spi                  (16'd0),
    .sa_wr_seq_low              (32'd0),
    .s_axis_rx_tvalid           (sdls_s_rx_tvalid),
    .s_axis_rx_tready           (sdls_s_rx_tready),
    .s_axis_rx_tdata            (sdls_s_rx_tdata),
    .s_axis_rx_tlast            (sdls_s_rx_tlast),
    .rx_frame_is_type_bc        (1'b0),
    .m_axis_rx_tvalid           (sdls_m_rx_tvalid),
    .m_axis_rx_tready           (sdls_m_rx_tready),
    .m_axis_rx_tdata            (sdls_m_rx_tdata),
    .m_axis_rx_tlast            (sdls_m_rx_tlast),
    .sdls_auth_done_pulse       (sdls_auth_done),
    .sdls_auth_ok               (sdls_auth_ok),
    .rx_active_spi_out          (sdls_active_spi),
    .sa_secded_single_err_pulse (),
    .sa_secded_double_err_pulse (),
    .s_axis_tx_tvalid           (sdls_s_tx_tvalid),
    .s_axis_tx_tready           (sdls_s_tx_tready),
    .s_axis_tx_tdata            (sdls_s_tx_tdata),
    .s_axis_tx_tlast            (sdls_s_tx_tlast),
    .m_axis_tx_tvalid           (sdls_m_tx_tvalid),
    .m_axis_tx_tready           (1'b1),
    .m_axis_tx_tdata            (sdls_m_tx_tdata),
    .m_axis_tx_tlast            (sdls_m_tx_tlast)
  );

  ccsds_pkt_reassembler u_sdls_pkt_reasm (
    .clk                     (clk),
    .rst_n                   (rst_n),
    .fhp_resync_en           (1'b0),
    .frame_fhp_in            (11'd0),
    .frame_start_pulse       (1'b0),
    .s_axis_tdata            (sdls_m_rx_tdata),
    .s_axis_tvalid           (sdls_m_rx_tvalid),
    .s_axis_tready           (sdls_m_rx_tready),
    .s_axis_tlast            (sdls_m_rx_tlast),
    .m_axis_pkt_tdata        (sdls_pkt_tdata),
    .m_axis_pkt_tvalid       (sdls_pkt_tvalid),
    .m_axis_pkt_tready       (1'b1),
    .m_axis_pkt_tlast        (sdls_pkt_tlast),
    .parsed_pkt_hdr          (sdls_parsed_pkt_hdr),
    .pkt_completed_pulse     (),
    .idle_pkt_stripped_pulse (),
    .pkt_len_err_pulse       ()
  );

  // ===========================================================================
  // 5. Step 3B: Ground EGSE RS(255,223) Error-Correcting Decoder -> TM Deframer
  // ===========================================================================
  logic [7:0]           rs_s_tdata, rs_m_tdata, rs_tm_def_tdata, rs_pkt_tdata;
  logic                 rs_s_tvalid, rs_s_tready, rs_s_tlast;
  logic                 rs_m_tvalid, rs_m_tready, rs_m_tlast;
  logic                 rs_tm_def_tvalid, rs_tm_def_tready, rs_tm_def_tlast;
  logic                 rs_pkt_tvalid, rs_pkt_tlast;
  logic                 rs_cw_done, rs_syn_clean, rs_tm_crc_ok, rs_tm_crc_err;
  logic [15:0]          rs_corr_sym_cnt;
  ccsds_space_pkt_hdr_t rs_parsed_pkt_hdr;

  ccsds_dl_rs255_223_dec u_rs_dec_dut (
    .clk                      (clk),
    .rst_n                    (rst_n),
    .interleave_depth_i_cfg   (4'd1),
    .virtual_fill_q_cfg       (8'd195),
    .s_axis_tvalid            (rs_s_tvalid),
    .s_axis_tready            (rs_s_tready),
    .s_axis_tdata             (rs_s_tdata),
    .s_axis_tlast             (rs_s_tlast),
    .m_axis_tvalid            (rs_m_tvalid),
    .m_axis_tready            (rs_m_tready),
    .m_axis_tdata             (rs_m_tdata),
    .m_axis_tlast             (rs_m_tlast),
    .rs_cw_done_pulse         (rs_cw_done),
    .rs_syndrome_clean_out    (rs_syn_clean),
    .rs_corrected_sym_cnt_out (rs_corr_sym_cnt)
  );

  ccsds_tm_aos_deframer u_rs_tm_deframer (
    .clk                      (clk),
    .rst_n                    (rst_n),
    .aos_mode_cfg             (1'b0),
    .aos_fhec_en_cfg          (1'b0),
    .tm_sec_hdr_en_cfg        (1'b0),
    .ocf_en_cfg               (1'b1),
    .fecf_en_cfg              (1'b1),
    .tfdf_byte_len_cfg        (16'd16),
    .s_axis_tvalid            (rs_m_tvalid),
    .s_axis_tready            (rs_m_tready),
    .s_axis_tdata             (rs_m_tdata),
    .s_axis_tlast             (rs_m_tlast),
    .m_axis_tfdf_tvalid       (rs_tm_def_tvalid),
    .m_axis_tfdf_tready       (rs_tm_def_tready),
    .m_axis_tfdf_tdata        (rs_tm_def_tdata),
    .m_axis_tfdf_tlast        (rs_tm_def_tlast),
    .rx_tm_hdr_out            (),
    .rx_obt_cuc_timestamp_out (),
    .extracted_clcw_out       (),
    .clcw_valid_pulse         (),
    .frame_crc_ok_pulse       (rs_tm_crc_ok),
    .frame_crc_err_pulse      (rs_tm_crc_err)
  );

  ccsds_pkt_reassembler u_rs_pkt_reasm (
    .clk                     (clk),
    .rst_n                   (rst_n),
    .fhp_resync_en           (1'b0),
    .frame_fhp_in            (11'd0),
    .frame_start_pulse       (1'b0),
    .s_axis_tdata            (rs_tm_def_tdata),
    .s_axis_tvalid           (rs_tm_def_tvalid),
    .s_axis_tready           (rs_tm_def_tready),
    .s_axis_tlast            (rs_tm_def_tlast),
    .m_axis_pkt_tdata        (rs_pkt_tdata),
    .m_axis_pkt_tvalid       (rs_pkt_tvalid),
    .m_axis_pkt_tready       (1'b1),
    .m_axis_pkt_tlast        (rs_pkt_tlast),
    .parsed_pkt_hdr          (rs_parsed_pkt_hdr),
    .pkt_completed_pulse     (),
    .idle_pkt_stripped_pulse (),
    .pkt_len_err_pulse       ()
  );

  // ===========================================================================
  // 6. Step 3C: CCSDS 231.1-O-1 (128,64) LDPC Decoder & Encoder Under Test
  // ===========================================================================
  logic signed [3:0]    ldpc_cb_llr_in;
  logic                 ldpc_cb_bit_in, ldpc_cb_start_in, ldpc_cb_valid_in;
  logic                 ldpc_tail_pulse, ldpc_conv_pulse, ldpc_abort_pulse;
  logic [7:0]           ldpc_m_tdata, ldpc_pkt_tdata;
  logic                 ldpc_m_tvalid, ldpc_m_tready, ldpc_m_tlast, ldpc_m_tabort;
  logic                 ldpc_pkt_tvalid, ldpc_pkt_tlast;
  ccsds_space_pkt_hdr_t ldpc_parsed_pkt_hdr;

  logic [7:0]           dl_ldpc_s_tdata, dl_ldpc_m_tdata;
  logic                 dl_ldpc_s_tvalid, dl_ldpc_s_tready, dl_ldpc_s_tlast;
  logic                 dl_ldpc_m_tvalid, dl_ldpc_m_tlast;

  ccsds_ul_short_ldpc_dec u_ldpc_dut (
    .clk                      (clk),
    .rst_n                    (rst_n),
    .ldpc_mode_512_en         (1'b0),
    .tc_derand_en             (1'b0),
    .cb_llr_in                (ldpc_cb_llr_in),
    .cb_hard_bit_in           (ldpc_cb_bit_in),
    .cb_start_pulse           (ldpc_cb_start_in),
    .cb_valid_in              (ldpc_cb_valid_in),
    .ldpc_tail_detected_pulse (ldpc_tail_pulse),
    .ldpc_converged_pulse     (ldpc_conv_pulse),
    .ldpc_uncorr_abort_pulse  (ldpc_abort_pulse),
    .m_axis_tdata             (ldpc_m_tdata),
    .m_axis_tvalid            (ldpc_m_tvalid),
    .m_axis_tready            (ldpc_m_tready),
    .m_axis_tlast             (ldpc_m_tlast),
    .m_axis_tabort            (ldpc_m_tabort)
  );

  ccsds_pkt_reassembler u_ldpc_pkt_reasm (
    .clk                     (clk),
    .rst_n                   (rst_n),
    .fhp_resync_en           (1'b0),
    .frame_fhp_in            (11'd0),
    .frame_start_pulse       (1'b0),
    .s_axis_tdata            (ldpc_m_tdata),
    .s_axis_tvalid           (ldpc_m_tvalid),
    .s_axis_tready           (ldpc_m_tready),
    .s_axis_tlast            (ldpc_m_tlast),
    .m_axis_pkt_tdata        (ldpc_pkt_tdata),
    .m_axis_pkt_tvalid       (ldpc_pkt_tvalid),
    .m_axis_pkt_tready       (1'b1),
    .m_axis_pkt_tlast        (ldpc_pkt_tlast),
    .parsed_pkt_hdr          (ldpc_parsed_pkt_hdr),
    .pkt_completed_pulse     (),
    .idle_pkt_stripped_pulse (),
    .pkt_len_err_pulse       ()
  );

  ccsds_dl_turbo_ldpc_enc #(.PARITY_BYTES(8)) u_dl_ldpc_enc_dut (
    .clk           (clk),
    .rst_n         (rst_n),
    .fec_mode_cfg  (4'd0),
    .s_axis_tdata  (dl_ldpc_s_tdata),
    .s_axis_tvalid (dl_ldpc_s_tvalid),
    .s_axis_tready (dl_ldpc_s_tready),
    .s_axis_tlast  (dl_ldpc_s_tlast),
    .m_axis_tdata  (dl_ldpc_m_tdata),
    .m_axis_tvalid (dl_ldpc_m_tvalid),
    .m_axis_tready (1'b1),
    .m_axis_tlast  (dl_ldpc_m_tlast)
  );

  // ===========================================================================
  // Stimulus & Capture Buffers
  // ===========================================================================
  logic [7:0] ext_ul_cltu_mem        [0:41];
  logic [7:0] ext_exp_ul_pkt         [0:13];
  logic [7:0] ext_ul_uslp_mem        [0:30];
  logic [7:0] ext_exp_uslp_pkt       [0:13];
  logic [7:0] ext_dl_pkt_mem         [0:15];
  logic [7:0] ext_sdls_rx_mem        [0:20];
  logic [7:0] ext_exp_sdls_pkt       [0:13];
  logic [7:0] ext_rs_corr_cw_mem     [0:59];
  logic [7:0] ext_ldpc_noisy_cbs_mem [0:31];
  logic [7:0] ext_exp_ldpc_pkt       [0:15];
  logic [7:0] ext_sdls_gcm_rx_mem    [0:35];

  logic [7:0] rtl_ul_pkt_out         [0:13];
  logic [7:0] rtl_uslp_pkt_out       [0:13];
  logic [7:0] rtl_dl_cadu_out        [0:63];
  logic [7:0] rtl_sdls_rx_pkt        [0:13];
  logic [7:0] rtl_sdls_tx_frame      [0:22];
  logic [7:0] rtl_rs_corr_pkt_out    [0:15];
  logic [7:0] rtl_ldpc_pkt_out       [0:15];
  logic [7:0] rtl_dl_ldpc_cw_out     [0:15];
  logic [7:0] rtl_sdls_gcm_rx_pkt    [0:13];
  logic [7:0] rtl_sdls_gcm_tx_frame  [0:37];

  integer ul_pkt_cnt, uslp_pkt_cnt, dl_cadu_cnt, sdls_rx_pkt_cnt, sdls_tx_cnt;
  integer rs_pkt_cnt, ldpc_pkt_cnt, ldpc_conv_cnt, dl_ldpc_cw_cnt;
  integer sdls_gcm_rx_pkt_cnt, sdls_gcm_tx_cnt;
  logic   ul_crc_ok_latched, ul_farm_acc_latched, uslp_crc_ok_latched;
  logic   sdls_auth_done_latched, sdls_auth_ok_latched, rs_tm_crc_ok_latched;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ul_pkt_cnt             <= 0;
      uslp_pkt_cnt           <= 0;
      dl_cadu_cnt            <= 0;
      sdls_rx_pkt_cnt        <= 0;
      sdls_tx_cnt            <= 0;
      rs_pkt_cnt             <= 0;
      ldpc_pkt_cnt           <= 0;
      ldpc_conv_cnt          <= 0;
      dl_ldpc_cw_cnt         <= 0;
      sdls_gcm_rx_pkt_cnt    <= 0;
      sdls_gcm_tx_cnt        <= 0;
      ul_crc_ok_latched      <= 1'b0;
      ul_farm_acc_latched    <= 1'b0;
      uslp_crc_ok_latched    <= 1'b0;
      uslp_ocf_latched       <= 32'd0;
      sdls_auth_done_latched <= 1'b0;
      sdls_auth_ok_latched   <= 1'b0;
      rs_tm_crc_ok_latched   <= 1'b0;
    end else begin
      if (ul_pkt_tvalid) begin
        rtl_ul_pkt_out[ul_pkt_cnt] <= ul_pkt_tdata;
        ul_pkt_cnt                 <= ul_pkt_cnt + 1;
      end
      if (ul_frame_done && ul_frame_crc_ok) begin
        ul_crc_ok_latched <= 1'b1;
      end
      if (ul_farm_accept) begin
        ul_farm_acc_latched <= 1'b1;
      end
      if (uslp_pkt_tvalid) begin
        rtl_uslp_pkt_out[uslp_pkt_cnt] <= uslp_pkt_tdata;
        uslp_pkt_cnt                   <= uslp_pkt_cnt + 1;
      end
      if (uslp_ext_ocf_valid) begin
        uslp_ocf_latched <= uslp_ext_ocf;
      end
      if (uslp_frame_done && uslp_frame_crc_ok) begin
        uslp_crc_ok_latched <= 1'b1;
      end
      if (dl_cadu_tvalid) begin
        rtl_dl_cadu_out[dl_cadu_cnt] <= dl_cadu_tdata;
        dl_cadu_cnt                  <= dl_cadu_cnt + 1;
      end
      if (sdls_pkt_tvalid) begin
        if (!sdls_gcm_mode_in && (sdls_rx_pkt_cnt < 14)) begin
          rtl_sdls_rx_pkt[sdls_rx_pkt_cnt] <= sdls_pkt_tdata;
          sdls_rx_pkt_cnt                  <= sdls_rx_pkt_cnt + 1;
        end else if (sdls_gcm_mode_in && (sdls_gcm_rx_pkt_cnt < 14)) begin
          rtl_sdls_gcm_rx_pkt[sdls_gcm_rx_pkt_cnt] <= sdls_pkt_tdata;
          sdls_gcm_rx_pkt_cnt                      <= sdls_gcm_rx_pkt_cnt + 1;
        end
      end
      if (sdls_auth_done) begin
        sdls_auth_done_latched <= 1'b1;
        sdls_auth_ok_latched   <= sdls_auth_ok;
      end
      if (sdls_m_tx_tvalid) begin
        if (!sdls_gcm_mode_in && (sdls_tx_cnt < 23)) begin
          rtl_sdls_tx_frame[sdls_tx_cnt] <= sdls_m_tx_tdata;
          sdls_tx_cnt                    <= sdls_tx_cnt + 1;
        end else if (sdls_gcm_mode_in && (sdls_gcm_tx_cnt < 38)) begin
          rtl_sdls_gcm_tx_frame[sdls_gcm_tx_cnt] <= sdls_m_tx_tdata;
          sdls_gcm_tx_cnt                        <= sdls_gcm_tx_cnt + 1;
        end
      end
      if (rs_pkt_tvalid && (rs_pkt_cnt < 16)) begin
        rtl_rs_corr_pkt_out[rs_pkt_cnt] <= rs_pkt_tdata;
        rs_pkt_cnt                      <= rs_pkt_cnt + 1;
      end
      if (rs_tm_crc_ok) begin
        rs_tm_crc_ok_latched <= 1'b1;
      end
      if (ldpc_pkt_tvalid && (ldpc_pkt_cnt < 16)) begin
        rtl_ldpc_pkt_out[ldpc_pkt_cnt] <= ldpc_pkt_tdata;
        ldpc_pkt_cnt                   <= ldpc_pkt_cnt + 1;
      end
      if (ldpc_conv_pulse) begin
        ldpc_conv_cnt <= ldpc_conv_cnt + 1;
      end
      if (dl_ldpc_m_tvalid && (dl_ldpc_cw_cnt < 16)) begin
        rtl_dl_ldpc_cw_out[dl_ldpc_cw_cnt] <= dl_ldpc_m_tdata;
        dl_ldpc_cw_cnt                     <= dl_ldpc_cw_cnt + 1;
      end
    end
  end

  integer fd;

  initial begin
    $readmemh("sim_waves/ext_ref_ul_cltu.hex",            ext_ul_cltu_mem);
    $readmemh("sim_waves/ext_ref_expected_ul_pkt.hex",    ext_exp_ul_pkt);
    $readmemh("sim_waves/ext_ref_ul_uslp.hex",            ext_ul_uslp_mem);
    $readmemh("sim_waves/ext_ref_expected_uslp_pkt.hex",  ext_exp_uslp_pkt);
    $readmemh("sim_waves/ext_ref_dl_pkt.hex",             ext_dl_pkt_mem);
    $readmemh("sim_waves/ext_ref_sdls_rx_frame.hex",      ext_sdls_rx_mem);
    $readmemh("sim_waves/ext_ref_expected_sdls_pkt.hex",  ext_exp_sdls_pkt);
    $readmemh("sim_waves/ext_ref_rs_corrupted_cw.hex",    ext_rs_corr_cw_mem);
    $readmemh("sim_waves/ext_ref_ldpc128_noisy_cbs.hex",  ext_ldpc_noisy_cbs_mem);
    $readmemh("sim_waves/ext_ref_expected_ldpc_pkt.hex",  ext_exp_ldpc_pkt);
    $readmemh("sim_waves/ext_ref_sdls_gcm_rx_frame.hex",  ext_sdls_gcm_rx_mem);

    rst_n             = 1'b0;
    ul_sym_llr_in     = 4'sd7;
    ul_sym_valid_in   = 1'b0;
    uslp_s_tdata      = 8'h00;
    uslp_s_tvalid     = 1'b0;
    dl_req_next_frame = 1'b0;
    dl_s_pkt_tdata    = 8'h00;
    dl_s_pkt_tvalid   = 1'b0;
    dl_s_pkt_tlast    = 1'b0;
    sdls_gcm_mode_in  = 1'b0;
    sdls_s_rx_tvalid  = 1'b0;
    sdls_s_rx_tdata   = 8'h00;
    sdls_s_rx_tlast   = 1'b0;
    sdls_s_tx_tvalid  = 1'b0;
    sdls_s_tx_tdata   = 8'h00;
    sdls_s_tx_tlast   = 1'b0;
    rs_s_tvalid       = 1'b0;
    rs_s_tdata        = 8'h00;
    rs_s_tlast        = 1'b0;
    ldpc_cb_llr_in    = 4'sd7;
    ldpc_cb_bit_in    = 1'b0;
    ldpc_cb_start_in  = 1'b0;
    ldpc_cb_valid_in  = 1'b0;
    dl_ldpc_s_tvalid  = 1'b0;
    dl_ldpc_s_tdata   = 8'h00;
    dl_ldpc_s_tlast   = 1'b0;

    #40 rst_n = 1'b1;
    repeat (4) @(posedge clk);
    #1;

    // =========================================================================
    // SUBTEST 1: External CLTU (`spacepackets-py`) -> Spacecraft Flight Rx RTL
    // =========================================================================
    $display("[TB-STAGE9][EXT-REF-1] Streaming 42-byte External CLTU (from spacepackets-py) into Spacecraft Uplink Rx Chain...");
    for (int b_idx = 0; b_idx < 42; b_idx++) begin
      for (int bit_pos = 7; bit_pos >= 0; bit_pos--) begin
        logic bit_val;
        bit_val         = ext_ul_cltu_mem[b_idx][bit_pos];
        ul_sym_llr_in   = bit_val ? -4'sd7 : 4'sd7;
        ul_sym_valid_in = 1'b1;
        @(posedge clk);
        #1;
      end
    end
    ul_sym_valid_in = 1'b0;
    repeat (40) @(posedge clk);
    #1;

    assert (ul_crc_ok_latched == 1'b1) else $fatal(1, "External CLTU TC Frame CRC-16 failed in RTL!");
    assert (ul_farm_acc_latched == 1'b1) else $fatal(1, "External CLTU TC Frame rejected by FARM-1!");
    assert (ul_pkt_cnt == 14) else $fatal(1, $sformatf("Expected 14 reassembled Space Packet bytes, got %0d", ul_pkt_cnt));
    for (int i = 0; i < 14; i++) begin
      assert (rtl_ul_pkt_out[i] == ext_exp_ul_pkt[i])
        else $fatal(1, $sformatf("UL Space Packet byte[%0d] mismatch: got 0x%02X, expected 0x%02X",
                                 i, rtl_ul_pkt_out[i], ext_exp_ul_pkt[i]));
    end

    fd = $fopen("sim_waves/rtl_out_ul_pkt.hex", "w");
    for (int i = 0; i < 14; i++) $fdisplay(fd, "%02X", rtl_ul_pkt_out[i]);
    $fclose(fd);
    $display("[TB-STAGE9][EXT-REF-1 PASS] Spacecraft RTL decoded external CLTU -> Space Packet (APID=0x%03X, Seq=%0d, Body=\"SAT_CMD1\") with 0 errors!",
             ul_parsed_pkt_hdr.apid, ul_parsed_pkt_hdr.pkt_seq_cnt);

    // =========================================================================
    // SUBTEST 2: External USLP Frame (`spacepackets-py`) -> Spacecraft Rx RTL
    // =========================================================================
    $display("[TB-STAGE9][EXT-REF-2] Streaming 31-byte External USLP Extended Frame into Spacecraft Uplink Deframer + Reassembler...");
    for (int i = 0; i < 31; i++) begin
      uslp_s_tvalid = 1'b1;
      uslp_s_tdata  = ext_ul_uslp_mem[i];
      @(posedge clk);
      while (!uslp_s_tready) @(posedge clk);
      #1;
    end
    uslp_s_tvalid = 1'b0;
    repeat (20) @(posedge clk);
    #1;

    assert (uslp_crc_ok_latched == 1'b1) else $fatal(1, "External USLP Frame CRC-16 failed in RTL!");
    assert (uslp_ocf_latched == 32'h0104_0002) else $fatal(1, "External USLP OCF extraction mismatch!");
    assert (uslp_pkt_cnt == 14) else $fatal(1, $sformatf("Expected 14 USLP Space Packet bytes, got %0d", uslp_pkt_cnt));
    for (int i = 0; i < 14; i++) begin
      assert (rtl_uslp_pkt_out[i] == ext_exp_uslp_pkt[i])
        else $fatal(1, $sformatf("USLP Space Packet byte[%0d] mismatch: got 0x%02X, expected 0x%02X",
                                 i, rtl_uslp_pkt_out[i], ext_exp_uslp_pkt[i]));
    end

    fd = $fopen("sim_waves/rtl_out_uslp_pkt.hex", "w");
    for (int i = 0; i < 14; i++) $fdisplay(fd, "%02X", rtl_uslp_pkt_out[i]);
    $fclose(fd);
    $display("[TB-STAGE9][EXT-REF-2 PASS] Spacecraft RTL decoded external USLP Frame -> Space Packet (APID=0x%03X, Seq=%0d, OCF=0x%08X) with 0 errors!",
             uslp_parsed_pkt_hdr.apid, uslp_parsed_pkt_hdr.pkt_seq_cnt, uslp_ocf_latched);

    // =========================================================================
    // SUBTEST 3: Spacecraft Flight Tx Chain -> External `spacepackets-py` Parser
    // =========================================================================
    $display("[TB-STAGE9][EXT-REF-3] Streaming 16-byte Telemetry Space Packet through Spacecraft Tx Chain (VC_Arb -> TM_Framer -> RS255_223_Enc)...");
    for (int i = 0; i < 16; i++) begin
      dl_s_pkt_tvalid = 1'b1;
      dl_s_pkt_tdata  = ext_dl_pkt_mem[i];
      dl_s_pkt_tlast  = (i == 15);
      @(posedge clk);
      while (!dl_s_pkt_tready) @(posedge clk);
      #1;
    end
    dl_s_pkt_tvalid = 1'b0;
    dl_s_pkt_tlast  = 1'b0;
    assert (dl_pkt_len_err == 1'b0) else $fatal(1, "VC Arbiter flagged Space Packet length error!");

    dl_req_next_frame = 1'b1;
    @(posedge clk);
    #1;
    dl_req_next_frame = 1'b0;

    while (!(dl_cadu_tvalid && dl_cadu_tlast)) @(posedge clk);
    repeat (4) @(posedge clk);
    #1;

    assert (dl_cadu_cnt == 64) else $fatal(1, $sformatf("Expected 64-byte CADU (4B ASM + 28B TM + 32B RS), got %0d", dl_cadu_cnt));
    assert ({rtl_dl_cadu_out[0], rtl_dl_cadu_out[1], rtl_dl_cadu_out[2], rtl_dl_cadu_out[3]} == 32'h1ACFFC1D)
      else $fatal(1, "Downlink CADU ASM 0x1ACFFC1D mismatch!");

    fd = $fopen("sim_waves/rtl_out_dl_cadu.hex", "w");
    for (int i = 0; i < 64; i++) $fdisplay(fd, "%02X", rtl_dl_cadu_out[i]);
    $fclose(fd);
    $display("[TB-STAGE9][EXT-REF-3 PASS] Spacecraft RTL emitted 64-byte RS(255,223)-encoded CADU to sim_waves/rtl_out_dl_cadu.hex!");

    // =========================================================================
    // SUBTEST 4 (Step 3A): External PyCA `cryptography` AES-128-CTR <-> SDLS RTL
    // =========================================================================
    $display("[TB-STAGE9][EXT-REF-4] Streaming 21-byte AES-128-CTR Frame (from Python cryptography) into ccsds_sdls_engine...");
    for (int i = 0; i < 21; i++) begin
      sdls_s_rx_tvalid = 1'b1;
      sdls_s_rx_tdata  = ext_sdls_rx_mem[i];
      sdls_s_rx_tlast  = (i == 20);
      @(posedge clk);
      while (!sdls_s_rx_tready) @(posedge clk);
      #1;
    end
    sdls_s_rx_tvalid = 1'b0;
    sdls_s_rx_tlast  = 1'b0;
    repeat (20) @(posedge clk);
    #1;

    assert (sdls_auth_done_latched == 1'b1 && sdls_auth_ok_latched == 1'b1)
      else $fatal(1, "SDLS AES-128-CTR authentication failed on valid Python cryptography frame!");
    assert (sdls_rx_pkt_cnt == 14)
      else $fatal(1, $sformatf("Expected 14 decrypted Space Packet bytes from SDLS, got %0d", sdls_rx_pkt_cnt));
    for (int i = 0; i < 14; i++) begin
      assert (rtl_sdls_rx_pkt[i] == ext_exp_sdls_pkt[i])
        else $fatal(1, $sformatf("SDLS Decrypted byte[%0d] mismatch: got 0x%02X, expected 0x%02X",
                                 i, rtl_sdls_rx_pkt[i], ext_exp_sdls_pkt[i]));
    end

    for (int i = 0; i < 21; i++) begin
      sdls_s_rx_tvalid = 1'b1;
      sdls_s_rx_tdata  = ext_sdls_rx_mem[i];
      sdls_s_rx_tlast  = (i == 20);
      @(posedge clk);
      while (!sdls_s_rx_tready) @(posedge clk);
      #1;
    end
    sdls_s_rx_tvalid = 1'b0;
    sdls_s_rx_tlast  = 1'b0;
    repeat (4) @(posedge clk);
    #1;
    assert (sdls_auth_ok_latched == 1'b0)
      else $fatal(1, "SDLS Anti-Replay failed to reject replayed Seq=5 frame!");

    for (int i = 0; i < 16; i++) begin
      sdls_s_tx_tvalid = 1'b1;
      sdls_s_tx_tdata  = ext_dl_pkt_mem[i];
      sdls_s_tx_tlast  = (i == 15);
      @(posedge clk);
      while (!sdls_s_tx_tready) @(posedge clk);
      #1;
    end
    sdls_s_tx_tvalid = 1'b0;
    sdls_s_tx_tlast  = 1'b0;
    while (sdls_tx_cnt < 23) @(posedge clk);
    repeat (4) @(posedge clk);
    #1;
    assert (sdls_tx_cnt == 23)
      else $fatal(1, $sformatf("Expected 23 SDLS Tx bytes (6B SecHdr + 16B CT + 1B Tag), got %0d", sdls_tx_cnt));

    fd = $fopen("sim_waves/rtl_out_sdls_rx_pkt.hex", "w");
    for (int i = 0; i < 14; i++) $fdisplay(fd, "%02X", rtl_sdls_rx_pkt[i]);
    $fclose(fd);

    fd = $fopen("sim_waves/rtl_out_sdls_tx_frame.hex", "w");
    for (int i = 0; i < 23; i++) $fdisplay(fd, "%02X", rtl_sdls_tx_frame[i]);
    $fclose(fd);
    $display("[TB-STAGE9][EXT-REF-4 PASS] Step 3A Real NIST FIPS-197 AES-128-CTR SDLS Decrypt/Encrypt + Anti-Replay verified with 0 errors!");

    // =========================================================================
    // SUBTEST 5 (Step 3B): Corrupted RS(255,223) Codeword -> Error Correction
    // =========================================================================
    $display("[TB-STAGE9][EXT-REF-5] Streaming 60-byte Corrupted Dual-Basis RS(255,223) Codeword (byte[7]^=0xA5, byte[14]^=0x3C) into ccsds_dl_rs255_223_dec...");
    for (int i = 0; i < 60; i++) begin
      rs_s_tvalid = 1'b1;
      rs_s_tdata  = ext_rs_corr_cw_mem[i];
      rs_s_tlast  = (i == 59);
      @(posedge clk);
      while (!rs_s_tready) @(posedge clk);
      #1;
    end
    rs_s_tvalid = 1'b0;
    rs_s_tlast  = 1'b0;

    repeat (60) @(posedge clk);
    #1;

    assert (rs_corr_sym_cnt == 16'd2)
      else $fatal(1, $sformatf("Expected 2 corrected RS symbols, got %0d", rs_corr_sym_cnt));
    assert (rs_tm_crc_ok_latched == 1'b1)
      else $fatal(1, "TM Frame CRC-16 did not pass after RS(255,223) error correction!");
    assert (rs_pkt_cnt == 16)
      else $fatal(1, $sformatf("Expected 16 reassembled Space Packet bytes after RS correction, got %0d", rs_pkt_cnt));
    for (int i = 0; i < 16; i++) begin
      assert (rtl_rs_corr_pkt_out[i] == ext_dl_pkt_mem[i])
        else $fatal(1, $sformatf("RS-Corrected Space Packet byte[%0d] mismatch: got 0x%02X, expected 0x%02X",
                                 i, rtl_rs_corr_pkt_out[i], ext_dl_pkt_mem[i]));
    end

    fd = $fopen("sim_waves/rtl_out_rs_corrected_pkt.hex", "w");
    for (int i = 0; i < 16; i++) $fdisplay(fd, "%02X", rtl_rs_corr_pkt_out[i]);
    $fclose(fd);
    $display("[TB-STAGE9][EXT-REF-5 PASS] Step 3B Dual-Basis RS(255,223) Decoder healed %0d corrupted bytes, restored TM CRC-16==0x0000, and recovered Space Packet (APID=0x%03X, Seq=%0d, Body=\"TLM_OBC_OK\")!",
             rs_corr_sym_cnt, rs_parsed_pkt_hdr.apid, rs_parsed_pkt_hdr.pkt_seq_cnt);

    // =========================================================================
    // SUBTEST 6 (Step 3C): Official CCSDS 231.1-O-1 (128,64) LDPC & Turbo
    // =========================================================================
    $display("[TB-STAGE9][EXT-REF-6] Streaming Two Noisy 128-bit CCSDS 231.1-O-1 Table 2-1/2-4 LDPC Codeblocks (4 bit errors total) into ccsds_ul_short_ldpc_dec...");
    for (int cb = 0; cb < 2; cb++) begin
      for (int b_idx = 0; b_idx < 16; b_idx++) begin
        for (int bit_pos = 7; bit_pos >= 0; bit_pos--) begin
          logic bit_val;
          bit_val          = ext_ldpc_noisy_cbs_mem[cb * 16 + b_idx][bit_pos];
          ldpc_cb_bit_in   = bit_val;
          ldpc_cb_llr_in   = bit_val ? -4'sd7 : 4'sd7;
          ldpc_cb_start_in = (cb == 0 && b_idx == 0 && bit_pos == 7);
          ldpc_cb_valid_in = 1'b1;
          @(posedge clk);
          #1;
        end
      end
      ldpc_cb_valid_in = 1'b0;
      ldpc_cb_start_in = 1'b0;
      repeat (35) @(posedge clk);
      #1;
    end

    assert (ldpc_conv_cnt == 2)
      else $fatal(1, $sformatf("Expected 2 converged LDPC(128,64) codeblocks, got %0d", ldpc_conv_cnt));
    assert (ldpc_pkt_cnt == 16)
      else $fatal(1, $sformatf("Expected 16 reassembled Space Packet bytes after LDPC(128,64) decoding, got %0d", ldpc_pkt_cnt));
    for (int i = 0; i < 16; i++) begin
      assert (rtl_ldpc_pkt_out[i] == ext_exp_ldpc_pkt[i])
        else $fatal(1, $sformatf("LDPC-Decoded Space Packet byte[%0d] mismatch: got 0x%02X, expected 0x%02X",
                                 i, rtl_ldpc_pkt_out[i], ext_exp_ldpc_pkt[i]));
    end

    // Also stream the first 8 bytes of the Space Packet into ccsds_dl_turbo_ldpc_enc (Table 2-1 W_64x64)
    for (int i = 0; i < 8; i++) begin
      dl_ldpc_s_tvalid = 1'b1;
      dl_ldpc_s_tdata  = ext_exp_ldpc_pkt[i];
      dl_ldpc_s_tlast  = (i == 7);
      @(posedge clk);
      while (!dl_ldpc_s_tready) @(posedge clk);
      #1;
    end
    dl_ldpc_s_tvalid = 1'b0;
    dl_ldpc_s_tlast  = 1'b0;
    repeat (16) @(posedge clk);
    #1;
    assert (dl_ldpc_cw_cnt == 16)
      else $fatal(1, $sformatf("Expected 16-byte (128-bit) LDPC codeword from ccsds_dl_turbo_ldpc_enc, got %0d", dl_ldpc_cw_cnt));

    fd = $fopen("sim_waves/rtl_out_ldpc_decoded_pkt.hex", "w");
    for (int i = 0; i < 16; i++) $fdisplay(fd, "%02X", rtl_ldpc_pkt_out[i]);
    $fclose(fd);

    fd = $fopen("sim_waves/rtl_out_dl_ldpc_cw.hex", "w");
    for (int i = 0; i < 16; i++) $fdisplay(fd, "%02X", rtl_dl_ldpc_cw_out[i]);
    $fclose(fd);

    $display("[TB-STAGE9][EXT-REF-6 PASS] Step 3C Official CCSDS 231.1-O-1 (128,64) LDPC Decoder healed 4 bit errors across 2 codeblocks and recovered Space Packet (APID=0x%03X, Seq=%0d, Body=\"LDPC128_OK\")!",
             ldpc_parsed_pkt_hdr.apid, ldpc_parsed_pkt_hdr.pkt_seq_cnt);

    // =========================================================================
    // SUBTEST 7 (Milestone 3): Full NIST SP 800-38D AES-128-GCM (GHASH) <-> RTL
    // =========================================================================
    $display("[TB-STAGE9][EXT-REF-7] Streaming 36-byte AES-128-GCM Frame (14B CT + 16B GHASH Tag from Python AESGCM) into ccsds_sdls_engine...");
    sdls_gcm_mode_in = 1'b1;
    @(posedge clk);
    #1;
    for (int i = 0; i < 36; i++) begin
      sdls_s_rx_tvalid = 1'b1;
      sdls_s_rx_tdata  = ext_sdls_gcm_rx_mem[i];
      sdls_s_rx_tlast  = (i == 35);
      @(posedge clk);
      while (!sdls_s_rx_tready) @(posedge clk);
      #1;
    end
    sdls_s_rx_tvalid = 1'b0;
    sdls_s_rx_tlast  = 1'b0;
    repeat (120) @(posedge clk);
    #1;

    assert (sdls_auth_done_latched == 1'b1 && sdls_auth_ok_latched == 1'b1)
      else $fatal(1, "SDLS AES-128-GCM GHASH authentication failed on valid Python AESGCM frame!");
    assert (sdls_gcm_rx_pkt_cnt == 14)
      else $fatal(1, $sformatf("Expected 14 decrypted Space Packet bytes from SDLS AES-128-GCM, got %0d", sdls_gcm_rx_pkt_cnt));
    for (int i = 0; i < 14; i++) begin
      assert (rtl_sdls_gcm_rx_pkt[i] == ext_exp_sdls_pkt[i])
        else $fatal(1, $sformatf("SDLS AES-128-GCM Decrypted byte[%0d] mismatch: got 0x%02X, expected 0x%02X",
                                 i, rtl_sdls_gcm_rx_pkt[i], ext_exp_sdls_pkt[i]));
    end

    // Verify 1-bit tamper in the 128-bit GHASH Tag (with fresh Seq=2) is rejected!
    for (int i = 0; i < 36; i++) begin
      sdls_s_rx_tvalid = 1'b1;
      if (i == 5) begin
        sdls_s_rx_tdata = 8'h02; // Seq = 2 (passes anti-replay, fails 128-bit GHASH tag)
      end else if (i == 35) begin
        sdls_s_rx_tdata = ext_sdls_gcm_rx_mem[i] ^ 8'h01; // Flip 1 bit in 128-bit GCM tag
      end else begin
        sdls_s_rx_tdata = ext_sdls_gcm_rx_mem[i];
      end
      sdls_s_rx_tlast  = (i == 35);
      @(posedge clk);
      while (!sdls_s_rx_tready) @(posedge clk);
      #1;
    end
    sdls_s_rx_tvalid = 1'b0;
    sdls_s_rx_tlast  = 1'b0;
    repeat (120) @(posedge clk);
    #1;
    assert (sdls_auth_ok_latched == 1'b0)
      else $fatal(1, "SDLS AES-128-GCM failed to reject tampered 128-bit GHASH tag!");

    // Downlink Tx AES-128-GCM Encryption + 128-bit GHASH Tag Generation (38 bytes: 6B SecHdr + 16B CT + 16B Tag)
    for (int i = 0; i < 16; i++) begin
      sdls_s_tx_tvalid = 1'b1;
      sdls_s_tx_tdata  = ext_dl_pkt_mem[i];
      sdls_s_tx_tlast  = (i == 15);
      @(posedge clk);
      while (!sdls_s_tx_tready) @(posedge clk);
      #1;
    end
    sdls_s_tx_tvalid = 1'b0;
    sdls_s_tx_tlast  = 1'b0;
    while (sdls_gcm_tx_cnt < 38) @(posedge clk);
    repeat (4) @(posedge clk);
    #1;
    assert (sdls_gcm_tx_cnt == 38)
      else $fatal(1, $sformatf("Expected 38 SDLS AES-128-GCM Tx bytes (6B SecHdr + 16B CT + 16B GHASH Tag), got %0d", sdls_gcm_tx_cnt));

    fd = $fopen("sim_waves/rtl_out_sdls_gcm_rx_pkt.hex", "w");
    for (int i = 0; i < 14; i++) $fdisplay(fd, "%02X", rtl_sdls_gcm_rx_pkt[i]);
    $fclose(fd);

    fd = $fopen("sim_waves/rtl_out_sdls_gcm_tx_frame.hex", "w");
    for (int i = 0; i < 38; i++) $fdisplay(fd, "%02X", rtl_sdls_gcm_tx_frame[i]);
    $fclose(fd);
    $display("[TB-STAGE9][EXT-REF-7 PASS] Milestone 3 Full NIST SP 800-38D AES-128-GCM (GHASH) 128-bit Tag Decrypt/Encrypt + Tag Tamper Rejection verified with 0 errors!");

    $display("[TB-STAGE9 PASS] All 7 External Reference Interoperability Subtests (Steps 2, 3A, 3B, 3C & Milestone 3 AES-128-GCM) passed in RTL!");
    $finish;
  end

endmodule : tb_stage9_external_ref_check
