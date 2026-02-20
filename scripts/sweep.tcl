set period 10.0
set wns 1.0

# Loop and decrease period by 0.2ns until timing fails
while {$wns >= 0.0} {
    set period [expr {$period - 0.2}]
    puts "Testing clock period: $period ns"

    # Override the clock constraint
    create_clock -force -name sys_clk_pin -period $period [get_ports aclk]
    
    # Run implementation
    opt_design
    place_design
    phys_opt_design -directive AggressiveExplore
    route_design
    
    # Extract Setup WNS
    set wns [get_property SLACK [get_timing_paths -setup]]
    puts "Resulting WNS: $wns ns"
}

set max_period [expr {$period + 0.2}]
puts "Timing failed at $period ns. Maximum passing period is $max_period ns."