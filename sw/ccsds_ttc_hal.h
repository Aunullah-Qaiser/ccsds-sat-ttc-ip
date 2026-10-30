/**
 * @file ccsds_ttc_hal.h
 * @brief Zero-Dependency Bare-Metal C11 Flight OBC & Ground EGSE Hardware
 *        Abstraction Layer (HAL) SDK for the CCSDS-SAT-TTC-IP Core (v2.36.0).
 *
 * Strictly bit-accurate against rtl/ccsds_axi_lite_csr.sv (0x00..0x50) and
 * enforces CCSDS Blue Book configuration gating rules in firmware via
 * ccsds_ttc_hal_validate_config() before committing CSR writes:
 *   - 0x00 : CORE_ID_VER        (RO) 0xCC5D0230
 *   - 0x04 : CTRL_SCID_PROTO    (RW, TMR) [9:0]=SCID, [14:12]=PROTO, [19:16]=FEC,
 *                                         [20]=OCF, [21]=FECF, [22]=CRC32, [23]=AOS_FHEC,
 *                                         [24]=TC_SEG_HDR, [25]=OBT_EN, [26]=SDLS_EN,
 *                                         [27]=BC_REQ_SDLS, [28]=SRRC_4SPS_EN,
 *                                         [29]=GARDNER_TED_EN, [31:30]=TURNAROUND_KABAND_CFG
 *   - 0x08 : CTRL_USLP_RS_CFG   (RW, TMR) [15:0]=USLP_SCID, [19:16]=RS_I, [27:20]=RS_Q,
 *                                         [28]=SDLS_GCM_MODE_CFG, [29]=FLL_ASSIST_EN_CFG,
 *                                         [30]=TM_RAND_EN_CFG
 *   - 0x0C : CTRL_COP1_TFDF_CFG (RW, TMR) [7:0]=WIN_W, [18:8]=TFDF_LEN, [24]=IRQ_EN
 *   - 0x10 : OBT_COARSE_SEC     (RW) 32-bit CUC Coarse Seconds
 *   - 0x14 : OBT_FINE_SUBSEC    (RW) [15:0] 16-bit CUC Fine Sub-seconds
 *   - 0x18 : EDAC_CORR_CNTS     (RO/W1C) [15:0]=SECDED/BCH 1b Corr Cnt, [31:16]=TMR SEU Corr Cnt
 *   - 0x1C : FAULT_ERR_CNTS     (RO/W1C) [15:0]=Uncorr FEC/CRC/Pkt Err Cnt, [31:16]=SDLS MAC Err Cnt
 *   - 0x20 : LATEST_CLCW_MON    (RO) Latest 32-bit COP-1 CLCW word
 *   - 0x24 : LATEST_PLCW_MON    (RO) Latest 32-bit Proximity-1 PLCW word
 *   - 0x28..0x44 : REG_SDLS_KEY_0..7 (RW) 256-bit SDLS Master Key
 *   - 0x48 : REG_SDLS_SA_CTRL   (RW) [15:0]=TX_DEFAULT_SPI, [21:16]=SA_WR_ADDR, [31]=SA_WR_EN
 *   - 0x4C : REG_SDLS_SA_SPI    (RW) [15:0]=SA_WR_SPI
 *   - 0x50 : REG_SDLS_SA_SEQ    (RW) [31:0]=SA_WR_SEQ_LOW
 */

