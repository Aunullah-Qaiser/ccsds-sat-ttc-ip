# CCSDS-SAT-TTC-IP (`v2.39.0`): Quick-Start Simulation, Lint, Synthesis & Verification Guide

This repository contains the complete **SystemVerilog (IEEE 1800-2017) Spacecraft Flight (`ROLE_MODE=0`), Hardware Ground EGSE (`ROLE_MODE=1`), and Universal Crosslink/BIST (`ROLE_MODE=2`) TT&C IP Core (`41` `.sv` files total: `28` synthesizable RTL files + `2` RF/Space flight channel models in `rtl/*.sv` + `11` self-checking SystemVerilog testbenches in `tb/tb_stage2_*.sv`..`tb/tb_stage12_*.sv`)**, the **Bare-Metal C11 Flight/EGSE HAL SDK (`sw/ccsds_ttc_hal.h`, `sw/ccsds_ttc_hal.c`, `sw/test_ccsds_ttc_hal.c`)**, the **Bit-Exact Python Ground EGSE Golden Model (`egse_model/ccsds_ground_egse_model.py`)**, and turnkey multi-simulator runners for **Windows PowerShell / CMD (`scripts\run_eda_sim.bat`, `scripts\run_eda_sim.ps1`)**, **WSL**, and **Linux (`Makefile`, `scripts/run_eda_sim.sh`)**.

Licensed under the **Apache License 2.0** (see [`LICENSE`](LICENSE)).

## 1. Running Xilinx Vivado (`xsim`) on Windows PowerShell / CMD / WSL

If you are running on **Windows PowerShell or Command Prompt** with a Windows installation of AMD/Xilinx Vivado (e.g., `C:\Xilinx\Vivado\2022.2\bin`):

### Option A1: Direct Native Batch or PowerShell Script (Stages 2 through 11)
```powershell
# Pull latest sync bundle (and clean any deprecated temporary files):
.\scripts\sync_from_gdrive.bat

# Run any self-checking RTL testbench (Stages 2..11) in Vivado xsim:
.\scripts\run_eda_sim.bat xsim 8
.\scripts\run_eda_sim.bat xsim 9
.\scripts\run_eda_sim.bat xsim 10
.\scripts\run_eda_sim.bat xsim 11
.\scripts\run_eda_sim.bat xsim 12
```

### Option A2: Using `make` in Windows PowerShell, WSL, or Linux
```powershell
make sim SIM=xsim STAGE=11
make sim SIM=xsim STAGE=10
make sim SIM=xsim STAGE=9
make sim SIM=xsim STAGE=8
```

## 2. Running Open-Source & Commercial Simulators (`Verilator`, `QuestaSim`, `Icarus Verilog`)

```bash
# Verilator (v5.0+ full-hierarchy lint & cycle-accurate --binary --timing simulation):
make lint
make sim SIM=verilator STAGE=8
make sim SIM=verilator STAGE=9
make sim SIM=verilator STAGE=10
make sim SIM=verilator STAGE=11

# Siemens QuestaSim / ModelSim:
make sim SIM=questa STAGE=11

# Icarus Verilog (-g2012):
make sim SIM=icarus STAGE=11
```

## 3. Running the Static AST Audit, C11 HAL SDK Test & Python/C++20 Reference-Model Cross-Check

```bash
make audit        # Audits all 39 SystemVerilog files (29 in rtl/ + 10 in tb/)
make hal-test     # Compiles and runs sw/test_ccsds_ttc_hal.c with gcc -std=c11 -Wall -Wextra -Werror
make regression   # Runs Python EGSE & C++20 Reference-Model Cross-Check suite
```

## 4. Stage 8: Sequential 4-Protocol Loopback, Real Simulator VCD Matcher & Channel Sweep

