# ==============================================================================
# File Name   : Makefile
# Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
# Version     : v2.10 (Native Windows PowerShell/CMD + WSL + Linux Support)
# Description : Turnkey Multi-Simulator Build, Lint & Verification Makefile
#               Supporting:
#                 1. Xilinx Vivado (SIM=xsim)   -- Windows xvlog.bat & Linux xvlog
#                 2. Verilator (SIM=verilator)  -- Open-Source Cycle-Accurate Sim
#                 3. Icarus Verilog (SIM=icarus)-- IEEE 1800-2012 Event Sim
#                 4. Siemens Questa (SIM=questa)-- vlog/vsim
#                 5. 3-Pillar C++20/Python/AST Gate (make audit / make regression)
# ==============================================================================

SIM   ?= xsim
STAGE ?= 8

RTL_SRCS := \
	rtl/ccsds_pkg.sv \
	rtl/ccsds_crc_universal.sv \
	rtl/ccsds_lfsr_scrambler.sv \
	rtl/ccsds_cdc_fifo_ecc.sv \
	rtl/ccsds_gf256_math.sv \
	rtl/ccsds_asm_correlator.sv \
	rtl/ccsds_bch6356_dec.sv \
	rtl/ccsds_farm1_tmr.sv \
	rtl/ccsds_vc_arbiter_mux.sv \
	rtl/ccsds_dl_rs255_223_enc.sv \
	rtl/ccsds_tc_uslp_deframer.sv \
	rtl/ccsds_tm_aos_uslp_framer.sv \
	rtl/ccsds_pkt_reassembler.sv \
	rtl/ccsds_prox1_plcw_ctrl.sv \
	rtl/ccsds_axi_lite_csr.sv \
	rtl/ccsds_conv_viterbi_codec.sv \
	rtl/ccsds_ul_short_ldpc_dec.sv \
	rtl/ccsds_dl_turbo_ldpc_enc.sv \
	rtl/ccsds_hcpd_ctrl.sv \
	rtl/ccsds_sdls_engine.sv \
	rtl/ccsds_pn_ranging.sv \
	rtl/ccsds_phy_modem.sv \
	rtl/ccsds_bch6356_enc.sv \
	rtl/ccsds_tc_cltu_framer.sv \
	rtl/ccsds_fop1_engine.sv \
	rtl/ccsds_tm_aos_deframer.sv \
	rtl/ccsds_dl_rs255_223_dec.sv \
	rtl/ccsds_channel_impairment_model.sv \
	rtl/ccsds_sat_ttc_top.sv

TB_STAGE2 := tb/tb_stage2_primitives.sv
TB_STAGE3 := tb/tb_stage3_vertical_slice.sv
TB_STAGE4 := tb/tb_stage4_multiprotocol.sv
TB_STAGE5 := tb/tb_stage5_fec_hcpd.sv
TB_STAGE6 := tb/tb_stage6_full_system.sv
TB_STAGE7 := tb/tb_stage7_hw_egse_loopback.sv
TB_STAGE8 := tb/tb_stage8_all_protocols_channel_loopback.sv
TB_STAGE9 := tb/tb_stage9_external_ref_check.sv

ifeq ($(STAGE),2)
  TB_TOP := tb_stage2_primitives
  TB_SRC := $(TB_STAGE2)
else ifeq ($(STAGE),3)
  TB_TOP := tb_stage3_vertical_slice
  TB_SRC := $(TB_STAGE3)
else ifeq ($(STAGE),4)
  TB_TOP := tb_stage4_multiprotocol
  TB_SRC := $(TB_STAGE4)
else ifeq ($(STAGE),5)
  TB_TOP := tb_stage5_fec_hcpd
  TB_SRC := $(TB_STAGE5)
else ifeq ($(STAGE),6)
  TB_TOP := tb_stage6_full_system
  TB_SRC := $(TB_STAGE6)
else ifeq ($(STAGE),7)
  TB_TOP := tb_stage7_hw_egse_loopback
  TB_SRC := $(TB_STAGE7)
else ifeq ($(STAGE),8)
  TB_TOP := tb_stage8_all_protocols_channel_loopback
  TB_SRC := $(TB_STAGE8)
else ifeq ($(STAGE),9)
  TB_TOP := tb_stage9_external_ref_check
  TB_SRC := $(TB_STAGE9)
endif

.PHONY: all audit regression lint sim waveform-diff channel-sweep sta clean

all: audit regression

audit:
	python3 scripts/sv_rtl_audit.py

regression:
	python3 scripts/run_regression_suite.py --stage 8

lint:
	verilator --lint-only -Wall --Wno-fatal -Wno-BLKSEQ -Wno-WIDTH -Wno-CASEINCOMPLETE -Wno-UNOPTFLAT -Wno-TIMESCALEMOD -Wno-UNUSED -Wno-UNDRIVEN -Wno-DECLFILENAME \
		-Irtl --top-module ccsds_sat_ttc_top $(RTL_SRCS)

ifeq ($(OS),Windows_NT)
sim:
	cmd.exe /c "scripts\run_eda_sim.bat $(SIM) $(STAGE)"
else
sim:
	bash scripts/run_eda_sim.sh $(SIM) $(STAGE)
endif

waveform-diff:
	python3 scripts/vcd_waveform_matcher.py

channel-sweep:
	python3 scripts/run_channel_ber_sweep.py

sta:
ifeq ($(OS),Windows_NT)
	cmd.exe /c "vivado.bat -mode batch -nojournal -nolog -source scripts/run_vivado_synth_sta.tcl -tclargs 0"
else
	vivado -mode batch -nojournal -nolog -source scripts/run_vivado_synth_sta.tcl -tclargs 0
endif

clean:
	rm -rf obj_dir xsim.dir work *.jou *.log *.pb *.wdb simv*
