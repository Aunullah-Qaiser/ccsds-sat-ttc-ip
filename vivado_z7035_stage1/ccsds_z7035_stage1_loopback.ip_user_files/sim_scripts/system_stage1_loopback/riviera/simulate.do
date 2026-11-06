transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

asim +access +r +m+system_stage1_loopback  -L xil_defaultlib -L xilinx_vip -L xpm -L axi_infrastructure_v1_1_0 -L axi_vip_v1_1_23 -L processing_system7_vip_v1_0_25 -L proc_sys_reset_v5_0_17 -L generic_baseblocks_v2_1_2 -L axi_register_slice_v2_1_37 -L fifo_generator_v13_2_15 -L axi_data_fifo_v2_1_37 -L axi_crossbar_v2_1_40 -L axi_lite_ipif_v3_1_0 -L interrupt_control_v3_2_0 -L axi_gpio_v2_0_38 -L axi_fifo_mm_s_v4_3_8 -L axis_infrastructure_v1_1_1 -L axis_register_slice_v1_1_35 -L axis_dwidth_converter_v1_1_34 -L axi_protocol_converter_v2_1_38 -L xilinx_vip -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.system_stage1_loopback xil_defaultlib.glbl

do {system_stage1_loopback.udo}

run 1000ns

endsim

quit -force
