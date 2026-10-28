/**
 * @file ccsds_ttc_hal.h
 * @brief Zero-Dependency Bare-Metal C11 Flight OBC & Ground EGSE Hardware
 *        Abstraction Layer (HAL) SDK for the CCSDS-SAT-TTC-IP Core (v2.33.0).
 *
 * Strictly bit-accurate against rtl/ccsds_axi_lite_csr.sv (0x00..0x24):
 *   - 0x00 : CORE_ID_VER        (RO) 0xCC5D0230
 *   - 0x04 : CTRL_SCID_PROTO    (RW, TMR) [9:0]=SCID, [14:12]=PROTO, [19:16]=FEC,
 *                                         [20]=OCF, [21]=FECF, [22]=CRC32, [23]=AOS_FHEC,
 *                                         [24]=TC_SEG_HDR, [25]=OBT_EN, [26]=SDLS_EN,
 *                                         [27]=BC_REQ_SDLS, [28]=SRRC_4SPS_EN,
 *                                         [29]=GARDNER_TED_EN, [31:30]=TURNAROUND_KABAND_CFG
 *   - 0x08 : CTRL_USLP_RS_CFG   (RW, TMR) [15:0]=USLP_SCID, [19:16]=RS_I, [27:20]=RS_Q,
 *                                         [28]=SDLS_GCM_MODE_CFG, [29]=FLL_ASSIST_EN_CFG
 *   - 0x0C : CTRL_COP1_TFDF_CFG (RW, TMR) [7:0]=WIN_W, [18:8]=TFDF_LEN, [24]=IRQ_EN
 *   - 0x10 : OBT_COARSE_SEC     (RW) 32-bit CUC Coarse Seconds
 *   - 0x14 : OBT_FINE_SUBSEC    (RW) [15:0] 16-bit CUC Fine Sub-seconds
 *   - 0x18 : EDAC_CORR_CNTS     (RO/W1C) [15:0]=SECDED/BCH 1b Corr Cnt, [31:16]=TMR SEU Corr Cnt
 *   - 0x1C : FAULT_ERR_CNTS     (RO/W1C) [15:0]=Uncorr FEC/CRC/Pkt Err Cnt, [31:16]=SDLS MAC Err Cnt
 *   - 0x20 : LATEST_CLCW_MON    (RO) Latest 32-bit COP-1 CLCW word
 *   - 0x24 : LATEST_PLCW_MON    (RO) Latest 32-bit Proximity-1 PLCW word
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
#define CCSDS_REG_CTRL_USLP_RS_CFG   0x08U /**< RW (TMR): 16b USLP SCID, RS(I,Q), SDLS GCM, FLL Assist */
#define CCSDS_REG_CTRL_COP1_TFDF_CFG 0x0CU /**< RW (TMR): COP-1 Window W, TFDF byte len, Fault IRQ Enable */
#define CCSDS_REG_OBT_COARSE_SEC     0x10U /**< RW: 32-bit CUC Coarse Seconds [47:16] */
#define CCSDS_REG_OBT_FINE_SUBSEC    0x14U /**< RW: 16-bit CUC Fine Sub-seconds [15:0] */
#define CCSDS_REG_EDAC_CORR_CNTS     0x18U /**< RO/W1C: [15:0] SECDED/BCH 1b Corr, [31:16] TMR SEU Corr */
#define CCSDS_REG_FAULT_ERR_CNTS     0x1CU /**< RO/W1C: [15:0] Uncorr FEC/CRC/Pkt Err, [31:16] SDLS MAC Err */
#define CCSDS_REG_LATEST_CLCW_MON    0x20U /**< RO: Latest scheduled 32-bit COP-1 CLCW */
#define CCSDS_REG_LATEST_PLCW_MON    0x24U /**< RO: Latest scheduled 32-bit Proximity-1 PLCW */

