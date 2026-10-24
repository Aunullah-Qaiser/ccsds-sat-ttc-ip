/**
 * @file ccsds_ttc_hal.c
 * @brief Implementation of the Bare-Metal C11 Flight OBC & Ground EGSE HAL SDK
 *        for the CCSDS-SAT-TTC-IP Core (v2.28.0).
 */

#include "ccsds_ttc_hal.h"

uint32_t ccsds_ttc_hal_reg_read(const ccsds_ttc_dev_t *dev, uint32_t reg_offset)
{
    if ((dev == NULL) || (dev->base_addr == NULL)) {
        return 0UL;
    }
    return dev->base_addr[reg_offset >> 2U];
}

void ccsds_ttc_hal_reg_write(const ccsds_ttc_dev_t *dev, uint32_t reg_offset, uint32_t val)
{
    if ((dev == NULL) || (dev->base_addr == NULL)) {
        return;
    }
    dev->base_addr[reg_offset >> 2U] = val;
}

int ccsds_ttc_hal_init(ccsds_ttc_dev_t *dev, volatile uint32_t *base_addr)
{
    uint32_t ver;
    if ((dev == NULL) || (base_addr == NULL)) {
        return -1;
    }
    dev->base_addr = base_addr;
    ver = ccsds_ttc_hal_reg_read(dev, CCSDS_REG_VERSION_ID);
    if (ver != CCSDS_EXPECTED_VERSION_ID) {
        return -2;
    }
    return 0;
}

int ccsds_ttc_hal_configure(const ccsds_ttc_dev_t *dev, const ccsds_ttc_config_t *cfg)
{
    uint32_t reg_scid;
    uint32_t reg_proto;
    uint32_t reg_uslp_rs;

    if ((dev == NULL) || (dev->base_addr == NULL) || (cfg == NULL)) {
        return -1;
    }

    reg_scid = ((uint32_t)(cfg->uslp_scid_16b) << 16U) |
               ((uint32_t)(cfg->scid_10b & 0x03FFU));

    reg_proto = ((uint32_t)(cfg->proto_mode & 0x07U) << 0U)  |
                ((uint32_t)(cfg->fec_mode   & 0x0FU) << 4U)  |
                ((cfg->ocf_en             ? 1UL : 0UL) << 8U)  |
                ((cfg->fecf_en            ? 1UL : 0UL) << 9U)  |
                ((cfg->fecf_crc32         ? 1UL : 0UL) << 10U) |
                ((cfg->aos_fhec_en        ? 1UL : 0UL) << 11U) |
                ((cfg->tc_seg_hdr_present ? 1UL : 0UL) << 12U) |
                ((cfg->obt_sec_hdr_en     ? 1UL : 0UL) << 13U) |
                ((cfg->sdls_en            ? 1UL : 0UL) << 14U) |
                ((cfg->bc_require_sdls    ? 1UL : 0UL) << 15U) |
                ((uint32_t)(cfg->window_half_w)        << 16U);

    reg_uslp_rs = ((uint32_t)(cfg->rs_interleave_i & 0x0FU) << 0U)  |
                  ((uint32_t)(cfg->rs_virt_fill_q)          << 4U)  |
                  ((uint32_t)(cfg->tfdf_byte_len  & 0x07FFU) << 12U) |
                  ((uint32_t)(cfg->turnaround_kaband & 0x03U) << 24U) |
                  ((cfg->srrc_4sps_en     ? 1UL : 0UL) << 26U) |
                  ((cfg->gardner_ted_en   ? 1UL : 0UL) << 27U) |
                  ((cfg->sdls_gcm_mode    ? 1UL : 0UL) << 28U) |
                  ((cfg->fll_assist_en    ? 1UL : 0UL) << 29U);

    ccsds_ttc_hal_reg_write(dev, CCSDS_REG_SCID_CFG,      reg_scid);
    ccsds_ttc_hal_reg_write(dev, CCSDS_REG_PROTO_FEC_CFG, reg_proto);
    ccsds_ttc_hal_reg_write(dev, CCSDS_REG_USLP_RS_CFG,   reg_uslp_rs);
    return 0;
}

