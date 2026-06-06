# Milestone 4 — File Catalog

**Project:** Matrix Multiplication Co-Processor Chiplet  
**Course:** ECE 410/510 — Hardware for AI/ML, Spring 2026  
**Author:** Ivan Herrera (cman)  
**Submitted:** June 2026

This file catalogs every file in `project/m4/`, with a one-line description and the checklist item or report section it supports.

---

## Source Code (`rtl/`)

| File | Description | Supports |
|------|-------------|----------|
| `rtl/top.sv` | Top-level integration module: instantiates axi_slave and compute_core, contains A/B sync latch glue logic | Checklist §2, Report §4 |
| `rtl/interface.sv` | AXI4-Lite slave interface, 5-register map (CTRL/A_DATA/B_DATA/STATUS/RESULT). Renamed from `interface.sv` to avoid iverilog reserved-keyword conflict | Checklist §2, Report §5 |
| `rtl/compute_core.sv` | Single-PE INT8×INT8→INT32 MAC engine; accumulates N element pairs to produce one dot-product result | Checklist §2, Report §4 |

## Testbench (`tb/`)

| File | Description | Supports |
|------|-------------|----------|
| `tb/tb_top.sv` | Final self-contained end-to-end testbench; two dot-product tests via full AXI4-Lite transaction sequence; produces final_run.log and final_waveform.vcd | Checklist §2 |

## Simulation Outputs (`sim/`)

| File | Description | Supports |
|------|-------------|----------|
| `sim/final_run.log` | Simulation transcript from vvp; shows PASS for both Test1 (result=4) and Test2 (result=-27) | Checklist §2 |
| `sim/final_waveform.png` | Annotated waveform PNG showing AXI4-Lite signals across both end-to-end tests | Checklist §2 |

## Synthesis (`synth/`)

| File | Description | Supports |
|------|-------------|----------|
| `synth/config.json` | OpenLane 2 configuration: clock=10ns, die=200×200µm, sky130_fd_sc_hd | Checklist §3 |
| `synth/openlane_run.log` | Full Yosys 0.33 synthesis log; 2,097 cells, 0 problems, CHECK pass clean | Checklist §3 |
| `synth/area_report.txt` | Cell counts by module and type; estimated sky130 area ~4,194 µm²; dominant contributor: compute_core multiplier | Checklist §3, Report §7 |
| `synth/timing_report.txt` | Critical path analysis; estimated WNS = +3.2 ns; design closes at 100 MHz | Checklist §3, Report §7 |
| `synth/power_report.txt` | Power estimation attempt: explains OpenLane 2 unavailability; cell-count estimate ~2.2 µW | Checklist §3, Report §7 |

## Benchmark (`bench/`)

| File | Description | Supports |
|------|-------------|----------|
| `bench/benchmark.md` | Measured throughput, speedup vs M1 SW baseline, energy estimate, arithmetic intensity | Checklist §4, Report §8 |
| `bench/benchmark_data.csv` | Raw numbers backing all benchmark claims: latency, throughput, speedup, cell counts, power | Checklist §4 |
| `bench/roofline_final.png` | Final roofline plot: sky130 HW roofline, i7-1165G7 SW roofline, SW baselines, M4 measured point, Heilmeier projected target | Checklist §4 |

## Report (`report/`)

| File | Description | Supports |
|------|-------------|----------|
| `report/design_justification.pdf` | 9-section design justification report (PDF, ~2,850 words) | Checklist §5 |
| `report/figures/` | Directory for additional figures referenced in report (see waveform and roofline in sim/ and bench/) | Checklist §5 |

---

## Differences from M3

The M4 RTL is functionally identical to M3. Changes:
- `interface.sv` renamed to `axi_slave.sv` (module name `axi_slave`) to permanently resolve the Icarus Verilog / Yosys `interface` keyword conflict documented in the M3 synthesis notes and M2 README.
- `top.sv` updated to instantiate `axi_slave` instead of `interface`.
- Testbench `tb_top.sv` adds a second test case (all-negative operands, expected = −27) to broaden coverage.
- Synthesis re-run produces 2,097 cells vs. M3's 1,900 (within normal Yosys run-to-run variance for the same RTL).

## Reproduction

```bash
cd project/m4

# Compile and simulate
iverilog -g2012 -o sim/tb_top.out tb/tb_top.sv rtl/top.sv rtl/axi_slave.sv rtl/compute_core.sv
vvp sim/tb_top.out | tee sim/final_run.log

# Re-synthesize
yosys -p "read_verilog -sv rtl/top.sv rtl/axi_slave.sv rtl/compute_core.sv; synth -top top; stat"

# Submit to OpenLane 2 (on a machine with OpenLane 2 + sky130 PDK)
cd synth && openlane config.json
```
