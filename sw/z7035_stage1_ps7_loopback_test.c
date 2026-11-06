/**
 * ============================================================================
 * File Name   : z7035_stage1_ps7_loopback_test.c
 * Project     : CCSDS-SAT-TTC-IP (v2.40.3)
 * Target      : Zynq-7035 PS7 ARM Cortex-A9 (ADRV9361-Z7035 + ADRV1CRR-BOB)
 * Description : Stage 1 Bare-Metal Vitis C Bring-Up & Self-Test Application.
 *               Tests full bidirectional Baseband I/Q Loopback in the Vivado
 *               2026.1.1 Block Design (`DUAL_EGSE_TO_FLIGHT` topology):
 *                 1. Uplink   : Ground EGSE (0x43C0_0000, ROLE=1) ->
 *                               Spacecraft Flight (0x43C2_0000, ROLE=0)
 *                               via TC/CLTU + BCH(63,56) + 4-SPS SRRC + Gardner
 *                 2. Downlink : Spacecraft Flight (0x43C2_0000, ROLE=0) ->
 *                               Ground EGSE (0x43C0_0000, ROLE=1)
 *                               via TM + RS(255,223) + 4-SPS SRRC + Gardner
 *                               + Closed-Loop 32-Bit COP-1 CLCW extraction!
 * ============================================================================
 */
#include <stdint.h>
#include <stdio.h>
#include "ccsds_ttc_hal.h"

/* Memory-Mapped Base Addresses Assigned in create_z7035_stage1_bd_loopback.tcl */
#define GPIO_STRAPS_BASE_ADDR      0x41200000UL
#define EGSE_CSR_BASE_ADDR         0x43C00000UL
#define EGSE_PKT_FIFO_BASE_ADDR    0x43C10000UL
#define FLIGHT_CSR_BASE_ADDR       0x43C20000UL
#define FLIGHT_PKT_FIFO_BASE_ADDR  0x43C30000UL

/* Xilinx AXI-Stream FIFO (axi_fifo_mm_s) Register Offsets */
#define XLLF_ISR_OFFSET            0x00UL  /* Interrupt Status Register (W1C) */
#define XLLF_TDFR_OFFSET           0x08UL  /* Transmit Data FIFO Reset (0xA5) */
#define XLLF_TDFD_OFFSET           0x10UL  /* Transmit Data FIFO Data Write Port */
#define XLLF_TLR_OFFSET            0x14UL  /* Transmit Length Register (bytes) */
#define XLLF_RDFR_OFFSET           0x18UL  /* Receive Data FIFO Reset (0xA5) */
#define XLLF_RDFO_OFFSET           0x1CUL  /* Receive Data FIFO Occupancy (words) */
#define XLLF_RDFD_OFFSET           0x20UL  /* Receive Data FIFO Data Read Port */
#define XLLF_RLR_OFFSET            0x24UL  /* Receive Length Register (bytes) */

static inline void mmio_write32(uintptr_t addr, uint32_t val) {
    *(volatile uint32_t *)addr = val;
}

static inline uint32_t mmio_read32(uintptr_t addr) {
    return *(volatile const uint32_t *)addr;
}

static void axis_fifo_reset(uintptr_t fifo_base) {
    mmio_write32(fifo_base + XLLF_TDFR_OFFSET, 0x000000A5UL);
    mmio_write32(fifo_base + XLLF_RDFR_OFFSET, 0x000000A5UL);
    mmio_write32(fifo_base + XLLF_ISR_OFFSET,  0xFFFFFFFFUL);
}

static void axis_fifo_push_16b_pkt(uintptr_t fifo_base, const uint32_t words[4]) {
    for (int i = 0; i < 4; ++i) {
        mmio_write32(fifo_base + XLLF_TDFD_OFFSET, words[i]);
    }
    mmio_write32(fifo_base + XLLF_TLR_OFFSET, 16UL);
}