/* Legacy macro aliases for source compatibility */
#define CCSDS_REG_VERSION_ID         CCSDS_REG_CORE_ID_VER
#define CCSDS_REG_SCID_CFG           CCSDS_REG_CTRL_SCID_PROTO
#define CCSDS_REG_PROTO_FEC_CFG      CCSDS_REG_CTRL_USLP_RS_CFG
#define CCSDS_REG_USLP_RS_CFG        CCSDS_REG_CTRL_COP1_TFDF_CFG
#define CCSDS_REG_OBT_CUC_HIGH       CCSDS_REG_OBT_COARSE_SEC
#define CCSDS_REG_OBT_CUC_LOW        CCSDS_REG_OBT_FINE_SUBSEC
#define CCSDS_REG_ERR_COUNTERS_0     CCSDS_REG_EDAC_CORR_CNTS
#define CCSDS_REG_ERR_COUNTERS_1     CCSDS_REG_FAULT_ERR_CNTS
#define CCSDS_REG_LATEST_CLCW        CCSDS_REG_LATEST_CLCW_MON
#define CCSDS_REG_LATEST_PLCW        CCSDS_REG_LATEST_PLCW_MON

#define CCSDS_EXPECTED_VERSION_ID    0xCC5D0230UL

/* ========================================================================== */
/* 2. Enumerations for Protocol, FEC, Turnaround & PHY Modes                  */
/* ========================================================================== */
typedef enum {
    CCSDS_PROTO_TC    = 0U, /**< CCSDS 232.0-B-4 Telecommand Transfer Frame */
    CCSDS_PROTO_TM    = 1U, /**< CCSDS 132.0-B-3 Telemetry Transfer Frame */
    CCSDS_PROTO_AOS   = 2U, /**< CCSDS 732.0-B-4 Advanced Orbiting Systems */
    CCSDS_PROTO_PROX1 = 3U, /**< CCSDS 211.0-B-6 Proximity-1 Space Link */
    CCSDS_PROTO_USLP  = 4U  /**< CCSDS 732.1-B-3 Unified Space Data Link Protocol */
} ccsds_proto_mode_t;

typedef enum {
    CCSDS_FEC_NONE       = 0U, /**< Uncoded / Bypass */
    CCSDS_FEC_BCH_63_56  = 1U, /**< Uplink BCH(63,56) SEC-DED */
    CCSDS_FEC_LDPC_128   = 2U, /**< Uplink Short-Block LDPC(128,64) / (512,256) r=1/2 */
    CCSDS_FEC_RS255_223  = 3U, /**< Downlink Dual-Basis Reed-Solomon (255,223) */
    CCSDS_FEC_CONV_R1_2  = 4U, /**< Convolutional r=1/2, K=7 + Soft Viterbi */
    CCSDS_FEC_TURBO_R1_2 = 5U, /**< CCSDS 131.0-B-5 Turbo Code r=1/2 */
    CCSDS_FEC_TURBO_R1_3 = 6U, /**< CCSDS 131.0-B-5 Turbo Code r=1/3 */
    CCSDS_FEC_TURBO_R1_4 = 7U, /**< CCSDS 131.0-B-5 Turbo Code r=1/4 */
    CCSDS_FEC_TURBO_R1_6 = 8U, /**< CCSDS 131.0-B-5 Turbo Code r=1/6 */
    CCSDS_FEC_DL_LDPC    = 9U  /**< Downlink AR4JA LDPC (r=1/2, 2/3, 4/5, 7/8) */
} ccsds_fec_mode_t;

typedef enum {
    CCSDS_KABAND_OFF        = 0U, /**< Use S-Band (240/221) or X-Band (880/749) strap */
    CCSDS_KABAND_CAT_B_3344 = 1U, /**< Ka-Band Deep-Space Category B (3344/749) */
    CCSDS_KABAND_CAT_A_3360 = 2U  /**< Ka-Band Near-Earth Category A (3360/749) */
} ccsds_kaband_mode_t;

/* ========================================================================== */
/* 3. Configuration & Telemetry Structures                                    */
/* ========================================================================== */
typedef struct {
    volatile uint32_t *base_addr; /**< Memory-mapped AXI4-Lite base address */
} ccsds_ttc_dev_t;

