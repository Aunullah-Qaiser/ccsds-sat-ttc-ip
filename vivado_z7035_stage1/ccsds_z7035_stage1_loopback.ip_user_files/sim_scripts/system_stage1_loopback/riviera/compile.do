transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

vlib work
vlib riviera/xilinx_vip
vlib riviera/xpm
vlib riviera/axi_infrastructure_v1_1_0
vlib riviera/axi_vip_v1_1_23
vlib riviera/processing_system7_vip_v1_0_25
vlib riviera/xil_defaultlib
vlib riviera/proc_sys_reset_v5_0_17
vlib riviera/generic_baseblocks_v2_1_2
vlib riviera/axi_register_slice_v2_1_37
vlib riviera/fifo_generator_v13_2_15
vlib riviera/axi_data_fifo_v2_1_37
vlib riviera/axi_crossbar_v2_1_40
vlib riviera/axi_lite_ipif_v3_1_0
vlib riviera/interrupt_control_v3_2_0
vlib riviera/axi_gpio_v2_0_38
vlib riviera/axi_fifo_mm_s_v4_3_8
vlib riviera/axis_infrastructure_v1_1_1
vlib riviera/axis_register_slice_v1_1_35
vlib riviera/axis_dwidth_converter_v1_1_34
vlib riviera/axi_protocol_converter_v2_1_38

vmap xilinx_vip riviera/xilinx_vip
vmap xpm riviera/xpm
vmap axi_infrastructure_v1_1_0 riviera/axi_infrastructure_v1_1_0
vmap axi_vip_v1_1_23 riviera/axi_vip_v1_1_23
vmap processing_system7_vip_v1_0_25 riviera/processing_system7_vip_v1_0_25
vmap xil_defaultlib riviera/xil_defaultlib
vmap proc_sys_reset_v5_0_17 riviera/proc_sys_reset_v5_0_17
vmap generic_baseblocks_v2_1_2 riviera/generic_baseblocks_v2_1_2
vmap axi_register_slice_v2_1_37 riviera/axi_register_slice_v2_1_37
vmap fifo_generator_v13_2_15 riviera/fifo_generator_v13_2_15
vmap axi_data_fifo_v2_1_37 riviera/axi_data_fifo_v2_1_37
vmap axi_crossbar_v2_1_40 riviera/axi_crossbar_v2_1_40
vmap axi_lite_ipif_v3_1_0 riviera/axi_lite_ipif_v3_1_0
vmap interrupt_control_v3_2_0 riviera/interrupt_control_v3_2_0
vmap axi_gpio_v2_0_38 riviera/axi_gpio_v2_0_38
vmap axi_fifo_mm_s_v4_3_8 riviera/axi_fifo_mm_s_v4_3_8
vmap axis_infrastructure_v1_1_1 riviera/axis_infrastructure_v1_1_1
vmap axis_register_slice_v1_1_35 riviera/axis_register_slice_v1_1_35
vmap axis_dwidth_converter_v1_1_34 riviera/axis_dwidth_converter_v1_1_34
vmap axi_protocol_converter_v2_1_38 riviera/axi_protocol_converter_v2_1_38

vlog -work xilinx_vip  -incr "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/hdl/axi4stream_vip_axi4streampc.sv" \
"C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/hdl/axi_vip_axi4pc.sv" \
"C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/hdl/xil_common_vip_pkg.sv" \
"C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/hdl/axi4stream_vip_pkg.sv" \
"C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/hdl/axi_vip_pkg.sv" \
"C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/hdl/axi4stream_vip_if.sv" \
"C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/hdl/axi_vip_if.sv" \
"C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/hdl/clk_vip_if.sv" \
"C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/hdl/rst_vip_if.sv" \

vlog -work xpm  -incr "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"C:/AMDDesignTools/2026.1.1/Vivado/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
"C:/AMDDesignTools/2026.1.1/Vivado/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv" \
"C:/AMDDesignTools/2026.1.1/Vivado/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm -93  -incr \
"C:/AMDDesignTools/2026.1.1/Vivado/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work axi_infrastructure_v1_1_0  -incr -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl/axi_infrastructure_v1_1_vl_rfs.v" \

vlog -work axi_vip_v1_1_23  -incr "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/4d28/hdl/axi_vip_v1_1_vl_rfs.sv" \

vlog -work processing_system7_vip_v1_0_25  -incr "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl/processing_system7_vip_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib  -incr -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_processing_system7_0_0/sim/system_stage1_loopback_processing_system7_0_0.v" \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_clk_wiz_ccsds_0/system_stage1_loopback_clk_wiz_ccsds_0_clk_wiz.v" \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_clk_wiz_ccsds_0/system_stage1_loopback_clk_wiz_ccsds_0.v" \

