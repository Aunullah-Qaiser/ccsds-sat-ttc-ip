/**
 * @file ccsds_ttc_hal.c
 * @brief Implementation of the Bare-Metal C11 Flight OBC & Ground EGSE HAL SDK
 *        for the CCSDS-SAT-TTC-IP Core (v2.36.0), bit-accurate against
 *        rtl/ccsds_axi_lite_csr.sv and enforcing CCSDS Blue Book configuration
 *        gating rules prior to hardware register writes.
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
        return CCSDS_HAL_ERR_NULL_PTR;
    }
    dev->base_addr = base_addr;
    ver = ccsds_ttc_hal_reg_read(dev, CCSDS_REG_CORE_ID_VER);
    if (ver != CCSDS_EXPECTED_VERSION_ID) {
        return CCSDS_HAL_ERR_BAD_VERSION;
    }
    return CCSDS_HAL_OK;
}

int ccsds_ttc_hal_validate_config(const ccsds_ttc_config_t *cfg)
{
    if (cfg == NULL) {
        return CCSDS_HAL_ERR_NULL_PTR;
    }

    /* Rule 1 (CCSDS 401.0-B-32): Bi-Phi-L (Manchester) is valid only for BPSK or PCM/PM */
    if ((cfg->line_code == CCSDS_LINE_BIPHI_L) &&
        ((cfg->mod_mode == CCSDS_MOD_QPSK) || (cfg->mod_mode == CCSDS_MOD_OQPSK))) {
        return CCSDS_HAL_ERR_MOD_LINE_INCOMPAT;
    }

    /* Rule 2 (CCSDS 401.0-B-32): 4-SPS SRRC filter cannot be paired with Bi-Phi-L Manchester */
    if (cfg->srrc_4sps_en && (cfg->line_code == CCSDS_LINE_BIPHI_L)) {
        return CCSDS_HAL_ERR_SRRC_BIPHI_INCOMPAT;
    }

    /* Rule 3: Closed-loop 4-SPS Gardner TED requires 4-SPS SRRC matched filter enabled */
    if (cfg->gardner_ted_en && (!cfg->srrc_4sps_en)) {
        return CCSDS_HAL_ERR_GARDNER_REQUIRES_4SPS;
    }

    /* Rule 4 (CCSDS 131.0-B-5 / 231.0-B-4 / 211.0-B-6): Protocol vs. FEC Gating */
    switch (cfg->proto_mode) {
        case CCSDS_PROTO_TC:
            /* Uplink TC only allows NONE, BCH(63,56), or Short-LDPC(128,64)/(512,256) */
            if ((cfg->fec_mode != CCSDS_FEC_NONE)        &&
                (cfg->fec_mode != CCSDS_FEC_BCH_63_56)   &&
                (cfg->fec_mode != CCSDS_FEC_LDPC_UL_128) &&
                (cfg->fec_mode != CCSDS_FEC_LDPC_UL_512)) {
                return CCSDS_HAL_ERR_PROTO_FEC_INCOMPAT;
            }
            break;

        case CCSDS_PROTO_TM:
        case CCSDS_PROTO_AOS:
            /* Downlink TM/AOS forbids Uplink-only BCH(63,56) and Short-LDPC(128/512) */
            if ((cfg->fec_mode == CCSDS_FEC_BCH_63_56)   ||
                (cfg->fec_mode == CCSDS_FEC_LDPC_UL_128) ||
                (cfg->fec_mode == CCSDS_FEC_LDPC_UL_512)) {
                return CCSDS_HAL_ERR_PROTO_FEC_INCOMPAT;
            }
            break;

        case CCSDS_PROTO_PROX1:
            /* Proximity-1 only allows NONE, Conv(K=7,r=1/2), or LDPC */
            if ((cfg->fec_mode == CCSDS_FEC_BCH_63_56)     ||
                (cfg->fec_mode == CCSDS_FEC_RS_255_223)    ||
                (cfg->fec_mode == CCSDS_FEC_CONCAT_RS_CNV) ||
                ((cfg->fec_mode >= CCSDS_FEC_TURBO_R1_2) && (cfg->fec_mode <= CCSDS_FEC_TURBO_R1_6))) {
                return CCSDS_HAL_ERR_PROTO_FEC_INCOMPAT;
            }
            break;

        case CCSDS_PROTO_USLP:
            /* USLP is unified bidirectional and supports both Uplink & Downlink FECs */
            break;

        default:
            return CCSDS_HAL_ERR_PROTO_FEC_INCOMPAT;
    }

    /* Rule 5 (CCSDS 211.0-B-6 & 732.1-B-3): 32-bit FECF CRC-32 Gating */
    if (cfg->fecf_crc32 &&
        (cfg->proto_mode != CCSDS_PROTO_PROX1) &&
        (cfg->proto_mode != CCSDS_PROTO_USLP)) {
        return CCSDS_HAL_ERR_CRC32_PROTO_INCOMPAT;
    }
    if ((cfg->proto_mode == CCSDS_PROTO_PROX1) && cfg->fecf_en && (!cfg->fecf_crc32)) {
        return CCSDS_HAL_ERR_CRC32_PROTO_INCOMPAT;
    }

    /* Rule 6 (CCSDS 732.0-B-4): AOS 16-bit GF(2^4) FHEC is valid only on AOS or USLP */
    if (cfg->aos_fhec_en &&
        (cfg->proto_mode != CCSDS_PROTO_AOS) &&
        (cfg->proto_mode != CCSDS_PROTO_USLP)) {
        return CCSDS_HAL_ERR_AOS_FHEC_INCOMPAT;
    }

    /* Rule 7 (CCSDS 131.0-B-5): RS(255,223) Interleave Depth I in {1,2,3,4,5,8} & Virtual Fill Q <= 215 */
    if ((cfg->rs_interleave_i != 1U) && (cfg->rs_interleave_i != 2U) &&
        (cfg->rs_interleave_i != 3U) && (cfg->rs_interleave_i != 4U) &&
        (cfg->rs_interleave_i != 5U) && (cfg->rs_interleave_i != 8U)) {
        return CCSDS_HAL_ERR_RS_PARAM_RANGE;
    }
    if (cfg->rs_virt_fill_q > 215U) {
        return CCSDS_HAL_ERR_RS_PARAM_RANGE;
    }

    /* Rule 8: TFDF Byte Length in [1..1024] & COP-1 Window Half-Width W in [1..128] */
    if ((cfg->tfdf_byte_len == 0U) || (cfg->tfdf_byte_len > 1024U) ||
        (cfg->window_half_w == 0U) || (cfg->window_half_w > 128U)) {
        return CCSDS_HAL_ERR_FRAME_LEN_RANGE;
    }

    return CCSDS_HAL_OK;
}

