# ==============================================================================
# File Name   : create_z7035_stage1_bd_loopback.tcl
# Project     : CCSDS-SAT-TTC-IP (v2.40.3)
# Target Hardware:
#   - SOM     : Analog Devices ADRV9361-Z7035 (Xilinx Zynq-7000 xc7z035ifbg676-2L)
#   - Carrier : Analog Devices ADRV1CRR-BOB Breakout Carrier
# Tool Version: AMD / Xilinx Vivado 2026.1.1 (version-agnostic IP lookup)
#
# Description :
#   Stage 1 of the 3-Stage Hardware Bring-Up Plan:
#     - Stage 1 (This Script) : Pure PL Block-Design Baseband I/Q Loopback driven
#                               by the Zynq-7035 PS7 ARM Cortex-A9 processor.
#     - Stage 2 (Next Step)   : Wire tx_i/q_dac_out & rx_i/q_adc_in to ADI axi_ad9361.
#     - Stage 3 (Final Step)  : Two-board RF link (Board A ROLE_MODE=1 <-> Board B ROLE_MODE=0).
#
#   Supports TWO selectable Stage 1 Block-Design Loopback Topologies via
#   the `LOOPBACK_TOPOLOGY` variable below:
#     1. "SINGLE_ROLE2" (Default):
#        Instantiates one Universal CCSDS transceiver (`ROLE_MODE = 2`) with its
#        16-bit baseband I/Q outputs (`tx_i/q_dac_out`) looped back directly into
#        its baseband I/Q inputs (`rx_i/q_adc_in`) on the Block Design canvas.
#     2. "DUAL_EGSE_TO_FLIGHT":
#        Instantiates BOTH a Ground EGSE core (`ROLE_MODE = 1` at 0x43C0_0000)
#        and a Spacecraft Flight core (`ROLE_MODE = 0` at 0x43C2_0000) on the
#        same Block Design canvas and cross-wires their baseband I/Q buses
#        (EGSE Tx -> Flight Rx Uplink, Flight Tx -> EGSE Rx Downlink).
#
# Usage (from Vivado 2026.1.1 Tcl Console or Command Line at repo root):
#   vivado -mode batch -source scripts/create_z7035_stage1_bd_loopback.tcl
#   -- or inside Vivado GUI Tcl Console:
#   cd <path-to-ccsds_sat_ttc_ip>
#   source scripts/create_z7035_stage1_bd_loopback.tcl
# ==============================================================================

# ------------------------------------------------------------------------------
# 0. User-Configurable Build Switches
# ------------------------------------------------------------------------------
set PROJ_NAME          "ccsds_z7035_stage1_loopback"
set PROJ_DIR           "./vivado_z7035_stage1"
set PART_NAME          "xc7z035ifbg676-2L"
set BD_NAME            "system_stage1_loopback"

# Choose "SINGLE_ROLE2" (1 core self-loopback) or "DUAL_EGSE_TO_FLIGHT" (2 cores cross-wired)
if {![info exists LOOPBACK_TOPOLOGY]} {
    set LOOPBACK_TOPOLOGY "DUAL_EGSE_TO_FLIGHT"
}

# Set to 1 to automatically run synthesis, implementation, bitstream & XSA export
if {![info exists RUN_BITSTREAM]} {
    set RUN_BITSTREAM 0
}

puts "======================================================================"
puts " Creating Vivado 2026.1.1 Stage 1 Block-Design Loopback Project"
puts " Target Part       : $PART_NAME (ADRV9361-Z7035 + ADRV1CRR-BOB)"
puts " Loopback Topology : $LOOPBACK_TOPOLOGY"
puts "======================================================================"

# ------------------------------------------------------------------------------
# 1. Create Project & Add All 28 Synthesizable SystemVerilog Modules + .v Wrapper
# ------------------------------------------------------------------------------
create_project -force $PROJ_NAME $PROJ_DIR -part $PART_NAME
set_property target_language Verilog [current_project]

