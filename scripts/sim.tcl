create_project -force sim_project ./sim_project -part xc7a35tcpg236-1

read_verilog -sv rtl/axi_lite_if.sv
read_verilog -sv rtl/rr_arbiter.sv
read_verilog -sv rtl/axi_decoder.sv
read_verilog -sv rtl/axi_crossbar.sv
read_verilog -sv tb/tb_crossbar.sv

set_property top tb_crossbar [get_filesets sim_1]

set_property XPM_LIBRARIES {XPM_CDC XPM_MEMORY XPM_FIFO} [current_project]

launch_simulation
run all

start_gui