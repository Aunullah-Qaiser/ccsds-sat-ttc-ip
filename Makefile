# ==============================================================================
# File Name   : Makefile
# Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
# Version     : v2.31.0 (Supports STAGE 2..12 across Vivado xsim, Verilator, Questa, Icarus)
# Description : Turnkey Multi-Simulator Build, Lint & Verification Makefile
#               Supporting:
#                 1. Xilinx Vivado (SIM=xsim)   -- Windows xvlog.bat & Linux xvlog
#                 2. Verilator (SIM=verilator)  -- Open-Source Cycle-Accurate RTL Sim
#                 3. Icarus Verilog (SIM=icarus)-- IEEE 1800-2012 Event Sim
#                 4. Siemens Questa (SIM=questa)-- vlog/vsim
#                 5. Static AST Audit & Reference Cross-Check (make audit / make regression)
# ==============================================================================

SIM   ?= xsim
STAGE ?= 12

RTL_SYNTH_SRCS := \
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
	rtl/ccsds_sat_ttc_top.sv

RTL_SRCS := $(RTL_SYNTH_SRCS) rtl/ccsds_channel_impairment_model.sv rtl/ccsds_space_flight_channel_model.sv

TB_STAGE2  := tb/tb_stage2_primitives.sv
TB_STAGE3  := tb/tb_stage3_vertical_slice.sv
TB_STAGE4  := tb/tb_stage4_multiprotocol.sv
TB_STAGE5  := tb/tb_stage5_fec_hcpd.sv
TB_STAGE6  := tb/tb_stage6_full_system.sv
TB_STAGE7  := tb/tb_stage7_hw_egse_loopback.sv
TB_STAGE8  := tb/tb_stage8_all_protocols_channel_loopback.sv
TB_STAGE9  := tb/tb_stage9_external_ref_check.sv
TB_STAGE10 := tb/tb_stage10_full_matrix_link_stress.sv
TB_STAGE11 := tb/tb_stage11_top_to_top_rf_link.sv
TB_STAGE12 := tb/tb_stage12_space_channel_loopback.sv

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
else ifeq ($(STAGE),10)
  TB_TOP := tb_stage10_full_matrix_link_stress
  TB_SRC := $(TB_STAGE10)
else ifeq ($(STAGE),11)
  TB_TOP := tb_stage11_top_to_top_rf_link
  TB_SRC := $(TB_STAGE11)
else ifeq ($(STAGE),12)
  TB_TOP := tb_stage12_space_channel_loopback
  TB_SRC := $(TB_STAGE12)
endif

.PHONY: all audit regression lint sim waveform-diff channel-sweep space-perf hal-test sta clean

all: audit regression hal-test space-perf

audit:
	python3 scripts/sv_rtl_audit.py

regression:
	python3 scripts/run_regression_suite.py --stage 8

hal-test:
	gcc -std=c11 -Wall -Wextra -Werror -Isw sw/ccsds_ttc_hal.c sw/test_ccsds_ttc_hal.c -o test_ccsds_ttc_hal
	./test_ccsds_ttc_hal
	rm -f test_ccsds_ttc_hal

lint:
	verilator --lint-only -Wall \
		-Wno-TIMESCALEMOD -Wno-UNUSED -Wno-BLKSEQ -Wno-UNOPTFLAT \
		-Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-CASEINCOMPLETE -Wno-PINCONNECTEMPTY \
		-GROLE_MODE=2 -Irtl --top-module ccsds_sat_ttc_top $(RTL_SYNTH_SRCS)

ifeq ($(OS),Windows_NT)
sim:
	cmd.exe /c "scripts\run_eda_sim.bat $(SIM) $(STAGE)"
else
sim:
	bash scripts/run_eda_sim.sh $(SIM) $(STAGE)
endif

waveform-diff:
	python3 scripts/vcd_waveform_matcher.py --rtl-vcd sim_waves/stage8_xsim_rtl.vcd

channel-sweep:
	python3 scripts/run_channel_ber_sweep.py

space-perf:
	python3 scripts/run_space_channel_perf_analysis.py

sta:
ifeq ($(OS),Windows_NT)
	cmd.exe /c "vivado.bat -mode batch -nojournal -nolog -source scripts/run_vivado_synth_sta.tcl -tclargs 0"
else
	vivado -mode batch -nojournal -nolog -source scripts/run_vivado_synth_sta.tcl -tclargs 0
endif

clean:
	rm -rf obj_dir xsim.dir work *.jou *.log *.pb *.wdb simv* test_ccsds_ttc_hal
