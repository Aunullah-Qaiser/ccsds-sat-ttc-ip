# ==============================================================================
# File Name   : ccsds_kintex_ultrascale.xdc
# Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
# Target      : AMD/Xilinx Kintex UltraScale (XQRKU060 / XCKU040-FFVA1156) &
#               Zynq-7000 (XC7Z020-CLG484 / XC7Z045-FFG900) + AD9361 FMC
# Description : Complete Multi-Clock Timing, CDC, TMR Preservation, I/O Delay &
#               Reference Physical Board Pinout Constraints (v2.34.0)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Primary Spacecraft & Transceiver Clock Definitions
# ------------------------------------------------------------------------------
create_clock -period 10.000 -name clk_sys     -waveform {0.000 5.000}  [get_ports clk_sys]
create_clock -period 8.333  -name clk_adc_iq  -waveform {0.000 4.166}  [get_ports clk_adc_iq]
create_clock -period 20.000 -name clk_tx_sym  -waveform {0.000 10.000} [get_ports clk_tx_sym]
create_clock -period 62.500 -name clk_tc_safe -waveform {0.000 31.250} [get_ports clk_tc_safe]

# Clock Uncertainty (Jitter & Phase Margin for Space-Grade Oscillators)
set_clock_uncertainty -setup 0.250 [get_clocks {clk_sys clk_adc_iq clk_tx_sym clk_tc_safe}]
set_clock_uncertainty -hold  0.100 [get_clocks {clk_sys clk_adc_iq clk_tx_sym clk_tc_safe}]

# ------------------------------------------------------------------------------
# 2. Asynchronous Clock Domain Groupings & CDC Constraints
# ------------------------------------------------------------------------------
set_clock_groups -asynchronous \
  -group [get_clocks clk_sys] \
  -group [get_clocks clk_adc_iq] \
  -group [get_clocks clk_tx_sym] \
  -group [get_clocks clk_tc_safe]

# Constrain max datapath delay across Gray-code FIFO pointers in ccsds_cdc_fifo_ecc
set_max_delay -datapath_only 8.000 \
  -from [get_cells -hierarchical -filter {NAME =~ *cdc_fifo*wr_ptr_gray_q_reg*}] \
  -to   [get_cells -hierarchical -filter {NAME =~ *cdc_fifo*wr_ptr_gray_meta_q_reg*}]

set_max_delay -datapath_only 8.000 \
  -from [get_cells -hierarchical -filter {NAME =~ *cdc_fifo*rd_ptr_gray_q_reg*}] \
  -to   [get_cells -hierarchical -filter {NAME =~ *cdc_fifo*rd_ptr_gray_meta_q_reg*}]

# ------------------------------------------------------------------------------
# 3. Asynchronous Reset, 1 PPS Reference & Static Strap False Paths
# ------------------------------------------------------------------------------
# Asynchronous master reset feeds per-domain 2-FF ASYNC_REG reset bridges
set_false_path -from [get_ports rst_n]

# External 1 PPS reference feeds 2-FF ASYNC_REG synchronizer in clk_sys
set_false_path -from [get_ports pps_1hz_in]

# Static / quasi-static hardware strap configuration pins
set_false_path -from [get_ports {link_proto_override_en[*] ul_fec_override_en[*] sdls_en_cfg bc_require_sdls_cfg pn_ranging_en_cfg pn_t4b_mode_cfg turnaround_xband_cfg mod_mode_cfg[*] line_code_cfg[*]}]

# Asynchronous emergency HCPD and interrupt discrete outputs
set_false_path -to [get_ports {hcpd_obc_reset_pulse hcpd_safe_mode_force hcpd_rf_chain_select[*] pn_All_Locked_out fault_irq_out edac_scrub_req_out}]

# ------------------------------------------------------------------------------
# 4. Source-Synchronous I/O Timing Constraints (AD9361 16-Bit I/Q Bus & AXI)
# ------------------------------------------------------------------------------
# AD9361 Baseband / IF Receiver Input Bus (synchronous to clk_adc_iq = 120 MHz)
set_input_delay  -clock [get_clocks clk_adc_iq] -max 2.000 [get_ports {rx_i_adc_in[*] rx_q_adc_in[*] rx_iq_valid_in}]
set_input_delay  -clock [get_clocks clk_adc_iq] -min 0.500 [get_ports {rx_i_adc_in[*] rx_q_adc_in[*] rx_iq_valid_in}]

# AD9361 Baseband / IF Transmitter Output Bus (synchronous to clk_adc_iq = 120 MHz)
set_output_delay -clock [get_clocks clk_adc_iq] -max 2.000 [get_ports {tx_i_dac_out[*] tx_q_dac_out[*] tx_iq_valid_out}]
set_output_delay -clock [get_clocks clk_adc_iq] -min 0.500 [get_ports {tx_i_dac_out[*] tx_q_dac_out[*] tx_iq_valid_out}]

