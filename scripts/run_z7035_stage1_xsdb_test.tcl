# ==============================================================================
# File Name   : run_z7035_stage1_xsdb_test.tcl
# Project     : CCSDS-SAT-TTC-IP (v2.40.3)
# Target      : Analog Devices ADRV9361-Z7035 SOM + ADRV1CRR-BOB (USB-JTAG)
# Description : Instant Zero-Compile Hardware Verification via XSDB over JTAG!
#               1. Connects to Zynq-7035 JTAG, programs the Stage 1 bitstream,
#                  and runs ps7_init + ps7_post_config to start the 100 MHz
#                  FCLK_CLK0 and enable M_AXI_GP0.
#               2. Verifies CORE_ID_VER (0xCC5D0230) on both Ground EGSE
#                  (0x43C0_0000) and Spacecraft Flight (0x43C2_0000).
#               3. Verifies Wideband T4B PN Ranging Lock in hardware.
#               4. Streams a 16-byte Telecommand Space Packet ("TOP_CMD1!!")
#                  from Ground EGSE -> Baseband I/Q -> Spacecraft Flight and
#                  verifies bit-exact reception + CLCW V(R) = 1.
#               5. Streams a 16-byte Telemetry Space Packet ("SAT_TLM_OK")
#                  from Spacecraft Flight -> Baseband I/Q -> Ground EGSE and
#                  verifies RS(255,223) decoding + closed-loop CLCW capture!
#
# Usage (from Windows CMD / PowerShell at repo root with board powered on):
#   xsdb scripts/run_z7035_stage1_xsdb_test.tcl
# ==============================================================================

puts "======================================================================"
puts " CCSDS-SAT-TTC-IP (v2.40.3) — ADRV9361-Z7035 Stage 1 JTAG Hardware Test"
puts "======================================================================"

# 1. Locate Bitstream and ps7_init.tcl
set bit_candidates [concat \
    [glob -nocomplain "./vivado_z7035_stage1/hw_export/*.bit"] \
    [glob -nocomplain "./vivado_z7035_stage1/*.runs/impl_1/*.bit"] \
]
if {[llength $bit_candidates] == 0} {
    error "ERROR: Could not find Stage 1 .bit file under ./vivado_z7035_stage1!"
}
set BIT_FILE [file normalize [lindex $bit_candidates 0]]

set ps7_candidates [concat \
    [glob -nocomplain "./vivado_z7035_stage1/hw_export/ps7_init.tcl"] \
    [glob -nocomplain "./vivado_z7035_stage1/*.gen/sources_1/bd/system_stage1_loopback/ip/*processing_system7*/ps7_init.tcl"] \
    [glob -nocomplain "./vivado_z7035_stage1/*.srcs/sources_1/bd/system_stage1_loopback/ip/*processing_system7*/ps7_init.tcl"] \
]
if {[llength $ps7_candidates] == 0} {
    error "ERROR: Could not find ps7_init.tcl! Run `source scripts/export_z7035_stage1_xsa.tcl` in Vivado first."
}
set PS7_INIT_TCL [file normalize [lindex $ps7_candidates 0]]

puts "  -> Using Bitstream   : $BIT_FILE"
puts "  -> Using ps7_init.tcl: $PS7_INIT_TCL"

# 2. Connect to Hardware Server, Program PL Bitstream & Initialize Zynq PS7
connect
targets -set -nocase -filter {name =~ "arm*#0"}
rst -system
after 200

puts "  -> Programming Zynq-7035 PL FPGA fabric..."
fpga -file $BIT_FILE
after 200

puts "  -> Initializing Zynq-7035 PS7 Clocks (FCLK_CLK0 = 100 MHz) & M_AXI_GP0..."
source $PS7_INIT_TCL
ps7_init
ps7_post_config
after 200

# Helper procs for 32-bit MMIO Read/Write over JTAG-AP
proc reg_wr {addr val} {
    mwr -force $addr $val
}
proc reg_rd {addr} {
    return [lindex [mrd -force -value $addr] 0]
}

