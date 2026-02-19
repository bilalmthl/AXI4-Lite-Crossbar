set part "xc7a35tcpg236-1"

set outputDir ./build_output
file mkdir $outputDir

puts "Reading Design Files..."
read_verilog -sv rtl/axi_lite_if.sv
read_verilog -sv rtl/axi_crossbar.sv

read_xdc constraints/basys3.xdc

puts "Running Synthesis..."
synth_design -top axi_crossbar -part $part -flatten_hierarchy rebuilt

report_timing_summary -file $outputDir/post_synth_timing_summary.rpt
report_utilization -file $outputDir/post_synth_utilization.rpt

puts "Synthesis Complete. Check build_output/ directory for reports."