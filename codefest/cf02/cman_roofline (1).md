# Roofline Model Analysis
**Hardware:** Peak Compute = 10 TFLOPS (FP32) | Peak DRAM Bandwidth = 320 GB/s | Ridge Point = 31.25 FLOP/byte

---

## (a) Roofline Diagram

```
 Performance
 (GFLOP/s)
 (log)
 100K |
      |
  10K |. . . . . . . . . . . . . . . [RIDGE: 31.25, 10K] ●————————————————
      |                            /                  (compute ceiling)
   1K |                          /
      |                        /       ● Kernel A (GEMM)
  100 |                      /          AI ≈ 2731 FLOP/byte
      |             ● B    /            Attainable: 10,000 GFLOP/s
   10 |      Vec Add  \  /
      |    AI=0.25     /
    1 |              /  (BW slope: 320 GB/s)
      |____________/______________________________
      0.1    1     10    100   1000   FLOP/byte (log)
                              →
                   memory-bound | compute-bound
```

- **Diagonal (bandwidth-limited):** slope = 320 GFLOP/s per FLOP/byte; attainable perf = min(AI × 320, 10000) GFLOP/s
- **Flat ceiling (compute-limited):** 10,000 GFLOP/s for AI > 31.25 FLOP/byte
- **Ridge point:** (31.25 FLOP/byte, 10,000 GFLOP/s)

---

## (b) Kernel A — Dense GEMM (1024 × 1024 FP32 Matrix Multiply)

### FLOPs

For square N×N matmul:

```
FLOPs = 2 × N³
      = 2 × 1024³
      = 2 × 1,073,741,824
      = 2,147,483,648 FLOPs
      ≈ 2.147 GFLOPs
```

### Bytes Transferred (no cache reuse, all from DRAM)

Three matrices: A (input), B (input), C (output), each N×N FP32 (4 bytes/element):

```
Bytes = 3 × N² × 4 bytes
      = 3 × 1024² × 4
      = 3 × 1,048,576 × 4
      = 12,582,912 bytes
      ≈ 12.58 MB
```

### Arithmetic Intensity

```
AI = FLOPs / Bytes
   = 2,147,483,648 / 12,582,912
   ≈ 170.67 FLOP/byte
```

> **Note:** This reflects a pessimistic no-reuse model. With full cache blocking, AI approaches N/3 ≈ 341 FLOP/byte. Many analyses use 2N³/(3N²×4) = N/6 ≈ 170 FLOP/byte for the naive streaming case, which matches above.

### Analysis

| Property | Value |
|---|---|
| Arithmetic Intensity | **170.67 FLOP/byte** |
| Ridge Point | 31.25 FLOP/byte |
| Bound | **Compute-bound** (AI ≫ ridge point) |
| Attainable Performance | **10,000 GFLOP/s** (compute ceiling) |
| Actual compute time (ideal) | ≈ 0.215 ms |

### Architectural Recommendation

**Increase peak FP32 compute throughput (more CUDA cores / wider SIMD units),** because GEMM sits deep in the compute-bound region (AI ≈ 171 FLOP/byte vs ridge at 31.25); additional memory bandwidth would have zero impact on attainable performance — only raising the compute ceiling can improve throughput.

---

## (c) Kernel B — Vector Addition (N = 4,194,304 FP32 elements)

### FLOPs

Element-wise addition: 1 FLOP per element:

```
FLOPs = N × 1
      = 4,194,304 FLOPs
      ≈ 4.19 MFLOPs
```

### Bytes Transferred

Two input vectors read + one output vector written, each N elements × 4 bytes:

```
Bytes = 3 × N × 4 bytes
      = 3 × 4,194,304 × 4
      = 50,331,648 bytes
      ≈ 50.33 MB
```

### Arithmetic Intensity

```
AI = FLOPs / Bytes
   = 4,194,304 / 50,331,648
   = 1/12
   ≈ 0.0833 FLOP/byte
```

> **Simplified view:** each element costs 1 FLOP and touches 12 bytes (4 read A + 4 read B + 4 write C), so AI = 1/12 ≈ 0.0833 FLOP/byte.

### Analysis

| Property | Value |
|---|---|
| Arithmetic Intensity | **0.0833 FLOP/byte** |
| Ridge Point | 31.25 FLOP/byte |
| Bound | **Memory-bound** (AI ≪ ridge point) |
| Attainable Performance | **0.0833 × 320 = 26.67 GFLOP/s** |
| Peak compute utilization | 26.67 / 10,000 = **0.27%** |

### Architectural Recommendation

**Increase DRAM memory bandwidth (e.g., HBM instead of GDDR, or wider memory bus),** because vector addition is severely memory-bound (AI ≈ 0.083 FLOP/byte, 375× below the ridge point); no amount of additional compute units will improve throughput — only higher bandwidth can raise the attainable performance ceiling.

---

## Summary Table

| Kernel | FLOPs | Bytes | AI (FLOP/byte) | Bound | Attainable GFLOP/s | Top Recommendation |
|---|---|---|---|---|---|---|
| A — GEMM 1024³ | 2.147 G | 12.58 MB | 170.67 | Compute | 10,000 | More compute units / wider SIMD |
| B — Vec Add 4M | 4.19 M | 50.33 MB | 0.083 | Memory | 26.67 | Higher memory bandwidth (HBM) |
