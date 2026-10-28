# CCSDS-SAT-TTC-IP (`v2.33.0`): Spacecraft & Ground EGSE TT&C Product Guide and User Manual

| Document Control | Details |
| :--- | :--- |
| **Document ID** | `PG-CCSDS-TTC-v2.33.0` |
| **IP Core Name** | `ccsds_sat_ttc_top` (`CCSDS-SAT-TTC-IP`) |
| **Version & Release Date** | `v2.33.0` — October 27, 2026 (All Stages 0–12 Verified in Vivado 2022.2 `xsim` & STA) |
| **RTL Standard** | IEEE 1800-2017 SystemVerilog (`30` Synthesizable/Model RTL Modules + `11` Self-Checking Testbenches) |
| **Flight Software SDK** | ANSI/ISO C11 Bare-Metal Hardware Abstraction Layer (`sw/ccsds_ttc_hal.h`, `sw/ccsds_ttc_hal.c`, `sw/test_ccsds_ttc_hal.c`) |
| **License** | Apache License 2.0 ([`LICENSE`](../LICENSE)) |

---

## 1. Product Overview & Key Features

The **`CCSDS-SAT-TTC-IP` (`ccsds_sat_ttc_top`)** is a vendor-agnostic, radiation-mitigated, all-digital **Telemetry, Tracking, and Command (TT&C)** SystemVerilog IP core compliant with **17 CCSDS Blue and Orange Books**. A single unified RTL codebase is compile-time parameterized via `ROLE_MODE` and feature-enable generics to synthesize into three distinct mission personas:

