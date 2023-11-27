add_file -type verilog "core/gowin/dvi_tx/dvi_tx.v"
add_file -type verilog "core/gowin/gowin_pllvr/GW_PLLVR.v"
add_file -type verilog "core/gowin/gowin_pllvr/TMDS_PLLVR.v"
add_file -type verilog "core/gowin/hyperram_memory_interface/hyperram_memory_interface.v"
add_file -type verilog "core/gowin/video_frame_buffer/video_frame_buffer.v"
add_file -type verilog "rtl/I2C_Interface.v"
add_file -type verilog "rtl/OV2640_Controller.v"
add_file -type verilog "rtl/OV2640_Registers.v"
add_file -type verilog "rtl/syn_gen.v"

add_file -type verilog "../../rtl/stretch.v"
add_file -type verilog "../../rtl/async_buf.v"
add_file -type verilog "../../rtl/divider.v"
add_file -type verilog "../../rtl/mult255.v"

add_file -type verilog "rtl/top.v"
add_file -type cst "constr/physical.cst"
add_file -type sdc "constr/timing.sdc"

set_device GW1NSR-LV4CQN48PC6/I5 -name GW1NSR-4C

set_option -output_base_name stretch 

set_option -verilog_std v2001

set_option -place_option 1
set_option -route_option 1

run all