set RTL_SV_FILES [list \
    [file normalize "rtl/ccsds_pkg.sv"] \
    [file normalize "rtl/ccsds_crc_universal.sv"] \
    [file normalize "rtl/ccsds_lfsr_scrambler.sv"] \
    [file normalize "rtl/ccsds_cdc_fifo_ecc.sv"] \
    [file normalize "rtl/ccsds_gf256_math.sv"] \
    [file normalize "rtl/ccsds_asm_correlator.sv"] \
    [file normalize "rtl/ccsds_bch6356_dec.sv"] \
    [file normalize "rtl/ccsds_bch6356_enc.sv"] \
    [file normalize "rtl/ccsds_ul_short_ldpc_dec.sv"] \
    [file normalize "rtl/ccsds_tc_uslp_deframer.sv"] \
    [file normalize "rtl/ccsds_farm1_tmr.sv"] \
    [file normalize "rtl/ccsds_hcpd_ctrl.sv"] \
    [file normalize "rtl/ccsds_sdls_engine.sv"] \
    [file normalize "rtl/ccsds_pkt_reassembler.sv"] \
    [file normalize "rtl/ccsds_vc_arbiter_mux.sv"] \
    [file normalize "rtl/ccsds_tm_aos_uslp_framer.sv"] \
    [file normalize "rtl/ccsds_dl_rs255_223_enc.sv"] \
    [file normalize "rtl/ccsds_dl_rs255_223_dec.sv"] \
    [file normalize "rtl/ccsds_dl_turbo_ldpc_enc.sv"] \
    [file normalize "rtl/ccsds_conv_viterbi_codec.sv"] \
    [file normalize "rtl/ccsds_fop1_engine.sv"] \
    [file normalize "rtl/ccsds_tc_cltu_framer.sv"] \
    [file normalize "rtl/ccsds_tm_aos_deframer.sv"] \
    [file normalize "rtl/ccsds_prox1_plcw_ctrl.sv"] \
    [file normalize "rtl/ccsds_axi_lite_csr.sv"] \
    [file normalize "rtl/ccsds_pn_ranging.sv"] \
    [file normalize "rtl/ccsds_phy_modem.sv"] \
    [file normalize "rtl/ccsds_sat_ttc_top.sv"] \
]

add_files -norecurse -fileset sources_1 $RTL_SV_FILES
set_property file_type SystemVerilog [get_files $RTL_SV_FILES]

# Add the Verilog-2001 IP Integrator wrapper last so Vivado can reference it in BD
set WRAPPER_V [file normalize "rtl/ccsds_sat_ttc_bd_wrapper.v"]
add_files -norecurse -fileset sources_1 $WRAPPER_V
set_property file_type Verilog [get_files $WRAPPER_V]

# Add Stage 1 XDC Constraints (Async Clock Groups + BOB Status LEDs)
set STAGE1_XDC [file normalize "constraints/adrv9361_z7035_bob_stage1.xdc"]
if {[file exists $STAGE1_XDC]} {
    add_files -fileset constrs_1 -norecurse $STAGE1_XDC
}

update_compile_order -fileset sources_1

# ------------------------------------------------------------------------------
# 2. Helper Procedure: Version-Agnostic IP VLNV Lookup for Vivado 2026.1.1
# ------------------------------------------------------------------------------
proc create_ip_cell {ip_name cell_name} {
    # Prefer Vivado 2025.2+ / 2026.1.1 inline_hdl equivalents for xlslice, xlconstant, xlconcat
    set inline_map [dict create "xlslice" "ilslice" "xlconstant" "ilconstant" "xlconcat" "ilconcat"]
    if {[dict exists $inline_map $ip_name]} {
        set il_name [dict get $inline_map $ip_name]
        set il_defs [lsort -dictionary [get_ipdefs -all -filter "NAME == $il_name && DESIGN_TOOL_CONTEXTS =~ *IPI*"]]
        if {[llength $il_defs] > 0} {
            set latest_vlnv [lindex $il_defs end]
            puts "  -> Instantiating $cell_name ($latest_vlnv)"
            return [create_bd_cell -type inline_hdl -vlnv $latest_vlnv $cell_name]
        }
    }
    set ip_defs [lsort -dictionary [get_ipdefs -all -filter "NAME == $ip_name && DESIGN_TOOL_CONTEXTS =~ *IPI*"]]
    if {[llength $ip_defs] == 0} {
        error "ERROR: Could not find IP '$ip_name' in Vivado IP catalog!"
    }
    set latest_vlnv [lindex $ip_defs end]
    puts "  -> Instantiating $cell_name ($latest_vlnv)"
    return [create_bd_cell -type ip -vlnv $latest_vlnv $cell_name]
}

