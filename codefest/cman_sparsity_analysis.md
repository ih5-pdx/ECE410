# CMAN CF07 — Sparsity Analysis: Dense vs CSR Matrix-Vector Multiply

**Parameters:** N = 512, sparsity s (fraction of zeros), FP32 weights (4 bytes/element), INT32 indices (4 bytes each)

---

## Task 1 — Expressions for Dense and Sparse MVM

### (a) Dense MVM — Compute (FLOPs)

Each output element y[i] = Σ_j W[i,j] · x[j] requires N multiply-accumulate operations.
With N output elements:

```
FLOPs_dense = 2 · N²
            = 2 · 512²
            = 524,288 FLOPs
```

*(Factor of 2: one multiply + one add per MAC)*

### (b) Dense MVM — Memory Bytes

The weight matrix W has N² elements at 4 bytes each. (Input vector x and output y are
N elements each and negligible relative to N² for large N; the problem statement counts
only weight loads for dense, matching the N² MACs model.)

```
Bytes_dense = N² · 4
            = 512² · 4
            = 1,048,576 bytes  (1 MB)
```

### (c) Sparse MVM — Compute (FLOPs)

With sparsity s, the number of non-zeros is `nnz = (1 − s) · N²`. Only non-zero weights
contribute a MAC:

```
FLOPs_sparse(s) = 2 · (1 − s) · N²
```

At s = 0.9: `2 · 0.1 · 262,144 = 52,429 FLOPs`

### (d) Sparse MVM — Memory Bytes (CSR format)

CSR storage requires three arrays:

| Array        | Size              | Bytes/entry | Total bytes          |
|--------------|-------------------|-------------|----------------------|
| values       | nnz = (1−s)·N²   | 4 (FP32)    | 4·(1−s)·N²          |
| col_indices  | nnz = (1−s)·N²   | 4 (INT32)   | 4·(1−s)·N²          |
| row_pointers | N+1               | 4 (INT32)   | 4·(N+1)             |

```
Bytes_sparse(s) = 4·(1−s)·N² + 4·(1−s)·N² + 4·(N+1)
                = 8·(1−s)·N² + 4·(N+1)
```

At s = 0.9, N = 512:
```
Bytes_sparse = 8 · 0.1 · 262,144 + 4 · 513
             = 209,715 + 2,052
             = 211,767 bytes
```

---

## Task 2 — FLOPs Speedup and 2× Breakeven Sparsity

The FLOPs speedup of sparse over dense is the ratio of dense FLOPs to sparse FLOPs:

```
Speedup_FLOPs(s) = FLOPs_dense / FLOPs_sparse
                 = [2·N²] / [2·(1−s)·N²]
                 = 1 / (1 − s)
```

**Setting Speedup = 2×:**

```
1 / (1 − s) = 2
1 − s = 1/2
s = 0.5
```

**At s = 50% sparsity, sparse MVM performs exactly 2× fewer FLOPs than dense.**

This makes intuitive sense: at 50% sparsity, exactly half the weights are zero and half
the MACs are skipped, halving the compute workload.

---

## Task 3 — Memory Breakeven Sparsity

Find s such that `Bytes_sparse(s) = Bytes_dense`:

```
8·(1−s)·N² + 4·(N+1)  =  4·N²
```

Subtract `4·(N+1)` from both sides:

```
8·(1−s)·N²  =  4·N² − 4·(N+1)
             =  4·(N² − N − 1)
```

Divide both sides by `8·N²`:

```
1−s  =  [4·(N² − N − 1)] / (8·N²)
      =  (N² − N − 1) / (2·N²)
```

Therefore:

```
s_breakeven  =  1 − (N² − N − 1) / (2·N²)
              =  [2·N² − N² + N + 1] / (2·N²)
              =  (N² + N + 1) / (2·N²)
```

**At N = 512:**

```
s_breakeven = (512² + 512 + 1) / (2 · 512²)
            = (262,144 + 512 + 1) / 524,288
            = 262,657 / 524,288
            ≈ 0.5010  (50.10%)
```

