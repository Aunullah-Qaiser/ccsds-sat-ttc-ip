# ==============================================================================
# File Name   : ccsds_kintex_ultrascale.xdc
# Project     : CCSDS-SAT-TTC-IP (Stage 8 Pillar 4: Kintex UltraScale Timing & CDC)
# Target FPGA : AMD Kintex UltraScale (XQRKU060-FFVA1517-1-I / XCKU040-FFVA1156-2-E)
# Description : Primary Clock Definitions, Asynchronous Clock Domain Crossing (CDC)
#               Groups, Input/Output Delay Constraints, and TMR Preservation Rules.
# ==============================================================================

# 1. Nominal Mission Clock Constraints
#    - clk_sys     : 100.0 MHz (10.000 ns) Spacecraft OBC AXI4-Stream / FEC domain
#    - clk_adc_iq  : 120.0 MHz ( 8.333 ns) Wideband RF ADC/DAC & PN Ranging domain
#    - clk_tx_sym  :  50.0 MHz (20.000 ns) Downlink Symbol & Inner Conv domain
#    - clk_tc_safe :  16.0 MHz (62.500 ns) Independent Radiation-Safe Uplink TC/HCPD domain
create_clock -period 10.000 -name clk_sys     [get_ports clk_sys]
create_clock -period  8.333 -name clk_adc_iq  [get_ports clk_adc_iq]
create_clock -period 20.000 -name clk_tx_sym  [get_ports clk_tx_sym]
create_clock -period 62.500 -name clk_tc_safe [get_ports clk_tc_safe]

# 2. Clock Uncertainty (Jitter + Radiation Supply Margin: 150 ps setup, 50 ps hold)
set_clock_uncertainty -setup 0.150 [all_clocks]
set_clock_uncertainty -hold  0.050 [all_clocks]

# 3. Asynchronous Clock Groups (All cross-domain paths traverse verified 2-FF Gray
#    FIFOs u_rx_commit_cdc_fifo / u_tx_hwm_cdc_fifo or 2-FF synchronizers)
set_clock_groups -asynchronous \
    -group [get_clocks clk_sys] \
    -group [get_clocks clk_adc_iq] \
    -group [get_clocks clk_tx_sym] \
    -group [get_clocks clk_tc_safe]

# 4. Preserve Triple-Modular Redundancy (TMR) Replicas A, B, C against LUT/FF merging
set_property DONT_TOUCH true [get_cells -hierarchical -filter {NAME =~ *tmr* || NAME =~ *_a_q* || NAME =~ *_b_q* || NAME =~ *_c_q*}]
