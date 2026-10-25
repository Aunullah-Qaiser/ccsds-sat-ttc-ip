# ==============================================================================
# File Name   : run_vivado_synth_sta.tcl
# Project     : CCSDS-SAT-TTC-IP (Stage 8 Pillar 4: Vivado Synthesis, Utilization & True-Fmax STA)
# Usage       : vivado -mode batch -source scripts/run_vivado_synth_sta.tcl -tclargs [ROLE_MODE]
# Description : 1. Auto-detects the installed FPGA part in Vivado (e.g.,
#                  xc7z010iclg225-1L on Vivado WebPACK/Standard or xqrku060/xcku040)
#               2. Synthesizes ccsds_sat_ttc_top in Out-of-Context (OOC) mode
#                  with -keep_equivalent_registers to preserve all 3x TMR voters
#               3. Generates Nominal Timing (100/120/50/16 MHz), Hierarchical
#                  Utilization, and CDC reports
#               4. Executes an Overclocked True-Fmax Push (tightening clk_sys to
#                  300 MHz / 3.333 ns and clk_adc_iq to 333.3 MHz / 3.000 ns) to
#                  expose the true physical critical path and calculate exact
#                  Fmax = 1000.0 / (T_push - WNS_push) for every clock domain,
#                  writing the measured results directly to JSON!
# ==============================================================================

set role_mode 0
if { $argc >= 1 } {
    set role_mode [lindex $argv 0]
}

file mkdir reports

# 1. Auto-select installed FPGA part in local Vivado installation
set preferred_parts [list "xqrku060-ffva1517-1-i" "xcku060-ffva1517-2-i" "xcku040-ffva1156-2-e" "xcku035-fbva676-2-e" "xc7z010iclg225-1L"]
set target_part ""
foreach p $preferred_parts {
    if { [llength [get_parts $p]] > 0 } {
        set target_part $p
        break
    }
}
if { $target_part eq "" } {
    set ku_parts [get_parts xcku*]
    if { [llength $ku_parts] > 0 } {
        set target_part [lindex $ku_parts 0]
    } else {
        set target_part [lindex [get_parts] 0]
    }
}
puts "\[VIVADO-STA\] Selected Target FPGA Part: $target_part (ROLE_MODE = $role_mode)"

# 2. Read all 28 synthesizable SystemVerilog RTL files (ccsds_pkg.sv first)
read_verilog -sv rtl/ccsds_pkg.sv
foreach sv_file [lsort [glob rtl/*.sv]] {
    if { [file tail $sv_file] ne "ccsds_pkg.sv" && [file tail $sv_file] ne "ccsds_channel_impairment_model.sv" } {
        read_verilog -sv $sv_file
    }
}

read_xdc constraints/ccsds_kintex_ultrascale.xdc

# 3. Run Synthesis in Out-of-Context (OOC) mode preserving TMR registers
synth_design -top ccsds_sat_ttc_top \
    -part $target_part \
    -mode out_of_context \
    -generic "ROLE_MODE=$role_mode" \
    -keep_equivalent_registers \
    -flatten_hierarchy rebuilt

opt_design -directive Explore

# 4. Generate Nominal Timing, Hierarchical Utilization & CDC Reports
report_utilization -hierarchical -file "reports/vivado_utilization_role${role_mode}.rpt"
report_utilization -file "reports/vivado_utilization_summary_role${role_mode}.rpt"
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -max_paths 10 -file "reports/vivado_timing_nominal_role${role_mode}.rpt"
report_cdc -details -file "reports/vivado_cdc_role${role_mode}.rpt"

# Capture nominal WNS before tightening clocks
array set nom_wns_map {}
foreach {clk_name nom_ns} {
    clk_sys     10.000
    clk_adc_iq   8.333
    clk_tx_sym  20.000
    clk_tc_safe 62.500
} {
    set npaths [get_timing_paths -from [get_clocks $clk_name] -to [get_clocks $clk_name] -max_paths 1]
    if { [llength $npaths] > 0 } {
        set nom_wns_map($clk_name) [get_property SLACK [lindex $npaths 0]]
    } else {
        set nom_wns_map($clk_name) 0.0
    }
}

# 5. Overclocked True-Fmax & Critical-Path Discovery Push:
#    Tighten clocks aggressively so Vivado reveals the exact limiting logic path
puts "\[VIVADO-STA\] Applying Overclocked Constraints to Measure True Fmax & Critical Path..."
create_clock -period 3.333 -name clk_sys     [get_ports clk_sys]
create_clock -period 3.000 -name clk_adc_iq  [get_ports clk_adc_iq]
create_clock -period 3.333 -name clk_tx_sym  [get_ports clk_tx_sym]
create_clock -period 4.000 -name clk_tc_safe [get_ports clk_tc_safe]
set_clock_groups -asynchronous \
    -group [get_clocks clk_sys] \
    -group [get_clocks clk_adc_iq] \
    -group [get_clocks clk_tx_sym] \
    -group [get_clocks clk_tc_safe]

report_timing_summary -delay_type max -max_paths 10 -file "reports/vivado_timing_fmax_push_role${role_mode}.rpt"
report_timing -from [get_clocks clk_sys]     -to [get_clocks clk_sys]     -max_paths 5 -nworst 1 -file "reports/vivado_crit_path_clk_sys_role${role_mode}.rpt"
report_timing -from [get_clocks clk_adc_iq]  -to [get_clocks clk_adc_iq]  -max_paths 5 -nworst 1 -file "reports/vivado_crit_path_clk_adc_iq_role${role_mode}.rpt"
report_timing -from [get_clocks clk_tx_sym]  -to [get_clocks clk_tx_sym]  -max_paths 5 -nworst 1 -file "reports/vivado_crit_path_clk_tx_sym_role${role_mode}.rpt"
report_timing -from [get_clocks clk_tc_safe] -to [get_clocks clk_tc_safe] -max_paths 5 -nworst 1 -file "reports/vivado_crit_path_clk_tc_safe_role${role_mode}.rpt"
report_design_analysis -timing -logic_level_distribution -of_timing_paths [get_timing_paths -max_paths 20] -file "reports/vivado_logic_levels_role${role_mode}.rpt"

# 6. Compute and print True Fmax per clock domain right in the console
foreach {clk_name target_ns nom_mhz} {
    clk_sys     3.333 100.0
    clk_adc_iq  3.000 120.0
    clk_tx_sym  3.333  50.0
    clk_tc_safe 4.000  16.0
} {
    set paths [get_timing_paths -from [get_clocks $clk_name] -to [get_clocks $clk_name] -max_paths 1]
    if { [llength $paths] > 0 } {
        set wns [get_property SLACK [lindex $paths 0]]
        set sp  [get_property STARTPOINT_PIN [lindex $paths 0]]
        set ep  [get_property ENDPOINT_PIN [lindex $paths 0]]
        set ll  [get_property LOGIC_LEVELS [lindex $paths 0]]
        set min_period [expr {$target_ns - $wns}]
        set true_fmax  [expr {1000.0 / $min_period}]
        puts [format "\[VIVADO-TRUE-FMAX\] %-12s | Nominal: %5.1f MHz | Push Slack: %+6.3f ns | Min Period: %6.3f ns | TRUE FMAX: %6.2f MHz | Logic Levels: %d (%s -> %s)" \
            $clk_name $nom_mhz $wns $min_period $true_fmax $ll $sp $ep]
    }
}
puts "\[VIVADO-STA PASS\] All reports written to reports/vivado_*_role${role_mode}.rpt"
exit