**Verification:**
```
Bytes_sparse at s = 0.5010:
  8 · (1 − 0.5010) · 262,144 + 4 · 513
  = 8 · 0.499 · 262,144 + 2,052
  ≈ 1,046,524 + 2,052 ≈ 1,048,576  ✓  (= Bytes_dense)
```

**Interpretation:** For N = 512, the CSR row pointer array costs only 4·513 = 2,052 bytes
of overhead, which is negligible (0.2%) relative to the 1 MB weight matrix. As a result,
the memory breakeven is barely above 50% — just 0.1% above the FLOPs breakeven. For large
N the overhead term `4·(N+1)` vanishes relative to `8·(1−s)·N²`, and both breakevens
converge to exactly s = 0.5.

---

## Task 4 — End-to-End Speedup at s = 0.9 (Memory-Bandwidth-Limited)

**Given:** s = 0.9, N = 512, BW = 320 GB/s, hardware perfectly skips zero MACs and
their memory loads.

### Memory traffic at s = 0.9

| Format | Bytes loaded | Calculation |
|--------|-------------|-------------|
| Dense  | 1,048,576   | N² · 4 = 262,144 · 4 |
| Sparse | 211,767     | 8·(1−0.9)·262,144 + 4·513 = 209,715 + 2,052 |

### Execution times (memory-bound model: T = Bytes / BW)

```
T_dense  = 1,048,576 bytes / (320 × 10⁹ bytes/s)  =  3.277 µs

T_sparse =   211,767 bytes / (320 × 10⁹ bytes/s)  =  0.662 µs
```

### End-to-end speedup

```
Speedup = T_dense / T_sparse
        = Bytes_dense / Bytes_sparse
        = 1,048,576 / 211,767
        ≈ 4.95×
```

### Why not 10× despite 90% sparsity?

The naive expectation at s = 0.9 would be a 10× speedup (1/(1-s)), but the actual
memory speedup is only ~5×. This gap arises from the CSR index overhead: each non-zero
weight requires an additional 4-byte column index, doubling the per-non-zero memory
footprint from 4 bytes (dense) to 8 bytes (values + col_idx). The row pointer array
adds a small fixed cost of 4·(N+1) = 2,052 bytes.

**Accounting for index overhead:**

```
Sparse bytes per nnz = 4 (value) + 4 (col_idx) = 8 bytes
Dense  bytes per nnz = 4 bytes

Index overhead factor = 2×
Effective memory reduction = (1−s) · 2 / 1  (relative to dense)

Speedup ≈ 1 / [2·(1−s)]  (ignoring row_ptr term)
        = 1 / (2 · 0.1)
        = 5×
```

This confirms the ~4.95× result: **CSR index overhead halves the memory reduction benefit**,
so a 10× sparse FLOPs reduction translates to only a ~5× memory bandwidth reduction for
a memory-bandwidth-limited MVM.

### Summary table

| Metric                    | Dense       | Sparse (s=0.9) |
|---------------------------|-------------|----------------|
| FLOPs                     | 524,288     | 52,429 (10× less) |
| Memory bytes (weight data)| 1,048,576 B | 211,767 B      |
| Execution time @ 320 GB/s | 3.277 µs    | 0.662 µs       |
| Speedup (FLOPs)           | —           | **10.0×**      |
| Speedup (memory/time)     | —           | **4.95×**      |

---

## Summary of All Expressions

| Quantity | Expression | Value at N=512, s=0.9 |
|---|---|---|
| Dense FLOPs | `2·N²` | 524,288 |
| Dense memory | `4·N²` bytes | 1,048,576 B |
| Sparse FLOPs | `2·(1−s)·N²` | 52,429 |
| Sparse memory | `8·(1−s)·N² + 4·(N+1)` bytes | 211,767 B |
| FLOPs speedup | `1/(1−s)` | 10.0× |
| s for 2× FLOPs speedup | `s = 0.5` | — |
| Memory breakeven sparsity | `s = (N²+N+1)/(2·N²)` | 0.5010 |
| Memory speedup at s=0.9 | `4·N² / [8·(1−s)·N²+4·(N+1)]` | **4.95×** |

---

*Analysis by: cman | N=512, CSR format, FP32 weights, INT32 indices, 320 GB/s bandwidth*