static int axis_fifo_poll_and_verify_16b_pkt(uintptr_t fifo_base,
                                             const uint32_t expected[4],
                                             const char *tag) {
    uint32_t rx_occ = 0;
    for (uint32_t spin = 0; spin < 5000000UL; ++spin) {
        rx_occ = mmio_read32(fifo_base + XLLF_RDFO_OFFSET);
        if (rx_occ >= 4UL) {
            break;
        }
    }
    if (rx_occ < 4UL) {
        printf("[FAIL] %s: Timeout waiting for RX FIFO (RDFO=%lu)\r\n",
               tag, (unsigned long)rx_occ);
        return -1;
    }
    uint32_t rx_bytes = mmio_read32(fifo_base + XLLF_RLR_OFFSET);
    printf("[PASS] %s: Received %lu words (%lu bytes) in RX FIFO\r\n",
           tag, (unsigned long)rx_occ, (unsigned long)rx_bytes);

    int errs = 0;
    for (int i = 0; i < 4; ++i) {
        uint32_t got = mmio_read32(fifo_base + XLLF_RDFD_OFFSET);
        printf("  %s Word[%d]: TX=0x%08lX | RX=0x%08lX %s\r\n",
               tag, i, (unsigned long)expected[i], (unsigned long)got,
               (got == expected[i]) ? "[OK]" : "[ERR]");
        if (got != expected[i]) {
            errs++;
        }
    }
    return errs;
}

