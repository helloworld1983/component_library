# TCL File Generated by Component Editor 18.0
# Thu Jan 16 08:21:56 MST 2020
# DO NOT MODIFY


# 
# FE_AD7768_v1 "FE_AD7768_v1" v1.0
#  2020.01.16.08:21:56
# 
# 

# 
# request TCL package from ACDS 16.1
# 
package require -exact qsys 16.1


# 
# module FE_AD7768_v1
# 
set_module_property DESCRIPTION ""
set_module_property NAME FE_AD7768_v1
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property AUTHOR ""
set_module_property DISPLAY_NAME FE_AD7768_v1
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false


# 
# file sets
# 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL FE_AD7768_v1
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file FE_AD7768_v1.vhd VHDL PATH FE_AD7768_v1.vhd TOP_LEVEL_FILE


# 
# parameters
# 
add_parameter n_channels INTEGER 8
set_parameter_property n_channels DEFAULT_VALUE 8
set_parameter_property n_channels DISPLAY_NAME n_channels
set_parameter_property n_channels TYPE INTEGER
set_parameter_property n_channels UNITS None
set_parameter_property n_channels ALLOWED_RANGES -2147483648:2147483647
set_parameter_property n_channels HDL_PARAMETER true


# 
# display items
# 


# 
# connection point sys_clk
# 
add_interface sys_clk clock end
set_interface_property sys_clk clockRate 0
set_interface_property sys_clk ENABLED true
set_interface_property sys_clk EXPORT_OF ""
set_interface_property sys_clk PORT_NAME_MAP ""
set_interface_property sys_clk CMSIS_SVD_VARIABLES ""
set_interface_property sys_clk SVD_ADDRESS_GROUP ""

add_interface_port sys_clk sys_clk clk Input 1


# 
# connection point AD7768_physical
# 
add_interface AD7768_physical conduit end
set_interface_property AD7768_physical associatedClock ""
set_interface_property AD7768_physical associatedReset ""
set_interface_property AD7768_physical ENABLED true
set_interface_property AD7768_physical EXPORT_OF ""
set_interface_property AD7768_physical PORT_NAME_MAP ""
set_interface_property AD7768_physical CMSIS_SVD_VARIABLES ""
set_interface_property AD7768_physical SVD_ADDRESS_GROUP ""

add_interface_port AD7768_physical AD7768_DOUT_in ad7768_dout_in Input n_channels
add_interface_port AD7768_physical AD7768_DRDY_in ad7768_drdy_in Input 1
add_interface_port AD7768_physical AD7768_DCLK_in ad7768_dclk_in Input 1


# 
# connection point data_out
# 
add_interface data_out avalon_streaming start
set_interface_property data_out associatedClock sys_clk
set_interface_property data_out associatedReset sys_reset
set_interface_property data_out dataBitsPerSymbol 32
set_interface_property data_out errorDescriptor ""
set_interface_property data_out firstSymbolInHighOrderBits true
set_interface_property data_out maxChannel 0
set_interface_property data_out readyLatency 0
set_interface_property data_out ENABLED true
set_interface_property data_out EXPORT_OF ""
set_interface_property data_out PORT_NAME_MAP ""
set_interface_property data_out CMSIS_SVD_VARIABLES ""
set_interface_property data_out SVD_ADDRESS_GROUP ""

add_interface_port data_out AD7768_data_out data Output 32
add_interface_port data_out AD7768_valid_out valid Output 1
add_interface_port data_out AD7768_error_out error Output 2
add_interface_port data_out AD7768_channel_out channel Output 3


# 
# connection point sys_reset
# 
add_interface sys_reset reset end
set_interface_property sys_reset associatedClock sys_clk
set_interface_property sys_reset synchronousEdges DEASSERT
set_interface_property sys_reset ENABLED true
set_interface_property sys_reset EXPORT_OF ""
set_interface_property sys_reset PORT_NAME_MAP ""
set_interface_property sys_reset CMSIS_SVD_VARIABLES ""
set_interface_property sys_reset SVD_ADDRESS_GROUP ""

add_interface_port sys_reset sys_reset_n reset_n Input 1