# ------------------------------------------------------------------------------
# 3. Create Block Design & Instantiate Zynq-7035 PS7 + 4-Clock Generator
# ------------------------------------------------------------------------------
create_bd_design $BD_NAME
current_bd_design $BD_NAME

# 3.1 Zynq-7000 Processing System (PS7) configured for ADRV9361-Z7035 + BOB UART0
set ps7 [create_ip_cell "processing_system7" "processing_system7_0"]
set_property -dict [list \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100.0} \
    CONFIG.PCW_USE_M_AXI_GP0            {1} \
    CONFIG.PCW_USE_FABRIC_INTERRUPT     {1} \
    CONFIG.PCW_IRQ_F2P_INTR             {1} \
    CONFIG.PCW_UART0_PERIPHERAL_ENABLE  {1} \
    CONFIG.PCW_UART0_UART0_IO           {MIO 14 .. 15} \
    CONFIG.PCW_UIPARAM_DDR_PARTNO       {MT41K256M16 RE-125} \
] $ps7

# Create fixed DDR and FIXED_IO external interfaces
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" Master "Disable" Slave "Disable"} $ps7

# 3.2 Clocking Wizard: Synthesize the 4 Isolated CCSDS Clock Domains from FCLK_CLK0 (100 MHz)
#   - clk_out1 : 100.0 MHz -> clk_sys     (OBC AXI4-Lite / AXI4-Stream / SDLS / Framer)
#   - clk_out2 :  16.0 MHz -> clk_tc_safe (Independent Uplink Telecommand / FARM-1 / HCPD)
#   - clk_out3 :  50.0 MHz -> clk_tx_sym  (Downlink CADU & Inner K=7 Convolutional Codec)
#   - clk_out4 : 120.0 MHz -> clk_adc_iq  (Baseband 4-SPS SRRC / Gardner STR / Costas / PN)
set clk_wiz [create_ip_cell "clk_wiz" "clk_wiz_ccsds"]
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ.VALUE_SRC       {USER} \
    CONFIG.PRIM_IN_FREQ                 {100.000} \
    CONFIG.CLKOUT2_USED                 {true} \
    CONFIG.CLKOUT3_USED                 {true} \
    CONFIG.CLKOUT4_USED                 {true} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ   {100.000} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ   {16.000} \
    CONFIG.CLKOUT3_REQUESTED_OUT_FREQ   {50.000} \
    CONFIG.CLKOUT4_REQUESTED_OUT_FREQ   {120.000} \
    CONFIG.RESET_TYPE                   {ACTIVE_LOW} \
    CONFIG.RESET_PORT                   {resetn} \
] $clk_wiz

connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0]   [get_bd_pins clk_wiz_ccsds/clk_in1]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] [get_bd_pins clk_wiz_ccsds/resetn]

# 3.3 Processor System Reset Synchronizer (Synchronous to clk_sys = 100 MHz)
set rst_sys [create_ip_cell "proc_sys_reset" "rst_clk_sys_100M"]
connect_bd_net [get_bd_pins clk_wiz_ccsds/clk_out1]           [get_bd_pins rst_clk_sys_100M/slowest_sync_clk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] [get_bd_pins rst_clk_sys_100M/ext_reset_in]
connect_bd_net [get_bd_pins clk_wiz_ccsds/locked]             [get_bd_pins rst_clk_sys_100M/dcm_locked]

