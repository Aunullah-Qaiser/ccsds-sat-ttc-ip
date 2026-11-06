# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "ENABLE_SDLS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "ENABLE_UL_LDPC" -parent ${Page_0}
  ipgui::add_param $IPINST -name "IQ_BUS_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "ROLE_MODE" -parent ${Page_0}
  ipgui::add_param $IPINST -name "RX_MSB_ALIGNED" -parent ${Page_0}


}

proc update_PARAM_VALUE.ENABLE_SDLS { PARAM_VALUE.ENABLE_SDLS } {
	# Procedure called to update ENABLE_SDLS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ENABLE_SDLS { PARAM_VALUE.ENABLE_SDLS } {
	# Procedure called to validate ENABLE_SDLS
	return true
}

proc update_PARAM_VALUE.ENABLE_UL_LDPC { PARAM_VALUE.ENABLE_UL_LDPC } {
	# Procedure called to update ENABLE_UL_LDPC when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ENABLE_UL_LDPC { PARAM_VALUE.ENABLE_UL_LDPC } {
	# Procedure called to validate ENABLE_UL_LDPC
	return true
}

proc update_PARAM_VALUE.IQ_BUS_WIDTH { PARAM_VALUE.IQ_BUS_WIDTH } {
	# Procedure called to update IQ_BUS_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.IQ_BUS_WIDTH { PARAM_VALUE.IQ_BUS_WIDTH } {
	# Procedure called to validate IQ_BUS_WIDTH
	return true
}

proc update_PARAM_VALUE.ROLE_MODE { PARAM_VALUE.ROLE_MODE } {
	# Procedure called to update ROLE_MODE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ROLE_MODE { PARAM_VALUE.ROLE_MODE } {
	# Procedure called to validate ROLE_MODE
	return true
}

proc update_PARAM_VALUE.RX_MSB_ALIGNED { PARAM_VALUE.RX_MSB_ALIGNED } {
	# Procedure called to update RX_MSB_ALIGNED when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.RX_MSB_ALIGNED { PARAM_VALUE.RX_MSB_ALIGNED } {
	# Procedure called to validate RX_MSB_ALIGNED
	return true
}


proc update_MODELPARAM_VALUE.ROLE_MODE { MODELPARAM_VALUE.ROLE_MODE PARAM_VALUE.ROLE_MODE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ROLE_MODE}] ${MODELPARAM_VALUE.ROLE_MODE}
}

proc update_MODELPARAM_VALUE.ENABLE_SDLS { MODELPARAM_VALUE.ENABLE_SDLS PARAM_VALUE.ENABLE_SDLS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ENABLE_SDLS}] ${MODELPARAM_VALUE.ENABLE_SDLS}
}

proc update_MODELPARAM_VALUE.ENABLE_UL_LDPC { MODELPARAM_VALUE.ENABLE_UL_LDPC PARAM_VALUE.ENABLE_UL_LDPC } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ENABLE_UL_LDPC}] ${MODELPARAM_VALUE.ENABLE_UL_LDPC}
}

proc update_MODELPARAM_VALUE.IQ_BUS_WIDTH { MODELPARAM_VALUE.IQ_BUS_WIDTH PARAM_VALUE.IQ_BUS_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.IQ_BUS_WIDTH}] ${MODELPARAM_VALUE.IQ_BUS_WIDTH}
}

proc update_MODELPARAM_VALUE.RX_MSB_ALIGNED { MODELPARAM_VALUE.RX_MSB_ALIGNED PARAM_VALUE.RX_MSB_ALIGNED } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.RX_MSB_ALIGNED}] ${MODELPARAM_VALUE.RX_MSB_ALIGNED}
}