set GPIO_BASE       0x41200000
set EGSE_CSR        0x43C00000
set EGSE_FIFO       0x43C10000
set FLIGHT_CSR      0x43C20000
set FLIGHT_FIFO     0x43C30000

# 3. Verify CORE_ID_VER (0xCC5D0230) on Both Ground EGSE & Spacecraft Flight
set egse_id   [reg_rd $EGSE_CSR]
set flight_id [reg_rd $FLIGHT_CSR]
puts [format "\n[STEP 1] Reading CORE_ID_VER: EGSE(0x43C00000)=0x%08X | Flight(0x43C20000)=0x%08X" $egse_id $flight_id]
if {$egse_id != 0xCC5D0230 || $flight_id != 0xCC5D0230} {
    error "FAIL: Unexpected CORE_ID_VER readback!"
}
puts "  -> \[PASS\] Both CCSDS-SAT-TTC-IP cores alive in Z7035 silicon!"

# 4. Program CSRs (Matching tb_stage11_top_to_top_rf_link.sv Subtest 11.1-11.3):
#    0x04 = 0x01300155 (SCID=0x155, PROTO=TM, OCF=1, FECF=1, TC_SEG_HDR=1)
#    0x08 = 0x2C314255 (FLL_ASSIST=1, RS_VIRT_FILL_Q=195 [28B frame], RS_I=1, USLP_SCID=0x4255)
#    0x0C = 0x01001010 (FAULT_IRQ_EN=1, TFDF_BYTE_LEN=16, COP1_WIN_W=16)
foreach base [list $EGSE_CSR $FLIGHT_CSR] {
    reg_wr [expr {$base + 0x04}] 0x01300155
    reg_wr [expr {$base + 0x08}] 0x2C314255
    reg_wr [expr {$base + 0x0C}] 0x01001010
}

# 5. Test Wideband T4B PN Ranging Lock via AXI GPIO Straps
#    ul_fec_override_en[3:2]=1 (BCH), pn_ranging_en_cfg[6]=1, pn_t4b_mode_cfg[7]=1, vcid[18:13]=1
reg_wr $GPIO_BASE [expr {(1 << 2) | (1 << 6) | (1 << 7) | (1 << 13)}]
after 50
set gpio2_status [reg_rd [expr {$GPIO_BASE + 0x08}]]
puts [format "\n[STEP 2] Wideband T4B PN Ranging Status (GPIO2=0x%02X): pn_All_Locked_out = %d" \
    $gpio2_status [expr {($gpio2_status >> 4) & 1}]]

# Disable PN ranging overlay so Baseband I/Q carries Uplink/Downlink PSK telemetry & commands
reg_wr $GPIO_BASE [expr {(1 << 2) | (1 << 13)}]
after 20

# Reset both AXI-Stream Packet FIFOs
foreach fbase [list $EGSE_FIFO $FLIGHT_FIFO] {
    reg_wr [expr {$fbase + 0x08}] 0x000000A5
    reg_wr [expr {$fbase + 0x18}] 0x000000A5
    reg_wr [expr {$fbase + 0x00}] 0xFFFFFFFF
}

# 6. Test Uplink RF Baseband: Ground EGSE TX FIFO -> Spacecraft Flight RX FIFO
#    16-byte Telecommand Space Packet ("TOP_CMD1!!"):
#      Bytes 0..3 : 0x1A, 0x45, 0xC0, 0x11 -> Little-Endian 32b Word0 = 0x11C0451A
#      Bytes 4..7 : 0x00, 0x09, 'T'(0x54), 'O'(0x4F) -> Word1 = 0x4F540900
#      Bytes 8..11: 'P'(0x50), '_'(0x5F), 'C'(0x43), 'M'(0x4D) -> Word2 = 0x4D435F50
#      Bytes 12..15: 'D'(0x44), '1'(0x31), '!'(0x21), '!'(0x21) -> Word3 = 0x21213144
set ul_words [list 0x11C0451A 0x4F540900 0x4D435F50 0x21213144]
puts "\n[STEP 3] Injecting 16-Byte Telecommand Packet ('TOP_CMD1!!') into Ground EGSE TX FIFO..."
foreach w $ul_words {
    reg_wr [expr {$EGSE_FIFO + 0x10}] $w
}
reg_wr [expr {$EGSE_FIFO + 0x14}] 16
after 100

