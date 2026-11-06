# ==============================================================================
# File Name   : adrv9361_z7035_bob_stage1.xdc
# Target      : Analog Devices ADRV9361-Z7035 SOM (xc7z035ifbg676-2L) + ADRV1CRR-BOB
# Description : Asynchronous Clock-Domain Crossing (CDC) Timing Exceptions &
#               False-Path Constraints for Stage 1 Block-Design Loopback.
# ==============================================================================

# Asynchronous Clock Groups Across the 4 Synthesized CCSDS Clock Domains
# (All cross-domain paths traverse Gray-coded Hsiao (39,32) SECDED LUTRAM FIFOs
#  or 2-FF ASYNC_REG synchronizers inside ccsds_sat_ttc_top)
set_clock_groups -asynchronous \
    -group [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ *clk_wiz_ccsds/clk_out1}]] \
    -group [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ *clk_wiz_ccsds/clk_out2}]] \
    -group [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ *clk_wiz_ccsds/clk_out3}]] \
    -group [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ *clk_wiz_ccsds/clk_out4}]]

# False path on static / quasi-static AXI GPIO hardware strap overrides
set_false_path -from [get_cells -hierarchical -filter {NAME =~ *axi_gpio_straps*}]
