# M4 Benchmark Report
**Project:** Matrix Multiplication Co-Processor Chiplet (ECE 410/510, S2026)
**Date:** 2026-06-06 | **Author:** cman

---

## Methodology

### Software Baseline (M1 reference)
Profiled in M1 (`project/m1/sw_baseline.md`): PyTorch `torch.matmul` on Intel Core
i7-1165G7, Ubuntu 22.04, Python 3.10, FP32, matrix dims X:128×256, W:256×256.
- Median runtime: 0.38 ms
- Throughput: 44.2 GFLOPS (FP32 GEMM)

For the INT8 apples-to-apples comparison (matching M4 accelerator precision),
re-measured in CF09 using NumPy INT8→INT32 dot-product:
- N=8 latency: 1,121 ns
- N=8 throughput: 14.27 MFLOP/s

### Hardware Accelerator (simulation-measured)
Cycle-accurate RTL simulation via Icarus Verilog 12 (`iverilog -g2012`).
DUT: `compute_core.sv` (M4 RTL, unchanged from M2/M3 verified version).
Clock: **100 MHz** (10 ns period, sky130 target).
Measurement: clock cycles from `start` assertion to `result_valid` pulse.
All HW numbers are **simulation-measured** at the behavioral-RTL level.

| Configuration | Clock cycles | Latency (ns) | FLOPs | Throughput |
|---------------|-------------|--------------|-------|------------|
| N=4 dot product | 5 cycles | 50 ns | 8 FLOP | 160.0 MFLOP/s |
| N=8 dot product | 9 cycles | 90 ns | 16 FLOP | 177.8 MFLOP/s |
| 4×4 matmul (16 dot products, N=4) | 95 cycles | 950 ns | 128 FLOP | 134.7 MFLOP/s |
| 8×8 matmul (64 dot products, N=8) | 639 cycles | 6,390 ns | 1,024 FLOP | 160.3 MFLOP/s |

Cycle count derivation: N cycles per dot product (one MAC per cycle, pipelined through
the AXI slave → glue → compute_core path). N=4 → 5 cycles (1 overhead for start
latency); N=8 → 9 cycles. Verified in M3 co-simulation log (`project/m3/sim/cosim_run.log`)
and confirmed in M4 final simulation (`project/m4/sim/final_run.log`).

---

## Speedup vs M1 Software Baseline

### INT8 kernel comparison (apples-to-apples)

| Metric | SW Baseline (INT8, N=8) | HW Accelerator (INT8, N=8) | Speedup |
|--------|------------------------|---------------------------|---------|
| Latency | 1,121 ns | 90 ns (simulation-measured) | **12.5×** |
| Throughput | 14.27 MFLOP/s | 177.8 MFLOP/s (simulation-measured) | **12.5×** |

### FP32 GEMM vs INT8 HW note
The M1 FP32 GEMM baseline (44.2 GFLOPS) uses BLAS/LAPACK with SIMD and operates on
much larger matrices (128×256 @ 256×256). Comparing this directly to the single-PE
INT8 accelerator (160–178 MFLOP/s) would be misleading: the accelerator targets
small INT8 dot products, not large FP32 GEMM. The correct comparison is INT8
SW baseline vs INT8 HW accelerator, giving 12.5× speedup.

For reference: the single-PE M4 design achieves ~160–178 MFLOP/s, which is 248–277×
below the M1 FP32 GEMM baseline. This gap is expected and documented — the M4
design is a single-PE baseline, not the multi-PE systolic array (55–65 GFLOPS target)
described in Heilmeier Q3. The systolic array target was deferred (see `What did not
work` section of the design justification report).

---

## Energy Comparison (estimated)

| Metric | SW Baseline | HW Accelerator |
|--------|-------------|----------------|
| Estimated power | ~3–6 W (i7-1165G7 at load) | ~2.2 µW (estimated, see power_report.txt) |
| Energy per N=8 dot product | ~3W × 1,121 ns ≈ **3.4 µJ** | ~2.2 µW × 90 ns ≈ **0.0002 nJ** |
| Energy ratio | 1× (baseline) | **~17,000× lower** (estimated) |

Note: HW energy estimate is based on Yosys cell-count power model without routing
parasitics. A routed sky130 design would likely be 2–3× higher. Even at 10× the
estimated power (~22 µW), the accelerator would be ~1,700× more energy-efficient than
the CPU for this kernel. These are order-of-magnitude estimates, not measurements.

---

## Arithmetic Intensity of M4 Accelerator

For the N=8 dot product:
- FLOPs: 2×N = 16 (8 multiplies + 7 adds + 1 final add)
- Bytes transferred (AXI4-Lite, N pairs at 4 bytes each direction):
  - 2×N writes × 4 bytes = 64 bytes input, 4 bytes output = 68 bytes total
- Arithmetic intensity: 16 FLOP / 68 bytes ≈ **0.24 FLOP/byte**

This places the single-PE accelerator firmly in the **memory-bound** region of the
roofline (AXI4-Lite single-beat transfers dominate over compute). The compute_core
itself operates at N FLOP/(2 bytes register read) ≈ 4 FLOP/byte when fed at full rate,
but the AXI interface bottleneck limits system-level arithmetic intensity to ~0.24.

See `roofline_final.png` for the final roofline plot showing this operating point.