1. **`ROLE_MODE = 0` (Spacecraft Flight Transceiver — 23 Modules):** Implements the complete spacecraft uplink command receiver (`Costas/FLL` + `4-SPS SRRC/Gardner` + `T2B/T4B PN Ranging` + `ASM Sync` + `BCH(63,56)` / `Short-LDPC(128,64)` + `TC/USLP/Prox-1 Deframer` + `3x TMR COP-1 FARM-1` + `NIST AES-128-CTR/GCM SDLS` + `3x TMR Emergency HCPD` + `Hsiao SECDED Commit/Rollback CDC FIFO` + `Space Packet Reassembler`) and downlink telemetry transmitter (`VC Priority Arbiter & Cycle-0 FHP` + `SDLS Encrypt/Tag` + `TM/AOS/USLP/Prox-1 Framer` + `Dual-Basis RS(255,223)` / `Turbo` / `LDPC` + `High-Watermark SECDED CDC FIFO` + `Rate-1/2 K=7 Convolutional` + `4-SPS SRRC IQ Modulator` + `S/X/Ka-Band Coherent Turnaround NCO`).
2. **`ROLE_MODE = 1` (Synthesizable Hardware Ground EGSE — 22 Modules):** Synthesizes the 17 shared core modules plus the 5 Ground Station EGSE endpoints (`ccsds_fop1_engine`, `ccsds_tc_cltu_framer`, `ccsds_bch6356_enc`, `ccsds_dl_rs255_223_dec` full $t=16$ Berlekamp-Massey/Chien/Forney decoder, and `ccsds_tm_aos_deframer`) for FlatSat racks, RFSoC ground modems, and Hardware-in-the-Loop (HIL) testbeds.
3. **`ROLE_MODE = 2` (Universal Crosslink / Relay & On-Orbit BIST Transceiver — All 28 Synthesizable Modules):** Instantiates both spacecraft flight and ground EGSE endpoints simultaneously for spacecraft-to-spacecraft [Proximity-1](https://ccsds.org/Pubs/211x0b6e1.pdf) / [USLP](https://ccsds.org/Pubs/732x1b3e1.pdf) crosslinks and autonomous on-orbit Built-In Self-Test (BIST).

---

## 2. Compile-Time Parameters & Mission Sizing Profiles

`ccsds_sat_ttc_top` exposes four top-level SystemVerilog parameters in `rtl/ccsds_sat_ttc_top.sv` so designers can trade optional subsystem features against FPGA LUT/FF footprint:

| Parameter | Type | Default | Allowed Values | Hardware Synthesis Effect |
| :--- | :---: | :---: | :---: | :--- |
| **`ROLE_MODE`** | `int unsigned` | `0` | `0`, `1`, `2` | Selects **Spacecraft Flight (`0`)**, **Hardware Ground EGSE (`1`)**, or **Universal Crosslink/BIST (`2`)**. |
| **`ENABLE_SDLS`** | `bit` | `1'b1` | `1'b0`, `1'b1` | When `1'b1`, synthesizes `u_sdls` (`ccsds_sdls_engine`: `AES-128-CTR`, `AES-128-GCM` $GF(2^{128})$ `GHASH`, and 64-entry Hsiao SECDED SA RAM). When `1'b0`, elides `u_sdls` with zero-latency AXI4-Stream pass-through (**saves ~7,919 LUTs and ~5,571 FFs**). |
| **`ENABLE_UL_LDPC`** | `bit` | `1'b1` | `1'b0`, `1'b1` | When `1'b1`, synthesizes `u_short_ldpc_dec` ([CCSDS 231.1-O-1](https://ccsds.org/Pubs/231x1o1s.pdf) `(128,64)` Soft-OMS iterative decoder). When `1'b0`, elides `u_short_ldpc_dec` for classic $\text{BCH}(63,56)$-only missions (**saves ~12,610 LUTs**). |
| **`ENABLE_DL_TURBO`** | `bit` | `1'b1` | `1'b0`, `1'b1` | When `1'b1`, synthesizes `u_turbo_ldpc_enc` ([CCSDS 131.0-B-5](https://ccsds.org/Pubs/131x0b5.pdf) RSC Turbo & Table 2-1 LDPC encoder). When `1'b0`, elides `u_turbo_ldpc_enc` for $\text{RS}(255,223)$/Convolutional-only downlinks. |

### 2.1 Measured Xilinx Vivado 2022.2 Resource Footprint & Device Fit Matrix

| Build Profile | Generics (`ROLE_MODE=0`) | Slice LUTs (Logic + LUTRAM) | Slice FFs | BRAM / DSP | Zynq-7010 (`xc7z010`, 17.6k LUTs) | Zynq-7020 (`xc7z020`, 53.2k LUTs) | Kintex UltraScale (`xcku040`, 242.4k) | Rad-Hard KU060 (`xqrku060`, 331.7k) |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Full Featured Flight Core** | `SDLS=1, LDPC=1, TURBO=1` | **`28,861`** (`27,661` + `1,200`) | **`13,864`** | `0 / 0` | Exceeds (`163.98%`) | **Fits (`54.25%`)** | **Fits (`11.91%`)** | **Fits (`8.70%`)** |
| **Classic BCH + AES-GCM Core** | `SDLS=1, LDPC=0, TURBO=1` | **`~16,251`** (`15,051` + `1,200`) | **`~12,732`** | `0 / 0` | **Fits (`92.34%`)** | **Fits (`30.55%`)** | **Fits (`6.70%`)** | **Fits (`4.90%`)** |
| **Compact CubeSat Core** | `SDLS=0, LDPC=0, TURBO=0` | **`~8,332`** (`7,132` + `1,200`) | **`~7,161`** | `0 / 0` | **Fits (`47.34%`)** | **Fits (`15.66%`)** | **Fits (`3.44%`)** | **Fits (`2.51%`)** |

---

## 3. Clock Domains, Reset Strategy & Measured Timing Closure (`v2.33.0`)

### 3.1 Four Asynchronous Clock Domains & Reset Architecture

The IP core operates across four independent, asynchronous clock domains separated by 2-FF `(* ASYNC_REG = "TRUE" *)` Gray-code / toggle synchronizers and dual-clock $(39,32)$ Hsiao SECDED FIFOs (`ccsds_cdc_fifo_ecc.sv`). All domains share an active-low asynchronous reset (`rst_n`) that must be deasserted synchronously or held low for at least 8 cycles of the slowest clock (`clk_tc_safe`, $\ge 500\text{ ns}$).

| Clock Port | Nominal Freq | Measured True $F_{\max}$ (`v2.32.0+`) | Nominal WNS | Push WNS ($T_{\text{push}}$) | Min Period ($T_{\min}$) | Logic Levels & Limiting Physical Critical Path |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **`clk_sys`** | `100.0 MHz` (`10.000 ns`) | **`116.40 MHz`** (`+16.40%`) | **`+1.409 ns`** | `-5.258 ns` (`3.333 ns`) | **`8.591 ns`** | **`7` levels** (`u_rx_commit_cdc_fifo/rd_ptr_q_reg[0]/C -> u_csr/cnt_uncorr_err_q_reg[0]/CE`) |
| **`clk_adc_iq`** | `120.0 MHz` (`8.333 ns`) | **`135.41 MHz`** (`+12.84%`) | **`+0.948 ns`** | `-4.385 ns` (`3.000 ns`) | **`7.385 ns`** | **`9` levels** (`u_phy_modem/rx_phase_q16_reg[10]/C -> u_phy_modem/i_derot_q_reg[13]/D`) |
| **`clk_tx_sym`** | `50.0 MHz` (`20.000 ns`) | **`169.46 MHz`** (`+238.92%`) | **`+14.099 ns`** | `-2.568 ns` (`3.333 ns`) | **`5.901 ns`** | **`9` levels** (`u_tx_hwm_cdc_fifo/wr_bin_sync2_rd_q_reg[1]/C -> u_tx_hwm_cdc_fifo/rd_gray_q_reg[6]/D`) |
| **`clk_tc_safe`** | `16.0 MHz` (`62.500 ns`) | **`110.22 MHz`** (`+588.88%`) | **`+53.427 ns`** | `-5.073 ns` (`4.000 ns`) | **`9.073 ns`** | **`11` levels** (`u_ul_deframer/cur_tc_hdr_q_reg[vcid][4]/C -> u_farm1/clcw_scheduled_out_reg[wait_flag]/D`) |

---

## 4. Top-Level Pinout & Interface Specification (`ccsds_sat_ttc_top`)

| Signal Group | Port Name | Dir | Width | Clock Domain | Description |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **Clocks & Reset** | `clk_sys` | In | 1 | `clk_sys` | System packet, framing, outer FEC & AXI4-Lite CSR clock (`100 MHz` nominal). |
| | `clk_tc_safe` | In | 1 | `clk_tc_safe` | Independent radiation-safe telecommand & emergency HCPD clock (`16 MHz` nominal). |
| | `clk_tx_sym` | In | 1 | `clk_tx_sym` | Downlink symbol & inner convolutional coding clock (`50 MHz` nominal). |
| | `clk_adc_iq` | In | 1 | `clk_adc_iq` | Wideband RF front-end ADC/DAC sample & PN ranging clock (`120 MHz` nominal). |
| | `rst_n` | In | 1 | Async | Active-low reset (`0` = reset all state machines & FIFOs; `1` = normal operation). |
| **AXI4-Lite CSR Slave** | `s_axi_awvalid`, `s_axi_awready` | In/Out | 1 | `clk_sys` | AXI4-Lite write address handshake. |
| | `s_axi_awaddr` | In | 8 | `clk_sys` | Byte address offset (`0x00` to `0x24`). |
| | `s_axi_wvalid`, `s_axi_wready` | In/Out | 1 | `clk_sys` | AXI4-Lite write data handshake. |
| | `s_axi_wdata`, `s_axi_wstrb` | In | 32, 4 | `clk_sys` | 32-bit write data word and 4-bit byte-lane write strobe. |
| | `s_axi_bvalid`, `s_axi_bready`, `s_axi_bresp` | Out/In/Out | 1, 1, 2 | `clk_sys` | AXI4-Lite write response (`2'b00 = OKAY`). |
| | `s_axi_arvalid`, `s_axi_arready`, `s_axi_araddr` | In/Out/In | 1, 1, 8 | `clk_sys` | AXI4-Lite read address channel (`0x00` to `0x24`). |
| | `s_axi_rvalid`, `s_axi_rready`, `s_axi_rdata`, `s_axi_rresp` | Out/In/Out/Out | 1, 1, 32, 2 | `clk_sys` | AXI4-Lite 32-bit read data channel (`2'b00 = OKAY`). |
| **Mission Straps** | `link_proto_override_en` | In | 2 | `clk_sys` | `2'b00`: Use CSR `PROTO_MODE`; non-zero: hardware pin strap override (`1=TC`, `2=Prox-1`, `3=USLP`). |
| | `ul_fec_override_en` | In | 2 | `clk_tc_safe` | Uplink FEC select: `2'd0` = Direct Frame Bytes, `2'd1` = `BCH(63,56)` CLTU, `2'd2` = `Short-LDPC(128,64)`. |
| | `sdls_en_cfg`, `bc_require_sdls_cfg` | In | 1, 1 | `clk_sys` | Hardware strap OR-ed with CSR bits `[26]` and `[27]` to enforce SDLS security. |
| | `pn_ranging_en_cfg`, `pn_t4b_mode_cfg` | In | 1, 1 | `clk_adc_iq` | Enable regenerative [CCSDS 414.1-B-3](https://ccsds.org/Pubs/414x1b3e1.pdf) PN ranging (`1=T4B`, `0=T2B`). |
| | `turnaround_xband_cfg` | In | 1 | `clk_adc_iq` | When CSR `TURNAROUND_KABAND == 2'd0`, selects `0 = S-band (240/221)` or `1 = X-band (880/749)`. |
| | `mod_mode_cfg`, `line_code_cfg` | In | 2, 2 | `clk_adc_iq` | Modulation (`0=BPSK, 1=QPSK, 2=OQPSK, 3=PCM/PM`) & Line Code (`0=NRZ-L, 1=NRZ-M, 2=Bi-Phi-L`). |
| **Uplink RF & Symbol In** | `rx_i_adc_in`, `rx_q_adc_in`, `rx_iq_valid_in` | In | 12s, 12s, 1 | `clk_adc_iq` | Signed 12-bit two's-complement baseband I/Q ADC samples and sample clock-enable strobe. |
| | `s_axis_ul_sym_tvalid/tready/tdata/tlast` | In/Out | 1, 1, 8, 1 | `clk_tc_safe` | Uplink soft-LLR symbol (`tdata[3:0]`) or direct frame byte stream into RX2/RX3/RX4. |
| **OBC Packet Rx Master** | `m_axis_rx_pkt_tvalid/tready/tdata/tlast/tuser` | Out/In | 1, 1, 8, 1, 64 | `clk_sys` | Validated, decrypted, reassembled Space Packet output stream to Spacecraft OBC DMA. |
| **OBC Packet Tx Slave** | `s_axis_tx_pkt_tvalid/tready/tdata/tlast/tuser` | In/Out | 1, 1, 8, 1, 64 | `clk_sys` | Downlink Telemetry Space Packet ingress from Spacecraft OBC (`tuser.vcid[2:0]` selects VC `0..7`). |
| **Downlink CADU & IQ Out**| `m_axis_dl_cad_tvalid/tready/tdata/tlast` | Out/In | 1, 1, 8, 1 | `clk_tx_sym` | Zero-bubble scrambled & FEC-encoded Downlink CADU byte stream. |
| | `tx_i_dac_out`, `tx_q_dac_out`, `tx_iq_valid_out` | Out | 12s, 12s, 1 | `clk_adc_iq` | Signed 12-bit baseband I/Q DAC samples (pulse-shaped SRRC or 1-SPS + regenerative PN chip on Q). |
| **Emergency & EDAC** | `hcpd_obc_reset_pulse`, `hcpd_safe_mode_force`, `hcpd_rf_chain_select` | Out | 1, 1, 2 | `clk_tc_safe` | Direct hardware emergency command outputs from 3x TMR `ccsds_hcpd_ctrl` (`VCID=63`). |
| | `pn_All_Locked_out` | Out | 1 | `clk_adc_iq` | Asserted high when all 6 PN ranging components ($C_1..C_6$, $L=1,009,470$) achieve correlation lock. |
| | `fault_irq_out`, `edac_scrub_req_out` | Out | 1, 1 | `clk_sys` | Uncorrectable fault interrupt to OBC and SEU scrub request to FPGA configuration scrubber (e.g., Xilinx SEM). |

---

## 5. Complete Programmer's Register Map (`rtl/ccsds_axi_lite_csr.sv`)

All configuration registers (`0x04`, `0x08`, `0x0C`) are stored in **3x Triple Modular Redundant (TMR)** flip-flop banks (`*_a_q`, `*_b_q`, `*_c_q`) with continuous single-cycle majority-vote scrubbing (`SVA-CSR-4`). The register map below is 100% bit-exact with `rtl/ccsds_axi_lite_csr.sv` and `sw/ccsds_ttc_hal.h`.

| Offset | Register Name | Access | Reset Value | Bitfield Layout & Hardware Description |
| :---: | :--- | :---: | :---: | :--- |
| **`0x00`** | `CORE_ID_VER` | RO | `0xCC5D_0230` | `[31:16]` Magic ID (`16'hCC5D`), `[15:0]` Core Architecture Version (`16'h0230`). |
| **`0x04`** | `CTRL_SCID_PROTO` | R/W (3x TMR) | `0x0131_5155` | • `[9:0]` `SCID_10B`: 10-bit Spacecraft ID for TC/TM/Prox-1 (`10'h155` default)<br>• `[14:12]` `PROTO_MODE`: `3'd0`=TM, `3'd1`=AOS, `3'd2`=Prox-1, `3'd3`=USLP, `3'd4`=TC<br>• `[19:16]` `FEC_MODE`: `4'd0`=RS(255,223), `4'd1..4`=Turbo ($r=1/2, 1/3, 1/4, 1/6$)<br>• `[20]` `OCF_EN`: Enable 32-bit OCF (`CLCW`/`PLCW`) injection/extraction<br>• `[21]` `FECF_EN`: Enable 16/32-bit Frame Error Control Field CRC<br>• `[22]` `FECF_CRC32`: `0`=CRC-16-CCITT (`0x1021`), `1`=Proximity-1/USLP CRC-32 (`0x00A00805`)<br>• `[23]` `AOS_FHEC_EN`: Enable AOS 16-bit $GF(2^4)$ $\text{RS}(10,6)$ Frame Header Error Control<br>• `[24]` `TC_SEG_HDR_EN`: TC 8-bit Segment Header present on Type-AD/BD frames<br>• `[25]` `OBT_SEC_HDR_EN`: Enable 8-byte [CCSDS 301.0-B-4](https://ccsds.org/Pubs/301x0b4e1.pdf) CUC On-Board Time TM Secondary Header<br>• `[26]` `SDLS_EN`: Enable inline [CCSDS 355.0-B-2](https://ccsds.org/Pubs/355x0b2.pdf) SDLS encryption/authentication<br>• `[27]` `BC_REQ_SDLS`: `0`=Exempt Type-BC `Unlock`/`Set V(R)` per Sec 3.3.2.3; `1`=Require SDLS on Type-BC<br>• `[28]` `SRRC_4SPS_EN`: Enable 4-SPS 17-Tap ($\alpha=0.35$) SRRC Tx Pulse-Shaping & Rx Matched Filter<br>• `[29]` `GARDNER_TED_EN`: Enable closed-loop 4-SPS Gardner / Nyquist Zero-ISI Symbol Timing Recovery<br>• `[31:30]` `TURNAROUND_KABAND`: `2'd0`=Use `turnaround_xband_cfg` (`0`=S-band $240/221$, `1`=X-band $880/749$), `2'd1`=Ka-band Cat-B ($3344/749$), `2'd2`=Ka-band Cat-A ($3360/749$) |
| **`0x08`** | `CTRL_USLP_RS_CFG` | R/W (3x TMR) | `0x0001_4255` | • `[15:0]` `USLP_SCID_16B`: 16-bit Spacecraft ID for USLP frames (`16'h4255` default)<br>• `[19:16]` `RS_INTERLEAVE_I`: Dual-basis $\text{RS}(255,223)$ interleaving depth $I \in \{1,2,3,4,5,8\}$<br>• `[27:20]` `RS_VIRT_FILL_Q`: Implicit virtual fill symbols $Q \in [0..200]$ per RS codeword<br>• `[28]` `SDLS_GCM_MODE`: `0`=`AES-128-CTR` (1B tag), `1`=Full NIST SP 800-38D `AES-128-GCM` (128-bit `GHASH` tag)<br>• `[29]` `FLL_ASSIST_EN`: Enable sign-quantized Differential Cross-Product FLL-Assisted Costas carrier pull-in |
| **`0x0C`** | `CTRL_COP1_TFDF_CFG` | R/W (3x TMR) | `0x010D_F010` | • `[7:0]` `WINDOW_HALF_W`: COP-1 `FARM-1` / COP-P sliding window half-width $W$ (`8'd16` default)<br>• `[18:8]` `TFDF_BYTE_LEN`: Downlink Transfer Frame Data Field byte length (`11'd223` default)<br>• `[24]` `FAULT_IRQ_EN`: Master interrupt enable for `fault_irq_out` |
| **`0x10`** | `OBT_COARSE_SEC` | R/W | `0x6530_0000` | `[31:0]` [CCSDS 301.0-B-4](https://ccsds.org/Pubs/301x0b4e1.pdf) CUC On-Board Time Coarse Seconds (increments on `pps_1hz_pulse` or internal $1\text{ Hz}$ divider). |
| **`0x14`** | `OBT_FINE_SUBSEC` | R/W | `0x0000_0000` | `[15:0]` CUC On-Board Time Fine Sub-Seconds ($2^{-16}\text{ s} \approx 15.26\,\mu\text{s}$ resolution). |
| **`0x18`** | `EDAC_CORR_CNTS` | RO / W1C | `0x0000_0000` | • `[15:0]` `SECDED_CORR_CNT`: Saturating 16-bit counter of corrected 1-bit BCH & Hsiao SECDED errors (Write `1` to bit `0` to clear)<br>• `[31:16]` `TMR_SEU_CORR_CNT`: Saturating 16-bit counter of scrubbed TMR SEU bit-flips across `CSR`, `FARM-1`, and `HCPD` (Write `1` to bit `16` to clear) |
| **`0x1C`** | `FAULT_ERR_CNTS` | RO / W1C | `0x0000_0000` | • `[15:0]` `UNCORR_ERR_CNT`: Saturating 16-bit counter of uncorrectable 2-bit BCH/SECDED, Frame CRC, and Packet Length errors (Write `1` to bit `0` to clear)<br>• `[31:16]` `SDLS_MAC_ERR_CNT`: Saturating 16-bit counter of rejected SDLS MAC/GCM tag or anti-replay frames (Write `1` to bit `16` to clear) |
| **`0x20`** | `LATEST_CLCW_MON` | RO | `0x0000_0000` | `[31:0]` Latest 32-bit [CCSDS 232.1-B-2](https://ccsds.org/Pubs/232x1b2e2c1.pdf) Communications Link Control Word (`CLCW`) scheduled by `u_farm1` (`[7:0]` = $V(R)$ `report_value`, `[10]` = `retransmit`, `[11]` = `wait`, `[12]` = `lockout`). |
| **`0x24`** | `LATEST_PLCW_MON` | RO | `0x0000_0000` | `[31:0]` Latest 32-bit [CCSDS 211.0-B-6](https://ccsds.org/Pubs/211x0b6e1.pdf) Proximity Link Control Word (`PLCW`) scheduled by `u_prox1_plcw`. |

---

## 6. Flight & Ground EGSE Software Integration Guide (Bare-Metal C11 HAL SDK)

The repository ships with a zero-dependency, `MISRA-C`/`C11`-clean Hardware Abstraction Layer in `sw/ccsds_ttc_hal.h` and `sw/ccsds_ttc_hal.c` (verified by `sw/test_ccsds_ttc_hal.c` via `make hal-test`).

### 6.1 Step-by-Step Spacecraft Flight Core (`ROLE_MODE = 0`) Initialization Example

```c
#include "ccsds_ttc_hal.h"

void obc_ttc_flight_init(uintptr_t axi_csr_base_addr) {
    ccsds_ttc_dev_t ttc_dev;

    // 1. Attach to AXI4-Lite CSR base address and verify CORE_ID_VER == 0xCC5D0230
    ccsds_hal_status_t st = ccsds_ttc_init(&ttc_dev, axi_csr_base_addr, NULL, NULL);
    if (st != CCSDS_HAL_OK) {
        // Handle bus fault or unexpected IP version
        return;
    }

    // 2. Configure Spacecraft Mission Profile:
    //    - SCID = 0x155 (10-bit), USLP SCID = 0x4255 (16-bit)
    //    - Protocol = Classic TM/TC (CCSDS_PROTO_TM), Outer FEC = Dual-Basis RS(255,223) (I=1, Q=195)
    //    - Enable OCF (CLCW), FECF (CRC-16), TC Segment Header, and 8-byte CUC OBT Secondary Header
    //    - Enable Inline SDLS with Full 128-bit NIST SP 800-38D AES-128-GCM (GHASH)
    //    - Enable 4-SPS 17-Tap SRRC + Closed-Loop 4-SPS Gardner STR + FLL-Assisted Costas + Ka-Band Cat-B (3344/749)
    ccsds_ttc_config_t cfg = {
        .scid_10b          = 0x155u,
        .uslp_scid_16b     = 0x4255u,
        .proto_mode        = CCSDS_PROTO_TM,
        .fec_mode          = CCSDS_FEC_RS255_223,
        .ocf_en            = true,
        .fecf_en           = true,
        .fecf_crc32        = false,
        .aos_fhec_en       = false,
        .tc_seg_hdr_en     = true,
        .obt_sec_hdr_en    = true,
        .sdls_en           = true,
        .bc_require_sdls   = false, // Exempt Type-BC Unlock/Set V(R) per CCSDS 355.0-B-2 Sec 3.3.2.3
        .srrc_4sps_en      = true,
        .gardner_ted_en    = true,
        .fll_assist_en     = true,
        .sdls_gcm_mode     = true,  // 128-bit AES-128-GCM authentication tag
        .turnaround_kaband = CCSDS_TURNAROUND_KA_CAT_B_3344_749,
        .rs_interleave_i   = 1u,
        .rs_virt_fill_q    = 195u,  // 28B TM frame -> 60B shortened RS codeword
        .cop1_window_w     = 16u,
        .tfdf_byte_len     = 16u,
        .fault_irq_en      = true
    };
    (void)ccsds_ttc_configure(&ttc_dev, &cfg);

    // 3. Synchronize 48-bit CCSDS 301.0-B-4 CUC On-Board Time (OBT) at GPS 1-PPS edge
    (void)ccsds_ttc_set_obt(&ttc_dev, 0x65300042u, 0x8000u);
}
```

### 6.2 Polling Live COP-1 `CLCW` & Scrubbing Radiation EDAC Telemetry

```c
void obc_ttc_1hz_health_check(const ccsds_ttc_dev_t *ttc_dev) {
    ccsds_ttc_clcw_t clcw;
    ccsds_ttc_telemetry_t tlm;

    // Decode live 32-bit COP-1 CLCW from offset 0x20
    (void)ccsds_ttc_read_clcw(ttc_dev, &clcw);

    // Read EDAC & Fault counters (0x18, 0x1C) and 48-bit CUC OBT (0x10, 0x14)
    (void)ccsds_ttc_get_telemetry(ttc_dev, &tlm);

    if (tlm.tmr_seu_corr_cnt > 0u || tlm.secded_corr_cnt > 0u) {
        // Log radiation event to spacecraft housekeeping telemetry and clear W1C counters
        (void)ccsds_ttc_clear_edac_counters(ttc_dev, true, true);
    }
}
```

---

## 7. Space Flight Channel Validation & Multi-Stage Verification Summary (Stages 2–12)

### 7.1 Stage 12 (`tb_stage12_space_channel_loopback.sv`): Orbital Channel Validation Sign-Off

The IP core has been validated end-to-end as both **Spacecraft Flight Equipment (`ROLE_MODE=0`)** and **Ground Station EGSE (`ROLE_MODE=1`)** across our synthesizable **Orbital Space Flight Channel Impairment Model (`rtl/ccsds_space_flight_channel_model.sv`)** in **Xilinx Vivado 2022.2 `xsim`** (`146,531,250 ps` simulation time, `2,800` Uplink IQ samples, `4,336` Downlink IQ samples, **`0` errors**):

| Stage 12 Suite | Swept Mission & Channel Parameters | Verified Hardware Result (`Vivado 2022.2 xsim`) |
| :--- | :--- | :--- |
| **`CFG-1` (Multi-Rate & 12-Waveform Matrix)** | All **12 PHY Waveforms** (`BPSK`, `QPSK`, `OQPSK`, `PCM/PM` $\times$ `NRZ-L`, `NRZ-M`, `Bi-Phi-L`), variable symbol rates (`sym_rate_div = 1, 2, 4, 8`), 1-SPS rectangular & 4-SPS 17-Tap SRRC + closed-loop Gardner timing recovery across sub-symbol delays $\tau \in \{0,1,2,3\}$ | **PASS (`28/28` configurations with `0` bit errors)** |
| **`CFG-2` (Dynamic S-Curve Orbital Doppler & 4 Turnaround Ratios)** | Continuous LEO overflight **S-curve Doppler sweep** (`+512` at AOS $\rightarrow$ `0` at TCA $\rightarrow$ `-512` at LOS, `slew = -2`/sample) + phase noise jitter + FLL-Assisted Costas pull-in + **S-Band ($240/221$)**, **X-Band ($880/749$)**, **Ka-Band Cat-B ($3344/749$)**, and **Ka-Band Cat-A ($3360/749$)** turnaround NCOs | **PASS (All 4 bands locked & tracked S-curve Doppler with `0` bit errors)** |
| **`CFG-3` (Two-Way Slant-Range Delay & Regenerative PN Ranging)** | Programmable propagation delay line (`tau_prop = 4` & `9` samples) + Rician multipath + AWGN across `ROLE_MODE=1` (Ground EGSE) $\leftrightarrow$ `ROLE_MODE=0` (Spacecraft) in **T4B** and **T2B** PN ranging modes | **PASS (`sc_pn_locked == 1` & `gnd_pn_locked == 1` across delayed Rician channels)** |
| **`CFG-4` (All 5 CCSDS Protocols & Multi-FEC Modes)** | Sequential flight-channel verification of **TC (`232.0-B-4`)**, **TM (`132.0-B-3` + 48b CUC OBT)**, **AOS (`732.0-B-4` + $GF(2^4)$ FHEC)**, **Proximity-1 (`211.0-B-6` + CRC-32 + PLCW)**, and **USLP (`732.1-B-3`)** with $\text{BCH}(63,56)$ and Dual-Basis $\text{RS}(255,223)$ CADUs | **PASS (All 5 protocols & CADU streams verified with `0` errors)** |
| **`CFG-5` (Mid-Pass Rician Deep Fade & COP-1 Go-Back-$N$ Recovery)** | Mid-pass Rician deep-fade burst (`fade_atten = 0`) erasing Frame `N(S)=1` while `N(S)=2` arrives $\rightarrow$ Spacecraft `FARM-1` asserts `CLCW.Retransmit=1, V(R)=1` $\rightarrow$ Ground `FOP-1` rolls back $V(S)$ and replays `N(S)=1, 2` | **PASS (`V(R)` restored to `3` with `0` lost or duplicate packets)** |
| **`CFG-6` (Emergency HCPD over Space Channel)** | Authenticated Emergency Command (`VCID=63`, `MAGIC_OBC_HARD_RESET = 0xC0DE_CAFE_05FA_0010`) transmitted through impaired space channel into `u_spacecraft_top` | **PASS (`hcpd_obc_reset_pulse == 1` asserted cleanly)** |

### 7.2 Quick-Start Commands for Simulation, Synthesis & Git Sync

```powershell
# 1. Sync latest repository bundle from Google Drive (CCSDS_SAT_TTC_IP_Sync):
.\scripts\sync_from_gdrive.bat

# 2. Run any self-checking SystemVerilog testbench (Stages 2..12) in Xilinx Vivado xsim:
.\scripts\run_eda_sim.bat xsim 12   # Stage 12: Full Orbital Space Flight Channel Loopback
.\scripts\run_eda_sim.bat xsim 11   # Stage 11: Chip-to-Chip Top-to-Top RF Link Closure
.\scripts\run_eda_sim.bat xsim 10   # Stage 10: 5-Matrix Link-Closure & SEU Stress Suite
.\scripts\run_eda_sim.bat xsim 9    # Stage 9:  External Reference Check (spacepackets-py & PyCA AESGCM)
.\scripts\run_eda_sim.bat xsim 8    # Stage 8:  4-Protocol Loopback & Real Simulator VCD Matcher

# 3. Run Vivado 2022.2 Out-of-Context Synthesis, Utilization & Two-Pass True-Fmax STA:
.\scripts\run_vivado_sta.bat 0

# 4. Run Static IEEE 1800-2017 AST Audit & Bare-Metal C11 HAL SDK Unit Test:
python scripts/sv_rtl_audit.py
gcc -std=c11 -Wall -Wextra -Werror -Isw sw/ccsds_ttc_hal.c sw/test_ccsds_ttc_hal.c -o test_hal && ./test_hal
```

---

## 8. Documented Future Enhancements Roadmap (Cataloged Only — Not Required for Current Sign-Off)

Per project governance, the following optional future enhancements are documented for long-term roadmap reference:

1. **Higher-Order Spectral-Efficiency Payload Downlink Modulations ([CCSDS 131.2-B-1 SCCC](https://ccsds.org/Pubs/131x2b1.pdf) / [131.3-B-2 DVB-S2X](https://ccsds.org/Pubs/131x3b2.pdf)):** Adding `GMSK`, `8PSK`, `16APSK`, `32APSK`, and `64APSK` mapper/slicer constellations for multi-Gbps X/Ka-band Earth-observation payload downlinks.
2. **Long-Block Downlink AR4JA LDPC (`k = 1024, 4096, 16384` at rates $1/2, 2/3, 4/5$) & Uplink `(512,256)` Table 3-1 ROM:** Expanding the parity-check matrix ROMs to include the full `(512,256)` uplink short-block LDPC table and long-block downlink AR4JA quasi-cyclic LDPC encoders/decoders.
3. **256-Bit Key Expansion (`AES-256-GCM`) & `HMAC-SHA-256` in `ccsds_sdls_engine.sv`:** Extending the 10-round `AES-128-GCM` key schedule to 14 rounds (`AES-256-GCM`) and adding an optional `HMAC-SHA-256` authentication path for missions mandating 256-bit key lengths.
4. **Autonomous Scatter-Gather AXI4 / AMBA AHB Master Descriptor DMA:** Adding an optional scatter-gather DMA master wrapper around `s_axis_tx_pkt` and `m_axis_rx_pkt` for CPU-offloaded descriptor ring fetching, alongside Foundry-Specific Rad-Hard Cell Library Tech-Mapping (`techmap` wrappers for Microchip RTG4/PolarFire RT, AMD XQRKU060 SEM, and NanoXplore DICE cells).