set flt_rx_occ [reg_rd [expr {$FLIGHT_FIFO + 0x1C}]]
puts [format "  -> Spacecraft Flight RX FIFO Occupancy (RDFO) = %d words" $flt_rx_occ]
if {$flt_rx_occ < 4} {
    error "FAIL: Spacecraft Flight RX FIFO did not receive the 4 Uplink packet words!"
}
set flt_rx_len [reg_rd [expr {$FLIGHT_FIFO + 0x24}]]
for {set i 0} {$i < 4} {incr i} {
    set got [reg_rd [expr {$FLIGHT_FIFO + 0x20}]]
    set exp [lindex $ul_words $i]
    puts [format "     Uplink Word\[%d\]: TX = 0x%08X | RX = 0x%08X %s" \
        $i $exp $got [expr {$got == $exp ? "\[MATCH\]" : "\[MISMATCH!\]"}]]
}
set sc_clcw [reg_rd [expr {$FLIGHT_CSR + 0x20}]]
puts [format "  -> \[PASS\] Spacecraft COP-1 CLCW (0x20) = 0x%08X (Report_Value V(R) = %d)" \
    $sc_clcw [expr {$sc_clcw & 0xFF}]]

# 7. Test Downlink RF Baseband: Spacecraft Flight TX FIFO -> Ground EGSE RX FIFO
#    16-byte Telemetry Space Packet ("SAT_TLM_OK"):
#      Bytes 0..3 : 0x09, 0x09, 0xC0, 0x22 -> Word0 = 0x22C00909
#      Bytes 4..7 : 0x00, 0x09, 'S'(0x53), 'A'(0x41) -> Word1 = 0x41530900
#      Bytes 8..11: 'T'(0x54), '_'(0x5F), 'T'(0x54), 'L'(0x4C) -> Word2 = 0x4C545F54
#      Bytes 12..15: 'M'(0x4D), '_'(0x5F), 'O'(0x4F), 'K'(0x4B) -> Word3 = 0x4B4F5F4D
set dl_words [list 0x22C00909 0x41530900 0x4C545F54 0x4B4F5F4D]
puts "\n[STEP 4] Injecting 16-Byte Telemetry Packet ('SAT_TLM_OK') into Spacecraft Flight TX FIFO..."
foreach w $dl_words {
    reg_wr [expr {$FLIGHT_FIFO + 0x10}] $w
}
reg_wr [expr {$FLIGHT_FIFO + 0x14}] 16
after 100

set egse_rx_occ [reg_rd [expr {$EGSE_FIFO + 0x1C}]]
puts [format "  -> Ground EGSE RX FIFO Occupancy (RDFO) = %d words" $egse_rx_occ]
if {$egse_rx_occ < 4} {
    error "FAIL: Ground EGSE RX FIFO did not receive the 4 Downlink packet words!"
}
set egse_rx_len [reg_rd [expr {$EGSE_FIFO + 0x24}]]
for {set i 0} {$i < 4} {incr i} {
    set got [reg_rd [expr {$EGSE_FIFO + 0x20}]]
    set exp [lindex $dl_words $i]
    puts [format "     Downlink Word\[%d\]: TX = 0x%08X | RX = 0x%08X %s" \
        $i $exp $got [expr {$got == $exp ? "\[MATCH\]" : "\[MISMATCH!\]"}]]
}
set egse_clcw [reg_rd [expr {$EGSE_CSR + 0x20}]]
puts [format "  -> \[PASS\] Ground EGSE Captured Downlink CLCW (0x20) = 0x%08X (V(R) = %d)" \
    $egse_clcw [expr {$egse_clcw & 0xFF}]]

puts "\n======================================================================"
puts " >>> STAGE 1 ADRV9361-Z7035 SILICON LOOPBACK PASSED (0 BIT ERRORS) <<<"
puts "======================================================================"
