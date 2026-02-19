set_property PACKAGE_PIN W5 [get_ports aclk]
set_property IOSTANDARD LVCMOS33 [get_ports aclk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports aclk]

set_property PACKAGE_PIN U18 [get_ports aresetn]
set_property IOSTANDARD LVCMOS33 [get_ports aresetn]

create_pblock pblock_congestion
resize_pblock [get_pblocks pblock_congestion] -add {SLICE_X10Y10:SLICE_X21Y21}
add_cells_to_pblock [get_pblocks pblock_congestion] [get_cells *]