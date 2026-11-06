# ==============================================================================
# File Name   : export_z7035_stage1_xsa.tcl
# Description : Run inside the Vivado 2026.1.1 Tcl Console after bitstream
#               generation completes to export the .xsa hardware platform and
#               copy the .bit + ps7_init.tcl into ./vivado_z7035_stage1/hw_export/
# Usage       : source scripts/export_z7035_stage1_xsa.tcl
# ==============================================================================
set EXPORT_DIR [file normalize "./vivado_z7035_stage1/hw_export"]
file mkdir $EXPORT_DIR

set XSA_PATH "${EXPORT_DIR}/system_stage1_loopback_wrapper.xsa"
write_hw_platform -fixed -include_bit -force -file $XSA_PATH

# Copy bitstream and ps7_init.tcl for direct XSDB JTAG execution
set bit_files [glob -nocomplain "./vivado_z7035_stage1/*.runs/impl_1/*.bit"]
if {[llength $bit_files] > 0} {
    file copy -force [lindex $bit_files 0] "${EXPORT_DIR}/system_stage1_loopback_wrapper.bit"
}
set ps7_files [glob -nocomplain "./vivado_z7035_stage1/*/*/*/bd/system_stage1_loopback/ip/*processing_system7*/ps7_init.tcl"]
if {[llength $ps7_files] == 0} {
    set ps7_files [glob -nocomplain "./vivado_z7035_stage1/**/ps7_init.tcl"]
}
if {[llength $ps7_files] > 0} {
    file copy -force [lindex $ps7_files 0] "${EXPORT_DIR}/ps7_init.tcl"
}

puts "======================================================================"
puts " Exported XSA, Bitstream & ps7_init.tcl to: $EXPORT_DIR"
puts " Next Step (Instant JTAG Loopback Test via XSDB):"
puts "   xsdb scripts/run_z7035_stage1_xsdb_test.tcl"
puts "======================================================================"