# Connect M_AXI_GP0 clock to clk_sys (100 MHz)
connect_bd_net [get_bd_pins clk_wiz_ccsds/clk_out1]           [get_bd_pins processing_system7_0/M_AXI_GP0_ACLK]

# 3.4 AXI Interconnect / SmartConnect for PS7 M_AXI_GP0 Slave Peripherals
set axi_ic [create_ip_cell "axi_interconnect" "axi_ic_gp0"]
set num_masters [expr {$LOOPBACK_TOPOLOGY eq "DUAL_EGSE_TO_FLIGHT" ? 5 : 3}]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI $num_masters] $axi_ic

connect_bd_intf_net [get_bd_intf_pins processing_system7_0/M_AXI_GP0] [get_bd_intf_pins axi_ic_gp0/S00_AXI]
connect_bd_net [get_bd_pins clk_wiz_ccsds/clk_out1]                   [get_bd_pins axi_ic_gp0/ACLK]
connect_bd_net [get_bd_pins clk_wiz_ccsds/clk_out1]                   [get_bd_pins axi_ic_gp0/S00_ACLK]
connect_bd_net [get_bd_pins rst_clk_sys_100M/interconnect_aresetn]    [get_bd_pins axi_ic_gp0/ARESETN]
connect_bd_net [get_bd_pins rst_clk_sys_100M/peripheral_aresetn]      [get_bd_pins axi_ic_gp0/S00_ARESETN]
for {set i 0} {$i < $num_masters} {incr i} {
    set m_aclk   [format "M%02d_ACLK" $i]
    set m_areset [format "M%02d_ARESETN" $i]
    connect_bd_net [get_bd_pins clk_wiz_ccsds/clk_out1]                [get_bd_pins axi_ic_gp0/$m_aclk]
    connect_bd_net [get_bd_pins rst_clk_sys_100M/peripheral_aresetn]   [get_bd_pins axi_ic_gp0/$m_areset]
}

# 3.5 AXI GPIO for Runtime Hardware Mission Straps (Ch 1 Output) & Status Monitor (Ch 2 Input)
#   GPIO Ch1 Out [17:0]:
#     [1:0]   = link_proto_override_en (2'b00 = use CSR 0x04[14:12])
#     [3:2]   = ul_fec_override_en     (2'd1 = BCH(63,56), 2'd2 = LDPC(128,64), 2'd0 = Uncoded)
#     [4]     = sdls_en_cfg
#     [5]     = bc_require_sdls_cfg
#     [6]     = pn_ranging_en_cfg
#     [7]     = pn_t4b_mode_cfg
#     [8]     = turnaround_xband_cfg
#     [10:9]  = mod_mode_cfg           (0=BPSK, 1=QPSK, 2=OQPSK, 3=PCM/PM)
#     [12:11] = line_code_cfg          (0=NRZ-L, 1=NRZ-M, 2=Bi-Phi-L)
#     [18:13] = default_tx_vcid_cfg    (6-bit VCID injected when FIFO tuser == 0)
#     [19]    = pps_1hz_sw_pulse       (Software 1-PPS strobe for OBT sync test)
#   GPIO Ch2 In [6:0]:
#     [0]     = hcpd_obc_reset_pulse
#     [1]     = hcpd_safe_mode_force
#     [3:2]   = hcpd_rf_chain_select[1:0]
#     [4]     = pn_ranging_locked_out
#     [5]     = fault_irq_out
#     [6]     = edac_scrub_req_out
set axi_gpio [create_ip_cell "axi_gpio" "axi_gpio_straps"]
set_property -dict [list \
    CONFIG.C_GPIO_WIDTH       {20} \
    CONFIG.C_GPIO2_WIDTH      {7} \
    CONFIG.C_IS_DUAL          {1} \
    CONFIG.C_ALL_OUTPUTS      {1} \
    CONFIG.C_ALL_INPUTS_2     {1} \
    CONFIG.C_DOUT_DEFAULT     {0x00000004} \
] $axi_gpio
connect_bd_intf_net [get_bd_intf_pins axi_ic_gp0/M00_AXI]            [get_bd_intf_pins axi_gpio_straps/S_AXI]
connect_bd_net [get_bd_pins clk_wiz_ccsds/clk_out1]                  [get_bd_pins axi_gpio_straps/s_axi_aclk]
connect_bd_net [get_bd_pins rst_clk_sys_100M/peripheral_aresetn]     [get_bd_pins axi_gpio_straps/s_axi_aresetn]

