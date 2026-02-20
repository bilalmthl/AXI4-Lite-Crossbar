create_project -force sim_project ./sim_project -part xc7a35tcpg236-1

read_verilog -sv rtl/axi_lite_if.sv
read_verilog -sv rtl/rr_arbiter.sv
read_verilog -sv rtl/axi_decoder.sv
read_verilog -sv rtl/axi_skid_buffer.sv
read_verilog -sv rtl/axi_crossbar.sv
read_verilog -sv tb/tb_crossbar.sv

set_property top tb_crossbar [get_filesets sim_1]

launch_simulation
run 1000ns