void ccsds_ttc_hal_get_config(const ccsds_ttc_dev_t *dev, ccsds_ttc_config_t *cfg_out)
{
    uint32_t reg_scid;
    uint32_t reg_proto;
    uint32_t reg_uslp_rs;

    if ((dev == NULL) || (cfg_out == NULL)) {
        return;
    }

    reg_scid    = ccsds_ttc_hal_reg_read(dev, CCSDS_REG_SCID_CFG);
    reg_proto   = ccsds_ttc_hal_reg_read(dev, CCSDS_REG_PROTO_FEC_CFG);
    reg_uslp_rs = ccsds_ttc_hal_reg_read(dev, CCSDS_REG_USLP_RS_CFG);

    cfg_out->scid_10b           = (uint16_t)(reg_scid & 0x03FFUL);
    cfg_out->uslp_scid_16b      = (uint16_t)((reg_scid >> 16U) & 0xFFFFUL);
    cfg_out->proto_mode         = (ccsds_proto_mode_t)(reg_proto & 0x07UL);
    cfg_out->fec_mode           = (ccsds_fec_mode_t)((reg_proto >> 4U) & 0x0FUL);
    cfg_out->ocf_en             = ((reg_proto >> 8U)  & 1UL) != 0UL;
    cfg_out->fecf_en            = ((reg_proto >> 9U)  & 1UL) != 0UL;
    cfg_out->fecf_crc32         = ((reg_proto >> 10U) & 1UL) != 0UL;
    cfg_out->aos_fhec_en        = ((reg_proto >> 11U) & 1UL) != 0UL;
    cfg_out->tc_seg_hdr_present = ((reg_proto >> 12U) & 1UL) != 0UL;
    cfg_out->obt_sec_hdr_en     = ((reg_proto >> 13U) & 1UL) != 0UL;
    cfg_out->sdls_en            = ((reg_proto >> 14U) & 1UL) != 0UL;
    cfg_out->bc_require_sdls    = ((reg_proto >> 15U) & 1UL) != 0UL;
    cfg_out->window_half_w      = (uint8_t)((reg_proto >> 16U) & 0xFFUL);

    cfg_out->rs_interleave_i    = (uint8_t)(reg_uslp_rs & 0x0FUL);
    cfg_out->rs_virt_fill_q     = (uint8_t)((reg_uslp_rs >> 4U) & 0xFFUL);
    cfg_out->tfdf_byte_len      = (uint16_t)((reg_uslp_rs >> 12U) & 0x07FFUL);
    cfg_out->turnaround_kaband  = (ccsds_kaband_mode_t)((reg_uslp_rs >> 24U) & 0x03UL);
    cfg_out->srrc_4sps_en       = ((reg_uslp_rs >> 26U) & 1UL) != 0UL;
    cfg_out->gardner_ted_en     = ((reg_uslp_rs >> 27U) & 1UL) != 0UL;
    cfg_out->sdls_gcm_mode      = ((reg_uslp_rs >> 28U) & 1UL) != 0UL;
    cfg_out->fll_assist_en      = ((reg_uslp_rs >> 29U) & 1UL) != 0UL;
}

void ccsds_ttc_hal_get_clcw(const ccsds_ttc_dev_t *dev, ccsds_clcw_status_t *clcw_out)
{
    uint32_t raw;
    if ((dev == NULL) || (clcw_out == NULL)) {
        return;
    }
    raw = ccsds_ttc_hal_reg_read(dev, CCSDS_REG_LATEST_CLCW);
    clcw_out->vcid           = (uint8_t)((raw >> 18U) & 0x3FUL);
    clcw_out->no_rf_avail    = ((raw >> 15U) & 1UL) != 0UL;
    clcw_out->no_bit_lock    = ((raw >> 14U) & 1UL) != 0UL;
    clcw_out->lockout        = ((raw >> 13U) & 1UL) != 0UL;
    clcw_out->wait_flag      = ((raw >> 12U) & 1UL) != 0UL;
    clcw_out->retransmit     = ((raw >> 11U) & 1UL) != 0UL;
    clcw_out->farm_b_counter = (uint8_t)((raw >> 9U) & 0x03UL);
    clcw_out->report_value   = (uint8_t)(raw & 0xFFUL);
}

uint64_t ccsds_ttc_hal_get_obt_cuc48(const ccsds_ttc_dev_t *dev)
{
    uint64_t lo, hi;
    if (dev == NULL) {
        return 0ULL;
    }
    lo = (uint64_t)ccsds_ttc_hal_reg_read(dev, CCSDS_REG_OBT_CUC_LOW);
    hi = (uint64_t)(ccsds_ttc_hal_reg_read(dev, CCSDS_REG_OBT_CUC_HIGH) & 0xFFFFUL);
    return (hi << 32U) | lo;
}

void ccsds_ttc_hal_get_error_telemetry(const ccsds_ttc_dev_t *dev, ccsds_err_telemetry_t *err_out)
{
    uint32_t e0, e1;
    if ((dev == NULL) || (err_out == NULL)) {
        return;
    }
    e0 = ccsds_ttc_hal_reg_read(dev, CCSDS_REG_ERR_COUNTERS_0);
    e1 = ccsds_ttc_hal_reg_read(dev, CCSDS_REG_ERR_COUNTERS_1);

    err_out->bch_single_err_cnt     = (uint8_t)((e0 >> 24U) & 0xFFUL);
    err_out->bch_double_abort_cnt   = (uint8_t)((e0 >> 16U) & 0xFFUL);
    err_out->fifo_secded_single_cnt = (uint8_t)((e0 >> 8U)  & 0xFFUL);
    err_out->fifo_secded_double_cnt = (uint8_t)(e0 & 0xFFUL);

    err_out->tmr_seu_corrected_cnt  = (uint8_t)((e1 >> 24U) & 0xFFUL);
    err_out->frame_crc_err_cnt      = (uint8_t)((e1 >> 16U) & 0xFFUL);
    err_out->pkt_len_err_cnt        = (uint8_t)((e1 >> 8U)  & 0xFFUL);
    err_out->sdls_mac_err_cnt       = (uint8_t)(e1 & 0xFFUL);
}