vcom -work proc_sys_reset_v5_0_17 -93  -incr \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/9438/hdl/proc_sys_reset_v5_0_rfs.vhd" \

vcom -work xil_defaultlib -93  -incr \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_rst_clk_sys_100M_0/sim/system_stage1_loopback_rst_clk_sys_100M_0.vhd" \

vlog -work generic_baseblocks_v2_1_2  -incr -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/0c28/hdl/generic_baseblocks_v2_1_rfs.v" \

vlog -work axi_register_slice_v2_1_37  -incr -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/8c55/hdl/axi_register_slice_v2_1_rfs.v" \

vlog -work fifo_generator_v13_2_15  -incr -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/084a/simulation/fifo_generator_vlog_beh.v" \

vcom -work fifo_generator_v13_2_15 -93  -incr \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/084a/hdl/fifo_generator_v13_2_vh_sim_rfs.vhd" \

vlog -work fifo_generator_v13_2_15  -incr -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/084a/hdl/fifo_generator_v13_2_vl_sim_rfs.v" \

vlog -work axi_data_fifo_v2_1_37  -incr -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/a62a/hdl/axi_data_fifo_v2_1_vl_rfs.v" \

vlog -work axi_crossbar_v2_1_40  -incr -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/52e8/hdl/axi_crossbar_v2_1_vl_rfs.v" \

vlog -work xil_defaultlib  -incr -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_axi_ic_gp0_imp_xbar_0/sim/system_stage1_loopback_axi_ic_gp0_imp_xbar_0.v" \

vcom -work axi_lite_ipif_v3_1_0 -93  -incr \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/de33/hdl/axi_lite_ipif_v3_1_rfs.vhd" \

vcom -work interrupt_control_v3_2_0 -93  -incr \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/e2ca/hdl/interrupt_control_v3_2_rfs.vhd" \

vcom -work axi_gpio_v2_0_38 -93  -incr \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/6ccd/hdl/axi_gpio_v2_0_rfs.vhd" \

vcom -work xil_defaultlib -93  -incr \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_axi_gpio_straps_0/sim/system_stage1_loopback_axi_gpio_straps_0.vhd" \

vlog -work xil_defaultlib  -incr -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_ccsds_gnd_egse_0/sim/system_stage1_loopback_ccsds_gnd_egse_0.v" \

vcom -work axi_fifo_mm_s_v4_3_8 -93  -incr \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/af09/hdl/axi_fifo_mm_s_v4_3_rfs.vhd" \

vcom -work xil_defaultlib -93  -incr \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_ccsds_gnd_egse_pkt_fifo_0/sim/system_stage1_loopback_ccsds_gnd_egse_pkt_fifo_0.vhd" \

vlog -work axis_infrastructure_v1_1_1  -incr -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl/axis_infrastructure_v1_1_vl_rfs.v" \

vlog -work axis_register_slice_v1_1_35  -incr -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/be12/hdl/axis_register_slice_v1_1_vl_rfs.v" \

vlog -work axis_dwidth_converter_v1_1_34  -incr -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/80a6/hdl/axis_dwidth_converter_v1_1_vl_rfs.v" \

vlog -work xil_defaultlib  -incr -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_ccsds_gnd_egse_dw_32to8_0/sim/system_stage1_loopback_ccsds_gnd_egse_dw_32to8_0.v" \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_ccsds_gnd_egse_dw_8to32_0/sim/system_stage1_loopback_ccsds_gnd_egse_dw_8to32_0.v" \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_ccsds_sc_flight_0/sim/system_stage1_loopback_ccsds_sc_flight_0.v" \

vcom -work xil_defaultlib -93  -incr \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_ccsds_sc_flight_pkt_fifo_0/sim/system_stage1_loopback_ccsds_sc_flight_pkt_fifo_0.vhd" \

vlog -work xil_defaultlib  -incr -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_ccsds_sc_flight_dw_32to8_0/sim/system_stage1_loopback_ccsds_sc_flight_dw_32to8_0.v" \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_ccsds_sc_flight_dw_8to32_0/sim/system_stage1_loopback_ccsds_sc_flight_dw_8to32_0.v" \

vlog -work axi_protocol_converter_v2_1_38  -incr -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/bb9b/hdl/axi_protocol_converter_v2_1_vl_rfs.v" \

vlog -work xil_defaultlib  -incr -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_axi_ic_gp0_imp_auto_pc_0/sim/system_stage1_loopback_axi_ic_gp0_imp_auto_pc_0.v" \
"../../../bd/system_stage1_loopback/sim/system_stage1_loopback.v" \

vlog -work xil_defaultlib \
"glbl.v"

