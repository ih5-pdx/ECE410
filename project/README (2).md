# Milestone 3 — README
**Project:** Matrix Multiplication Co-Processor Chiplet
**Course:** ECE 410/510 — Hardware for AI/ML, Spring 2026
**Student:** Ivan Herrera

---

## File Catalog

Every file in `project/m3/` is listed below with a one-line description.

### `rtl/`
| File | Description |
|------|-------------|
| `rtl/top.sv` | Integrated top module: instantiates `interface` (AXI4-Lite slave) and `compute_core` (MAC engine), connects all inter-module signals, and contains the A/B valid-synchronisation glue latch |

_Note: `compute_core.sv` and `interface.sv` are the M2 modules located at `project/m2/rtl/`. They are compiled from that path for both simulation and synthesis; copies are not duplicated in `m3/rtl/`._

### `tb/`
| File | Description |
|------|-------------|
| `tb/tb_top.sv` | End-to-end co-simulation testbench for `top.sv`; all host traffic is exclusively via AXI4-Lite port — no direct access to compute_core or interface internals; drives 4-element dot product [3,−1,2,5]·[4,7,−3,1]=4 and prints PASS/FAIL |

### `sim/`
| File | Description |
|------|-------------|
| `sim/cosim_run.log` | Actual simulation transcript from `vvp` run showing all four phases (CTRL write, element streaming, STATUS poll, RESULT read) and the `PASS: result = 4 (expected 4)` line |
| `sim/cosim_waveform.png` | Annotated waveform showing three regions: ① host AXI write phase (CTRL + 4 element pairs), ② internal compute activity, ③ host AXI read phase (STATUS poll + RESULT read) |

### `synth/`
| File | Description |
|------|-------------|
| `synth/config.json` | OpenLane 2 configuration: design name `top`, clock period 10 ns (100 MHz), sky130A PDK library paths, die area 200×200 µm |
| `synth/openlane_run.log` | Full Yosys 0.33 synthesis stdout: RTL parse, elaboration, optimisation passes, ABC technology mapping, final stat (1,900 cells, 0 problems) |
| `synth/area_report.txt` | Area report: cell count by module (compute_core 1,653; axi_slave 190; top glue 57) and cell type, with estimated sky130 area and utilisation |
| `synth/timing_report.txt` | Timing report: critical path identification (accumulator Q → multiply → accumulate → accumulator D), estimated combinational delay 6.8 ns, estimated slack +3.2 ns at 10 ns clock |
| `synth/critical_path.md` | Critical path narrative: start register, end register, 5 logic stages, explanation of why the 32-bit ripple-carry accumulator is the bottleneck, and two specific fixes (pipeline + CLA adder) |
| `synth/power_report.txt` | Power estimation attempt: OpenLane 2 not available for full annotated power; Yosys generic estimate ~2.1 µW total (leakage + dynamic); M4 action item documented |

### Top-level M3 files
| File | Description |
|------|-------------|
| `README.md` | This file — catalogs every file in `project/m3/` and provides simulation/synthesis reproduction instructions |
| `synthesis_notes.md` | ≥500-word narrative: what synthesized, what did not, the `interface`→`axi_slave` naming issue, co-sim result, scope status, M4 outlook |

---

## How to Reproduce Co-Simulation

**Simulator:** Icarus Verilog 12.0 (`iverilog`)

**Install:**
```bash
sudo apt install iverilog   # Ubuntu 24.04
```

**Compile and run:**
```bash
# From repository root
iverilog -g2012 -o /tmp/tb_top.out \
    project/m3/tb/tb_top.sv \
    project/m3/rtl/top.sv \
    project/m2/rtl/interface.sv \
    project/m2/rtl/compute_core.sv

vvp /tmp/tb_top.out | tee project/m3/sim/cosim_run.log
```

**Note on module name:** `interface.sv` uses `module interface` which conflicts
with the SystemVerilog `interface` keyword in iverilog. For the simulation run,
apply the rename:
```bash
sed 's/^module interface /module axi_slave /' project/m2/rtl/interface.sv \
    > /tmp/interface_sim.sv

iverilog -g2012 -o /tmp/tb_top.out \
    project/m3/tb/tb_top.sv \
    project/m3/rtl/top.sv \
    /tmp/interface_sim.sv \
    project/m2/rtl/compute_core.sv
```

**Expected output (last lines of log):**
```
PASS: result = 4 (expected 4)
[TB] busy correctly deasserted
```

**View waveform (optional):**
```bash
gtkwave sim/cosim_run.vcd &
```

---

## How to Reproduce Synthesis

### Yosys (available now, produces area/cell data)

**Install:** `sudo apt install yosys`

```bash
cd project/m3/synth
yosys -p '
  read_verilog -sv ../rtl/top.sv
  read_verilog -sv ../../m2/rtl/interface_renamed.sv
  read_verilog -sv ../../m2/rtl/compute_core.sv
  hierarchy -check -top top
  synth -top top
  stat
' 2>&1 | tee openlane_run.log
```

### OpenLane 2 (full sky130 flow — requires PDK)

**Version:** OpenLane 2 ≥ v2.0.0 (https://github.com/The-OpenROAD-Project/OpenLane2)

**Prerequisites:**
```bash
# Install OpenLane 2
pip install openlane
# Install sky130A PDK
volare enable sky130A
export PDK_ROOT=~/.volare
```

**Run:**
```bash
cd project/m3/synth
openlane config.json
```

**Outputs:** `runs/<timestamp>/reports/signoff/` for timing, area, and power.

---

## M2 Paths Still Present

All M2 deliverables remain at `project/m2/` as required. M3 adds `project/m3/`
only; no M2 files were modified.

---

## Scope Note

The M3 design is a single-PE baseline (MAX_DIM=8), consistent with the M2 scope
declared in `project/m2/README.md`. The multi-PE systolic array targeting
55–65 GFLOPS is the M4 deliverable per the Heilmeier Q3 plan.
