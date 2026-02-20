set part "xc7a35tcpg236-1"
set outputDir ./build_output
file mkdir $outputDir

# Load sources
read_verilog -sv rtl/axi_lite_if.sv
read_verilog -sv rtl/rr_arbiter.sv
read_verilog -sv rtl/axi_decoder.sv
read_verilog -sv rtl/axi_skid_buffer.sv
read_verilog -sv rtl/axi_crossbar.sv
read_xdc constraints/basys3.xdc

# Synthesize ONCE and save a clean checkpoint
synth_design -top axi_crossbar -part $part -flatten_hierarchy rebuilt -mode out_of_context
write_checkpoint -force $outputDir/post_synth.dcp

set period 10.0
set wns 1.0

# Loop the implementation flow
while {$wns >= 0.0} {
    set period [format "%.1f" [expr {$period - 0.2}]]
    puts "\n======================================="
    puts "Testing clock period: $period ns"
    puts "=======================================\n"

    # Use open_checkpoint to replace the active design in memory
    open_checkpoint $outputDir/post_synth.dcp
    
    # Apply the new aggressive clock constraint (removed -force)
    create_clock -name sys_clk_pin -period $period [get_ports aclk]
    
    # Run physical implementation
    opt_design
    place_design
    phys_opt_design -directive AggressiveExplore
    route_design
    
    # Extract the WNS
    set wns [get_property SLACK [get_timing_paths -setup]]
    puts "Resulting WNS: $wns ns"
}

set max_period [format "%.1f" [expr {$period + 0.2}]]
puts "\nTiming failed at $period ns."
puts "Maximum passing period is $max_period ns."