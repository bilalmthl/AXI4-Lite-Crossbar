# AXI4-Lite Crossbar Interconnect

A parameterizable AXI4-Lite crossbar written in SystemVerilog. The design focuses on physical implementation and timing closure, using registered skid buffers to break long combinational `READY` paths. This trades one cycle of latency for a significantly higher maximum clock frequency (Fmax).

## Features
* **Configurable topology:** Parameterized `N_MASTERS` and `M_SLAVES`.
* **Round-robin arbitration:** Prevents master starvation on contested slave ports.
* **Pipelined handshaking:** Integrated skid buffers isolate timing paths between nodes.
* **Protocol verification:** Bound SystemVerilog Assertions (SVA) catch AXI protocol violations during simulation.
* **Automated timing sweep:** Custom Tcl scripts to push aggressive physical optimization and discover absolute Fmax.

## Implementation Results
Targeted for an AMD Xilinx Artix-7 (`xc7a35tcpg236-1`):
* **Achieved Fmax:** 178.57 MHz (5.6 ns period)
* **Worst Negative Slack (WNS):** +0.000 ns
* **Optimization:** Pushed using `phys_opt_design -directive AggressiveExplore`.

## Repo Structure
```text
├── rtl/
│   ├── axi_crossbar.sv      # Top-level interconnect
│   ├── axi_skid_buffer.sv   # Pipeline stages for valid/ready paths
│   ├── axi_decoder.sv       # Address decoding
│   ├── rr_arbiter.sv        # Round-robin arbiter
│   └── axi_lite_if.sv       # SV interface
├── tb/
│   └── tb_crossbar.sv       # Latency-aware testbench with SVA
├── scripts/
│   ├── build.tcl            # Synthesis and P&R
│   ├── sim.tcl              # XSim compile and run
│   └── sweep.tcl            # Fmax discovery script
└── constraints/
    └── basys3.xdc           # Physical/timing constraints