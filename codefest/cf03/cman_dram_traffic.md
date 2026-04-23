# DRAM Traffic Analysis: FP32 Matrix Multiply (N=32)

**Parameters:** N = 32, FP32 (4 bytes/element), T = 8 (tile size)

---

## Task 1 — Naive Triple Loop (ijk order)

### Accesses per output element C[i][j]

To compute one element `C[i][j] = Σ_k A[i][k] × B[k][j]` over k = 0..N-1:

| Matrix | Accesses per C[i][j] | Reason |
|--------|----------------------|--------|
| A      | N = 32               | One full row of A (stride-1, cache-friendly) |
| B      | N = 32               | One full column of B (stride-N, **cache-hostile**) |

**Each element of B[k][j]** is accessed once per output element in the same column j.  
Across all N output rows that share the same j, each B[k][j] is accessed **N = 32 times**.

### Total accesses across full N×N output

There are N² = 1024 output elements. Each requires N reads from A and N reads from B:

```
Total A accesses = N² × N = N³ = 32³ = 32,768
Total B accesses = N² × N = N³ = 32³ = 32,768
Total element accesses = 2 × N³ = 65,536
```

### Total DRAM traffic (assuming zero reuse — every access hits DRAM)

```
Traffic_naive = 2 × N³ × 4 bytes
             = 2 × 32,768 × 4
             = 262,144 bytes
             = 256 KB
```

---

## Task 2 — Tiled Loop (Tile Size T = 8)

### Structure of the tiled computation

The N×N matrices are divided into (N/T)² = (32/8)² = **16 tiles** per matrix.

The triple loop over tiles iterates over:
- (N/T) = 4 tile-rows of C
- (N/T) = 4 tile-columns of C
- (N/T) = 4 tiles along the K dimension

For each output tile C[I][J], the algorithm accumulates contributions from K = 4 A-tiles and 4 B-tiles.

### DRAM loads per tile

Each tile is T×T = 64 elements × 4 bytes = **256 bytes**.

| Matrix | Loads per output tile C[I][J] | Total tile loads |
|--------|-------------------------------|-----------------|
| A      | N/T = 4  (one A-row-strip)    | (N/T)² × (N/T) = (N/T)³ = 4³ = **64** |
| B      | N/T = 4  (one B-col-strip)    | (N/T)² × (N/T) = (N/T)³ = 4³ = **64** |

Total tile loads for A and B = 64 + 64 = **128 tile loads**.

### Total DRAM traffic

```
Traffic_tiled = 2 × (N/T)³ × T² × 4 bytes
             = 2 × 64 × 64 × 4
             = 32,768 bytes
             = 32 KB
```

Alternatively: each of the N² elements in A and B is loaded exactly **(N/T) = 4 times** (once per tile pass through K), so:

```
Traffic_tiled = 2 × N² × (N/T) × 4 bytes = 2 × 1024 × 4 × 4 = 32,768 bytes ✓
```

---

## Task 3 — Traffic Ratio

```
Ratio = Traffic_naive / Traffic_tiled
      = 262,144 / 32,768
      = 8
      = N / T
      = 32 / 8
```

Wait — let's re-examine carefully using general formulas:

| Scheme | DRAM traffic formula          | Value (bytes) |
|--------|-------------------------------|---------------|
| Naive  | 2 · N³ · 4                    | 262,144       |
| Tiled  | 2 · N² · (N/T) · 4           | 32,768        |

```
Ratio = (2 · N³ · 4) / (2 · N² · (N/T) · 4) = N / (N/T) = T = 8
```

**The ratio equals T (the tile size), not N.**

More precisely: tiling reduces the number of times each element is reloaded from N (naive) to N/T (tiled), a factor-of-T improvement. Each element in A and B is accessed N times in the naive case but only N/T times in the tiled case because the T×T tile fits in cache and is reused T times across the T rows (or columns) of the output tile before being evicted.

> **One-sentence explanation:** The ratio equals T = 8 because tiling amortizes each loaded data tile across T output rows (or columns) within a cache-resident block, reducing each element's reload count from N to N/T and thus cutting total DRAM traffic by a factor of T.

---

## Task 4 — Execution Time and Bottleneck Analysis

### Hardware parameters

| Parameter | Value |
|-----------|-------|
| DRAM bandwidth | 320 GB/s |
| Peak compute | 10 TFLOPS |
| FP32 ops per matmul | 2 · N³ = 2 · 32,768 = **65,536 FLOP** |

### Roofline thresholds

**Arithmetic intensity boundary** (ops/byte at which compute = memory):

```
I* = Peak FLOPS / Bandwidth = 10×10¹² / (320×10⁹) ≈ 31.25 FLOP/byte
```

### Naive case

```
Arithmetic intensity = 65,536 FLOP / 262,144 bytes = 0.25 FLOP/byte
```

Since 0.25 << 31.25, the naive case is **heavily memory-bound**.

```
Time_naive = Traffic / Bandwidth
           = 262,144 bytes / (320 × 10⁹ bytes/s)
           ≈ 0.819 µs
```

*(Compute time would be 65,536 FLOP / 10¹³ FLOP/s = 0.0066 µs — 124× faster than memory)*

### Tiled case

```
Arithmetic intensity = 65,536 FLOP / 32,768 bytes = 2.0 FLOP/byte
```

Since 2.0 << 31.25, the tiled case is **still memory-bound** (for this small N=32).

```
Time_tiled = Traffic / Bandwidth
           = 32,768 bytes / (320 × 10⁹ bytes/s)
           ≈ 0.102 µs
```

*(Compute time would still be 0.0066 µs — 15× faster than memory)*

> **Note:** For N=32, both cases are memory-bound because the problem is too small to saturate the compute units. Tiling provides an **8× speedup** by cutting DRAM traffic. To become compute-bound, arithmetic intensity must exceed ~31.25 FLOP/byte, which requires either much larger N or higher-level blocking (e.g., keeping entire rows/columns in L1/L2 registers).

### Summary table

| Case  | DRAM Traffic | Arith. Intensity | Bottleneck | Execution Time |
|-------|-------------|-----------------|------------|----------------|
| Naive | 256 KB      | 0.25 FLOP/byte  | **Memory** | ~0.819 µs      |
| Tiled | 32 KB       | 2.0 FLOP/byte   | **Memory** | ~0.102 µs      |

**Speedup from tiling: 8× (= tile size T)**

---

*Analysis by: cman | N=32, T=8, FP32, row-major storage*