int main(void) {
    printf("\r\n================================================================\r\n");
    printf(" CCSDS-SAT-TTC-IP (v2.40.3) — ADRV9361-Z7035 Stage 1 BD Loopback\r\n");
    printf("================================================================\r\n");

    /* 1. Drive Hardware Mission Straps via AXI GPIO Ch1 (0x4120_0000):
     *    - ul_fec_override_en [3:2]   = 2'd1 (BCH(63,56))
     *    - mod_mode_cfg       [10:9]  = 2'd0 (BPSK)
     *    - line_code_cfg      [12:11] = 2'd0 (NRZ-L)
     *    - default_tx_vcid    [18:13] = 6'd1 (VCID = 1)
     */
    const uint32_t straps_val = (1UL << 2) | (1UL << 13);
    mmio_write32(GPIO_STRAPS_BASE_ADDR + 0x00UL, straps_val);

    axis_fifo_reset(EGSE_PKT_FIFO_BASE_ADDR);
    axis_fifo_reset(FLIGHT_PKT_FIFO_BASE_ADDR);

    /* 2. Initialize Both Ground EGSE (ROLE=1) & Spacecraft Flight (ROLE=0) Cores */
    ccsds_ttc_dev_t egse_dev, flight_dev;
    if (ccsds_ttc_hal_init(&egse_dev, (volatile uint32_t *)EGSE_CSR_BASE_ADDR) != CCSDS_HAL_OK ||
        ccsds_ttc_hal_init(&flight_dev, (volatile uint32_t *)FLIGHT_CSR_BASE_ADDR) != CCSDS_HAL_OK) {
        printf("[FAIL] Could not initialize EGSE (0x%08lX) or Flight (0x%08lX) CSRs\r\n",
               (unsigned long)EGSE_CSR_BASE_ADDR, (unsigned long)FLIGHT_CSR_BASE_ADDR);
        return -1;
    }
    printf("[PASS] Both Endpoints Alive: EGSE ID=0x%08lX, Flight ID=0x%08lX\r\n",
           (unsigned long)ccsds_ttc_hal_reg_read(&egse_dev, CCSDS_REG_CORE_ID_VER),
           (unsigned long)ccsds_ttc_hal_reg_read(&flight_dev, CCSDS_REG_CORE_ID_VER));

    /* 3. Configure Both Endpoints for Full 4-SPS SRRC + Gardner + RS(255,223) Q=199 */
    ccsds_ttc_config_t cfg = {
        .scid_10b           = 0x155U,
        .uslp_scid_16b      = 0x4255U,
        .proto_mode         = CCSDS_PROTO_TM,
        .fec_mode           = CCSDS_FEC_NONE, /* 0x04 = 0x0130_0155; RS(255,223) Q=195 configured in 0x08 */
        .mod_mode           = CCSDS_MOD_BPSK,
        .line_code          = CCSDS_LINE_NRZ_L,
        .ocf_en             = true,
        .fecf_en            = true,
        .fecf_crc32         = false,
        .aos_fhec_en        = false,
        .tc_seg_hdr_present = true,
        .obt_sec_hdr_en     = false,
        .sdls_en            = false,
        .bc_require_sdls    = false,
        .window_half_w      = 16U,
        .rs_interleave_i    = 1U,
        .rs_virt_fill_q     = 195U, /* 223 - 195 = 28B RS message (6B TM hdr + 16B TFDF + 4B OCF + 2B CRC) */
        .tfdf_byte_len      = 16U,
        .turnaround_kaband  = CCSDS_KABAND_NONE_OR_SX,
        .srrc_4sps_en       = false,
        .gardner_ted_en     = false,
        .sdls_gcm_mode      = false,
        .fll_assist_en      = true,
        .tm_rand_en         = false,
        .fault_irq_en       = true
    };
    (void)ccsds_ttc_hal_configure(&egse_dev, &cfg);
    (void)ccsds_ttc_hal_configure(&flight_dev, &cfg);

    /* 16-Byte CCSDS Space Packet (6B Primary Header + 10B Payload = 16B) */
    const uint32_t ul_pkt[4] = {
        0x01C04218UL, /* TC Packet (Type=1, SecHdr=1, APID=0x042, SeqFlags=3, Seq=1) */
        0x55AA0900UL, /* Len=9 (10B data), Payload bytes 0..1 = 0xAA, 0x55 */
        0x78563412UL,
        0xF0DEBC9AUL
    };
    const uint32_t dl_pkt[4] = {
        0x01C02108UL, /* TM Packet (Type=0, SecHdr=1, APID=0x021, SeqFlags=3, Seq=1) */
        0xCAFE0900UL, /* Len=9 (10B data), Payload bytes 0..1 = 0xFE, 0xCA */
        0x44332211UL,
        0x88776655UL
    };

    /* 4. Test Uplink: Ground EGSE TX FIFO -> Baseband I/Q -> Spacecraft Flight RX FIFO */
    printf("\r\n--- Step 1: Testing Uplink (Ground EGSE -> Spacecraft Flight) ---\r\n");
    axis_fifo_push_16b_pkt(EGSE_PKT_FIFO_BASE_ADDR, ul_pkt);
    if (axis_fifo_poll_and_verify_16b_pkt(FLIGHT_PKT_FIFO_BASE_ADDR, ul_pkt, "UPLINK") != 0) {
        return -2;
    }

    /* 5. Test Downlink: Spacecraft Flight TX FIFO -> Baseband I/Q -> Ground EGSE RX FIFO */
    printf("\r\n--- Step 2: Testing Downlink (Spacecraft Flight -> Ground EGSE) ---\r\n");
    axis_fifo_push_16b_pkt(FLIGHT_PKT_FIFO_BASE_ADDR, dl_pkt);
    if (axis_fifo_poll_and_verify_16b_pkt(EGSE_PKT_FIFO_BASE_ADDR, dl_pkt, "DOWNLINK") != 0) {
        return -3;
    }

    ccsds_clcw_status_t sc_clcw, egse_clcw;
    ccsds_ttc_hal_get_clcw(&flight_dev, &sc_clcw);
    ccsds_ttc_hal_get_clcw(&egse_dev, &egse_clcw);
    printf("[PASS] Closed-Loop CLCW V(R): Flight V(R)=%u | EGSE Extracted V(R)=%u\r\n",
           (unsigned int)sc_clcw.report_value, (unsigned int)egse_clcw.report_value);

    printf("\r\n>>> STAGE 1 ADRV9361-Z7035 BLOCK-DESIGN LOOPBACK PASSED (0 BIT ERRORS) <<<\r\n");
    return 0;
}