#ifndef CCSDS_TTC_HAL_H
#define CCSDS_TTC_HAL_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ========================================================================== */
/* 1. AXI4-Lite Register Map Offsets (Byte Addresses matching RTL)            */
/* ========================================================================== */
#define CCSDS_REG_CORE_ID_VER        0x00U /**< RO: Core ID & Version (0xCC5D0230) */
#define CCSDS_REG_CTRL_SCID_PROTO    0x04U /**< RW (TMR): 10b SCID, Proto, FEC, OCF/FECF, SDLS, SRRC, Gardner, KaBand */
#define CCSDS_REG_CTRL_USLP_RS_CFG   0x08U /**< RW (TMR): 16b USLP SCID, RS(I,Q), SDLS GCM, FLL Assist, TM Rand */
#define CCSDS_REG_CTRL_COP1_TFDF_CFG 0x0CU /**< RW (TMR): COP-1 Window W, TFDF byte len, Fault IRQ Enable */
#define CCSDS_REG_OBT_COARSE_SEC     0x10U /**< RW: 32-bit CUC Coarse Seconds [47:16] */
#define CCSDS_REG_OBT_FINE_SUBSEC    0x14U /**< RW: 16-bit CUC Fine Sub-seconds [15:0] */
#define CCSDS_REG_EDAC_CORR_CNTS     0x18U /**< RO/W1C: [15:0] SECDED/BCH 1b Corr, [31:16] TMR SEU Corr */
#define CCSDS_REG_FAULT_ERR_CNTS     0x1CU /**< RO/W1C: [15:0] Uncorr FEC/CRC/Pkt Err, [31:16] SDLS MAC Err */
#define CCSDS_REG_LATEST_CLCW_MON    0x20U /**< RO: Latest scheduled 32-bit COP-1 CLCW */
#define CCSDS_REG_LATEST_PLCW_MON    0x24U /**< RO: Latest scheduled 32-bit Proximity-1 PLCW */

/* Runtime SDLS 256-Bit Master Key & Security Association (SA) Provisioning */
#define CCSDS_REG_SDLS_KEY_0         0x28U /**< RW: SDLS Master Key[31:0]   (LSW) */
#define CCSDS_REG_SDLS_KEY_1         0x2CU /**< RW: SDLS Master Key[63:32]  */
#define CCSDS_REG_SDLS_KEY_2         0x30U /**< RW: SDLS Master Key[95:64]  */
#define CCSDS_REG_SDLS_KEY_3         0x34U /**< RW: SDLS Master Key[127:96] */
#define CCSDS_REG_SDLS_KEY_4         0x38U /**< RW: SDLS Master Key[159:128] */
#define CCSDS_REG_SDLS_KEY_5         0x3CU /**< RW: SDLS Master Key[191:160] */
#define CCSDS_REG_SDLS_KEY_6         0x40U /**< RW: SDLS Master Key[223:192] */
#define CCSDS_REG_SDLS_KEY_7         0x44U /**< RW: SDLS Master Key[255:224] (MSW) */
#define CCSDS_REG_SDLS_SA_CTRL       0x48U /**< RW: [15:0]=TX_DEFAULT_SPI, [21:16]=SA_WR_ADDR, [31]=SA_WR_EN */
#define CCSDS_REG_SDLS_SA_SPI        0x4CU /**< RW: [15:0]=SA_WR_SPI */
#define CCSDS_REG_SDLS_SA_SEQ        0x50U /**< RW: [31:0]=SA_WR_SEQ_LOW */

/* Legacy macro aliases for source compatibility */
#define CCSDS_REG_VERSION_ID         CCSDS_REG_CORE_ID_VER
#define CCSDS_REG_SCID_CFG           CCSDS_REG_CTRL_SCID_PROTO
#define CCSDS_REG_PROTO_FEC_CFG      CCSDS_REG_CTRL_USLP_RS_CFG
#define CCSDS_REG_USLP_RS_CFG        CCSDS_REG_CTRL_COP1_TFDF_CFG
#define CCSDS_REG_OBT_CUC_HIGH       CCSDS_REG_OBT_COARSE_SEC
#define CCSDS_REG_OBT_CUC_LOW        CCSDS_REG_OBT_FINE_SUBSEC

#define CCSDS_EXPECTED_VERSION_ID    0xCC5D0230UL

