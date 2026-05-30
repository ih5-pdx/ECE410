# CF09 — Arithmetic Intensity Analysis
## Matrix Multiplication Co-Processor Chiplet (ECE 410/510, S2026)

**Author:** cman | **Target PDK:** SkyWater sky130 (ASIC)

---

## 1. Dominant Kernel Identification

**Kernel:** Signed integer dot-product (INT8 × INT8 → INT32 accumulation)

This is the innermost MAC loop inside `compute_core.sv`: one row of matrix A
dotted with one column of matrix B, producing one output element of C.

### Dimensions and Data Types (M2 Operating Point)

| Parameter | Value | Notes |
|-----------|-------|-------|
| Matrix dimension N | 8 (MAX_DIM) | Square NxN matrices |
| Input type (A, B) | INT8 — signed 8-bit | 1 byte per element |
| Accumulator type | INT32 — signed 32-bit | 4 bytes per element |
| Kernel invocation | One dot-product of length N | Produces one C[i][j] |
| Full matrix multiply | N² dot-products | Produces all of C |

The kernel matches the **GEMM-style weight-reuse pattern**: weights (B) are
stationary in a weight-stationary dataflow (cf. CF05 systolic trace), while
input activations (A) stream through. Weight reuse is therefore the primary
data-movement optimization axis.

---

## 2. FLOPs Count — One Full N×N Matrix Multiply

One dot-product of length N requires:
- N multiplications
- N additions (accumulation)
- → **2N MAC operations = 2N FLOPs** per output element

For the full N×N output (N² elements):

```
FLOPs = 2 × N × N² = 2 × N³

At N = 8:
FLOPs = 2 × 8³ = 2 × 512 = 1,024 FLOPs
```

> The factor of 2 is exact: each multiply-accumulate counts as 1 multiply + 1 add = 2 FLOPs, consistent with the standard FLOPs = 2·M·N·K formula for GEMM with M=N=K=N.

---

## 3. Bytes Transferred from Off-Chip Memory

### Matrix sizes at N = 8

| Matrix | Elements | Bytes (INT8 inputs) | Bytes (INT32 output) |
|--------|----------|---------------------|----------------------|
| A      | N² = 64  | 64 × 1 = **64 B**   | —                    |
| B      | N² = 64  | 64 × 1 = **64 B**   | —                    |
| C      | N² = 64  | —                   | 64 × 4 = **256 B**   |

### Case 1 — No Data Reuse (Lower Bound on AI)

In the naive case, every element of A and B is fetched from off-chip memory
on every access. For one output element C[i][j], the kernel reads:
- N elements of A (one row): N × 1 byte
- N elements of B (one column): N × 1 byte

For all N² output elements:
```
Bytes_A_naive = N² × N × 1 byte  = N³ bytes
Bytes_B_naive = N² × N × 1 byte  = N³ bytes
Bytes_C_write = N² × 4 bytes

Total_naive = 2·N³ + 4·N² bytes

At N = 8:
Bytes_A = 512 B
Bytes_B = 512 B
Bytes_C = 256 B
Total_naive = 512 + 512 + 256 = 1,280 bytes
```

**Formula:** `Total_naive = 2·N³·sizeof(int8) + N²·sizeof(int32)`
              `= 2·N³·1 + N²·4 = 2N³ + 4N²`

### Case 2 — Perfect On-Chip Weight Reuse (Upper Bound on AI)

In weight-stationary dataflow (the M3 target systolic array design), the
weight matrix B is preloaded into PE registers once and never re-fetched.
Each element of B is reused N times (once per input row). Each element of A
is loaded once and reused N times (once per output column). Only one load
each of A and B, plus one store of C:

```
Bytes_A_reuse = N² × 1 byte           (loaded once, reused across N output cols)
Bytes_B_reuse = N² × 1 byte           (preloaded once, stationary in PEs)
Bytes_C_write = N² × 4 bytes

Total_reuse = 2·N²·sizeof(int8) + N²·sizeof(int32)
            = 2·N²·1 + N²·4
            = 6·N² bytes

At N = 8:
Bytes_A = 64 B
Bytes_B = 64 B
Bytes_C = 256 B
Total_reuse = 64 + 64 + 256 = 384 bytes
```

**Formula:** `Total_reuse = 2·N²·sizeof(int8) + N²·sizeof(int32) = 6·N²`

**Reuse pattern:** GEMM weight-stationary — B matrix is loaded once into
on-chip PE storage and reused across all N input rows. A is streamed once per
output column (reused N times across the N output rows). This matches the CF05
systolic trace exactly, where each B[r][c] weight stays in its PE for the full
computation.

---

## 4. Arithmetic Intensity — Both Bounds

### AI Lower Bound (no reuse)

```
AI_low = FLOPs / Total_naive
       = 1,024 / 1,280
       = 0.800 FLOP/byte
```

### AI Upper Bound (perfect weight reuse)

```
AI_high = FLOPs / Total_reuse
        = 1,024 / 384
        = 2.667 FLOP/byte
```

### Summary

