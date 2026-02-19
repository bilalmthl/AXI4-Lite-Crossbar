set part "xc7a35tcpg236-1"
set outputDir ./build_output
file mkdir $outputDir

read_verilog -sv rtl/axi_lite_if.sv
read_verilog -sv rtl/rr_arbiter.sv
read_verilog -sv rtl/axi_decoder.sv
read_verilog -sv rtl/axi_crossbar.sv

read_xdc constraints/basys3.xdc

synth_design -top axi_crossbar -part $part -flatten_hierarchy rebuilt

opt_design
place_design
phys_opt_design -directive AggressiveExplore
route_design

report_design_analysis -congestion -file $outputDir/congestion.rpt
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -max_paths 10 -input_pins -file $outputDir/timing_summary.rpt
report_utilization -file $outputDir/utilization.rpt
report_power -file $outputDir/power.rpt

write_checkpoint -force $outputDir/post_route.dcp