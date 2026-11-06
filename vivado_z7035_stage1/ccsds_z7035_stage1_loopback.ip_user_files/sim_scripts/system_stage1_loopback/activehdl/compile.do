transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

vlib work
vlib activehdl/xilinx_vip
vlib activehdl/xpm
vlib activehdl/axi_infrastructure_v1_1_0
vlib activehdl/axi_vip_v1_1_23
vlib activehdl/processing_system7_vip_v1_0_25
vlib activehdl/xil_defaultlib
vlib activehdl/proc_sys_reset_v5_0_17
vlib activehdl/generic_baseblocks_v2_1_2
vlib activehdl/axi_register_slice_v2_1_37
vlib activehdl/fifo_generator_v13_2_15
vlib activehdl/axi_data_fifo_v2_1_37
vlib activehdl/axi_crossbar_v2_1_40
vlib activehdl/axi_lite_ipif_v3_1_0
vlib activehdl/interrupt_control_v3_2_0
vlib activehdl/axi_gpio_v2_0_38
vlib activehdl/axi_fifo_mm_s_v4_3_8
vlib activehdl/axis_infrastructure_v1_1_1
vlib activehdl/axis_register_slice_v1_1_35
vlib activehdl/axis_dwidth_converter_v1_1_34
vlib activehdl/axi_protocol_converter_v2_1_38

vmap xilinx_vip activehdl/xilinx_vip
vmap xpm activehdl/xpm
vmap axi_infrastructure_v1_1_0 activehdl/axi_infrastructure_v1_1_0
vmap axi_vip_v1_1_23 activehdl/axi_vip_v1_1_23
vmap processing_system7_vip_v1_0_25 activehdl/processing_system7_vip_v1_0_25
vmap xil_defaultlib activehdl/xil_defaultlib
vmap proc_sys_reset_v5_0_17 activehdl/proc_sys_reset_v5_0_17
vmap generic_baseblocks_v2_1_2 activehdl/generic_baseblocks_v2_1_2
vmap axi_register_slice_v2_1_37 activehdl/axi_register_slice_v2_1_37
vmap fifo_generator_v13_2_15 activehdl/fifo_generator_v13_2_15
vmap axi_data_fifo_v2_1_37 activehdl/axi_data_fifo_v2_1_37
vmap axi_crossbar_v2_1_40 activehdl/axi_crossbar_v2_1_40
vmap axi_lite_ipif_v3_1_0 activehdl/axi_lite_ipif_v3_1_0
vmap interrupt_control_v3_2_0 activehdl/interrupt_control_v3_2_0
vmap axi_gpio_v2_0_38 activehdl/axi_gpio_v2_0_38
vmap axi_fifo_mm_s_v4_3_8 activehdl/axi_fifo_mm_s_v4_3_8
vmap axis_infrastructure_v1_1_1 activehdl/axis_infrastructure_v1_1_1
vmap axis_register_slice_v1_1_35 activehdl/axis_register_slice_v1_1_35
vmap axis_dwidth_converter_v1_1_34 activehdl/axis_dwidth_converter_v1_1_34
vmap axi_protocol_converter_v2_1_38 activehdl/axi_protocol_converter_v2_1_38

vlog -work xilinx_vip  -sv2k12 "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/hdl/axi4stream_vip_axi4streampc.sv" \
"C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/hdl/axi_vip_axi4pc.sv" \
"C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/hdl/xil_common_vip_pkg.sv" \
"C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/hdl/axi4stream_vip_pkg.sv" \
"C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/hdl/axi_vip_pkg.sv" \
"C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/hdl/axi4stream_vip_if.sv" \
"C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/hdl/axi_vip_if.sv" \
"C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/hdl/clk_vip_if.sv" \
"C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/hdl/rst_vip_if.sv" \

vlog -work xpm  -sv2k12 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"C:/AMDDesignTools/2026.1.1/Vivado/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
"C:/AMDDesignTools/2026.1.1/Vivado/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv" \
"C:/AMDDesignTools/2026.1.1/Vivado/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm -93  \
"C:/AMDDesignTools/2026.1.1/Vivado/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work axi_infrastructure_v1_1_0  -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl/axi_infrastructure_v1_1_vl_rfs.v" \

vlog -work axi_vip_v1_1_23  -sv2k12 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/4d28/hdl/axi_vip_v1_1_vl_rfs.sv" \

vlog -work processing_system7_vip_v1_0_25  -sv2k12 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl/processing_system7_vip_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib  -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_processing_system7_0_0/sim/system_stage1_loopback_processing_system7_0_0.v" \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_clk_wiz_ccsds_0/system_stage1_loopback_clk_wiz_ccsds_0_clk_wiz.v" \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_clk_wiz_ccsds_0/system_stage1_loopback_clk_wiz_ccsds_0.v" \

vcom -work proc_sys_reset_v5_0_17 -93  \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/9438/hdl/proc_sys_reset_v5_0_rfs.vhd" \

vcom -work xil_defaultlib -93  \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_rst_clk_sys_100M_0/sim/system_stage1_loopback_rst_clk_sys_100M_0.vhd" \

vlog -work generic_baseblocks_v2_1_2  -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/0c28/hdl/generic_baseblocks_v2_1_rfs.v" \