# ------------------------------------------------------------------------------
# 5. Triple-Modular Redundancy (TMR) Preservation Directives (Fix #9)
#    Prevents Vivado synthesis/opt_design from merging redundant voter registers
# ------------------------------------------------------------------------------
set_property DONT_TOUCH true [get_cells -hierarchical -filter {NAME =~ *tmr_*_a_q_reg*}]
set_property DONT_TOUCH true [get_cells -hierarchical -filter {NAME =~ *tmr_*_b_q_reg*}]
set_property DONT_TOUCH true [get_cells -hierarchical -filter {NAME =~ *tmr_*_c_q_reg*}]
set_property DONT_TOUCH true [get_cells -hierarchical -filter {NAME =~ *u_farm1/state_a_q_reg*}]
set_property DONT_TOUCH true [get_cells -hierarchical -filter {NAME =~ *u_farm1/state_b_q_reg*}]
set_property DONT_TOUCH true [get_cells -hierarchical -filter {NAME =~ *u_farm1/state_c_q_reg*}]
set_property DONT_TOUCH true [get_cells -hierarchical -filter {NAME =~ *u_farm1/vr_a_q_reg*}]
set_property DONT_TOUCH true [get_cells -hierarchical -filter {NAME =~ *u_farm1/vr_b_q_reg*}]
set_property DONT_TOUCH true [get_cells -hierarchical -filter {NAME =~ *u_farm1/vr_c_q_reg*}]

# ------------------------------------------------------------------------------
# 6. Physical Board Package Pin & I/O Standard Assignments
#    Reference Target: Kintex UltraScale KCU105 (xcku040-ffva1156-2-e) +
#                      AD-FMCOMMS2/3-EBZ (AD9361) on FMC HPC Connector
#    Note: Wrapped in a quiet check so Out-of-Context (OOC) STA synthesis runs
#          cleanly on any target part while full board builds bind pins directly.
# ------------------------------------------------------------------------------
if { [string match "*xcku040*" [get_property PART [current_project]]] } {
  catch {
    # Primary Clocks, Master Reset & 1 PPS Input (Bank 44 / Bank 45 1.8V LVCMOS18)
    set_property -dict {PACKAGE_PIN G10  IOSTANDARD LVCMOS18} [get_ports clk_sys]
    set_property -dict {PACKAGE_PIN H11  IOSTANDARD LVCMOS18} [get_ports clk_adc_iq]
    set_property -dict {PACKAGE_PIN G11  IOSTANDARD LVCMOS18} [get_ports clk_tx_sym]
    set_property -dict {PACKAGE_PIN F10  IOSTANDARD LVCMOS18} [get_ports clk_tc_safe]
    set_property -dict {PACKAGE_PIN AN8  IOSTANDARD LVCMOS18} [get_ports rst_n]
    set_property -dict {PACKAGE_PIN AP8  IOSTANDARD LVCMOS18} [get_ports pps_1hz_in]

    # Emergency HCPD & Discrete Status Outputs (Bank 44 1.8V LVCMOS18)
    set_property -dict {PACKAGE_PIN AL8  IOSTANDARD LVCMOS18 SLEW FAST} [get_ports hcpd_obc_reset_pulse]
    set_property -dict {PACKAGE_PIN AM8  IOSTANDARD LVCMOS18 SLEW FAST} [get_ports hcpd_safe_mode_force]
    set_property -dict {PACKAGE_PIN AK8  IOSTANDARD LVCMOS18} [get_ports {hcpd_rf_chain_select[0]}]
    set_property -dict {PACKAGE_PIN AJ8  IOSTANDARD LVCMOS18} [get_ports {hcpd_rf_chain_select[1]}]
    set_property -dict {PACKAGE_PIN AH8  IOSTANDARD LVCMOS18} [get_ports pn_All_Locked_out]
    set_property -dict {PACKAGE_PIN AG8  IOSTANDARD LVCMOS18} [get_ports fault_irq_out]
    set_property -dict {PACKAGE_PIN AF8  IOSTANDARD LVCMOS18} [get_ports edac_scrub_req_out]

    # AD9361 16-Bit Rx ADC I/Q Bus & Strobe (FMC HPC Bank 66/67 1.8V LVCMOS18)
    set_property IOSTANDARD LVCMOS18 [get_ports {rx_i_adc_in[*] rx_q_adc_in[*] rx_iq_valid_in}]
    set_property IOSTANDARD LVCMOS18 [get_ports {tx_i_dac_out[*] tx_q_dac_out[*] tx_iq_valid_out}]
  }
}