int ccsds_ttc_hal_configure(const ccsds_ttc_dev_t *dev, const ccsds_ttc_config_t *cfg)
{
    int      val_rc;
    uint32_t reg_scid_proto;
    uint32_t reg_uslp_rs;
    uint32_t reg_cop1_tfdf;

    if ((dev == NULL) || (dev->base_addr == NULL) || (cfg == NULL)) {
        return CCSDS_HAL_ERR_NULL_PTR;
    }

    /* Enforce firmware configuration gating before touching hardware CSRs */
    val_rc = ccsds_ttc_hal_validate_config(cfg);
    if (val_rc != CCSDS_HAL_OK) {
        return val_rc;
    }

    /* 0x04 CTRL_SCID_PROTO */
    reg_scid_proto = ((uint32_t)(cfg->scid_10b & 0x03FFU)          << 0U)  |
                     ((uint32_t)(cfg->proto_mode & 0x07U)          << 12U) |
                     ((uint32_t)(cfg->fec_mode   & 0x0FU)          << 16U) |
                     ((cfg->ocf_en             ? 1UL : 0UL)        << 20U) |
                     ((cfg->fecf_en            ? 1UL : 0UL)        << 21U) |
                     ((cfg->fecf_crc32         ? 1UL : 0UL)        << 22U) |
                     ((cfg->aos_fhec_en        ? 1UL : 0UL)        << 23U) |
                     ((cfg->tc_seg_hdr_present ? 1UL : 0UL)        << 24U) |
                     ((cfg->obt_sec_hdr_en     ? 1UL : 0UL)        << 25U) |
                     ((cfg->sdls_en            ? 1UL : 0UL)        << 26U) |
                     ((cfg->bc_require_sdls    ? 1UL : 0UL)        << 27U) |
                     ((cfg->srrc_4sps_en       ? 1UL : 0UL)        << 28U) |
                     ((cfg->gardner_ted_en     ? 1UL : 0UL)        << 29U) |
                     ((uint32_t)(cfg->turnaround_kaband & 0x03U)   << 30U);

    /* 0x08 CTRL_USLP_RS_CFG */
    reg_uslp_rs    = ((uint32_t)(cfg->uslp_scid_16b)               << 0U)  |
                     ((uint32_t)(cfg->rs_interleave_i & 0x0FU)     << 16U) |
                     ((uint32_t)(cfg->rs_virt_fill_q)              << 20U) |
                     ((cfg->sdls_gcm_mode      ? 1UL : 0UL)        << 28U) |
                     ((cfg->fll_assist_en      ? 1UL : 0UL)        << 29U) |
                     ((cfg->tm_rand_en         ? 1UL : 0UL)        << 30U);

    /* 0x0C CTRL_COP1_TFDF_CFG */
    reg_cop1_tfdf  = ((uint32_t)(cfg->window_half_w)               << 0U)  |
                     ((uint32_t)(cfg->tfdf_byte_len & 0x07FFU)     << 8U)  |
                     ((cfg->fault_irq_en       ? 1UL : 0UL)        << 24U);

    ccsds_ttc_hal_reg_write(dev, CCSDS_REG_CTRL_SCID_PROTO,    reg_scid_proto);
    ccsds_ttc_hal_reg_write(dev, CCSDS_REG_CTRL_USLP_RS_CFG,   reg_uslp_rs);
    ccsds_ttc_hal_reg_write(dev, CCSDS_REG_CTRL_COP1_TFDF_CFG, reg_cop1_tfdf);
    return CCSDS_HAL_OK;
}