vlog -work axi_register_slice_v2_1_37  -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/8c55/hdl/axi_register_slice_v2_1_rfs.v" \

vlog -work fifo_generator_v13_2_15  -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/084a/simulation/fifo_generator_vlog_beh.v" \

vcom -work fifo_generator_v13_2_15 -93  \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/084a/hdl/fifo_generator_v13_2_vh_sim_rfs.vhd" \

vlog -work fifo_generator_v13_2_15  -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/084a/hdl/fifo_generator_v13_2_vl_sim_rfs.v" \

vlog -work axi_data_fifo_v2_1_37  -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/a62a/hdl/axi_data_fifo_v2_1_vl_rfs.v" \

vlog -work axi_crossbar_v2_1_40  -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/52e8/hdl/axi_crossbar_v2_1_vl_rfs.v" \

vlog -work xil_defaultlib  -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_axi_ic_gp0_imp_xbar_0/sim/system_stage1_loopback_axi_ic_gp0_imp_xbar_0.v" \

vcom -work axi_lite_ipif_v3_1_0 -93  \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/de33/hdl/axi_lite_ipif_v3_1_rfs.vhd" \

vcom -work interrupt_control_v3_2_0 -93  \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/e2ca/hdl/interrupt_control_v3_2_rfs.vhd" \

vcom -work axi_gpio_v2_0_38 -93  \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/6ccd/hdl/axi_gpio_v2_0_rfs.vhd" \

vcom -work xil_defaultlib -93  \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_axi_gpio_straps_0/sim/system_stage1_loopback_axi_gpio_straps_0.vhd" \

vlog -work xil_defaultlib  -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_ccsds_gnd_egse_0/sim/system_stage1_loopback_ccsds_gnd_egse_0.v" \

vcom -work axi_fifo_mm_s_v4_3_8 -93  \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/af09/hdl/axi_fifo_mm_s_v4_3_rfs.vhd" \

vcom -work xil_defaultlib -93  \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_ccsds_gnd_egse_pkt_fifo_0/sim/system_stage1_loopback_ccsds_gnd_egse_pkt_fifo_0.vhd" \

vlog -work axis_infrastructure_v1_1_1  -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl/axis_infrastructure_v1_1_vl_rfs.v" \

vlog -work axis_register_slice_v1_1_35  -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/be12/hdl/axis_register_slice_v1_1_vl_rfs.v" \

vlog -work axis_dwidth_converter_v1_1_34  -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/80a6/hdl/axis_dwidth_converter_v1_1_vl_rfs.v" \

vlog -work xil_defaultlib  -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_ccsds_gnd_egse_dw_32to8_0/sim/system_stage1_loopback_ccsds_gnd_egse_dw_32to8_0.v" \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_ccsds_gnd_egse_dw_8to32_0/sim/system_stage1_loopback_ccsds_gnd_egse_dw_8to32_0.v" \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_ccsds_sc_flight_0/sim/system_stage1_loopback_ccsds_sc_flight_0.v" \

vcom -work xil_defaultlib -93  \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_ccsds_sc_flight_pkt_fifo_0/sim/system_stage1_loopback_ccsds_sc_flight_pkt_fifo_0.vhd" \

vlog -work xil_defaultlib  -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_ccsds_sc_flight_dw_32to8_0/sim/system_stage1_loopback_ccsds_sc_flight_dw_32to8_0.v" \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_ccsds_sc_flight_dw_8to32_0/sim/system_stage1_loopback_ccsds_sc_flight_dw_8to32_0.v" \

vlog -work axi_protocol_converter_v2_1_38  -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/bb9b/hdl/axi_protocol_converter_v2_1_vl_rfs.v" \

vlog -work xil_defaultlib  -v2k5 "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ec67/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/df05/hdl" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/ee6d" "+incdir+../../../../ccsds_z7035_stage1_loopback.gen/sources_1/bd/system_stage1_loopback/ipshared/434f/hdl" "+incdir+../../../../../../../../../AMDDesignTools/2026.1.1/Vivado/data/rsb/busdef" "+incdir+C:/AMDDesignTools/2026.1.1/Vivado/data/xilinx_vip/include" -l xilinx_vip -l xpm -l axi_infrastructure_v1_1_0 -l axi_vip_v1_1_23 -l processing_system7_vip_v1_0_25 -l xil_defaultlib -l proc_sys_reset_v5_0_17 -l generic_baseblocks_v2_1_2 -l axi_register_slice_v2_1_37 -l fifo_generator_v13_2_15 -l axi_data_fifo_v2_1_37 -l axi_crossbar_v2_1_40 -l axi_lite_ipif_v3_1_0 -l interrupt_control_v3_2_0 -l axi_gpio_v2_0_38 -l axi_fifo_mm_s_v4_3_8 -l axis_infrastructure_v1_1_1 -l axis_register_slice_v1_1_35 -l axis_dwidth_converter_v1_1_34 -l axi_protocol_converter_v2_1_38 \
"../../../bd/system_stage1_loopback/ip/system_stage1_loopback_axi_ic_gp0_imp_auto_pc_0/sim/system_stage1_loopback_axi_ic_gp0_imp_auto_pc_0.v" \
"../../../bd/system_stage1_loopback/sim/system_stage1_loopback.v" \

vlog -work xil_defaultlib \
"glbl.v"

