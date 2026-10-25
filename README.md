# CCSDS-SAT-TTC-IP (`v2.29.0`): Quick-Start Simulation, Lint, Synthesis & Verification Guide

This repository contains the complete **SystemVerilog (IEEE 1800-2017) Spacecraft Flight (`ROLE_MODE=0`), Hardware Ground EGSE (`ROLE_MODE=1`), and Universal Crosslink/BIST (`ROLE_MODE=2`) TT&C IP Core (`39` `.sv` files total: `28` synthesizable RTL files + `1` channel impairment model in `rtl/*.sv` + `10` self-checking SystemVerilog testbenches in `tb/tb_stage2_*.sv`..`tb/tb_stage11_*.sv`)**, the **Bare-Metal C11 Flight/EGSE HAL SDK (`sw/ccsds_ttc_hal.h`, `sw/ccsds_ttc_hal.c`, `sw/test_ccsds_ttc_hal.c`)**, the **Bit-Exact Python Ground EGSE Golden Model (`egse_model/ccsds_ground_egse_model.py`)**, and turnkey multi-simulator runners for **Windows PowerShell / CMD (`scripts\run_eda_sim.bat`, `scripts\run_eda_sim.ps1`)**, **WSL**, and **Linux (`Makefile`, `scripts/run_eda_sim.sh`)**.

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

## 5. Stage 9: External Third-Party Library Interoperability & Zero-Placeholder Sign-Off (`v2.29.0`)

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

## 6. Measured Xilinx Vivado 2022.2 (`xc7z010iclg225-1L`) Synthesis, Utilization & Two-Pass True-$F_{\max}$ STA (`v2.29.0`)

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

## 7. Stage 10: Full-Matrix Configuration & Impaired-Channel Link-Closure Stress Suite (`v2.29.0`)

Run the **5-Matrix End-to-End Configuration & Impaired-Channel Link-Closure Stress Testbench (`tb_stage10_full_matrix_link_stress.sv`)**:

```powershell
.\scripts\run_eda_sim.bat xsim 10
```

- **`MATRIX-1A, 1B, 1C, 1D & 1E`:** Sweeps all **12 Baseband PHY modes** (`BPSK`, `QPSK`, `OQPSK`, `PCM/PM` $\times$ `NRZ-L`, `NRZ-M`, `Bi-Phi-L`) under AWGN and $180^\circ$ phase inversion (`MATRIX-1A`), Continuous $\pm 384$ CFO (`MATRIX-1B`), 4-SPS 17-Tap SRRC ($\alpha=0.35$) Pulse-Shaping + Matched Filter (`MATRIX-1C`), Closed-Loop 4-SPS Gardner Symbol Timing Recovery across all 48 `(4 Modulations x 4 Timing Offsets tau=0..3 x 3 CFOs)` + S/X/Ka-Band Turnaround Ratios (`MATRIX-1D`), Wide Cold-Start $\pm 640$ CFO FLL-Assisted Costas Carrier Pull-In (`MATRIX-1E`), and **T2B/T4B PN Ranging**.
- **`MATRIX-2`:** Proves **concatenated `Conv(K=7, r=1/2)` + `64-State Soft Viterbi` + `RS(255,223)` Peterson-Berlekamp** link closure when the channel injects both distributed symbol errors and a 2-byte burst error (`"CONCAT_FEC_OK!"`).
- **`MATRIX-3`:** Verifies `AOS` $GF(2^4)$ `FHEC` and sweeps all 5 `ccsds_dl_turbo_ldpc_enc` modes (`LDPC(128,64)` + `Turbo r=1/2, 1/3, 1/4, 1/6`).
- **`MATRIX-4A & 4B`:** Proves encrypted **NIST FIPS-197 `AES-128-CTR`** (`MATRIX-4A`) and **NIST SP 800-38D `AES-128-GCM` (`GHASH` 128-bit Tag + Tamper Rejection, `MATRIX-4B`)** over noisy `BCH(63,56)` ($180^\circ$ phase inversion + 1-bit SEC + 2-bit burst drop recovery via `CLCW.Retransmit=1` & `FOP-1` Go-Back-$N$).
- **`MATRIX-5`:** Injects a simultaneous **Radiation SEU Storm** across `FARM-1` TMR, `HCPD` TMR, and `Hsiao SECDED FIFO` during an authenticated `EMERGENCY_VCID=63` command (`0xC0DE_CAFE_05FA_0010`).

## 8. Stage 11: Full Chip-to-Chip Top-Level RF Link-Closure Testbench & C11 HAL SDK (`v2.29.0`)

Run the **Top-to-Top RF Link-Closure Testbench (`tb_stage11_top_to_top_rf_link.sv`)** and **Bare-Metal C11 Flight/EGSE HAL Unit Test (`sw/test_ccsds_ttc_hal.c`)**:

```powershell
.\scripts\run_eda_sim.bat xsim 11
gcc -std=c11 -Wall -Wextra -Werror -Isw sw/ccsds_ttc_hal.c sw/test_ccsds_ttc_hal.c -o test_ccsds_ttc_hal && ./test_ccsds_ttc_hal
```

- **`SUBTEST-11.1`:** Verifies `AXI4-Lite` CSR programming and readback on `ccsds_sat_ttc_top (ROLE_MODE=0)` (`REG_CTRL=0x04`, `REG_ASM_PAT=0x2C314255`, `REG_USLP_RS_CFG=0x01001010`).
- **`SUBTEST-11.2`:** Runs Wideband **T4B PN Ranging** acquisition (`pn_epoch_locked_out == 1`) + Uplink Telecommand CLTU (`APID=0x245, Seq=7, "TOP_CMD1"`) across `u_ul_rf_channel` into Spacecraft Top OBC `m_axis_rx_pkt`, verifying `CLCW V(R) == 1`.
- **`SUBTEST-11.3`:** Streams a 16-byte Telemetry Space Packet (`APID=0x109, Seq=33, "SAT_TLM_OK"`) into Spacecraft Top `s_axis_tx_pkt`, verifying the emitted 64-byte Dual-Basis $\text{RS}(255,223)$ Downlink CADU (`ASM=0x1ACFFC1D`, embedded `CLCW V(R)=1`) and 64 baseband IQ samples across `u_dl_rf_channel`.