| Case | FLOPs | Bytes | AI (FLOP/byte) |
|------|-------|-------|----------------|
| No reuse (lower bound) | 1,024 | 1,280 | **0.800** |
| Perfect reuse (upper bound) | 1,024 | 384 | **2.667** |

> **Note on small N:** Both AI values are low because N=8 is a very small
> problem. For the M3 target (N=512), AI_high = 2·N³ / (6·N²) = N/3 ≈ 170.7
> FLOP/byte — firmly compute-bound. The M2 single-PE baseline is inherently
> memory-access-bound at N=8; this is expected and documented in the M2 README.

---

## 5. Target Platform Roofline Parameters

### sky130 PDK Nominal Figures (ASIC target)

The design targets synthesis via OpenLane 2 on the SkyWater sky130 130 nm
process. The following nominal figures are used for the roofline:

| Parameter | sky130 Value | Notes |
|-----------|-------------|-------|
| Clock frequency | 100 MHz (nominal) | Achievable for simple integer datapaths at 130 nm |
| Peak INT8 MAC throughput | 1 MAC/cycle × 1 PE = **100 MMAC/s = 200 MFLOP/s** | M2 single-PE |
| On-chip SRAM bandwidth | ~3.2 GB/s | sky130 SRAM at 100 MHz, 32-bit port |
| Off-chip interface bandwidth | AXI4-Lite @ 100 MHz, 32-bit ≈ **0.4 GB/s** | Current M2 implementation |

**Ridge point (off-chip interface):**
```
Ridge = Peak_FLOPS / BW_interface
      = 200 MFLOP/s / 0.4 GB/s
      = 0.5 FLOP/byte
```

**Ridge point (on-chip SRAM):**
```
Ridge_SRAM = 200 MFLOP/s / 3,200 MB/s
           = 0.0625 FLOP/byte
```

See `cman_roofline_sketch.png` for the annotated roofline diagram.

---

## 6. Bottleneck Identification

### Current M2 Bottleneck: **Off-Chip Interface Bandwidth**

The M2 design uses AXI4-Lite for data transfer — a single-beat (non-burst)
32-bit interface at 100 MHz. This provides approximately 0.4 GB/s of effective
throughput.

Comparing AI to ridge points:

| Bound | AI (FLOP/byte) | Interface Ridge (0.5) | SRAM Ridge (0.0625) | Region |
|-------|---------------|----------------------|---------------------|--------|
| No reuse | 0.800 | Above | Above | Compute-bound vs interface |
| Perfect reuse | 2.667 | Above | Above | Compute-bound vs interface |

Both AI bounds sit above the AXI4-Lite ridge point (0.5 FLOP/byte), which
means **the interface is not the bottleneck given sufficient reuse**. However,
the no-reuse AI of 0.800 is only marginally above the ridge, and at N=8 the
problem is so small that **startup overhead and interface transaction latency
dominate** — the interface effectively becomes the bottleneck in practice.

For the M3 512×512 target (AI_high ≈ 170 FLOP/byte), the design will be
firmly **compute-bound** — the single PE cannot deliver enough MACs/second.

**Root cause at M2:** single-PE compute throughput (200 MFLOP/s) is far too
low for any meaningful application. The design is currently
bottlenecked by **compute unit count (single PE)**, not memory bandwidth.

### Highest-Leverage Improvement

**Scale to a multi-PE systolic array (the M3 plan).**

Specifically:
- A 16×16 systolic array on sky130 at 100 MHz delivers 16² × 2 × 100M
  = **51.2 GFLOP/s**, a 256× improvement over the single-PE baseline.
- At N=512, this achieves AI_high ≈ 170 FLOP/byte against a compute ridge
  of Peak_FLOPS / SRAM_BW = 51.2 GFLOP/s / 3.2 GB/s = **16 FLOP/byte**,
  placing the 512×512 kernel solidly in the **compute-bound** region.
- The AXI4 burst interface (not AXI4-Lite) selected in M1
  (12.8 GB/s @ 32-bit, 400 MHz) provides sufficient bandwidth to feed the
  systolic array: ridge_AXI4 = 51.2 GFLOP/s / 12.8 GB/s = 4 FLOP/byte,
  well below AI_high.

The single highest-leverage change at this point is therefore:
> **Implement the M3 systolic PE array** (tile the compute_core to N_PE × N_PE
> PEs sharing an on-chip SRAM tile buffer), replacing the sequential single-PE
> design with a parallel array that delivers throughput proportional to N_PE².

---

## Appendix — Scaling Summary

| N | FLOPs | AI_low | AI_high | Bottleneck (1-PE, sky130) |
|---|-------|--------|---------|--------------------------|
| 8 | 1,024 | 0.800 | 2.667 | Compute (too few PEs) |
| 32 | 65,536 | 3.2 | 10.67 | Compute |
| 512 | 268 M | 51.2 | 170.7 | Compute (well above ridge) |

*All AI values in FLOP/byte. Ridge point (AXI4-Lite interface) = 0.5 FLOP/byte.*
*Ridge point (SRAM) = 0.0625 FLOP/byte. Ridge point (AXI4 burst, M3) = 4 FLOP/byte.*
