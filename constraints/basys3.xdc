## Clock signal
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports aclk]

## Pblock Definition
create_pblock pblock_congestion
resize_pblock [get_pblocks pblock_congestion] -add {SLICE_X10Y10:SLICE_X30Y30}
add_cells_to_pblock [get_pblocks pblock_congestion] [get_cells *]

## Configuration bits
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]