typedef struct {
    uint16_t            scid_10b;            /**< 10-bit TM/TC Spacecraft ID [9:0] */
    uint16_t            uslp_scid_16b;       /**< 16-bit USLP/AOS Spacecraft ID [15:0] */
    ccsds_proto_mode_t  proto_mode;          /**< Active link protocol [14:12] */
    ccsds_fec_mode_t    fec_mode;            /**< Active FEC mode [19:16] */
    bool                ocf_en;              /**< Enable 32-bit OCF (CLCW) trailer [20] */
    bool                fecf_en;             /**< Enable 16/32-bit FECF CRC trailer [21] */
    bool                fecf_crc32;          /**< 0: CRC-16-CCITT, 1: CRC-32 (Prox-1) [22] */
    bool                aos_fhec_en;         /**< Enable AOS GF(2^4) RS(10,6) FHEC [23] */
    bool                tc_seg_hdr_present;  /**< TC Segment Header present [24] */
    bool                obt_sec_hdr_en;      /**< Enable 48-bit CUC OBT Secondary Header [25] */
    bool                sdls_en;             /**< Enable CCSDS 355.0-B-2 SDLS Security [26] */
    bool                bc_require_sdls;     /**< Require SDLS on Type-BC frames [27] */
    bool                srrc_4sps_en;        /**< Enable 4-SPS 17-tap SRRC FIR [28] */
    bool                gardner_ted_en;      /**< Enable 4-SPS Gardner TED [29] */
    ccsds_kaband_mode_t turnaround_kaband;   /**< Ka-Band turnaround ratio [31:30] */
    uint8_t             rs_interleave_i;     /**< RS(255,223) interleave depth I (1..8) */
    uint8_t             rs_virt_fill_q;      /**< RS(255,223) virtual fill bytes Q */
    bool                sdls_gcm_mode;       /**< Enable 128-bit AES-128-GCM GHASH */
    bool                fll_assist_en;       /**< Enable FLL-Assisted Costas Loop */
    uint8_t             window_half_w;       /**< COP-1 FARM-1 sliding window W */
    uint16_t            tfdf_byte_len;       /**< Transfer Frame Data Field byte length */
    bool                fault_irq_en;        /**< Enable fault_irq_out interrupt [24] */
} ccsds_ttc_config_t;

typedef struct {
    uint8_t vcid;
    bool    no_rf_avail;
    bool    no_bit_lock;
    bool    lockout;
    bool    wait_flag;
    bool    retransmit;
    uint8_t farm_b_counter;
    uint8_t report_value; /**< V(R) Next Expected Frame Sequence Number */
} ccsds_clcw_status_t;

typedef struct {
    uint16_t secded_bch_single_corr_cnt; /**< 16-bit saturating SECDED/BCH 1b corrected count */
    uint16_t tmr_seu_corrected_cnt;      /**< 16-bit saturating TMR SEU auto-scrubbed count */
    uint16_t uncorr_frame_pkt_err_cnt;   /**< 16-bit saturating uncorrectable FEC/CRC/Pkt error count */
    uint16_t sdls_mac_err_cnt;           /**< 16-bit saturating SDLS CMAC/GMAC authentication reject count */
} ccsds_err_telemetry_t;

/* ========================================================================== */
/* 4. Public HAL API Functions                                                */
/* ========================================================================== */
int      ccsds_ttc_hal_init(ccsds_ttc_dev_t *dev, volatile uint32_t *base_addr);
uint32_t ccsds_ttc_hal_reg_read(const ccsds_ttc_dev_t *dev, uint32_t reg_offset);
void     ccsds_ttc_hal_reg_write(const ccsds_ttc_dev_t *dev, uint32_t reg_offset, uint32_t val);
int      ccsds_ttc_hal_configure(const ccsds_ttc_dev_t *dev, const ccsds_ttc_config_t *cfg);
void     ccsds_ttc_hal_get_config(const ccsds_ttc_dev_t *dev, ccsds_ttc_config_t *cfg_out);
void     ccsds_ttc_hal_get_clcw(const ccsds_ttc_dev_t *dev, ccsds_clcw_status_t *clcw_out);
uint64_t ccsds_ttc_hal_get_obt_cuc48(const ccsds_ttc_dev_t *dev);
void     ccsds_ttc_hal_set_obt_cuc48(const ccsds_ttc_dev_t *dev, uint32_t coarse_sec, uint16_t fine_subsec);
void     ccsds_ttc_hal_get_error_telemetry(const ccsds_ttc_dev_t *dev, ccsds_err_telemetry_t *err_out);
void     ccsds_ttc_hal_clear_error_telemetry(const ccsds_ttc_dev_t *dev, bool clr_edac, bool clr_tmr, bool clr_uncorr, bool clr_sdls);

#ifdef __cplusplus
}
#endif

#endif /* CCSDS_TTC_HAL_H */
