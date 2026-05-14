# Milestone 2 — Simulation Reproduction Guide

**Project:** Matrix Multiplication Co-Processor Chiplet  
**Course:** ECE 410/510 — Hardware for AI/ML, Spring 2026  
**Interface:** AXI4-Lite  
**Target flow:** OpenLane 2  

---

## Repository Layout (M2)

```
project/m2/
├── rtl/
│   ├── compute_core.sv       # Synthesizable MAC compute core
│   └── interface.sv          # AXI4-Lite slave interface
├── tb/
│   ├── tb_compute_core.sv    # Compute core testbench
│   └── tb_interface.sv       # Interface testbench
├── sim/
│   ├── compute_core_run.log  # Simulation transcript (PASS line included)
│   ├── interface_run.log     # Simulation transcript (PASS line included)
│   └── waveform.png          # Annotated waveform screenshot
├── precision.md              # Numerical format choice and error analysis
└── README.md                 # This file
```

---

## Prerequisites

| Tool | Version Tested | Install |
|------|---------------|---------|
| Icarus Verilog (`iverilog`) | 11.0 | `sudo apt install iverilog` |
| GTKWave (optional, for waveforms) | 3.3.x | `sudo apt install gtkwave` |
| Python | 3.10+ | For reference model and precision analysis |
| NumPy | 1.24+ | `pip install numpy` |

> **Alternative simulators:** The testbenches are written in standard
> SystemVerilog-2012 and should work with ModelSim (vsim), Vivado XSIM, or
> VCS. Command lines for those tools are noted in the per-testbench sections below.

---

## Running the Compute Core Testbench

### Icarus Verilog

From the repository root:

```bash
cd project/m2

# Compile
iverilog -g2012 -o sim/tb_compute_core.out \
    tb/tb_compute_core.sv \
    rtl/compute_core.sv

# Run
vvp sim/tb_compute_core.out | tee sim/compute_core_run.log
```

Expected output in `sim/compute_core_run.log`:

```
PASS: result = 4 (expected 4)
```

### Vivado XSIM (alternative)

```bash
xvlog --sv rtl/compute_core.sv tb/tb_compute_core.sv
xelab -debug typical tb_compute_core -s tb_compute_core_sim
xsim tb_compute_core_sim --runall --log sim/compute_core_run.log
```

### Test vector

The testbench computes the dot product of:

```
A = [3, -1, 2, 5]   (INT8)
B = [4,  7, -3, 1]  (INT8)
```

Expected result: `3×4 + (−1)×7 + 2×(−3) + 5×1 = 12 − 7 − 6 + 5 = 4`

This was independently verified in Python:

```python
import numpy as np
a = np.array([3, -1, 2, 5], dtype=np.int32)
b = np.array([4,  7, -3, 1], dtype=np.int32)
print(np.dot(a, b))  # => 4
```

The vector exercises the dominant kernel (multiply-accumulate with mixed-sign
operands) identified during M1 profiling.

---

## Running the Interface Testbench

### Icarus Verilog

```bash
cd project/m2

# Compile
iverilog -g2012 -o sim/tb_interface.out \
    tb/tb_interface.sv \
    rtl/interface.sv

# Run
vvp sim/tb_interface.out | tee sim/interface_run.log
```

Expected output in `sim/interface_run.log`:

```
--- Test 1: CTRL register write (DIM=4, START=1) ---
PASS: core_dim = 4 (expected 4)
--- Test 2: A_DATA and B_DATA write, RESULT read-back ---
PASS: core_a_data written correctly (3)
PASS: core_b_data written correctly (4)
PASS: STATUS.result_valid = 1 after core_result_v
PASS: RESULT register = 42 (expected 42)
PASS: All 5 checks passed.
```

### Vivado XSIM (alternative)

```bash
xvlog --sv rtl/interface.sv tb/tb_interface.sv
xelab -debug typical tb_interface -s tb_interface_sim
xsim tb_interface_sim --runall --log sim/interface_run.log
```

---

## Viewing Waveforms

Both testbenches dump VCD files to `sim/`:

```bash
# After running vvp, open with GTKWave
gtkwave sim/compute_core_run.vcd &
gtkwave sim/interface_run.vcd &
```

A pre-generated annotated waveform image is committed at `sim/waveform.png`,
showing the compute core test vector: input application (`a_data`, `b_data`,
`a_valid`, `b_valid`), internal pipeline activity (`accumulator`), and output
capture (`result`, `result_valid`).

---

## Numerical Precision

See `project/m2/precision.md` for the full numerical format rationale and
quantization error analysis. Summary: INT8 operands with INT32 accumulation.
Mean absolute quantization error measured at 0.0021 across 1,000 random 4×4
matrix pairs (well within the 0.01 acceptability threshold cited from the
INT8 transformer inference literature).

---

## Deviations from M1 Plan

**Interface:** No change to the M1 interface selection decision. AXI4 remains
the correct primary data-movement interface for the full design as documented
in `project/m1/interface_selection.md`. See the interface scope note below for
how M2 fits within that decision.

**Interface scope (M2 boundary):** M1 selected full AXI4 (with burst transfers)
as the primary data-movement interface, explicitly ruling out AXI4-Lite for bulk
matrix streaming. That decision remains correct for the M3 systolic array, which
must stream tile-sized blocks of data continuously to saturate the multi-PE
datapath. However, M2's single-PE core accepts one operand pair per cycle and has
no tile buffer — there is no burst transfer to perform. AXI4-Lite (single-beat
register writes) is therefore sufficient for M2's data rate: feeding one INT8
element to A_DATA and one to B_DATA per cycle is simply a sequence of 8-bit
register writes, well within AXI4-Lite's single-beat model. Full AXI4 burst
support will be added in M3 alongside the tile loop controller and on-chip SRAM
buffers that make burst transfers necessary.

**Numerical format:** No change. INT8 operands with INT32 accumulation was
proposed in M1 and is confirmed here with quantization error analysis in
`precision.md`.

**Compute core scope (M2 boundary):** The Heilmeier Q3 describes the eventual
target as a systolic-array-style compute core capable of accelerating 512×512
matrix multiplication, with a local SRAM scratchpad to hold working tiles and
reduce off-chip DRAM traffic. M2 does **not** yet implement the full systolic
array or tile buffers. Instead, `compute_core.sv` is a single-PE sequential
MAC engine that computes one dot-product element at a time (one row of A dotted
with one column of B), with `MAX_DIM` capped at 8 for testbench scope.

This is an intentional M2 scoping decision, not an architecture change:
- The single-PE baseline establishes correct MAC kernel behavior in
  synthesizable RTL and allows a clean PASS/FAIL testbench before the
  design scales.
- The multi-PE systolic array, tile loop controller, and on-chip SRAM
  buffers required to handle 512×512 matrices are planned for M3.
- The throughput targets from Q3 (55–65 GFLOPS) apply to the M3
  multi-PE design; M2 makes no performance claims beyond functional
  correctness of the MAC kernel.

---

## Python Dependencies (for precision analysis script)

```
numpy>=1.24
```

Install with:

```bash
pip install numpy
```

No other Python packages are required. The quantization analysis is
self-contained in the script described in `precision.md`.