# Slice GPIO Ch1 [19:0] into individual strap buses using xlslice
proc make_slice {name din_width from_bit to_bit src_pin} {
    set sl [create_ip_cell "xlslice" $name]
    set_property -dict [list \
        CONFIG.DIN_WIDTH $din_width \
        CONFIG.DIN_FROM  $from_bit \
        CONFIG.DIN_TO    $to_bit \
        CONFIG.DOUT_WIDTH [expr {$from_bit - $to_bit + 1}] \
    ] $sl
    connect_bd_net $src_pin [get_bd_pins $sl/Din]
    return [get_bd_pins $sl/Dout]
}

set gpio_out_pin [get_bd_pins axi_gpio_straps/gpio_io_o]
set p_proto_ovr  [make_slice "sl_proto_ovr"  20 1  0  $gpio_out_pin]
set p_ul_fec     [make_slice "sl_ul_fec"     20 3  2  $gpio_out_pin]
set p_sdls_en    [make_slice "sl_sdls_en"    20 4  4  $gpio_out_pin]
set p_bc_sdls    [make_slice "sl_bc_sdls"    20 5  5  $gpio_out_pin]
set p_pn_en      [make_slice "sl_pn_en"      20 6  6  $gpio_out_pin]
set p_pn_t4b     [make_slice "sl_pn_t4b"     20 7  7  $gpio_out_pin]
set p_turn_xb    [make_slice "sl_turn_xb"    20 8  8  $gpio_out_pin]
set p_mod_mode   [make_slice "sl_mod_mode"   20 10 9  $gpio_out_pin]
set p_line_code  [make_slice "sl_line_code"  20 12 11 $gpio_out_pin]
set p_tx_vcid    [make_slice "sl_tx_vcid"    20 18 13 $gpio_out_pin]
set p_pps_pulse  [make_slice "sl_pps_pulse"  20 19 19 $gpio_out_pin]


