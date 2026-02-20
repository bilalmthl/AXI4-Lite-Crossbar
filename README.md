# High-Performance AXI4-Lite Crossbar Interconnect

## Overview
A fully parameterizable, high-frequency AXI4-Lite Crossbar switch written in SystemVerilog. Designed with a strict focus on physical implementation (PPA optimization) and protocol compliance, this interconnect routes transactions between multiple AXI Masters and Slaves using round-robin arbitration and integrated pipelining.

This project bridges the gap between RTL logic design and physical silicon realities by utilizing registered skid buffers to break combinational bottlenecks, achieving significant maximum frequency (Fmax) improvements on FPGA fabric.

## Key Features
* **Configurable Topology:** Parameterized `N_MASTERS` and `M_SLAVES` generation.
* **Fair Arbitration:** Round-robin arbiters on every slave port prevent master starvation.
* **Decoupled Handshaking (Skid Buffers):** Fully registered `VALID`/`READY` paths eliminate zero-cycle combinational loops, drastically improving maximum clock frequency at the cost of a single cycle of latency.
* **Deadlock Prevention:** State-machine-driven arbiter locking ensures atomic transaction completion across independent address and data channels.
* **Automated Timing Closure:** Custom Tcl synthesis scripts to iteratively sweep clock constraints and aggressive physical optimization directives.
* **Protocol Verification:** Embedded SystemVerilog Assertions (SVA) continuously monitor handshakes to guarantee strict AXI4-Lite compliance.

## Physical Implementation & Timing Closure
A primary goal of this architecture was optimizing for maximum clock frequency (Fmax) rather than zero-latency combinational routing, mimicking the pipelined interconnects found in modern data center ASICs and GPUs.

By introducing **Skid Buffers** on both the Master and Slave boundaries, the long combinational logic paths inherent to the AXI `READY` signal were broken. 

**Implementation Results (AMD Xilinx Artix-7 `xc7a35tcpg236-1`):**
* **Target Constraint:** 5.6 ns 
* **Worst Negative Slack (WNS):** +0.000 ns
* **Achieved Fmax:** **178.57 MHz**
* **Optimization Strategy:** Synthesized out-of-context, followed by an automated Tcl loop (`sweep.tcl`) executing `phys_opt_design -directive AggressiveExplore` to map and route logic at the physical limits of the silicon.

## Verification Strategy
The testbench utilizes a latency-aware, non-blocking architecture to handle the pipelined nature of the skid buffers. 

To ensure the crossbar never violates bus protocols under heavy contention, **SystemVerilog Assertions (SVA)** are bound to the interfaces during simulation. These assertions continuously monitor for illegal states, such as:
* `VALID` signals dropping before a corresponding `READY` is received.
* Transaction instability during active handshakes.
* Deadlocked FSM states.
