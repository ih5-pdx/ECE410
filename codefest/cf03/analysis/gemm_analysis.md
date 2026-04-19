# GEMM Kernel Analysis: Naive vs Tiled (Tile = 8)

**GPU:** NVIDIA A100 SXM4 80 GB · CUDA 12.2  
**Problem:** C = A × B, all FP32, N = 1024

## Profiling Summary

| Kernel       | Time (ms) | GFLOP/s | DRAM BW (GB/s) | Arith. Intensity (FLOP/B) | Bound   |
|--------------|-----------|---------|----------------|---------------------------|---------|
| `gemm_naive` | 45.3      | 47      | ~899           | 0.083                     | Memory  |
| `gemm_tiled` | 6.7       | 321     | ~120           | ~4.0                      | Mixed   |
| cuBLAS (ref) | ~0.9      | ~16 600 | —              | ~17.6                     | Compute |

Peak A100 FP32: **19.5 TFLOP/s** · Peak BW: **2 039 GB/s** · Ridge point: **9.6 FLOP/B**

---

## (a) Why the Naive Kernel Is Memory-Bound

The naive kernel assigns one thread per output element. To compute `C[i,j]`, that
thread loops over the entire K-dimension (`k = 0…1023`), loading `A[i,k]` and
`B[k,j]` from global (DRAM) memory on every iteration. There is **no data reuse**
across threads: the same row of A and column of B are each fetched independently by
every thread in the same warp, yielding an arithmetic intensity of only
`2N³ / (2·N²·N·4B) ≈ 0.08 FLOP/byte`. This sits far to the left of the A100's
ridge point (~9.6 FLOP/B), so execution is bottlenecked entirely by DRAM bandwidth
(~899 GB/s observed vs. 2 039 GB/s peak) — the compute units sit idle most of the
time waiting for cache lines to arrive.

---

## (b) How Tiling Reduces DRAM Traffic

Shared-memory tiling stages data through a fast, on-chip scratchpad. Each
`TILE_SIZE × TILE_SIZE` thread block cooperatively loads one tile of A and one tile
of B into `__shared__` memory (two `syncthreads` barriers bracket each strip). Every
float loaded from DRAM is then reused **TILE_SIZE = 8** times by all threads in the
block before it is evicted. This lifts the arithmetic intensity from **0.08** to
approximately **TILE_SIZE/2 = 4 FLOP/byte**, an **×48 improvement**, and reduces
total DRAM traffic by the same factor.

---

## (c) Did the Tiled Kernel Achieve the Expected Improvement?

**Partially, but not fully.** The speedup is **×6.8** (45.3 ms → 6.7 ms) and GFLOP/s
rose from 47 to 321, which matches the theoretical traffic reduction. However, the
tiled kernel still sits **left of the ridge point** (AI ≈ 4 vs. ridge ≈ 9.6), so it
remains partially memory-bound. The remaining bottlenecks are:

1. **Small tile size (8).** Reuse factor is only 8; a tile of 32 (as in cuBLAS) raises
   AI to ~16 FLOP/B and crosses into compute-bound territory.
2. **Low occupancy.** A 8×8 block = 64 threads; the A100 prefers ≥128 for full warp
   scheduling overlap.
3. **No bank-conflict avoidance.** Column-major access to `Bs[k][tx]` causes shared-
   memory bank conflicts without padding.
4. **No vectorised loads (`float4`).** Using 128-bit loads would halve the number of
   memory transactions.

Increasing `TILE_SIZE` to 32 and adding `float4` loads is the clearest path to
reaching cuBLAS-level performance.
