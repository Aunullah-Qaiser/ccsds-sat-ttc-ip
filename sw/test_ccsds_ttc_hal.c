/**
 * @file test_ccsds_ttc_hal.c
 * @brief Unit, register-map, and CCSDS Blue Book firmware configuration gating
 *        verification test for the C11 Flight/EGSE HAL SDK (v2.36.0).
 */

#include "ccsds_ttc_hal.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

int main(void)
{
    volatile uint32_t mock_axi_regs[32];
    ccsds_ttc_dev_t dev;
    ccsds_ttc_config_t cfg_in, cfg_out, bad_cfg;
    ccsds_clcw_status_t clcw;
    ccsds_err_telemetry_t err_tlm;
    const uint32_t test_key[8] = {
        0x1C1D1E1FUL, 0x18191A1BUL, 0x14151617UL, 0x10111213UL,
        0x0C0D0E0FUL, 0x08090A0BUL, 0x04050607UL, 0x00010203UL
    };

    memset((void *)mock_axi_regs, 0, sizeof(mock_axi_regs));
    mock_axi_regs[CCSDS_REG_CORE_ID_VER     >> 2U] = CCSDS_EXPECTED_VERSION_ID;
    mock_axi_regs[CCSDS_REG_OBT_COARSE_SEC  >> 2U] = 0x65300042UL;
    mock_axi_regs[CCSDS_REG_OBT_FINE_SUBSEC >> 2U] = 0x00008000UL;
    mock_axi_regs[CCSDS_REG_EDAC_CORR_CNTS  >> 2U] = (0x0002UL << 16U) | 0x0004UL;
    mock_axi_regs[CCSDS_REG_FAULT_ERR_CNTS  >> 2U] = (0x0003UL << 16U) | 0x0001UL;
    mock_axi_regs[CCSDS_REG_LATEST_CLCW_MON >> 2U] = (1UL << 18U) | (1UL << 11U) | (2UL << 9U) | 0x05UL;

    assert(ccsds_ttc_hal_init(&dev, mock_axi_regs) == CCSDS_HAL_OK);

    /* 1. Verify valid full-featured USLP configuration */
    memset(&cfg_in, 0, sizeof(cfg_in));
    cfg_in.scid_10b           = 0x155U;
    cfg_in.uslp_scid_16b      = 0x4255U;
    cfg_in.proto_mode         = CCSDS_PROTO_USLP;
    cfg_in.fec_mode           = CCSDS_FEC_TURBO_R1_4;
    cfg_in.mod_mode           = CCSDS_MOD_QPSK;
    cfg_in.line_code          = CCSDS_LINE_NRZ_M;
    cfg_in.ocf_en             = true;
    cfg_in.fecf_en            = true;
    cfg_in.fecf_crc32         = true;
    cfg_in.aos_fhec_en        = true;
    cfg_in.tc_seg_hdr_present = true;
    cfg_in.obt_sec_hdr_en     = true;
    cfg_in.sdls_en            = true;
    cfg_in.bc_require_sdls    = false;
    cfg_in.window_half_w      = 16U;
    cfg_in.rs_interleave_i    = 4U;
    cfg_in.rs_virt_fill_q     = 195U;
    cfg_in.tfdf_byte_len      = 223U;
    cfg_in.turnaround_kaband  = CCSDS_KABAND_CAT_B_3344;
    cfg_in.srrc_4sps_en       = true;
    cfg_in.gardner_ted_en     = true;
    cfg_in.sdls_gcm_mode      = true;
    cfg_in.fll_assist_en      = true;
    cfg_in.tm_rand_en         = true;
    cfg_in.fault_irq_en       = true;

    assert(ccsds_ttc_hal_configure(&dev, &cfg_in) == CCSDS_HAL_OK);
    ccsds_ttc_hal_get_config(&dev, &cfg_out);

    assert(cfg_out.scid_10b          == 0x155U);
    assert(cfg_out.uslp_scid_16b     == 0x4255U);
    assert(cfg_out.proto_mode        == CCSDS_PROTO_USLP);
    assert(cfg_out.fec_mode          == CCSDS_FEC_TURBO_R1_4);
    assert(cfg_out.ocf_en            == true);
    assert(cfg_out.fecf_en           == true);
    assert(cfg_out.fecf_crc32        == true);
    assert(cfg_out.aos_fhec_en       == true);
    assert(cfg_out.sdls_en           == true);
    assert(cfg_out.window_half_w     == 16U);
    assert(cfg_out.rs_interleave_i   == 4U);
    assert(cfg_out.rs_virt_fill_q    == 195U);
    assert(cfg_out.tfdf_byte_len     == 223U);
    assert(cfg_out.turnaround_kaband == CCSDS_KABAND_CAT_B_3344);
    assert(cfg_out.srrc_4sps_en      == true);
    assert(cfg_out.gardner_ted_en    == true);
    assert(cfg_out.sdls_gcm_mode     == true);
    assert(cfg_out.fll_assist_en     == true);
    assert(cfg_out.tm_rand_en        == true);
    assert(cfg_out.fault_irq_en      == true);

    /* 2. Verify Firmware Configuration Gating rejects all invalid combinations */
    /* Rule 1: QPSK/OQPSK + Bi-Phi-L is forbidden */
    bad_cfg = cfg_in;
    bad_cfg.srrc_4sps_en   = false;
    bad_cfg.gardner_ted_en = false;
    bad_cfg.mod_mode       = CCSDS_MOD_QPSK;
    bad_cfg.line_code      = CCSDS_LINE_BIPHI_L;
    assert(ccsds_ttc_hal_configure(&dev, &bad_cfg) == CCSDS_HAL_ERR_MOD_LINE_INCOMPAT);

    bad_cfg.mod_mode       = CCSDS_MOD_OQPSK;
    assert(ccsds_ttc_hal_configure(&dev, &bad_cfg) == CCSDS_HAL_ERR_MOD_LINE_INCOMPAT);

    /* Rule 2: 4-SPS SRRC + Bi-Phi-L is forbidden even on BPSK */
    bad_cfg = cfg_in;
    bad_cfg.mod_mode       = CCSDS_MOD_BPSK;
    bad_cfg.line_code      = CCSDS_LINE_BIPHI_L;
    bad_cfg.srrc_4sps_en   = true;
    assert(ccsds_ttc_hal_configure(&dev, &bad_cfg) == CCSDS_HAL_ERR_SRRC_BIPHI_INCOMPAT);

    /* Rule 3: Gardner TED without 4-SPS SRRC is forbidden */
    bad_cfg = cfg_in;
    bad_cfg.srrc_4sps_en   = false;
    bad_cfg.gardner_ted_en = true;
    assert(ccsds_ttc_hal_configure(&dev, &bad_cfg) == CCSDS_HAL_ERR_GARDNER_REQUIRES_4SPS);

    /* Rule 4: TC protocol with Downlink RS(255,223) or Turbo is forbidden */
    bad_cfg = cfg_in;
    bad_cfg.proto_mode     = CCSDS_PROTO_TC;
    bad_cfg.fec_mode       = CCSDS_FEC_RS_255_223;
    bad_cfg.fecf_crc32     = false;
    bad_cfg.aos_fhec_en    = false;
    assert(ccsds_ttc_hal_configure(&dev, &bad_cfg) == CCSDS_HAL_ERR_PROTO_FEC_INCOMPAT);

    /* Rule 4B: TM protocol with Uplink BCH(63,56) is forbidden */
    bad_cfg = cfg_in;
    bad_cfg.proto_mode     = CCSDS_PROTO_TM;
    bad_cfg.fec_mode       = CCSDS_FEC_BCH_63_56;
    bad_cfg.fecf_crc32     = false;
    bad_cfg.aos_fhec_en    = false;
    assert(ccsds_ttc_hal_configure(&dev, &bad_cfg) == CCSDS_HAL_ERR_PROTO_FEC_INCOMPAT);

    /* Rule 5: CRC-32 on TM/AOS/TC is forbidden */
    bad_cfg = cfg_in;
    bad_cfg.proto_mode     = CCSDS_PROTO_TM;
    bad_cfg.fec_mode       = CCSDS_FEC_RS_255_223;
    bad_cfg.fecf_crc32     = true;
    bad_cfg.aos_fhec_en    = false;
    assert(ccsds_ttc_hal_configure(&dev, &bad_cfg) == CCSDS_HAL_ERR_CRC32_PROTO_INCOMPAT);

    /* Rule 6: AOS FHEC on TM/TC/Prox-1 is forbidden */
    bad_cfg = cfg_in;
    bad_cfg.proto_mode     = CCSDS_PROTO_TM;
    bad_cfg.fec_mode       = CCSDS_FEC_RS_255_223;
    bad_cfg.fecf_crc32     = false;
    bad_cfg.aos_fhec_en    = true;
    assert(ccsds_ttc_hal_configure(&dev, &bad_cfg) == CCSDS_HAL_ERR_AOS_FHEC_INCOMPAT);

    /* Rule 7: Invalid RS interleave depth I=6 or Q > 215 is forbidden */
    bad_cfg = cfg_in;
    bad_cfg.rs_interleave_i = 6U;
    assert(ccsds_ttc_hal_configure(&dev, &bad_cfg) == CCSDS_HAL_ERR_RS_PARAM_RANGE);

    /* Rule 8: Out-of-range TFDF length (0 or > 1024) is forbidden */
    bad_cfg = cfg_in;
    bad_cfg.tfdf_byte_len   = 0U;
    assert(ccsds_ttc_hal_configure(&dev, &bad_cfg) == CCSDS_HAL_ERR_FRAME_LEN_RANGE);

    /* 3. Verify Runtime SDLS 256-Bit Key & SA Provisioning Registers (0x28..0x50) */
    assert(ccsds_ttc_hal_set_sdls_key256(&dev, test_key) == CCSDS_HAL_OK);
    for (uint32_t i = 0U; i < 8U; i++) {
        assert(ccsds_ttc_hal_reg_read(&dev, CCSDS_REG_SDLS_KEY_0 + (i * 4U)) == test_key[i]);
    }
    assert(ccsds_ttc_hal_provision_sdls_sa(&dev, 2U, 0x0042U, 0x00000100UL, 0x0042U) == CCSDS_HAL_OK);
    assert(ccsds_ttc_hal_reg_read(&dev, CCSDS_REG_SDLS_SA_SPI)  == 0x00000042UL);
    assert(ccsds_ttc_hal_reg_read(&dev, CCSDS_REG_SDLS_SA_SEQ)  == 0x00000100UL);
    assert(ccsds_ttc_hal_reg_read(&dev, CCSDS_REG_SDLS_SA_CTRL) == ((1UL << 31U) | (2UL << 16U) | 0x0042UL));

    ccsds_ttc_hal_get_clcw(&dev, &clcw);
    assert(clcw.vcid           == 1U);
    assert(clcw.retransmit     == true);
    assert(clcw.farm_b_counter == 2U);
    assert(clcw.report_value   == 5U);

    assert(ccsds_ttc_hal_get_obt_cuc48(&dev) == 0x653000428000ULL);

    ccsds_ttc_hal_get_error_telemetry(&dev, &err_tlm);
    assert(err_tlm.secded_bch_single_corr_cnt == 4U);
    assert(err_tlm.tmr_seu_corrected_cnt      == 2U);
    assert(err_tlm.uncorr_frame_pkt_err_cnt   == 1U);
    assert(err_tlm.sdls_mac_err_cnt           == 3U);

    printf("[HAL-SDK-TEST PASS] All C11 Flight/EGSE HAL register pack/unpack, SDLS provisioning & 8 CCSDS configuration gating rules passed!\n");
    return 0;
}