void ccsds_ttc_hal_get_config(const ccsds_ttc_dev_t *dev, ccsds_ttc_config_t *cfg_out)
{
    uint32_t reg_scid_proto;
    uint32_t reg_uslp_rs;
    uint32_t reg_cop1_tfdf;

    if ((dev == NULL) || (cfg_out == NULL)) {
        return;
    }

    reg_scid_proto = ccsds_ttc_hal_reg_read(dev, CCSDS_REG_CTRL_SCID_PROTO);
    reg_uslp_rs    = ccsds_ttc_hal_reg_read(dev, CCSDS_REG_CTRL_USLP_RS_CFG);
    reg_cop1_tfdf  = ccsds_ttc_hal_reg_read(dev, CCSDS_REG_CTRL_COP1_TFDF_CFG);

    cfg_out->scid_10b           = (uint16_t)(reg_scid_proto & 0x03FFUL);
    cfg_out->proto_mode         = (ccsds_proto_mode_t)((reg_scid_proto >> 12U) & 0x07UL);
    cfg_out->fec_mode           = (ccsds_fec_mode_t)((reg_scid_proto >> 16U) & 0x0FUL);
    cfg_out->mod_mode           = CCSDS_MOD_BPSK;
    cfg_out->line_code          = CCSDS_LINE_NRZ_L;
    cfg_out->ocf_en             = ((reg_scid_proto >> 20U) & 1UL) != 0UL;
    cfg_out->fecf_en            = ((reg_scid_proto >> 21U) & 1UL) != 0UL;
    cfg_out->fecf_crc32         = ((reg_scid_proto >> 22U) & 1UL) != 0UL;
    cfg_out->aos_fhec_en        = ((reg_scid_proto >> 23U) & 1UL) != 0UL;
    cfg_out->tc_seg_hdr_present = ((reg_scid_proto >> 24U) & 1UL) != 0UL;
    cfg_out->obt_sec_hdr_en     = ((reg_scid_proto >> 25U) & 1UL) != 0UL;
    cfg_out->sdls_en            = ((reg_scid_proto >> 26U) & 1UL) != 0UL;
    cfg_out->bc_require_sdls    = ((reg_scid_proto >> 27U) & 1UL) != 0UL;
    cfg_out->srrc_4sps_en       = ((reg_scid_proto >> 28U) & 1UL) != 0UL;
    cfg_out->gardner_ted_en     = ((reg_scid_proto >> 29U) & 1UL) != 0UL;
    cfg_out->turnaround_kaband  = (ccsds_kaband_mode_t)((reg_scid_proto >> 30U) & 0x03UL);

    cfg_out->uslp_scid_16b      = (uint16_t)(reg_uslp_rs & 0xFFFFUL);
    cfg_out->rs_interleave_i    = (uint8_t)((reg_uslp_rs >> 16U) & 0x0FUL);
    cfg_out->rs_virt_fill_q     = (uint8_t)((reg_uslp_rs >> 20U) & 0xFFUL);
    cfg_out->sdls_gcm_mode      = ((reg_uslp_rs >> 28U) & 1UL) != 0UL;
    cfg_out->fll_assist_en      = ((reg_uslp_rs >> 29U) & 1UL) != 0UL;
    cfg_out->tm_rand_en         = ((reg_uslp_rs >> 30U) & 1UL) != 0UL;

    cfg_out->window_half_w      = (uint8_t)(reg_cop1_tfdf & 0xFFUL);
    cfg_out->tfdf_byte_len      = (uint16_t)((reg_cop1_tfdf >> 8U) & 0x07FFUL);
    cfg_out->fault_irq_en       = ((reg_cop1_tfdf >> 24U) & 1UL) != 0UL;
}

