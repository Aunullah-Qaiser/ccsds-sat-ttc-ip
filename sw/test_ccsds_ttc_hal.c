/**
 * @file test_ccsds_ttc_hal.c
 * @brief Unit & register-map verification test for the C11 Flight/EGSE HAL SDK
 *        (strictly aligned with rtl/ccsds_axi_lite_csr.sv).
 */

#include "ccsds_ttc_hal.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

int main(void)
{
    volatile uint32_t mock_axi_regs[16];
    ccsds_ttc_dev_t dev;
    ccsds_ttc_config_t cfg_in, cfg_out;
    ccsds_clcw_status_t clcw;
    ccsds_err_telemetry_t err_tlm;

    memset((void *)mock_axi_regs, 0, sizeof(mock_axi_regs));
    mock_axi_regs[CCSDS_REG_CORE_ID_VER     >> 2U] = CCSDS_EXPECTED_VERSION_ID;
    mock_axi_regs[CCSDS_REG_OBT_COARSE_SEC  >> 2U] = 0x65300042UL;
    mock_axi_regs[CCSDS_REG_OBT_FINE_SUBSEC >> 2U] = 0x00008000UL;
    mock_axi_regs[CCSDS_REG_EDAC_CORR_CNTS  >> 2U] = (0x0002UL << 16U) | 0x0004UL;
    mock_axi_regs[CCSDS_REG_FAULT_ERR_CNTS  >> 2U] = (0x0003UL << 16U) | 0x0001UL;
    mock_axi_regs[CCSDS_REG_LATEST_CLCW_MON >> 2U] = (1UL << 18U) | (1UL << 11U) | (2UL << 9U) | 0x05UL;

    assert(ccsds_ttc_hal_init(&dev, mock_axi_regs) == 0);

    memset(&cfg_in, 0, sizeof(cfg_in));
    cfg_in.scid_10b           = 0x155U;
    cfg_in.uslp_scid_16b      = 0x4255U;
    cfg_in.proto_mode         = CCSDS_PROTO_USLP;
    cfg_in.fec_mode           = CCSDS_FEC_TURBO_R1_4;
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
    cfg_in.fault_irq_en       = true;

    assert(ccsds_ttc_hal_configure(&dev, &cfg_in) == 0);
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
    assert(cfg_out.fault_irq_en      == true);

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

    printf("[HAL-SDK-TEST PASS] All C11 Flight/EGSE HAL register pack/unpack assertions passed!\n");
    return 0;
}