/* ========================================================================== */
/* 2. Firmware Configuration Gating & Validation Status Codes                 */
/* ========================================================================== */
#define CCSDS_HAL_OK                         0   /**< Configuration valid & applied */
#define CCSDS_HAL_ERR_NULL_PTR              -1   /**< Null device or config pointer */
#define CCSDS_HAL_ERR_BAD_VERSION           -2   /**< Unexpected CORE_ID_VER readback */
#define CCSDS_HAL_ERR_MOD_LINE_INCOMPAT    -10   /**< QPSK/OQPSK paired with Bi-Phi-L (violates CCSDS 401.0-B-32) */
#define CCSDS_HAL_ERR_SRRC_BIPHI_INCOMPAT  -11   /**< 4-SPS SRRC filter enabled with Bi-Phi-L Manchester coding */
#define CCSDS_HAL_ERR_GARDNER_REQUIRES_4SPS -12  /**< 4-SPS Gardner TED enabled without 4-SPS SRRC filter */
#define CCSDS_HAL_ERR_PROTO_FEC_INCOMPAT   -13   /**< Protocol paired with incompatible Uplink/Downlink FEC mode */
#define CCSDS_HAL_ERR_CRC32_PROTO_INCOMPAT -14   /**< 32-bit FECF enabled on TM/AOS/TC or disabled on Proximity-1 */
#define CCSDS_HAL_ERR_AOS_FHEC_INCOMPAT    -15   /**< AOS FHEC enabled when protocol is not AOS or USLP */
#define CCSDS_HAL_ERR_RS_PARAM_RANGE       -16   /**< RS interleave I not in {1,2,3,4,5,8} or Q > 215 */
#define CCSDS_HAL_ERR_FRAME_LEN_RANGE      -17   /**< TFDF length not in [1..1024] or COP-1 window W not in [1..128] */

/* ========================================================================== */
/* 3. Enumerations & Configuration Structures                                 */
/* ========================================================================== */
typedef enum {
    CCSDS_PROTO_TM    = 0U, /**< CCSDS 132.0-B-3 Telemetry Transfer Frame */
    CCSDS_PROTO_AOS   = 1U, /**< CCSDS 732.0-B-4 Advanced Orbiting Systems */
    CCSDS_PROTO_TC    = 2U, /**< CCSDS 232.0-B-4 Telecommand Transfer Frame */
    CCSDS_PROTO_USLP  = 3U, /**< CCSDS 732.1-B-3 Unified Space Data Link Protocol */
    CCSDS_PROTO_PROX1 = 4U  /**< CCSDS 211.0-B-6 Proximity-1 Space Link Protocol */
} ccsds_proto_mode_t;

typedef enum {
    CCSDS_FEC_NONE          = 0U,
    CCSDS_FEC_BCH_63_56     = 1U,
    CCSDS_FEC_CONV_K7_R1_2  = 2U,
    CCSDS_FEC_RS_255_223    = 3U,
    CCSDS_FEC_CONCAT_RS_CNV = 4U,
    CCSDS_FEC_TURBO_R1_2    = 5U,
    CCSDS_FEC_TURBO_R1_3    = 6U,
    CCSDS_FEC_TURBO_R1_4    = 7U,
    CCSDS_FEC_TURBO_R1_6    = 8U,
    CCSDS_FEC_LDPC_AR4JA_12 = 9U,
    CCSDS_FEC_LDPC_AR4JA_23 = 10U,
    CCSDS_FEC_LDPC_AR4JA_45 = 11U,
    CCSDS_FEC_LDPC_UL_128   = 12U,
    CCSDS_FEC_LDPC_UL_512   = 13U
} ccsds_fec_mode_t;

typedef enum {
    CCSDS_MOD_BPSK   = 0U, /**< CCSDS 401.0-B-32 Suppressed-Carrier BPSK */
    CCSDS_MOD_QPSK   = 1U, /**< CCSDS 401.0-B-32 QPSK */
    CCSDS_MOD_OQPSK  = 2U, /**< CCSDS 401.0-B-32 Offset QPSK (half-symbol Q delay) */
    CCSDS_MOD_PCM_PM = 3U  /**< CCSDS 401.0-B-32 Residual-Carrier PCM/PSK/PM */
} ccsds_mod_mode_t;

typedef enum {
    CCSDS_LINE_NRZ_L   = 0U, /**< Non-Return-to-Zero Level */
    CCSDS_LINE_NRZ_M   = 1U, /**< Non-Return-to-Zero Mark (differential) */
    CCSDS_LINE_BIPHI_L = 2U  /**< Bi-Phase-Level (Manchester split-phase; BPSK/PCM-PM only) */
} ccsds_line_code_t;

