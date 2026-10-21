// =============================================================================
// File Name   : ccsds_pkg.sv
// Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
// Standard    : IEEE 1800-2017 SystemVerilog (Synthesizable)
// Description : Master protocol package defining synthesis parameters, packed
//               bit-exact transfer frame headers (TM 132.0-B-3, TC 232.0-B-4,
//               AOS 732.0-B-4, Proximity-1 211.0-B-6, USLP 732.1-B-3, Space
//               Packet 133.0-B-2), COP-1 CLCW (232.1-B-2) & PLCW (211.0-B-6),
//               64-bit internal AXI4-Stream tuser sideband bus, sync markers,
//               polynomials, and GF(2^8) standard/dual-basis conversion tables.
// =============================================================================

`ifndef CCSDS_PKG_SV
`define CCSDS_PKG_SV
`timescale 1ns / 1ps


package ccsds_pkg;

  // ---------------------------------------------------------------------------
  // 1. Global Synthesis & Role Selection Parameters
  // ---------------------------------------------------------------------------
  typedef enum logic [1:0] {
    ROLE_SPACECRAFT_FLIGHT = 2'd0, // Synthesizes Satellite Rx Decoders/FARM-1 & Tx Encoders
    ROLE_GROUND_EGSE       = 2'd1, // Synthesizes Ground Tx Encoders/FOP-1 & Rx Decoders
    ROLE_UNIVERSAL_SYM     = 2'd2  // Synthesizes full symmetric transceiver
  } ccsds_role_mode_e;

  parameter int unsigned DEFAULT_DATA_WIDTH         = 32;
  parameter int unsigned DEFAULT_NUM_VC             = 8;
  parameter int unsigned DEFAULT_MAX_RX_FRAME_BYTES = 2048;

  // ---------------------------------------------------------------------------
  // 2. Protocol, FEC, Modulation & COP-1 Enumerations
  // ---------------------------------------------------------------------------
  typedef enum logic [2:0] {
    PROTO_TM    = 3'd0, // CCSDS 132.0-B-3 Telemetry Transfer Frame
    PROTO_TC    = 3'd1, // CCSDS 232.0-B-4 Telecommand Transfer Frame
    PROTO_AOS   = 3'd2, // CCSDS 732.0-B-4 Advanced Orbiting Systems Frame
    PROTO_PROX1 = 3'd3, // CCSDS 211.0-B-6 Proximity-1 Version-3 Frame
    PROTO_USLP  = 3'd4  // CCSDS 732.1-B-3 Unified Space Link Protocol Frame
  } ccsds_proto_e;

  typedef enum logic [3:0] {
    FEC_NONE           = 4'd0, // Uncoded (ASM only)
    FEC_UL_BCH_63_56   = 4'd1, // CCSDS 231.0-B-4 Uplink BCH(63,56) SEC-DED
    FEC_UL_LDPC_128_64 = 4'd2, // CCSDS 231.1-O-1 Short Uplink LDPC(128,64)
    FEC_UL_LDPC_512_256= 4'd3, // CCSDS 231.1-O-1 Short Uplink LDPC(512,256)
    FEC_PROX1_CONV_K7  = 4'd4, // CCSDS 211.2-B-3 Rate 1/2, K=7 Convolutional
    FEC_DL_RS_255_223  = 4'd5, // CCSDS 131.0-B-5 Dual-Basis RS(255,223) E=16
    FEC_DL_RS_255_239  = 4'd6, // CCSDS 131.0-B-5 Dual-Basis RS(255,239) E=8
    FEC_DL_CONCAT_RS_CV= 4'd7, // Concatenated Outer RS(255,223) + Inner Conv
    FEC_DL_LDPC_AR4JA  = 4'd8, // CCSDS 131.0-B-5 AR4JA LDPC (r=1/2, 2/3, 4/5)
    FEC_DL_LDPC_C2     = 4'd9, // CCSDS 131.0-B-5 C2(8160,7136) Rate 7/8 LDPC
    FEC_DL_TURBO_R1_2  = 4'd10,// CCSDS 131.0-B-5 Parallel Concatenated Turbo r=1/2
    FEC_DL_TURBO_R1_3  = 4'd11,// CCSDS 131.0-B-5 Parallel Concatenated Turbo r=1/3
    FEC_DL_TURBO_R1_4  = 4'd12,// CCSDS 131.0-B-5 Parallel Concatenated Turbo r=1/4
    FEC_DL_TURBO_R1_6  = 4'd13 // CCSDS 131.0-B-5 Parallel Concatenated Turbo r=1/6
  } ccsds_fec_mode_e;

  typedef enum logic [2:0] {
    MOD_BPSK           = 3'd0, // Residual or Suppressed-Carrier BPSK
    MOD_QPSK           = 3'd1, // Gray-Coded QPSK
    MOD_OQPSK          = 3'd2, // Offset QPSK (T_s/2 Q-channel delay)
    MOD_PCM_PM_SUB     = 3'd3, // PCM/PSK/PM on 8 kHz or 16 kHz Sine/Square Subcarrier
    MOD_PCM_PM_BIPHASE = 3'd4  // Direct PCM/PM/Bi-Phase-L
  } ccsds_mod_mode_e;

  typedef enum logic [1:0] {
    LINE_NRZ_L   = 2'd0, // Non-Return-to-Zero Level
    LINE_NRZ_M   = 2'd1, // Non-Return-to-Zero Mark (Differential)
    LINE_BIPHIL  = 2'd2  // Bi-Phase-L (Manchester)
  } ccsds_line_code_e;

  typedef enum logic [1:0] {
    FARM_STATE_OPEN    = 2'b00, // Accepts in-sequence Type-AD frames
    FARM_STATE_WAIT    = 2'b01, // Buffer backpressure wait state
    FARM_STATE_LOCKOUT = 2'b10  // Out-of-window lockout; requires Type-BC Unlock
  } ccsds_farm_state_e;

  typedef enum logic [1:0] {
    TC_TYPE_AD = 2'b00, // Bypass=0, Ctrl=0: Sequence-Controlled Data Frame
    TC_TYPE_RES= 2'b01, // Bypass=0, Ctrl=1: Reserved by CCSDS
    TC_TYPE_BD = 2'b10, // Bypass=1, Ctrl=0: Expedited Data Frame
    TC_TYPE_BC = 2'b11  // Bypass=1, Ctrl=1: COP-1 Control Command (Unlock / Set V(R))
  } ccsds_tc_frame_type_e;

  // ---------------------------------------------------------------------------
  // 3. Synchronization Markers, Frame Pointers & Polynomial Constants
  // ---------------------------------------------------------------------------
  localparam logic [15:0]  CLTU_START_SEQ_16B    = 16'hEB90;
  localparam logic [63:0]  CLTU_TAIL_SEQ_BCH_C5  = 64'hC5C5_C5C5_C5C5_C579;
  localparam logic [63:0]  CLTU_TAIL_SEQ_LDPC_55 = 64'h5555_5555_5555_55AA;
  localparam logic [63:0]  UL_LDPC_START_SEQ_64B = 64'h0347_76C7_2728_95B0;
  localparam logic [31:0]  DL_ASM_TM_RS_CONV_32B = 32'h1ACFFC1D;
  localparam logic [63:0]  DL_ASM_LDPC_AR4JA_64B = 64'h0347_76C7_2728_95B0;
  localparam logic [23:0]  PROX1_ASM_24B         = 24'hFAF320;
  localparam logic [7:0]   CLTU_IDLE_FILL_OCTET  = 8'h55;

  localparam logic [10:0]  TM_FHP_NO_PKT_START   = 11'h7FF;
  localparam logic [10:0]  TM_FHP_OID_IDLE_FRAME = 11'h7FE;
  localparam logic [5:0]   AOS_USLP_VCID_OID     = 6'b111111;

  localparam logic [15:0]  POLY_CRC16_CCITT      = 16'h1021;
  localparam logic [15:0]  INIT_CRC16_CCITT      = 16'hFFFF;
  localparam logic [15:0]  RESIDUE_CRC16_VALID   = 16'h0000;

  localparam logic [31:0]  POLY_CRC32_PROX1      = 32'h00A0_0805;
  localparam logic [31:0]  INIT_CRC32_PROX1      = 32'hFFFF_FFFF;
  localparam logic [31:0]  RESIDUE_CRC32_VALID   = 32'h0000_0000;

  localparam logic [6:0]   POLY_BCH6356          = 7'h45;
  localparam logic [8:0]   POLY_RS_GF256         = 9'h187;
  localparam logic [6:0]   POLY_CONV_G1          = 7'b1111001;
  localparam logic [6:0]   POLY_CONV_G2          = 7'b1011011;

  localparam logic [7:0]   LFSR_TM_TAP_MASK      = 8'hA9;
  localparam logic [7:0]   LFSR_TC_TAP_MASK      = 8'h5F;
  localparam logic [7:0]   LFSR_INIT_ALL_ONES    = 8'hFF;

  localparam logic [7:0]   COP1_CMD_UNLOCK       = 8'h00;
  localparam logic [7:0]   COP1_CMD_SET_VR_HDR   = 8'h82;

  // ---------------------------------------------------------------------------
  // 4. Bit-Exact Packed Protocol Header & Trailer Structures (MSB-First)
  // ---------------------------------------------------------------------------

  // 4.1 CCSDS 133.0-B-2 Space Packet Primary Header (Exactly 48 bits / 6 octets)
  typedef struct packed {
    logic [2:0]  pkt_vn;         // [47:45] Packet Version Number ("000")
    logic        pkt_type;       // [44]    0 = Telemetry (TM), 1 = Telecommand (TC)
    logic        sec_hdr_flag;   // [43]    Secondary Header Flag
    logic [10:0] apid;           // [42:32] Application Process ID (11'h7FF = Idle Packet)
    logic [1:0]  seq_flags;      // [31:30] 01=First, 00=Cont, 10=Last, 11=Unsegmented
    logic [13:0] pkt_seq_cnt;    // [29:16] Packet Sequence Count or Packet Name
    logic [15:0] pkt_data_len;   // [15:0]  C = (Total Octets in Data Field) - 1
  } ccsds_space_pkt_hdr_t;       // TOTAL = 48 bits

  // 4.2 CCSDS 232.0-B-4 Telecommand (TC) Transfer Frame Primary Header (Exactly 40 bits / 5 octets)
  typedef struct packed {
    logic [1:0]  tfvn;           // [39:38] Transfer Frame Version Number ("00")
    logic        bypass_flag;    // [37]    0 = Type-A (Seq Controlled), 1 = Type-B (Expedited)
    logic        ctrl_cmd_flag;  // [36]    0 = Type-D (Data), 1 = Type-C (Control Command)
    logic [1:0]  rsvd_spare;     // [35:34] Reserved Spare ("00")
    logic [9:0]  scid;           // [33:24] Spacecraft Identifier (10 bits)
    logic [5:0]  vcid;           // [23:18] Virtual Channel Identifier (6 bits)
    logic [9:0]  frame_len;      // [17:8]  C = (Total Octets in TC Frame) - 1
    logic [7:0]  frame_seq_num;  // [7:0]   N(S) Frame Sequence Number
  } ccsds_tc_prim_hdr_t;         // TOTAL = 40 bits

  // 4.3 CCSDS 232.0-B-4 TC Segment Header (Exactly 8 bits / 1 octet)
  typedef struct packed {
    logic [1:0]  seq_flags;      // [7:6]   01=First, 00=Cont, 10=Last, 11=No Segmentation
    logic [5:0]  map_id;         // [5:0]   Multiplexer Access Point ID
  } ccsds_tc_seg_hdr_t;          // TOTAL = 8 bits

  // 4.4 CCSDS 132.0-B-3 Telemetry (TM) Transfer Frame Primary Header (Exactly 48 bits / 6 octets)
  typedef struct packed {
    logic [1:0]  tfvn;           // [47:46] Transfer Frame Version Number ("00")
    logic [9:0]  scid;           // [45:36] Spacecraft Identifier (10 bits)
    logic [2:0]  vcid;           // [35:33] Virtual Channel Identifier (3 bits, VC 0..7)
    logic        ocf_flag;       // [32]    Operational Control Field (CLCW) Present Flag
    logic [7:0]  mc_frame_cnt;   // [31:24] Master Channel Frame Count
    logic [7:0]  vc_frame_cnt;   // [23:16] Virtual Channel Frame Count
    logic        sec_hdr_flag;   // [15]    Transfer Frame Secondary Header Flag
    logic        sync_flag;      // [14]    0 = Octet-synced Space Packets, 1 = VCA/Bit-stream
    logic        pkt_order_flag; // [13]    Packet Order Flag (always "0")
    logic [1:0]  seg_len_id;     // [12:11] Segment Length Identifier (always "11")
    logic [10:0] first_hdr_ptr;  // [10:0]  First Header Pointer (0x7FE=Idle, 0x7FF=No Start)
  } ccsds_tm_prim_hdr_t;         // TOTAL = 48 bits

  // 4.5 CCSDS 732.0-B-4 AOS Transfer Frame Primary Header (Exactly 48 bits / 6 octets base)
  typedef struct packed {
    logic [1:0]  tfvn;           // [47:46] Transfer Frame Version Number ("01")
    logic [7:0]  scid;           // [45:38] Spacecraft Identifier (8 bits)
    logic [5:0]  vcid;           // [37:32] Virtual Channel Identifier (6 bits, 63=Idle)
    logic [23:0] vc_frame_cnt;   // [31:8]  24-bit Virtual Channel Frame Count
    logic        replay_flag;    // [7]     Replay Flag
    logic        vc_cnt_usage;   // [6]     VC Frame Count Usage Flag
    logic [1:0]  rsvd_spare;     // [5:4]   Reserved ("00")
    logic [3:0]  vc_cnt_cycle;   // [3:0]   VC Frame Count Cycle
  } ccsds_aos_prim_hdr_t;        // TOTAL = 48 bits

  // 4.6 CCSDS 211.0-B-6 Proximity-1 Transfer Frame Primary Header (Exactly 40 bits / 5 octets)
  typedef struct packed {
    logic [1:0]  tfvn;           // [39:38] Transfer Frame Version Number ("10")
    logic        qos_ind;        // [37]    0 = Sequence Controlled (Expedited=0), 1 = Expedited
    logic        pdu_type_id;    // [36]    0 = User Data, 1 = SPDU (Supervisory Protocol Data Unit)
    logic [1:0]  dfc_id;         // [35:34] Data Field Construction ID
    logic [9:0]  scid;           // [33:24] Spacecraft Identifier (10 bits)
    logic        pcid;           // [23]    Physical Channel Identifier
    logic [2:0]  port_id;        // [22:20] Port Identifier
    logic        src_dst_id;     // [19]    0 = Source SCID, 1 = Destination SCID
    logic [10:0] frame_len;      // [18:8]  C = (Total Octets in Frame Header + Data) - 1
    logic [7:0]  frame_seq_num;  // [7:0]   8-bit Frame Sequence Number
  } ccsds_prox1_prim_hdr_t;      // TOTAL = 40 bits

  // 4.7 CCSDS 732.1-B-3 USLP Truncated/Base Primary Header (Exactly 32 bits / 4 octets)
  typedef struct packed {
    logic [3:0]  tfvn;           // [31:28] Transfer Frame Version Number ("1100" = 4'hC)
    logic [15:0] scid;           // [27:12] 16-bit Spacecraft Identifier
    logic        src_dst_id;     // [11]    0 = Source SCID, 1 = Destination SCID
    logic [5:0]  vcid;           // [10:5]  6-bit Virtual Channel Identifier
    logic [3:0]  map_id;         // [4:1]   4-bit Multiplexer Access Point ID
    logic        end_of_ph_flag; // [0]     1 = Truncated 4-octet Header, 0 = Extended Header follows
  } ccsds_uslp_trunc_hdr_t;      // TOTAL = 32 bits

  // 4.8 CCSDS 732.1-B-3 USLP Extended Primary Header Fields (Exactly 24 bits / 3 octets before VCF_Count)
  typedef struct packed {
    logic [15:0] frame_len;      // [23:8]  C = (Total Octets in USLP Frame) - 1
    logic        bypass_flag;    // [7]     Sequence Control / Bypass Flag
    logic        ctrl_cmd_flag;  // [6]     Protocol Control Command Flag
    logic [1:0]  rsvd_spare;     // [5:4]   Reserved ("00")
    logic        ocf_flag;       // [3]     OCF Present Flag
    logic [2:0]  vcf_cnt_len;    // [2:0]   Number of octets in VCF Count (0 to 7 octets = 0..56 bits)
  } ccsds_uslp_ext_hdr_t;        // TOTAL = 24 bits

  // 4.9 CCSDS 732.1-B-3 USLP Transfer Frame Data Field Header (TFDFH) (Exactly 24 bits / 3 octets max)
  typedef struct packed {
    logic [2:0]  tfdf_constr_rule; // [23:21] TFDZ Construction Rule (000 = Spanning Packets)
    logic [4:0]  up_id;            // [20:16] USLP Protocol Identifier
    logic [15:0] fhp_or_lvo;       // [15:0]  First Header Pointer or Last Valid Octet Pointer
  } ccsds_uslp_tfdf_hdr_t;         // TOTAL = 24 bits

  // 4.10 CCSDS 232.1-B-2 Communications Link Control Word (CLCW) (Exactly 32 bits / 4 octets)
  typedef struct packed {
    logic        ctrl_word_type; // [31]    Always "0" for CLCW
    logic [1:0]  clcw_version;   // [30:29] Version Number ("00")
    logic [2:0]  status_field;   // [28:26] Mission-specific status
    logic [1:0]  cop_in_effect;  // [25:24] "01" = COP-1 in effect
    logic [5:0]  vcid;           // [23:18] Virtual Channel ID being reported
    logic [1:0]  rsvd_spare;     // [17:16] Reserved ("00")
    logic        no_rf_avail;    // [15]    0 = RF Carrier Locked, 1 = Loss of Carrier
    logic        no_bit_lock;    // [14]    0 = Symbol/Bit Sync Locked, 1 = Loss of Bit Lock
    logic        lockout;        // [13]    FARM-1 Lockout Flag
    logic        wait_flag;      // [12]    FARM-1 Wait Flag
    logic        retransmit;     // [11]    FARM-1 Retransmit Flag (N(S) != V(R))
    logic [1:0]  farm_b_cnt;     // [10:9]  2 LSBs of FARM-B Expedited Frame Counter
    logic        rsvd_zero;      // [8]     Reserved ("0")
    logic [7:0]  report_value;   // [7:0]   V(R) Next Expected Frame Sequence Number
  } ccsds_clcw_t;                // TOTAL = 32 bits

  // 4.11 CCSDS 211.0-B-6 Proximity Link Control Word (PLCW) (Exactly 32 bits / 4 octets)
  typedef struct packed {
    logic        ctrl_word_type; // [31]    "0" for PLCW
    logic [1:0]  plcw_version;   // [30:29] "00"
    logic [2:0]  status_field;   // [28:26] Status Field
    logic [1:0]  cop_in_effect;  // [25:24] "10" = COP-P in effect
    logic        pcid;           // [23]    Physical Channel ID
    logic [2:0]  port_id;        // [22:20] Port ID
    logic [2:0]  rsvd_spare;     // [19:17] Reserved
    logic        no_rf_avail;    // [16]    No RF Available
    logic        no_bit_lock;    // [15]    No Bit Lock
    logic        lockout;        // [14]    Lockout Flag
    logic        wait_flag;      // [13]    Wait Flag
    logic        retransmit;     // [12]    Retransmit Flag
    logic [3:0]  expedited_cnt;  // [11:8]  4-bit Expedited Frame Counter
    logic [7:0]  report_value;   // [7:0]   V(R) Report Value
  } ccsds_plcw_t;                // TOTAL = 32 bits

  // 4.12 Unified Internal AXI4-Stream Sideband Bus (Exactly 64 bits)
  typedef struct packed {
    logic [15:0] scid;           // [63:48] Spacecraft ID (10b TM/TC/Prox-1, 8b AOS, 16b USLP)
    logic [5:0]  vcid;           // [47:42] Virtual Channel ID (0..63)
    logic [5:0]  map_id;         // [41:36] MAP ID / Port ID
    logic [2:0]  proto_mode;     // [35:33] ccsds_proto_e
    logic [3:0]  fec_mode;       // [32:29] ccsds_fec_mode_e
    logic        bypass_flag;    // [28]    Type-B Bypass / Expedited QoS
    logic        ctrl_cmd_flag;  // [27]    Type-C Control Command / SPDU
    logic        sec_en;         // [26]    SDLS Security Enabled on this VC
    logic        ocf_en;         // [25]    OCF (CLCW/PLCW) Enabled on this Frame
    logic        fecf_en;        // [24]    FECF CRC Enabled on this Frame
    logic        fecf_crc32;     // [23]    0 = CRC-16 (0x1021), 1 = CRC-32 (0x00A00805)
    logic [3:0]  rs_interleave;  // [22:19] Reed-Solomon Interleaving Depth I (1..8)
    logic [7:0]  rs_virt_fill_q; // [18:11] Reed-Solomon Virtual Fill Length Q (0..200)
    logic [6:0]  spi;            // [10:4]  SDLS Security Parameter Index (0..63)
    logic        crc_err;        // [3]     FECF CRC Residue Error Flag
    logic        fec_uncorr_err; // [2]     BCH / LDPC / RS Uncorrectable Codeblock Abort
    logic        sdls_mac_err;   // [1]     SDLS MAC Authentication / Anti-Replay Failure
    logic        pkt_len_err;    // [0]     Space Packet Length Mismatch Error
  } ccsds_tuser_t;               // TOTAL = 64 bits

  // ---------------------------------------------------------------------------
  // 5. Dual-Basis GF(2^8) Conversion & RS(255,223) Generator Tables (131.0-B-5)
  // ---------------------------------------------------------------------------
  localparam logic [7:0] RS_T_STD_TO_DUAL [0:7] = '{
    8'b1111_1110, // z0 (0xFE)
    8'b0110_1001, // z1 (0x69)
    8'b0110_1011, // z2 (0x6B)
    8'b0000_1101, // z3 (0x0D)
    8'b1110_1111, // z4 (0xEF)
    8'b1111_0010, // z5 (0xF2)
    8'b0101_1011, // z6 (0x5B)
    8'b1100_0111  // z7 (0xC7)
  };

  localparam logic [7:0] RS_T_DUAL_TO_STD [0:7] = '{
    8'b1001_1011, // u7 (0x9B)
    8'b1101_1101, // u6 (0xDD)
    8'b0011_1110, // u5 (0x3E)
    8'b0001_1100, // u4 (0x1C)
    8'b0011_0111, // u3 (0x37)
    8'b1011_0011, // u2 (0xB3)
    8'b0110_0000, // u1 (0x60)
    8'b1001_0100  // u0 (0x94)
  };

  // Exact Standard-Basis Coefficients G_1..G_32 of Symmetric Generator Polynomial:
  //   g(x) = prod_{j=112}^{143} (x - alpha^(11*j)) = x^32 + G_1 x^31 + ... + G_31 x + G_32
  // Verified against F(x) = x^8 + x^7 + x^2 + x + 1 (0x187) where G_k = G_{32-k} and G_32 = 1:
  localparam logic [7:0] RS_GEN_POLY_STD [1:32] = '{
    8'h5B, // G_1  = alpha^249
    8'h7F, // G_2  = alpha^59
    8'h56, // G_3  = alpha^66
    8'h10, // G_4  = alpha^4
    8'h1E, // G_5  = alpha^43
    8'h0D, // G_6  = alpha^126
    8'hEB, // G_7  = alpha^251
    8'h61, // G_8  = alpha^97
    8'hA5, // G_9  = alpha^30
    8'h08, // G_10 = alpha^3
    8'h2A, // G_11 = alpha^213
    8'h36, // G_12 = alpha^50
    8'h56, // G_13 = alpha^66
    8'hAB, // G_14 = alpha^170
    8'h20, // G_15 = alpha^5
    8'h71, // G_16 = alpha^24 (center tap)
    8'h20, // G_17 = alpha^5
    8'hAB, // G_18 = alpha^170
    8'h56, // G_19 = alpha^66
    8'h36, // G_20 = alpha^50
    8'h2A, // G_21 = alpha^213
    8'h08, // G_22 = alpha^3
    8'hA5, // G_23 = alpha^30
    8'h61, // G_24 = alpha^97
    8'hEB, // G_25 = alpha^251
    8'h0D, // G_26 = alpha^126
    8'h1E, // G_27 = alpha^43
    8'h10, // G_28 = alpha^4
    8'h56, // G_29 = alpha^66
    8'h7F, // G_30 = alpha^59
    8'h5B, // G_31 = alpha^249
    8'h01  // G_32 = alpha^0 = 1
  };

  // Helper function: Convert 8-bit Standard Basis element to Dual Basis (Berlekamp)
  function automatic logic [7:0] gf256_std_to_dual(input logic [7:0] std_val);
    logic [7:0] dual_val;
    for (int i = 0; i < 8; i++) begin
      dual_val[7 - i] = ^(std_val & RS_T_STD_TO_DUAL[i]);
    end
    return dual_val;
  endfunction

  // Helper function: Convert 8-bit Dual Basis (Berlekamp) element to Standard Basis
  function automatic logic [7:0] gf256_dual_to_std(input logic [7:0] dual_val);
    logic [7:0] std_val;
    for (int i = 0; i < 8; i++) begin
      std_val[7 - i] = ^(dual_val & RS_T_DUAL_TO_STD[i]);
    end
    return std_val;
  endfunction


  // Emergency Hardware Command Pulse Decoder (HCPD) Constants (CCSDS 231.0-B-4)
  localparam logic [5:0]  EMERGENCY_VCID        = 6'd63;
  localparam logic [63:0] MAGIC_OBC_HARD_RESET  = 64'hC0DE_CAFE_DEAD_BEEF;
  localparam logic [63:0] MAGIC_SAFE_MODE_FORCE = 64'h5AFE_FA11_B007_C0DE;
  localparam logic [63:0] MAGIC_SWAP_RF_CHAIN   = 64'hABCD_EF01_2345_6789;

endpackage : ccsds_pkg

`endif // CCSDS_PKG_SV
