## Clock signal (100 MHz on Basys 3)
set_property PACKAGE_PIN W5 [get_ports aclk]
set_property IOSTANDARD LVCMOS33 [get_ports aclk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports aclk]

## Reset (Center Button)
set_property PACKAGE_PIN U18 [get_ports aresetn]
set_property IOSTANDARD LVCMOS33 [get_ports aresetn]