```powershell
# 1. Run Vivado xsim (or Verilator) on Stage 8 — dumps real simulator VCD to sim_waves/stage8_xsim_rtl.vcd
#    and automatically verifies it via scripts/vcd_waveform_matcher.py:
.\scripts\run_eda_sim.bat xsim 8

# 2. Run Best-to-Worst-Case Eb/N0 Channel Sweep (0..11 dB) + Generate PNG Plots:
python3 scripts/run_channel_ber_sweep.py

# 3. Run Vivado 2022.2 Out-of-Context Synthesis, Utilization & Two-Pass True-Fmax STA:
.\scripts\run_vivado_sta.bat 0
```

## 5. Stage 9: External Third-Party Library Interoperability & Zero-Placeholder Sign-Off (`v2.39.0`)

Run the complete **7-Subtest External Reference Interoperability Suite** (verified against University of Stuttgart IRS [`spacepackets-py`](https://github.com/us-irs/spacepackets-py) and PyCA [`cryptography`](https://cryptography.io/) NIST FIPS-197 `AES-128-CTR` & NIST SP 800-38D `AES-128-GCM` with **no self-loopback**):

```powershell
pip install spacepackets cryptography
.\scripts\run_eda_sim.bat xsim 9
```

| Subtest | External Reference Oracle | Hardware Under Test | Result |
| :--- | :--- | :--- | :--- |
| **EXT-REF-1** | `spacepackets-py` 42B CLTU (`APID=0x245, Seq=19, "SAT_CMD1"`) | `asm_correlator -> bch6356_dec -> tc_uslp_deframer -> farm1_tmr -> pkt_reassembler` | **PASS (`0` errors)** |
| **EXT-REF-2** | `spacepackets-py` 31B USLP Extended Frame (`APID=0x31A, Seq=42, OCF=0x01040002`) | `tc_uslp_deframer -> pkt_reassembler` | **PASS (`0` errors)** |
| **EXT-REF-3** | `spacepackets-py` 16B Telemetry Space Packet (`APID=0x109, Seq=88, "TLM_OBC_OK"`) | `vc_arbiter_mux -> tm_aos_uslp_framer -> dl_rs255_223_enc` (`64B CADU`) | **PASS (`32/32` RS syndromes `== 0`)** |
| **EXT-REF-4** | `cryptography` NIST FIPS-197 `AES-128-CTR` (`Key=2B7E1516...4F3C`) | `ccsds_sdls_engine` (1-round/clk AES-128-CTR Decrypt, Anti-Replay & Encrypt) | **PASS (`0` errors)** |
| **EXT-REF-5** | Corrupted 60B Dual-Basis $\text{RS}(255,223)$ Codeword (`byte[7]^=0xA5, byte[14]^=0x3C`) | `ccsds_dl_rs255_223_dec` (Peterson-Berlekamp + Chien + Forney Corrector) | **PASS (`2` corrupted bytes healed)** |
| **EXT-REF-6** | Two Noisy 128b CCSDS 231.1-O-1 Table 2-1/2-4 `(128,64)` LDPC CBs (`4` bit flips) | `ccsds_ul_short_ldpc_dec` & `ccsds_dl_turbo_ldpc_enc` (Table 2-1 $W_{64 \times 64}$ + Turbo 8-Prime) | **PASS (`4` bit errors healed)** |
| **EXT-REF-7** | `cryptography` NIST SP 800-38D `AES-128-GCM` (`GHASH` 128-bit Tag + Tamper Check) | `ccsds_sdls_engine` (`sdls_gcm_mode_cfg=1`, 4-bit/clk $GF(2^{128})$ `GHASH` + 16B Tag Stripper) | **PASS (`0` errors + tamper rejected)** |

## 6. Measured Xilinx Vivado 2022.2 (`xc7z010iclg225-1L`) Synthesis, Utilization & Two-Pass True-$F_{\max}$ STA (`v2.39.0`)

- **Synthesized Target Device (`reports/vivado_*_role0.rpt` & `reports/kintex_ultrascale_sta_and_utilization.json`):** **`xc7z010iclg225-1L`** (AMD/Xilinx Zynq-7000 28nm FPGA in the slowest `-1L` low-power speed grade; `17,600` available Slice LUTs, `35,200` available Slice Registers/FFs, `60` RAMB36, `80` DSP48E1).
- **Top-Level Utilization (`ROLE_MODE = 0` Spacecraft Flight Core):** **`17,064 / 17,600 Total Slice LUTs (`96.95%`)`** (`15,864 Logic LUTs` + `1,200 Distributed LUTRAMs`, `0 SRLs`), **`12,499 / 35,200 Slice Flip-Flops (`35.51%`)`**, **`0` RAMB36/RAMB18**, **`0` DSP Blocks**.
  - **Hierarchical Breakdown:** `u_sdls` (`ccsds_sdls_engine`): `7,919` LUTs, `5,571` FFs | `u_vc_arb` (`ccsds_vc_arbiter_mux`): `1,308` LUTs (`412` Logic + `896` LUTRAM), `151` FFs | `u_csr` (`ccsds_axi_lite_csr`): `839` LUTs, `438` FFs | `u_farm1` (`ccsds_farm1_tmr`): `431` LUTs, `341` FFs.
- **Two-Pass Static Timing Analysis (`Pass 1` Nominal Closure vs. `Pass 2` Overclock-Push True-$F_{\max}$):**
  - In **Pass 1 (`vivado_timing_nominal_role0.rpt`)**, all 4 clock domains meet their nominal mission targets (`100 / 120 / 50 / 16 MHz`) with positive slack (`WNS > 0, TNS = 0.000 ns`).
  - In **Pass 2 (`vivado_timing_fmax_push_role0.rpt`)**, clocks are intentionally over-constrained to `3.333 / 3.000 / 3.333 / 4.000 ns` (`300 / 333.3 / 300 / 250 MHz`) to expose each domain's limiting physical path and compute $T_{\min} = T_{\text{push}} - \text{WNS}_{\text{push}}$ and $\text{True } F_{\max} = 1000 / T_{\min}$:

| Clock Domain | Nominal Target ($T_{\text{nom}}$) | Nominal Slack (`Pass 1`) | Overclock-Push Target ($T_{\text{push}}$) | Push Slack (`Pass 2`) | Min Period ($T_{\min}$) | **True $F_{\max}$ (`xc7z010-1L`)** | Logic Levels & Limiting Physical Critical Path |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **`clk_sys`** | `100.0 MHz` (`10.000 ns`) | **`+1.374 ns` (`PASS`)** | `300.0 MHz` (`3.333 ns`) | `-5.293 ns` | `8.626 ns` | **`115.93 MHz` (`+15.93%`)** | `8` levels (`u_rx_commit_cdc_fifo/rd_ptr_q_reg[0]/C -> u_reassembler/hdr_idx_q_reg[0]/D`) |
| **`clk_adc_iq`** | `120.0 MHz` (`8.333 ns`) | **`+1.265 ns` (`PASS`)** | `333.3 MHz` (`3.000 ns`) | `-4.068 ns` | `7.068 ns` | **`141.48 MHz` (`+17.90%`)** | `8` levels (`u_phy_modem/rx_phase_q16_reg[10]/C -> u_phy_modem/i_derot_q_reg[13]/D`) |
| **`clk_tx_sym`** | `50.0 MHz` (`20.000 ns`) | **`+14.594 ns` (`PASS`)** | `300.0 MHz` (`3.333 ns`) | `-2.073 ns` | `5.406 ns` | **`184.98 MHz` (`+269.96%`)** | `5` levels (`u_tx_hwm_cdc_fifo/wr_spec_ptr_q_reg[1]/C -> u_tx_hwm_cdc_fifo/wr_spec_ptr_q_reg[0]/CE`) |
| **`clk_tc_safe`** | `16.0 MHz` (`62.500 ns`) | **`+52.901 ns` (`PASS`)** | `250.0 MHz` (`4.000 ns`) | `-5.599 ns` | `9.599 ns` | **`104.18 MHz` (`+551.13%`)** | `11` levels (`u_farm1/v_r_tmr_reg[1][7][1]/C -> u_farm1/clcw_scheduled_out_reg[lockout]/D`) |

## 7. Stage 10: Full-Matrix Configuration & Impaired-Channel Link-Closure Stress Suite (`v2.39.0`)

Run the **5-Matrix End-to-End Configuration & Impaired-Channel Link-Closure Stress Testbench (`tb_stage10_full_matrix_link_stress.sv`)**:

```powershell
.\scripts\run_eda_sim.bat xsim 10
```

- **`MATRIX-1A, 1B, 1C, 1D & 1E`:** Sweeps all **12 Baseband PHY modes** (`BPSK`, `QPSK`, `OQPSK`, `PCM/PM` $\times$ `NRZ-L`, `NRZ-M`, `Bi-Phi-L`) under AWGN and $180^\circ$ phase inversion (`MATRIX-1A`), Continuous $\pm 384$ CFO (`MATRIX-1B`), 4-SPS 17-Tap SRRC ($\alpha=0.35$) Pulse-Shaping + Matched Filter (`MATRIX-1C`), Closed-Loop 4-SPS Gardner Symbol Timing Recovery across all 48 `(4 Modulations x 4 Timing Offsets tau=0..3 x 3 CFOs)` + S/X/Ka-Band Turnaround Ratios (`MATRIX-1D`), Wide Cold-Start $\pm 640$ CFO FLL-Assisted Costas Carrier Pull-In (`MATRIX-1E`), and **T2B/T4B PN Ranging**.
- **`MATRIX-2`:** Proves **concatenated `Conv(K=7, r=1/2)` + `64-State Soft Viterbi` + `RS(255,223)` Peterson-Berlekamp** link closure when the channel injects both distributed symbol errors and a 2-byte burst error (`"CONCAT_FEC_OK!"`).
- **`MATRIX-3`:** Verifies `AOS` $GF(2^4)$ `FHEC` and sweeps all 5 `ccsds_dl_turbo_ldpc_enc` modes (`LDPC(128,64)` + `Turbo r=1/2, 1/3, 1/4, 1/6`).
- **`MATRIX-4A & 4B`:** Proves encrypted **NIST FIPS-197 `AES-128-CTR`** (`MATRIX-4A`) and **NIST SP 800-38D `AES-128-GCM` (`GHASH` 128-bit Tag + Tamper Rejection, `MATRIX-4B`)** over noisy `BCH(63,56)` ($180^\circ$ phase inversion + 1-bit SEC + 2-bit burst drop recovery via `CLCW.Retransmit=1` & `FOP-1` Go-Back-$N$).
- **`MATRIX-5`:** Injects a simultaneous **Radiation SEU Storm** across `FARM-1` TMR, `HCPD` TMR, and `Hsiao SECDED FIFO` during an authenticated `EMERGENCY_VCID=63` command (`0xC0DE_CAFE_05FA_0010`).

## 8. Stage 11: Full Chip-to-Chip Top-Level RF Link-Closure Testbench & C11 HAL SDK (`v2.39.0`)

Run the **Top-to-Top RF Link-Closure Testbench (`tb_stage11_top_to_top_rf_link.sv`)** and **Bare-Metal C11 Flight/EGSE HAL Unit Test (`sw/test_ccsds_ttc_hal.c`)**:

```powershell
.\scripts\run_eda_sim.bat xsim 11
gcc -std=c11 -Wall -Wextra -Werror -Isw sw/ccsds_ttc_hal.c sw/test_ccsds_ttc_hal.c -o test_ccsds_ttc_hal && ./test_ccsds_ttc_hal
```

- **`SUBTEST-11.1`:** Verifies `AXI4-Lite` CSR programming and readback on both Spacecraft Top (`ROLE_MODE=0`) and Ground EGSE Top (`ROLE_MODE=1`) (`REG_CTRL=0x04`, `REG_ASM_PAT=0x2C314255`, `REG_USLP_RS_CFG=0x01001010`).
- **`SUBTEST-11.2`:** Runs Wideband **T4B PN Ranging** acquisition (`sc_pn_locked == 1 && gnd_pn_locked == 1`) + True Top-to-Top 16-bit AD9361 RF Uplink CLTU Loopback (`sc_ul_sym_tvalid == 0`, `384` Uplink RF IQ samples across `u_ul_rf_channel`, `u_rx_phy_cdc_fifo -> u_asm_corr -> u_bch_dec`, `"TOP_CMD1"` delivered to Spacecraft OBC, `CLCW V(R) == 1`).
- **`SUBTEST-11.3`:** Streams a 16-byte Telemetry Space Packet (`APID=0x109, Seq=33, "SAT_TLM_OK"`) into Spacecraft Top `s_axis_tx_pkt`, modulating a 64-byte Dual-Basis $\text{RS}(255,223)$ Downlink CADU (`512` Downlink RF IQ samples across `u_dl_rf_channel`), which Ground EGSE Top demodulates, derandomizes, RS-decodes, deframes, captures live `CLCW V(R)=1` at CSR `0x20`, and reassembles into `"SAT_TLM_OK"` (`38,626 ns`, `0` errors in Vivado 2022.2 `xsim`).

## 9. Stage 12: Multi-Configuration Space Flight Channel Loopback & Modular Synthesis (`v2.39.0`)

Run the **Multi-Configuration Space Flight Channel Loopback Testbench (`tb_stage12_space_channel_loopback.sv`)** across `rtl/ccsds_space_flight_channel_model.sv`:

```powershell
.\scripts\run_eda_sim.bat xsim 12
```

- **`CFG-1` (28 Waveforms x Symbol Rates x 4-SPS Gardner STR):** Sweeps all 12 PHY waveforms (`BPSK`, `QPSK`, `OQPSK`, `PCM/PM` x `NRZ-L`, `NRZ-M`, `Bi-Phi-L`), variable symbol rates (`sym_rate_div = 1, 2, 4, 8`), and 4-SPS SRRC + Gardner timing recovery (`tau = 0..3`).
- **`CFG-2` (Dynamic S-Curve Orbital Doppler + All 4 Turnaround Ratios):** Sweeps dynamic LEO pass Doppler (`+512` AOS -> `0` TCA -> `-512` LOS), phase noise, and all 4 coherent turnaround ratios (`S-Band 240/221`, `X-Band 880/749`, `Ka-Band Cat-B 3344/749`, `Ka-Band Cat-A 3360/749`).
- **`CFG-3` (Wideband T4B & T2B Regenerative PN Ranging):** Verifies all 6 PN ranging components (`pn_All_Locked_out == 1`) under orbital propagation delay and AWGN.
- **`CFG-4` (All 5 Framing Protocols & All Uplink/Downlink FEC + SDLS Modes):** Exercises `TC`, `TM`, `AOS` (with FHEC), `Proximity-1` (`CRC-32`), and `USLP` alongside `BCH(63,56)`, `Short-LDPC(128,64)`, `RS(255,223)`, `Conv(K=7)/Viterbi`, `Turbo`, `AES-128-CTR`, and `AES-128-GCM`.
- **`CFG-5` & `CFG-6` (Mid-Pass Rician Deep Fade COP-1 Recovery & Emergency HCPD):** Proves automatic `CLCW.Retransmit=1` Go-Back-N recovery across a mid-pass Rician deep fade and `VCID=63` emergency `HCPD` execution.
- **Modular Synthesis Parameters (`ENABLE_SDLS`, `ENABLE_UL_LDPC`):** Full transceiver (`ENABLE_SDLS=1, ENABLE_UL_LDPC=1`) synthesizes into `28,861` Slice LUTs (**`54.25%` of `xc7z020clg484-1`**, `0` BRAMs, `0` DSPs) with **0 critical CDC violations** (`u_tx_phy_cdc_fifo` bridging `clk_tx_sym -> clk_adc_iq`), while compact builds (`ENABLE_SDLS=0, ENABLE_UL_LDPC=0`) fit in `xc7z010` (`~8,332` LUTs, `47.3%`).


### Product Guide & User Manual (`PG-CCSDS-TTC-v2.39.0`)
- **Markdown Product & User Guide:** [`docs/CCSDS_SAT_TTC_IP_PRODUCT_USER_GUIDE.md`](docs/CCSDS_SAT_TTC_IP_PRODUCT_USER_GUIDE.md)
- **Publication-Grade LaTeX & PDF Product Guide:** [`docs/CCSDS_SAT_TTC_IP_Product_User_Guide.tex`](docs/CCSDS_SAT_TTC_IP_Product_User_Guide.tex) / [`docs/CCSDS_SAT_TTC_IP_Product_User_Guide.pdf`](docs/CCSDS_SAT_TTC_IP_Product_User_Guide.pdf)
- **Engineering Architecture Book:** [`docs/ccsds_ttc_ip_engineering_book.tex`](docs/ccsds_ttc_ip_engineering_book.tex)


### Latest Vivado 2022.2 Measured True-Fmax Sign-Off (`v2.39.0`, Post-Stage-12 Full-Featured `ROLE_MODE = 0`)
- **`clk_sys` (Nominal 100.0 MHz)**: Push Target `300.0 MHz` (`3.333 ns`), Push Slack `-1.268 ns`, Min Period `4.601 ns` -> **True Fmax = `217.34 MHz` (`+117.34%` margin)**, 13 Logic Levels (`u_vc_arb/cur_pkt_byte_cnt_q_reg[5]/C -> u_vc_arb/wr_spec_ptr_q_reg[3]/D`)
- **`clk_adc_iq` (Nominal 120.0 MHz)**: Push Target `333.3 MHz` (`3.000 ns`), Push Slack `-0.680 ns`, Min Period `3.680 ns` -> **True Fmax = `271.74 MHz` (`+126.45%` margin)**, 7 Logic Levels (`u_phy_modem/rx_phase_q16_reg[10]/C -> u_phy_modem/q_derot_q_reg[13]/D`)
- **`clk_tx_sym` (Nominal 50.0 MHz)**: Push Target `300.0 MHz` (`3.333 ns`), Push Slack `-0.968 ns`, Min Period `4.301 ns` -> **True Fmax = `232.50 MHz` (`+365.00%` margin)**, 6 Logic Levels (`u_tx_hwm_cdc_fifo/rd_ptr_q_reg[0]/C -> u_tx_phy_cdc_fifo/mem_ecc_reg_0_63_6_6/DP/I`)
- **`clk_tc_safe` (Nominal 16.0 MHz)**: Push Target `250.0 MHz` (`4.000 ns`), Push Slack `-0.917 ns`, Min Period `4.917 ns` -> **True Fmax = `203.38 MHz` (`+1171.13%` margin)**, 11 Logic Levels (`u_ul_deframer/cur_tc_hdr_q_reg[vcid][4]/C -> u_farm1/clcw_scheduled_out_reg[wait_flag]/D`)


## 10. Pre-Hardware Deployment Audit Upgrades (`v2.39.0`)

1. **Internal 4-Bit AD9361 I/Q Bus Adaptation (`IQ_BUS_WIDTH = 16` default in `rtl/ccsds_sat_ttc_top.sv`):** Directly interfaces with 16-bit Analog Devices `axi_ad9361` I/Q ports (`adc_data_i0[15:0]` / `dac_data_i0[15:0]`) by slicing the lower 12 two's-complement ADC bits (`rx_i_adc_in[11:0]`) on receive and zero-padding 4 LSBs (`{phy_tx_i_12b, 4'b0000}`) on transmit, while preserving `IQ_BUS_WIDTH = 12` for legacy 12-bit channel models.
2. **Uplink Rx Asynchronous CDC FIFO (`u_rx_phy_cdc_fifo`) & Bit-to-LLR Serializer:** Bridges demodulated uplink symbol bytes (`phy_rx_sym_byte`, `phy_rx_sym_valid`) from `clk_adc_iq` (`120 MHz`) into `clk_tc_safe` (`16 MHz`) via a dual-clock Gray-code Hsiao SECDED FIFO (`ccsds_cdc_fifo_ecc`) and MSB-first 8-bit serializer feeding `u_asm_corr`.
3. **Per-Domain 2-Flip-Flop Reset Synchronizer Bridges:** Asynchronous-assert, synchronous-deassert `(* ASYNC_REG = "TRUE" *)` 2-FF reset bridges (`rst_sys_n`, `rst_tc_n`, `rst_tx_n`, `rst_adc_n`) across all 4 independent clock domains.
4. **Runtime SDLS 256-Bit Key & Security Association (`SA`) Provisioning (`0x28..0x50`):** Adds AXI4-Lite registers `CCSDS_REG_SDLS_KEY_0..7` (`0x28..0x44`), `CCSDS_REG_SDLS_SA_CTRL` (`0x48`), `CCSDS_REG_SDLS_SA_SPI` (`0x4C`), and `CCSDS_REG_SDLS_SA_SEQ` (`0x50`) with `clk_sys -> clk_tc_safe` CDC synchronization and C11 HAL APIs (`ccsds_ttc_hal_set_sdls_key256`, `ccsds_ttc_hal_provision_sdls_sa`).
5. **Top-Level `pps_1hz_in` Pin & Active OBT Timebase:** Exposes `pps_1hz_in` on `ccsds_sat_ttc_top` with a 2-FF `ASYNC_REG` synchronizer, rising-edge detector, and internal `100,000,000`-cycle (`1.000 s @ 100 MHz`) free-running fallback divider driving `u_csr.pps_1hz_pulse`.
6. **Downlink CADU Pseudo-Randomizer (`tm_rand_en_cfg`) & Complete Board XDC Constraints:** Exposes `tm_rand_en_cfg` at `CTRL_USLP_RS_CFG[30]` (`0x08`) wired to `u_rs_enc` and `u_tm_scram`, and adds asynchronous reset/strap false-paths, AD9361 source-synchronous I/O delays, and reference board `PACKAGE_PIN`/`IOSTANDARD` constraints to `constraints/ccsds_kintex_ultrascale.xdc`.

## 11. Firmware Configuration Gating & 12-Thread Parallel 5,760-Configuration Stage 11 RF Matrix Sign-Off (`v2.39.0`)

- **Firmware Configuration Gating (`sw/ccsds_ttc_hal.c` — `ccsds_ttc_hal_validate_config`)**:
  Automatically validates all configuration structures before writing hardware CSRs (`0x04..0x0C`), rejecting illegal non-CCSDS combinations with explicit status codes (`CCSDS_HAL_ERR_MOD_LINE_INCOMPAT = -10` through `CCSDS_HAL_ERR_FRAME_LEN_RANGE = -17`), verified by `sw/test_ccsds_ttc_hal.c`.
- **12-Thread Parallel 480-Configuration Valid RF Matrix (`scripts/run_stage11_matrix_parallel.py` & `scripts\run_stage11_matrix_parallel.bat`)**:
  Compiles the 41-file SystemVerilog hierarchy once (`xvlog` + `xelab`) and launches **12 isolated parallel `xsim` worker threads** (`CHUNK_ID=0..11`, `40` configurations/thread) to sweep **100% (`480/480`) of the valid chip-to-chip RF configuration matrix** (`10` Valid Waveforms $\times$ `4` Turnaround Bands $\times$ `3` Variable Uplink Packet/Frame Sizes `{8B, 14B, 28B}` $\times$ `4` Variable Downlink Frame/OBT/Randomizer Modes `{10B, 16B+Rand, 16B+OBT+Rand, 32B+Rand}` = `960` true 16-bit RF packet transfers):
  ```powershell
  .\scripts\sync_from_gdrive.bat
  gcc -std=c11 -Wall -Wextra -Werror -Isw sw/ccsds_ttc_hal.c sw/test_ccsds_ttc_hal.c -o test_ccsds_ttc_hal.exe && .\test_ccsds_ttc_hal.exe
  .\scripts\run_stage11_matrix_parallel.bat 12
  ```

- **Measured 5,760-Configuration Combined Mission Envelope Sign-Off (`reports/stage11_rf_matrix_coverage.json`, Vivado 2022.2 `xsim`, 12 Threads):**
  - **Command Executed:** `.\scripts\run_stage11_matrix_parallel.bat 12 1 combined`
  - **Configuration Coverage:** **`5,760 / 5,760` (`100.0%` PASS, `0` FAIL)** across all `10` PHY waveforms $\times$ `4` coherent turnaround bands $\times$ `3` uplink packet sizes (`8B`, `14B`, `28B`) $\times$ `4` downlink frame/OBT/randomizer modes (`10B`, `16B`, `16B+OBT`, `32B`) $\times$ `2` uplink FECs (`BCH(63,56)`, `Short-LDPC(128,64)`) $\times$ `3` downlink framing protocols (`TM`, `AOS`, `USLP`) $\times$ `2` security modes (`Clear`, `SDLS AES-128-CTR+MAC`).
  - **Total RF Traffic & IQ Samples:** **`11,520` bidirectional RF packet transfers** (`5,760` UL packets / `96,000` B Space Packet payload + `5,760` DL packets / `106,560` B Space Packet payload) across **`6,551,040` 16-bit AD9361 RF I/Q samples** (`3,179,520` Uplink IQ samples + `3,371,520` Downlink IQ samples).
  - **Active FEC & Channel Impairment Performance (`P5_COMBINED_MC`):** **`11,520` pre-FEC injected channel errors corrected $\rightarrow$ `0` post-FEC bit errors** (`empirical_post_fec_ber = 0.0`, `empirical_post_fec_fer = 0.0`) in **`343.81s` (`5.73 min`) wall-clock time** (`197.85s..327.43s` per 480-config worker thread).

- **Measured 5,760-Configuration $\times$ 6-Profile Progressive Monte Carlo Sign-Off (`reports/stage11_rf_matrix_coverage.json`, Vivado 2022.2 `xsim`, 12 Threads):**
  - **Command Executed:** `.\scripts\run_stage11_matrix_parallel.bat 12 6 progressive`
  - **Configuration & Profile Coverage:** **`5,760 / 5,760` configurations (`100.0%` PASS, `0` FAIL)** and **`34,560 / 34,560` bidirectional Monte Carlo trials (`100.0%` PASS, `0` FAIL)** across all **6 Progressive OAT + Combined Mission Envelope profiles** (`P0_CLEAN_REF = 5,760/5,760`, `P1_OAT_AWGN_FEC = 5,760/5,760`, `P2_OAT_DOPPLER_PN = 5,760/5,760`, `P3_OAT_DELAY_MP = 5,760/5,760`, `P4_OAT_RF_ANALOG = 5,760/5,760`, `P5_COMBINED_MC = 5,760/5,760`).
  - **Total RF Traffic & 16-Bit IQ Samples:** **`69,120` RF packet transfers** (`34,560` UL packets / `576,000` B Space Packet payload + `34,560` DL packets / `639,360` B Space Packet payload = `1,215,360` B total payload) across **`39,306,240` 16-bit AD9361 RF I/Q samples** (`19,077,120` Uplink IQ samples + `20,229,120` Downlink IQ samples).
  - **Active Hardware FEC Error Correction:** **`23,040` pre-FEC injected channel errors (`1,920`/worker) corrected $\rightarrow$ `0` post-FEC bit errors** (`empirical_post_fec_ber = 0.0`, `empirical_post_fec_fer = 0.0`) in **`1,984.46s` (`33.07 min`) wall-clock time** (`1,252.11s..1,972.55s` per 2,880-trial worker thread).