# ------------------------------------------------------------------------------
# 4. Helper Procedure: Instantiate a CCSDS Core + AXI-Stream Packet FIFO Bridge
# ------------------------------------------------------------------------------
proc create_ccsds_node {node_name role_mode m_csr_idx m_fifo_idx} {
    upvar 1 p_proto_ovr p_proto_ovr p_ul_fec p_ul_fec p_sdls_en p_sdls_en \
            p_bc_sdls p_bc_sdls p_pn_en p_pn_en p_pn_t4b p_pn_t4b \
            p_turn_xb p_turn_xb p_mod_mode p_mod_mode p_line_code p_line_code \
            p_tx_vcid p_tx_vcid p_pps_pulse p_pps_pulse

    set core [create_bd_cell -type module -reference ccsds_sat_ttc_bd_wrapper $node_name]
    set_property -dict [list \
        CONFIG.ROLE_MODE      $role_mode \
        CONFIG.ENABLE_SDLS    {1} \
        CONFIG.ENABLE_UL_LDPC {1} \
        CONFIG.IQ_BUS_WIDTH   {16} \
        CONFIG.RX_MSB_ALIGNED {1} \
    ] $core

    # Ensure clk_sys is associated with s_axi, s_axis_tx_pkt, and m_axis_rx_pkt for BD validation
    catch {set_property CONFIG.ASSOCIATED_BUSIF {s_axi:s_axis_tx_pkt:m_axis_rx_pkt} [get_bd_pins $core/clk_sys]}

    # Clocks & Reset
    connect_bd_net [get_bd_pins clk_wiz_ccsds/clk_out1]               [get_bd_pins $core/clk_sys]
    connect_bd_net [get_bd_pins clk_wiz_ccsds/clk_out2]               [get_bd_pins $core/clk_tc_safe]
    connect_bd_net [get_bd_pins clk_wiz_ccsds/clk_out3]               [get_bd_pins $core/clk_tx_sym]
    connect_bd_net [get_bd_pins clk_wiz_ccsds/clk_out4]               [get_bd_pins $core/clk_adc_iq]
    connect_bd_net [get_bd_pins rst_clk_sys_100M/peripheral_aresetn]  [get_bd_pins $core/rst_n]
    connect_bd_net $p_pps_pulse                                       [get_bd_pins $core/pps_1hz_in]

    # Hardware Mission Straps
    connect_bd_net $p_proto_ovr [get_bd_pins $core/link_proto_override_en]
    connect_bd_net $p_ul_fec    [get_bd_pins $core/ul_fec_override_en]
    connect_bd_net $p_sdls_en   [get_bd_pins $core/sdls_en_cfg]
    connect_bd_net $p_bc_sdls   [get_bd_pins $core/bc_require_sdls_cfg]
    connect_bd_net $p_pn_en     [get_bd_pins $core/pn_ranging_en_cfg]
    connect_bd_net $p_pn_t4b    [get_bd_pins $core/pn_t4b_mode_cfg]
    connect_bd_net $p_turn_xb   [get_bd_pins $core/turnaround_xband_cfg]
    connect_bd_net $p_mod_mode  [get_bd_pins $core/mod_mode_cfg]
    connect_bd_net $p_line_code [get_bd_pins $core/line_code_cfg]
    connect_bd_net $p_tx_vcid   [get_bd_pins $core/default_tx_vcid_cfg]


    # Connect AXI4-Lite CSR Slave
    set m_csr_port [format "M%02d_AXI" $m_csr_idx]
    connect_bd_intf_net [get_bd_intf_pins axi_ic_gp0/$m_csr_port] [get_bd_intf_pins $core/s_axi]

    # Instantiate AXI-Stream FIFO (32-bit MM2S/S2MM) + 32b<->8b Width Converters
    set fifo [create_ip_cell "axi_fifo_mm_s" "${node_name}_pkt_fifo"]
    set_property -dict [list \
        CONFIG.C_DATA_INTERFACE_TYPE {0} \
        CONFIG.C_USE_TX_DATA         {1} \
        CONFIG.C_USE_RX_DATA         {1} \
        CONFIG.C_USE_TX_CTRL         {0} \
        CONFIG.C_HAS_AXIS_TKEEP      {1} \
    ] $fifo

    set dw_tx [create_ip_cell "axis_dwidth_converter" "${node_name}_dw_32to8"]
    set_property -dict [list CONFIG.S_TDATA_NUM_BYTES {4} CONFIG.M_TDATA_NUM_BYTES {1}] $dw_tx

    set dw_rx [create_ip_cell "axis_dwidth_converter" "${node_name}_dw_8to32"]
    set_property -dict [list CONFIG.S_TDATA_NUM_BYTES {1} CONFIG.M_TDATA_NUM_BYTES {4} CONFIG.HAS_MI_TKEEP {1}] $dw_rx

    foreach blk [list $fifo $dw_tx $dw_rx] {
        connect_bd_net [get_bd_pins clk_wiz_ccsds/clk_out1]              [lindex [get_bd_pins $blk/*aclk] 0]
        connect_bd_net [get_bd_pins rst_clk_sys_100M/peripheral_aresetn] [lindex [get_bd_pins $blk/*aresetn] 0]
    }

    set m_fifo_port [format "M%02d_AXI" $m_fifo_idx]
    connect_bd_intf_net [get_bd_intf_pins axi_ic_gp0/$m_fifo_port]       [get_bd_intf_pins $fifo/S_AXI]
    connect_bd_intf_net [get_bd_intf_pins $fifo/AXI_STR_TXD]             [get_bd_intf_pins $dw_tx/S_AXIS]
    connect_bd_intf_net [get_bd_intf_pins $dw_tx/M_AXIS]                 [get_bd_intf_pins $core/s_axis_tx_pkt]
    connect_bd_intf_net [get_bd_intf_pins $core/m_axis_rx_pkt]           [get_bd_intf_pins $dw_rx/S_AXIS]
    connect_bd_intf_net [get_bd_intf_pins $dw_rx/M_AXIS]                 [get_bd_intf_pins $fifo/AXI_STR_RXD]

    return $core
}

# ------------------------------------------------------------------------------
# 5. Elaborate Selected Stage 1 Loopback Topology & Wire Baseband I/Q Loopback
# ------------------------------------------------------------------------------
if {$LOOPBACK_TOPOLOGY eq "DUAL_EGSE_TO_FLIGHT"} {
    # Dual-Core Asymmetric Link: Ground EGSE (ROLE=1) <-> Spacecraft Flight (ROLE=0)
    set u_egse   [create_ccsds_node "ccsds_gnd_egse"   1 1 2]
    set u_flight [create_ccsds_node "ccsds_sc_flight"  0 3 4]

    # Uplink RF Baseband: Ground EGSE Tx -> Spacecraft Flight Rx
    connect_bd_net [get_bd_pins $u_egse/tx_i_dac_out]    [get_bd_pins $u_flight/rx_i_adc_in]
    connect_bd_net [get_bd_pins $u_egse/tx_q_dac_out]    [get_bd_pins $u_flight/rx_q_adc_in]
    connect_bd_net [get_bd_pins $u_egse/tx_iq_valid_out] [get_bd_pins $u_flight/rx_iq_valid_in]

    # Downlink RF Baseband: Spacecraft Flight Tx -> Ground EGSE Rx
    connect_bd_net [get_bd_pins $u_flight/tx_i_dac_out]    [get_bd_pins $u_egse/rx_i_adc_in]
    connect_bd_net [get_bd_pins $u_flight/tx_q_dac_out]    [get_bd_pins $u_egse/rx_q_adc_in]
    connect_bd_net [get_bd_pins $u_flight/tx_iq_valid_out] [get_bd_pins $u_egse/rx_iq_valid_in]

    set mon_core $u_flight
} else {
    # Single-Core Universal Self-Loopback (ROLE_MODE = 2)
    set u_ttc [create_ccsds_node "ccsds_ttc_univ" 2 1 2]

    # Loop Tx I/Q DAC directly back into Rx I/Q ADC on the Block Design canvas
    connect_bd_net [get_bd_pins $u_ttc/tx_i_dac_out]    [get_bd_pins $u_ttc/rx_i_adc_in]
    connect_bd_net [get_bd_pins $u_ttc/tx_q_dac_out]    [get_bd_pins $u_ttc/rx_q_adc_in]
    connect_bd_net [get_bd_pins $u_ttc/tx_iq_valid_out] [get_bd_pins $u_ttc/rx_iq_valid_in]

    set mon_core $u_ttc
}

# Concatenate status outputs into AXI GPIO Ch2 Input [6:0]
set xl_stat [create_ip_cell "xlconcat" "concat_status_7b"]
set_property -dict [list CONFIG.NUM_PORTS {6}] $xl_stat
connect_bd_net [get_bd_pins $mon_core/hcpd_obc_reset_pulse]  [get_bd_pins $xl_stat/In0]
connect_bd_net [get_bd_pins $mon_core/hcpd_safe_mode_force]  [get_bd_pins $xl_stat/In1]
connect_bd_net [get_bd_pins $mon_core/hcpd_rf_chain_select]  [get_bd_pins $xl_stat/In2]
connect_bd_net [get_bd_pins $mon_core/pn_ranging_locked_out] [get_bd_pins $xl_stat/In3]
connect_bd_net [get_bd_pins $mon_core/fault_irq_out]         [get_bd_pins $xl_stat/In4]
connect_bd_net [get_bd_pins $mon_core/edac_scrub_req_out]    [get_bd_pins $xl_stat/In5]
connect_bd_net [get_bd_pins $xl_stat/dout]                   [get_bd_pins axi_gpio_straps/gpio2_io_i]
connect_bd_net [get_bd_pins $mon_core/fault_irq_out]         [get_bd_pins processing_system7_0/IRQ_F2P]

# ------------------------------------------------------------------------------
# 6. Assign Deterministic Non-Overlapping AXI4-Lite Memory Map for PS7 C Driver
# ------------------------------------------------------------------------------
set ps7_space [get_bd_addr_spaces processing_system7_0/Data]

assign_bd_address -target_address_space $ps7_space     -offset 0x41200000 -range 64K [get_bd_addr_segs axi_gpio_straps/S_AXI/Reg]

if {$LOOPBACK_TOPOLOGY eq "DUAL_EGSE_TO_FLIGHT"} {
    assign_bd_address -target_address_space $ps7_space         -offset 0x43C00000 -range 4K  [get_bd_addr_segs ccsds_gnd_egse/s_axi/reg0]
    assign_bd_address -target_address_space $ps7_space         -offset 0x43C10000 -range 64K [get_bd_addr_segs ccsds_gnd_egse_pkt_fifo/S_AXI/Mem0]
    assign_bd_address -target_address_space $ps7_space         -offset 0x43C20000 -range 4K  [get_bd_addr_segs ccsds_sc_flight/s_axi/reg0]
    assign_bd_address -target_address_space $ps7_space         -offset 0x43C30000 -range 64K [get_bd_addr_segs ccsds_sc_flight_pkt_fifo/S_AXI/Mem0]
} else {
    assign_bd_address -target_address_space $ps7_space         -offset 0x43C00000 -range 4K  [get_bd_addr_segs ccsds_ttc_univ/s_axi/reg0]
    assign_bd_address -target_address_space $ps7_space         -offset 0x43C10000 -range 64K [get_bd_addr_segs ccsds_ttc_univ_pkt_fifo/S_AXI/Mem0]
}

# ------------------------------------------------------------------------------
# 7. Regenerate Layout, Validate Block Design & Create Top HDL Wrapper
# ------------------------------------------------------------------------------
regenerate_bd_layout
validate_bd_design
save_bd_design

set bd_file [get_files ${BD_NAME}.bd]
make_wrapper -files $bd_file -top
set wrapper_top [file normalize "${PROJ_DIR}/${PROJ_NAME}.gen/sources_1/bd/${BD_NAME}/hdl/${BD_NAME}_wrapper.v"]
if {![file exists $wrapper_top]} {
    set wrapper_top [file normalize "${PROJ_DIR}/${PROJ_NAME}.srcs/sources_1/bd/${BD_NAME}/hdl/${BD_NAME}_wrapper.v"]
}
add_files -norecurse $wrapper_top
set_property top ${BD_NAME}_wrapper [current_fileset]
update_compile_order -fileset sources_1

puts "======================================================================"
puts " SUCCESS: Stage 1 Block Design ($BD_NAME) Validated!"
puts "   - AXI GPIO Straps Base   : 0x4120_0000"
puts "   - CCSDS CSR Base         : 0x43C0_0000 (HAL Base Address)"
puts "   - Packet Stream FIFO Base: 0x43C1_0000"
puts "======================================================================"

if {$RUN_BITSTREAM == 1} {
    launch_runs impl_1 -to_step write_bitstream -jobs 8
    wait_on_run impl_1
    write_hw_platform -fixed -include_bit -force -file "${PROJ_DIR}/${PROJ_NAME}_stage1.xsa"
    puts " Exported Hardware Platform XSA: ${PROJ_DIR}/${PROJ_NAME}_stage1.xsa"
}
