#!/usr/bin/env bash
# ==============================================================================
# File Name   : run_eda_sim.sh
# Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
# Version     : v2.10 (Auto-Detects Windows Vivado under WSL/Git-Bash vs Linux)
# Description : Unified RTL Simulator Runner for Verilator, Icarus Verilog,
#               Xilinx Vivado (xsim), and Siemens QuestaSim, with automatic
#               detection of Windows Vivado (.bat) when invoked inside WSL.
# ==============================================================================
set -euo pipefail

SIM="${1:-auto}"
STAGE="${2:-7}"

RTL_SRCS=(
  rtl/ccsds_pkg.sv
  rtl/ccsds_crc_universal.sv
  rtl/ccsds_lfsr_scrambler.sv
  rtl/ccsds_cdc_fifo_ecc.sv
  rtl/ccsds_gf256_math.sv
  rtl/ccsds_asm_correlator.sv
  rtl/ccsds_bch6356_dec.sv
  rtl/ccsds_farm1_tmr.sv
  rtl/ccsds_vc_arbiter_mux.sv
  rtl/ccsds_dl_rs255_223_enc.sv
  rtl/ccsds_tc_uslp_deframer.sv
  rtl/ccsds_tm_aos_uslp_framer.sv
  rtl/ccsds_pkt_reassembler.sv
  rtl/ccsds_prox1_plcw_ctrl.sv
  rtl/ccsds_axi_lite_csr.sv
  rtl/ccsds_conv_viterbi_codec.sv
  rtl/ccsds_ul_short_ldpc_dec.sv
  rtl/ccsds_dl_turbo_ldpc_enc.sv
  rtl/ccsds_hcpd_ctrl.sv
  rtl/ccsds_sdls_engine.sv
  rtl/ccsds_pn_ranging.sv
  rtl/ccsds_phy_modem.sv
  rtl/ccsds_bch6356_enc.sv
  rtl/ccsds_tc_cltu_framer.sv
  rtl/ccsds_fop1_engine.sv
  rtl/ccsds_tm_aos_deframer.sv
  rtl/ccsds_dl_rs255_223_dec.sv
  rtl/ccsds_sat_ttc_top.sv
)

case "${STAGE}" in
  2) TB_TOP="tb_stage2_primitives";       TB_SRC="tb/tb_stage2_primitives.sv" ;;
  3) TB_TOP="tb_stage3_vertical_slice";   TB_SRC="tb/tb_stage3_vertical_slice.sv" ;;
  4) TB_TOP="tb_stage4_multiprotocol";    TB_SRC="tb/tb_stage4_multiprotocol.sv" ;;
  5) TB_TOP="tb_stage5_fec_hcpd";         TB_SRC="tb/tb_stage5_fec_hcpd.sv" ;;
  6) TB_TOP="tb_stage6_full_system";      TB_SRC="tb/tb_stage6_full_system.sv" ;;
  7) TB_TOP="tb_stage7_hw_egse_loopback"; TB_SRC="tb/tb_stage7_hw_egse_loopback.sv" ;;
  *) echo "Unknown STAGE=${STAGE} (expected 2..7)"; exit 1 ;;
esac

if [[ "${SIM}" == "auto" ]]; then
  if command -v verilator >/dev/null 2>&1; then
    SIM="verilator"
  elif command -v xvlog >/dev/null 2>&1 || command -v xvlog.bat >/dev/null 2>&1; then
    SIM="xsim"
  elif command -v vlog >/dev/null 2>&1; then
    SIM="questa"
  elif command -v iverilog >/dev/null 2>&1; then
    SIM="icarus"
  else
    SIM="cosim"
  fi
fi

echo "[CCSDS-SIM] Selected Simulator: ${SIM} | Target Testbench: ${TB_TOP}"

case "${SIM}" in
  verilator)
    verilator --binary --timing --trace -Irtl -Wno-BLKSEQ -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC \
      --top-module "${TB_TOP}" "${RTL_SRCS[@]}" "${TB_SRC}"
    "./obj_dir/V${TB_TOP}"
    ;;
  xsim)
    # Detect if running inside WSL / Git-Bash with a Windows installation of Vivado (win64.o)
    XVLOG_PATH="$(command -v xvlog || true)"
    if [[ -n "${WSL_DISTRO_NAME:-}" ]] || [[ "${XVLOG_PATH}" == /mnt/* ]] || command -v xvlog.bat >/dev/null 2>&1; then
      echo "[CCSDS-SIM] Detected Windows Vivado installation from WSL/Windows shell; invoking xvlog.bat / xelab.bat / xsim.bat via cmd.exe..."
      cmd.exe /c "xvlog.bat -sv -i rtl ${RTL_SRCS[*]} ${TB_SRC}"
      cmd.exe /c "xelab.bat -debug typical ${TB_TOP} -s ${TB_TOP}_sim"
      cmd.exe /c "xsim.bat ${TB_TOP}_sim -R"
    else
      xvlog -sv -i rtl "${RTL_SRCS[@]}" "${TB_SRC}"
      xelab -debug typical "${TB_TOP}" -s "${TB_TOP}_sim"
      xsim "${TB_TOP}_sim" -R
    fi
    ;;
  questa)
    vlib work
    vlog -sv +incdir+rtl "${RTL_SRCS[@]}" "${TB_SRC}"
    vsim -c -do "run -all; quit -f" "work.${TB_TOP}"
    ;;
  icarus)
    iverilog -g2012 -I rtl -s "${TB_TOP}" -o "obj_${TB_TOP}.vvp" "${RTL_SRCS[@]}" "${TB_SRC}"
    vvp "obj_${TB_TOP}.vvp"
    ;;
  cosim)
    python3 scripts/sv_rtl_audit.py
    python3 scripts/run_regression_suite.py --stage "${STAGE}"
    ;;
esac