int ccsds_ttc_hal_set_sdls_key256(const ccsds_ttc_dev_t *dev, const uint32_t key_words[8])
{
    uint32_t i;
    if ((dev == NULL) || (dev->base_addr == NULL) || (key_words == NULL)) {
        return CCSDS_HAL_ERR_NULL_PTR;
    }
    for (i = 0U; i < 8U; i++) {
        ccsds_ttc_hal_reg_write(dev, CCSDS_REG_SDLS_KEY_0 + (i * 4U), key_words[i]);
    }
    return CCSDS_HAL_OK;
}

int ccsds_ttc_hal_provision_sdls_sa(const ccsds_ttc_dev_t *dev,
                                    uint8_t vcid_addr,
                                    uint16_t spi,
                                    uint32_t seq_low,
                                    uint16_t tx_default_spi)
{
    uint32_t ctrl_word;
    if ((dev == NULL) || (dev->base_addr == NULL)) {
        return CCSDS_HAL_ERR_NULL_PTR;
    }
    ccsds_ttc_hal_reg_write(dev, CCSDS_REG_SDLS_SA_SPI, (uint32_t)spi);
    ccsds_ttc_hal_reg_write(dev, CCSDS_REG_SDLS_SA_SEQ, seq_low);

    ctrl_word = ((uint32_t)tx_default_spi & 0xFFFFUL) |
                (((uint32_t)vcid_addr & 0x3FUL) << 16U) |
                (1UL << 31U); /* Auto-clearing SA_WR_EN pulse */
    ccsds_ttc_hal_reg_write(dev, CCSDS_REG_SDLS_SA_CTRL, ctrl_word);
    return CCSDS_HAL_OK;
}

void ccsds_ttc_hal_get_clcw(const ccsds_ttc_dev_t *dev, ccsds_clcw_status_t *clcw_out)
{
    uint32_t raw;
    if ((dev == NULL) || (clcw_out == NULL)) {
        return;
    }
    raw = ccsds_ttc_hal_reg_read(dev, CCSDS_REG_LATEST_CLCW_MON);
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
    uint64_t coarse, fine;
    if (dev == NULL) {
        return 0ULL;
    }
    coarse = (uint64_t)ccsds_ttc_hal_reg_read(dev, CCSDS_REG_OBT_COARSE_SEC);
    fine   = (uint64_t)(ccsds_ttc_hal_reg_read(dev, CCSDS_REG_OBT_FINE_SUBSEC) & 0xFFFFUL);
    return (coarse << 16U) | fine;
}

void ccsds_ttc_hal_set_obt_cuc48(const ccsds_ttc_dev_t *dev, uint32_t coarse_sec, uint16_t fine_subsec)
{
    if (dev == NULL) {
        return;
    }
    ccsds_ttc_hal_reg_write(dev, CCSDS_REG_OBT_COARSE_SEC,  coarse_sec);
    ccsds_ttc_hal_reg_write(dev, CCSDS_REG_OBT_FINE_SUBSEC, (uint32_t)fine_subsec);
}

void ccsds_ttc_hal_get_error_telemetry(const ccsds_ttc_dev_t *dev, ccsds_err_telemetry_t *err_out)
{
    uint32_t edac_reg, fault_reg;
    if ((dev == NULL) || (err_out == NULL)) {
        return;
    }
    edac_reg  = ccsds_ttc_hal_reg_read(dev, CCSDS_REG_EDAC_CORR_CNTS);
    fault_reg = ccsds_ttc_hal_reg_read(dev, CCSDS_REG_FAULT_ERR_CNTS);

    err_out->secded_bch_single_corr_cnt = (uint16_t)(edac_reg & 0xFFFFUL);
    err_out->tmr_seu_corrected_cnt      = (uint16_t)((edac_reg >> 16U) & 0xFFFFUL);
    err_out->uncorr_frame_pkt_err_cnt   = (uint16_t)(fault_reg & 0xFFFFUL);
    err_out->sdls_mac_err_cnt           = (uint16_t)((fault_reg >> 16U) & 0xFFFFUL);
}

void ccsds_ttc_hal_clear_error_telemetry(const ccsds_ttc_dev_t *dev,
                                         bool clr_edac,
                                         bool clr_tmr,
                                         bool clr_uncorr,
                                         bool clr_sdls)
{
    if (dev == NULL) {
        return;
    }
    if (clr_edac || clr_tmr) {
        uint32_t w1c_edac = (clr_edac ? (1UL << 0U) : 0UL) | (clr_tmr ? (1UL << 16U) : 0UL);
        ccsds_ttc_hal_reg_write(dev, CCSDS_REG_EDAC_CORR_CNTS, w1c_edac);
    }
    if (clr_uncorr || clr_sdls) {
        uint32_t w1c_fault = (clr_uncorr ? (1UL << 0U) : 0UL) | (clr_sdls ? (1UL << 16U) : 0UL);
        ccsds_ttc_hal_reg_write(dev, CCSDS_REG_FAULT_ERR_CNTS, w1c_fault);
    }
}
