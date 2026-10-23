# CCSDS-SAT-TTC-IP (`v2.10`): Quick-Start Simulation, Lint & Verification Guide

This archive contains the complete **28-module SystemVerilog (IEEE 1800-2017) Spacecraft Flight (`ROLE_MODE=0`), Hardware Ground EGSE (`ROLE_MODE=1`), and Universal Crosslink/BIST (`ROLE_MODE=2`) TT&C IP Core**, along with **6 self-checking SystemVerilog testbenches (`tb/*.sv`)**, **6 pre-generated `.vcd` waveforms (`sim_waves/*.vcd`)**, the **Bit-Exact Python Ground EGSE Golden Model (`egse_model/ccsds_ground_egse_model.py`)**, and turnkey multi-simulator runners for **Windows PowerShell / CMD (`scripts\run_eda_sim.bat`, `scripts\run_eda_sim.ps1`)**, **WSL**, and **Linux (`Makefile`, `scripts/run_eda_sim.sh`)**.

## 1. Running Xilinx Vivado (`xsim`) on Windows PowerShell / CMD / WSL

If you are running on **Windows PowerShell or Command Prompt** with a Windows installation of AMD/Xilinx Vivado (e.g., `C:\Xilinx\Vivado\2022.2\bin`):

### Option A1: Using `make` in Windows PowerShell or WSL
```powershell
# Makefile automatically detects Windows_NT (or WSL /mnt/c/Xilinx/...) and invokes
# xvlog.bat / xelab.bat / xsim.bat (64-bit win64.o executables) instead of lnx64.o:
make sim SIM=xsim STAGE=7
make sim SIM=xsim STAGE=6
```

### Option A2: Direct Native PowerShell or Batch Script (Zero `make` or `WSL` Required)
```powershell
# Run directly in Windows PowerShell:
.\scripts\run_eda_sim.ps1 -Sim xsim -Stage 7
.\scripts\run_eda_sim.ps1 -Sim xsim -Stage 6

# Or via Windows Command Prompt / PowerShell batch file:
.\scripts\run_eda_sim.bat xsim 7
```

### Option A3: Running Individual Vivado `xvlog` / `xelab` / `xsim` Commands Manually in PowerShell
```powershell
xvlog.bat -sv -i rtl rtl/ccsds_pkg.sv rtl/ccsds_crc_universal.sv rtl/ccsds_lfsr_scrambler.sv rtl/ccsds_cdc_fifo_ecc.sv rtl/ccsds_gf256_math.sv rtl/ccsds_asm_correlator.sv rtl/ccsds_bch6356_dec.sv rtl/ccsds_farm1_tmr.sv rtl/ccsds_vc_arbiter_mux.sv rtl/ccsds_dl_rs255_223_enc.sv rtl/ccsds_tc_uslp_deframer.sv rtl/ccsds_tm_aos_uslp_framer.sv rtl/ccsds_pkt_reassembler.sv rtl/ccsds_prox1_plcw_ctrl.sv rtl/ccsds_axi_lite_csr.sv rtl/ccsds_conv_viterbi_codec.sv rtl/ccsds_ul_short_ldpc_dec.sv rtl/ccsds_dl_turbo_ldpc_enc.sv rtl/ccsds_hcpd_ctrl.sv rtl/ccsds_sdls_engine.sv rtl/ccsds_pn_ranging.sv rtl/ccsds_phy_modem.sv rtl/ccsds_bch6356_enc.sv rtl/ccsds_tc_cltu_framer.sv rtl/ccsds_fop1_engine.sv rtl/ccsds_tm_aos_deframer.sv rtl/ccsds_dl_rs255_223_dec.sv rtl/ccsds_sat_ttc_top.sv tb/tb_stage7_hw_egse_loopback.sv
xelab.bat -debug typical tb_stage7_hw_egse_loopback -s tb_stage7_hw_egse_loopback_sim
xsim.bat tb_stage7_hw_egse_loopback_sim -R
```

## 2. Running Other Simulators (`Verilator`, `QuestaSim`, `Icarus Verilog`)

```bash
# Verilator (v5.0+):
make lint
make sim SIM=verilator STAGE=7

# Siemens QuestaSim / ModelSim:
make sim SIM=questa STAGE=7

# Icarus Verilog (-g2012):
make sim SIM=icarus STAGE=7
```

## 3. Running the 3-Pillar Static AST + C++20 Co-Sim + Python EGSE Regression Suite

```bash
make audit        # Audits all 34 SystemVerilog files (28 RTL + 6 TB)
make regression   # Runs 10,000-vector Python EGSE & C++20 co-simulation suite
```

## 5. Stage 8 (`v2.13`): Sequential 4-Protocol Loopback, Waveform Matcher, Channel Sweep & Kintex UltraScale True-Fmax

```powershell
# 1. Run Vivado xsim on Stage 8 (All 4 Protocols Sequentially + Channel Impairment Sweep):
.\scripts\run_eda_sim.bat xsim 8
# or via make:
make sim SIM=xsim STAGE=8

# 2. Run Python Golden vs. RTL VCD Waveform Similarity Matcher (rho >= 0.995, 0 byte mismatches):
python3 scripts/vcd_waveform_matcher.py

# 3. Run Best-to-Worst-Case Eb/N0 Channel Sweep (0..11 dB) + Generate PNG Plots:
python3 scripts/run_channel_ber_sweep.py

# 4. Run Vivado 2022.2 Kintex UltraScale Out-of-Context Synthesis, Utilization & True-Fmax Push:
.\scripts\run_vivado_sta.bat 0
```


## Stage 9: External Third-Party Library Interoperability & Zero-Placeholder Sign-Off (`v2.23.0`)

Run the complete **6-Subtest External Reference Interoperability Suite** (verified against University of Stuttgart IRS [`spacepackets-py`](https://github.com/us-irs/spacepackets-py) and PyCA [`cryptography`](https://cryptography.io/) NIST FIPS-197 AES-128 with **no self-loopback**):

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

### Measured Xilinx Vivado 2022.2 Kintex UltraScale (`xcku040-ffva1156-2-e`) Post-Upgrade Sign-Off (`v2.23.0`)

- **Top-Level Utilization (`ROLE_MODE = 0`):** `23,882 Total LUTs` (`23,578 Logic LUTs` + `304 Distributed LUTRAMs`), `25,401 Flip-Flops` (`9.87%` LUTs / `5.24%` FFs on `XCKU040`; `7.20%` LUTs / `3.83%` FFs on `XQRKU060`).
- **Measured True-$F_{\max}$ Across All 4 Clock Domains (`WNS > 0, TNS = 0.000 ns`):**
  - `clk_sys` (`100.0 MHz` nominal): **`104.67 MHz`** (`ROLE_MODE=0`) / **`106.39 MHz`** (`ROLE_MODE=2`)
  - `clk_adc_iq` (`120.0 MHz` nominal): **`166.53 MHz`** (`+38.8%` margin)
  - `clk_tx_sym` (`50.0 MHz` nominal): **`174.19 MHz`** (`+248.4%` margin)
  - `clk_tc_safe` (`16.0 MHz` nominal): **`104.18 MHz`** (`+551.1%` margin)
