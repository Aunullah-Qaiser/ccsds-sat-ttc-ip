/**
 * @file ccsds_ttc_hal.h
 * @brief Zero-Dependency Bare-Metal C11 Flight OBC & Ground EGSE Hardware
 *        Abstraction Layer (HAL) SDK for the CCSDS-SAT-TTC-IP Core (v2.28.0).
 *
 * Covers all TMR-protected AXI4-Lite Control & Status Registers (`0x00..0x24`),
 * runtime protocol/FEC/PHY/SDLS configuration, CLCW/PLCW telemetry unpacking,
 * and EDAC/TMR SEU fault counter polling.
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
/* 1. AXI4-Lite Register Map Offsets (Byte Addresses)                         */
/* ========================================================================== */
#define CCSDS_REG_VERSION_ID        0x00U /**< RO: Core ID & Version (0xCC5D0230) */
#define CCSDS_REG_SCID_CFG          0x04U /**< RW (TMR): [9:0] 10b SCID, [31:16] 16b USLP SCID */
#define CCSDS_REG_PROTO_FEC_CFG     0x08U /**< RW (TMR): Protocol, FEC, OCF/FECF, SDLS, Window */
#define CCSDS_REG_USLP_RS_CFG       0x0CU /**< RW (TMR): RS(I,Q), TFDF len, Ka-Band, SRRC, Gardner, GCM, FLL */
#define CCSDS_REG_LATEST_CLCW       0x10U /**< RO: Latest scheduled 32-bit COP-1 CLCW */
#define CCSDS_REG_LATEST_PLCW       0x14U /**< RO: Latest scheduled 32-bit Proximity-1 PLCW */
#define CCSDS_REG_OBT_CUC_LOW       0x18U /**< RO: 48-bit CUC On-Board Time [31:0] */
#define CCSDS_REG_OBT_CUC_HIGH      0x1CU /**< RO: 48-bit CUC On-Board Time [47:32] */
#define CCSDS_REG_ERR_COUNTERS_0    0x20U /**< RO: [31:24] BCH1, [23:16] BCH2, [15:8] ECC1, [7:0] ECC2 */
#define CCSDS_REG_ERR_COUNTERS_1    0x24U /**< RO: [31:24] TMR_SEU, [23:16] CRC_Err, [15:8] Pkt_Err, [7:0] SDLS_Err */

#define CCSDS_EXPECTED_VERSION_ID   0xCC5D0230UL

/* ========================================================================== */
/* 2. Enumerations for Protocol, FEC, Turnaround & PHY Modes                  */
/* ========================================================================== */
typedef enum {
    CCSDS_PROTO_TM    = 0U, /**< CCSDS 132.0-B-3 Telemetry Transfer Frame */
    CCSDS_PROTO_AOS   = 1U, /**< CCSDS 732.0-B-4 Advanced Orbiting Systems */
    CCSDS_PROTO_PROX1 = 2U, /**< CCSDS 211.0-B-6 Proximity-1 Space Link */
    CCSDS_PROTO_USLP  = 3U  /**< CCSDS 732.1-B-3 Unified Space Data Link Protocol */
} ccsds_proto_mode_t;

typedef enum {
    CCSDS_FEC_RS255_223  = 0U, /**< Dual-Basis Reed-Solomon (255,223) */
    CCSDS_FEC_LDPC_128   = 1U, /**< CCSDS 231.1-O-1 / 131.0-B-5 LDPC r=1/2 */
    CCSDS_FEC_TURBO_R1_2 = 2U, /**< CCSDS 131.0-B-5 Turbo Code r=1/2 */
    CCSDS_FEC_TURBO_R1_3 = 3U, /**< CCSDS 131.0-B-5 Turbo Code r=1/3 */
    CCSDS_FEC_TURBO_R1_4 = 4U, /**< CCSDS 131.0-B-5 Turbo Code r=1/4 */
    CCSDS_FEC_TURBO_R1_6 = 5U  /**< CCSDS 131.0-B-5 Turbo Code r=1/6 */
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
    uint16_t            scid_10b;            /**< 10-bit TM/TC Spacecraft ID */
    uint16_t            uslp_scid_16b;       /**< 16-bit USLP/AOS Spacecraft ID */
    ccsds_proto_mode_t  proto_mode;          /**< Active downlink/link protocol */
    ccsds_fec_mode_t    fec_mode;            /**< Active downlink outer FEC mode */
    bool                ocf_en;              /**< Enable 32-bit OCF (CLCW) trailer */
    bool                fecf_en;             /**< Enable 16/32-bit FECF CRC trailer */
    bool                fecf_crc32;          /**< 0: CRC-16-CCITT, 1: CRC-32C (USLP) */
    bool                aos_fhec_en;         /**< Enable AOS GF(2^4) RS(10,6) FHEC */
    bool                tc_seg_hdr_present;  /**< TC Segment Header present */
    bool                obt_sec_hdr_en;      /**< Enable 48-bit CUC OBT Secondary Header */
    bool                sdls_en;             /**< Enable CCSDS 355.0-B-2 SDLS Security */
    bool                bc_require_sdls;     /**< Require SDLS on Type-BC frames */
    uint8_t             window_half_w;       /**< COP-1 FARM-1 sliding window W */
    uint8_t             rs_interleave_i;     /**< RS(255,223) interleave depth I (1..8) */
    uint8_t             rs_virt_fill_q;      /**< RS(255,223) virtual fill bytes Q */
    uint16_t            tfdf_byte_len;       /**< Transfer Frame Data Field byte length */
    ccsds_kaband_mode_t turnaround_kaband;   /**< Ka-Band turnaround ratio (Milestone 2) */
    bool                srrc_4sps_en;        /**< Enable 4-SPS 17-tap SRRC FIR */
    bool                gardner_ted_en;      /**< Enable 4-SPS Gardner TED (Milestone 2) */
    bool                sdls_gcm_mode;       /**< Enable 128-bit AES-128-GCM GHASH (Milestone 3) */
    bool                fll_assist_en;       /**< Enable FLL-Assisted Costas Loop (Milestone 4) */
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
    uint8_t bch_single_err_cnt;
    uint8_t bch_double_abort_cnt;
    uint8_t fifo_secded_single_cnt;
    uint8_t fifo_secded_double_cnt;
    uint8_t tmr_seu_corrected_cnt;
    uint8_t frame_crc_err_cnt;
    uint8_t pkt_len_err_cnt;
    uint8_t sdls_mac_err_cnt;
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
void     ccsds_ttc_hal_get_error_telemetry(const ccsds_ttc_dev_t *dev, ccsds_err_telemetry_t *err_out);

#ifdef __cplusplus
}
#endif

#endif /* CCSDS_TTC_HAL_H */