typedef enum {
    CCSDS_KABAND_NONE_OR_SX = 0U, /**< S-band (240/221) or X-band (880/749) via strap */
    CCSDS_KABAND_CAT_A_3328 = 1U, /**< Ka-band Near-Earth Category A (3328/749) */
    CCSDS_KABAND_CAT_B_3344 = 2U, /**< Ka-band Deep-Space Category B (3344/749) */
    CCSDS_KABAND_CAT_B_3360 = 3U  /**< Ka-band Deep-Space Alt Category B (3360/749) */
} ccsds_kaband_mode_t;

typedef struct {
    volatile uint32_t *base_addr;
} ccsds_ttc_dev_t;

typedef struct {
    uint16_t            scid_10b;
    uint16_t            uslp_scid_16b;
    ccsds_proto_mode_t  proto_mode;
    ccsds_fec_mode_t    fec_mode;
    ccsds_mod_mode_t    mod_mode;
    ccsds_line_code_t   line_code;
    bool                ocf_en;
    bool                fecf_en;
    bool                fecf_crc32;
    bool                aos_fhec_en;
    bool                tc_seg_hdr_present;
    bool                obt_sec_hdr_en;
    bool                sdls_en;
    bool                bc_require_sdls;
    uint8_t             window_half_w;
    uint8_t             rs_interleave_i;
    uint8_t             rs_virt_fill_q;
    uint16_t            tfdf_byte_len;
    ccsds_kaband_mode_t turnaround_kaband;
    bool                srrc_4sps_en;
    bool                gardner_ted_en;
    bool                sdls_gcm_mode;
    bool                fll_assist_en;
    bool                tm_rand_en;
    bool                fault_irq_en;
} ccsds_ttc_config_t;

typedef struct {
    uint8_t vcid;
    bool    no_rf_avail;
    bool    no_bit_lock;
    bool    lockout;
    bool    wait_flag;
    bool    retransmit;
    uint8_t farm_b_counter;
    uint8_t report_value;
} ccsds_clcw_status_t;

typedef struct {
    uint16_t secded_bch_single_corr_cnt;
    uint16_t tmr_seu_corrected_cnt;
    uint16_t uncorr_frame_pkt_err_cnt;
    uint16_t sdls_mac_err_cnt;
} ccsds_err_telemetry_t;

/* ========================================================================== */
/* 4. Public HAL Driver API Prototypes                                        */
/* ========================================================================== */
int      ccsds_ttc_hal_init(ccsds_ttc_dev_t *dev, volatile uint32_t *base_addr);
int      ccsds_ttc_hal_validate_config(const ccsds_ttc_config_t *cfg);
int      ccsds_ttc_hal_configure(const ccsds_ttc_dev_t *dev, const ccsds_ttc_config_t *cfg);
void     ccsds_ttc_hal_get_config(const ccsds_ttc_dev_t *dev, ccsds_ttc_config_t *cfg_out);

int      ccsds_ttc_hal_set_sdls_key256(const ccsds_ttc_dev_t *dev, const uint32_t key_words[8]);
int      ccsds_ttc_hal_provision_sdls_sa(const ccsds_ttc_dev_t *dev,
                                         uint8_t vcid_addr,
                                         uint16_t spi,
                                         uint32_t seq_low,
                                         uint16_t tx_default_spi);

void     ccsds_ttc_hal_get_clcw(const ccsds_ttc_dev_t *dev, ccsds_clcw_status_t *clcw_out);
uint64_t ccsds_ttc_hal_get_obt_cuc48(const ccsds_ttc_dev_t *dev);
void     ccsds_ttc_hal_set_obt_cuc48(const ccsds_ttc_dev_t *dev, uint32_t coarse_sec, uint16_t fine_subsec);

void     ccsds_ttc_hal_get_error_telemetry(const ccsds_ttc_dev_t *dev, ccsds_err_telemetry_t *err_out);
void     ccsds_ttc_hal_clear_error_telemetry(const ccsds_ttc_dev_t *dev,
                                             bool clr_edac,
                                             bool clr_tmr,
                                             bool clr_uncorr,
                                             bool clr_sdls);

uint32_t ccsds_ttc_hal_reg_read(const ccsds_ttc_dev_t *dev, uint32_t reg_offset);
void     ccsds_ttc_hal_reg_write(const ccsds_ttc_dev_t *dev, uint32_t reg_offset, uint32_t val);

#ifdef __cplusplus
}
#endif

#endif /* CCSDS_TTC_HAL_H */
