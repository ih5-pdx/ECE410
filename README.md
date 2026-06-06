# ECE 410/510 — Hardware for AI and ML, Spring 2026
## Matrix Multiplication Co-Processor Chiplet

**Author:** Ivan Herrera | Portland State University

---

## Milestone 4 Submission

**→ [project/m4/](project/m4/)** — all M4 deliverables  
**→ [project/m4/report/design_justification.pdf](project/m4/report/design_justification.pdf)** — 9-section design justification report

The M4 folder contains the complete final submission: synthesizable RTL, end-to-end testbench with simulation log, Yosys synthesis reports, hardware vs. software benchmark comparison, final roofline plot, and the design justification report. See `project/m4/README.md` for a one-line description of every file.

---

## Project Summary

This project builds a custom hardware chiplet that accelerates dense matrix multiplication (GEMM) for transformer inference workloads. The accelerator uses INT8×INT8→INT32 arithmetic and an AXI4-Lite host interface, targeting the SkyWater sky130 130nm ASIC process at 100 MHz.

**Measured results (M4, simulation):**
- N=8 dot product: 90 ns latency (vs. 1,121 ns software) — **12.5× speedup**
- Throughput: 177.8 MFLOP/s (simulation-measured)
- Synthesis: 2,097 cells, 0 problems, estimated WNS +3.2 ns

---

## Repository Structure

```
project/
├── heilmeier.md          ← Project framing (Heilmeier Catechism)
├── m1/                   ← Software baseline, interface selection, roofline
├── m2/                   ← RTL (compute_core, axi_slave), unit testbenches, precision analysis
├── m3/                   ← top.sv integration, co-simulation, Yosys synthesis
└── m4/                   ← FINAL: RTL, tb, sim, synth, bench, report
codefest/                 ← Weekly codefest deliverables (cf01–cf09)
```

---

## Git Tag

The graded commit is tagged `m4-submission`.
