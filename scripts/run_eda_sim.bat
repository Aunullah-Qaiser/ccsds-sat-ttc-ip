@echo off
REM ============================================================================
REM File Name   : run_eda_sim.bat
REM Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
REM Version     : v2.19 (Supports STAGE 2..9 + External Reference Check)
REM Description : Native Windows Batch Runner for Xilinx Vivado (xsim),
REM               Verilator, QuestaSim, and Icarus Verilog (No WSL required).
REM ============================================================================
setlocal

set SIM=%1
if "%SIM%"=="" set SIM=xsim

set STAGE=%2
if "%STAGE%"=="" set STAGE=9

set RTL_SRCS=rtl/ccsds_pkg.sv rtl/ccsds_crc_universal.sv rtl/ccsds_lfsr_scrambler.sv rtl/ccsds_cdc_fifo_ecc.sv rtl/ccsds_gf256_math.sv rtl/ccsds_asm_correlator.sv rtl/ccsds_bch6356_dec.sv rtl/ccsds_farm1_tmr.sv rtl/ccsds_vc_arbiter_mux.sv rtl/ccsds_dl_rs255_223_enc.sv rtl/ccsds_tc_uslp_deframer.sv rtl/ccsds_tm_aos_uslp_framer.sv rtl/ccsds_pkt_reassembler.sv rtl/ccsds_prox1_plcw_ctrl.sv rtl/ccsds_axi_lite_csr.sv rtl/ccsds_conv_viterbi_codec.sv rtl/ccsds_ul_short_ldpc_dec.sv rtl/ccsds_dl_turbo_ldpc_enc.sv rtl/ccsds_hcpd_ctrl.sv rtl/ccsds_sdls_engine.sv rtl/ccsds_pn_ranging.sv rtl/ccsds_phy_modem.sv rtl/ccsds_bch6356_enc.sv rtl/ccsds_tc_cltu_framer.sv rtl/ccsds_fop1_engine.sv rtl/ccsds_tm_aos_deframer.sv rtl/ccsds_dl_rs255_223_dec.sv rtl/ccsds_channel_impairment_model.sv rtl/ccsds_sat_ttc_top.sv

if "%STAGE%"=="2" (
  set TB_TOP=tb_stage2_primitives
  set TB_SRC=tb/tb_stage2_primitives.sv
) else if "%STAGE%"=="3" (
  set TB_TOP=tb_stage3_vertical_slice
  set TB_SRC=tb/tb_stage3_vertical_slice.sv
) else if "%STAGE%"=="4" (
  set TB_TOP=tb_stage4_multiprotocol
  set TB_SRC=tb/tb_stage4_multiprotocol.sv
) else if "%STAGE%"=="5" (
  set TB_TOP=tb_stage5_fec_hcpd
  set TB_SRC=tb/tb_stage5_fec_hcpd.sv
) else if "%STAGE%"=="6" (
  set TB_TOP=tb_stage6_full_system
  set TB_SRC=tb/tb_stage6_full_system.sv
) else if "%STAGE%"=="7" (
  set TB_TOP=tb_stage7_hw_egse_loopback
  set TB_SRC=tb/tb_stage7_hw_egse_loopback.sv
) else if "%STAGE%"=="8" (
  set TB_TOP=tb_stage8_all_protocols_channel_loopback
  set TB_SRC=tb/tb_stage8_all_protocols_channel_loopback.sv
) else if "%STAGE%"=="9" (
  set TB_TOP=tb_stage9_external_ref_check
  set TB_SRC=tb/tb_stage9_external_ref_check.sv
) else (
  echo Unknown STAGE=%STAGE% ^(expected 2..9^)
  exit /b 1
)

echo [CCSDS-SIM-WIN] Selected Simulator: %SIM% ^| Target Testbench: %TB_TOP%

if "%STAGE%"=="9" (
  echo [CCSDS-SIM-WIN] Generating external reference vectors via spacepackets-py...
  python scripts/run_external_ref_check.py --generate
  if errorlevel 1 exit /b 1
)

if "%SIM%"=="xsim" (
  if not exist sim_waves mkdir sim_waves
  call xvlog.bat -sv -i rtl %RTL_SRCS% %TB_SRC%
  if errorlevel 1 exit /b 1
  call xelab.bat -timescale 1ns/1ps -debug typical %TB_TOP% -s %TB_TOP%_sim
  if errorlevel 1 exit /b 1
  call xsim.bat %TB_TOP%_sim -R
  if errorlevel 1 exit /b 1
) else if "%SIM%"=="questa" (
  if not exist sim_waves mkdir sim_waves
  vlib work
  vlog -sv +incdir+rtl %RTL_SRCS% %TB_SRC%
  vsim -c -do "run -all; quit -f" work.%TB_TOP%
) else if "%SIM%"=="icarus" (
  if not exist sim_waves mkdir sim_waves
  iverilog -g2012 -I rtl -s %TB_TOP% -o obj_%TB_TOP%.vvp %RTL_SRCS% %TB_SRC%
  vvp obj_%TB_TOP%.vvp
) else (
  python scripts/sv_rtl_audit.py
)

if "%STAGE%"=="9" (
  echo [CCSDS-SIM-WIN] Verifying RTL output hex dumps against external spacepackets-py parser...
  python scripts/run_external_ref_check.py --verify
  if errorlevel 1 exit /b 1
)
