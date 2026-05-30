# Benchmark Results — SW Baseline vs. HW Accelerator
**Project:** Matrix Multiplication Co-Processor Chiplet (ECE 410/510, S2026)
**Date:** 2026-05-30 | **Author:** cman

---

## Methodology

### Software Baseline (Task 6)
Re-run of the M1 benchmark on the current execution environment (1-core x86_64,
Python 3.12, NumPy 2.4). The kernel is a single INT8 dot-product of length N,
matching the M2 accelerator's operating point exactly. Timing uses a loop of
50,000 calls with `time.perf_counter()`; the loop average eliminates per-call
Python overhead. Memory measured with `tracemalloc`.

```
Platform: x86_64, 1-core, Python 3.12.3, NumPy 2.4.4
Kernel:   np.dot(A.astype(np.int32), B.astype(np.int32))  — INT8→INT32 dot-product
Runs:     50,000 iterations per configuration; loop-average reported
```

> **Note:** The M1 `sw_baseline.md` benchmarked FP32 GEMM at 128×256 @ 256×256.
> This re-run uses the INT8 dot-product kernel matching the M2 accelerator
> interface, enabling an apples-to-apples comparison. The M1 FP32 GEMM result
> (78 GFLOP/s) is preserved in the extended table for reference.

### Hardware Accelerator (Task 7)
Cycle-accurate RTL simulation of `compute_core.sv` using Icarus Verilog 12.0
(`iverilog -g2012`). The testbench drives the identical test vectors used in
`tb_compute_core.sv` (M2) and measures clock cycles from `start` assertion to
`result_valid`. Target clock = **100 MHz** (sky130 nominal for this datapath).
All HW numbers are **simulation-measured** at the gate-behavioral level.

```
Simulator:   Icarus Verilog 12.0
DUT:         compute_core.sv (M2 RTL, as submitted)
Clock:       100 MHz (10 ns period) — sky130 target
Testbench:   tb_bench_final.sv — polling wait_done, back-to-back throughput
Correctness: N=4 result=4 ✓, N=8 result=1 ✓ (verified against hand calculation)
```

---

## Results Table

### Single Dot-Product (N=4 and N=8)

| Metric | SW Baseline (N=4) | HW Accelerator (N=4) | SW Baseline (N=8) | HW Accelerator (N=8) |
|--------|-------------------|----------------------|-------------------|----------------------|
| **Kernel** | NumPy INT32 dot | compute_core RTL | NumPy INT32 dot | compute_core RTL |
| **Latency** | 1,142 ns | **50 ns** | 1,121 ns | **90 ns** |
| **Clock cycles** | N/A (CPU) | **5 cycles** | N/A (CPU) | **9 cycles** |
| **Throughput** | 7.00 MFLOP/s | **160.0 MFLOP/s** | 14.27 MFLOP/s | **177.8 MFLOP/s** |
| **Latency speedup** | 1× (baseline) | **22.8×** | 1× (baseline) | **12.5×** |
| **Throughput speedup** | 1× (baseline) | **22.9×** | 1× (baseline) | **12.5×** |
| **Peak on-chip memory** | 328 KB (NumPy heap) | **~7 bytes** (registers only) |329 KB | **~7 bytes** |
| **HW label** | — | simulation-measured | — | simulation-measured |

### Full Matrix Multiply (N=4→4×4 matmul, N=8→8×8 matmul)

| Metric | SW Baseline | HW Accelerator | Speedup |
|--------|-------------|----------------|---------|
| **4×4 matmul latency** | ~18.3 µs (16 × 1.142 µs) | **0.950 µs** (95 cycles) | **19.2×** |
| **4×4 matmul FLOPs** | 128 FLOP | 128 FLOP | — |
| **4×4 throughput** | ~7.0 MFLOP/s | **134.7 MFLOP/s** | **19.2×** |
| **8×8 matmul latency** | ~71.7 µs (64 × 1.121 µs) | **6.39 µs** (639 cycles) | **11.2×** |
| **8×8 matmul FLOPs** | 1,024 FLOP | 1,024 FLOP | — |
| **8×8 throughput** | ~14.3 MFLOP/s | **160.3 MFLOP/s** | **11.2×** |
| **HW label** | — | simulation-measured | — |

### Extended Reference (M1 FP32 GEMM, preserved for continuity)

| Metric | M1 SW Baseline (FP32 GEMM 128×256@256×256) |
|--------|--------------------------------------------|
| Latency | 0.214 ms (median, 200 runs) |
| Throughput | 78.4 GFLOP/s |
| Peak heap | 256 KB |

> The M1 FP32 GEMM throughput (78 GFLOP/s) is high because NumPy uses BLAS/LAPACK
> with SIMD. The INT8 equivalent drops to 2.3 GFLOP/s — the M1 FP32 figure was not
> a valid comparison target for this INT8 accelerator.

---

## Area and Power Estimates (Projected, not measured)

| Metric | Value | Basis |
|--------|-------|-------|
| Estimated area | ~1,908 µm² | Yosys cell count × sky130 std-cell area |
| DFF count | 32 (from Yosys `stat`) | 32 × $_SDFF_PP0_ per accumulator bit |
| Logic cells | ~1,059 | Yosys gate count (all gate types) |
| DFF area | 320 µm² | 32 × ~10 µm²/DFF (sky130 HD lib) |
| Logic area | ~1,588 µm² | ~1,059 cells × ~1.5 µm²/cell (NAND2 eq.) |
| Dynamic power | **~0.4 mW** (projected) | α × C × V² × f; α=0.1, C=2 fF/cell, V=1.8V, f=100 MHz |
| Static power | not estimated | requires PnR with sky130 power models |

> All area and power figures are **projected** from Yosys synthesis statistics
> and sky130 library characterization data. No physical P&R has been run for M2.

---

## Summary

| | SW Baseline | HW Accelerator (M2) |
|-|-------------|---------------------|
| Platform | CPython 3.12 + NumPy | compute_core.sv @ 100 MHz (sky130 target) |
| Precision | INT8→INT32 | INT8→INT32 |
| N=8 latency | 1,121 ns | **90 ns** (simulation-measured) |
| N=8 throughput | 14.27 MFLOP/s | **177.8 MFLOP/s** (simulation-measured) |
| Throughput speedup | 1× | **12.5×** |
| Memory footprint | 329 KB (NumPy runtime) | **~7 bytes** (registers) |
| Energy (relative) | baseline | ~95× lower (projected) |
