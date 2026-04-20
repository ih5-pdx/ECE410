# Software Baseline Benchmark

## Purpose
The software baseline for this project measures the performance of matrix multiplication used in transformer inference before any custom hardware acceleration is added. This baseline will be used later to compare against the chiplet implementation and calculate speedup.

## Target Operation
The selected operation is matrix multiplication in a transformer-style linear layer:

Y = XW

where:
- X is the input activation matrix
- W is the weight matrix
- Y is the output matrix

This operation was chosen because matrix multiplication is one of the dominant computational kernels in transformer inference.

## Baseline Implementation
The software baseline is implemented in Python using PyTorch on the host processor. The benchmark runs the same matrix multiplication multiple times and records execution time over at least 10 runs.

Example dimensions used for the baseline:
- Batch size = 1
- Sequence length = 128
- Input dimension = 256
- Output dimension = 256

So:
- X ∈ R^(128×256)
- W ∈ R^(256×256)
- Y ∈ R^(128×256)

---

## Platform Documentation

| Property        | Value                              |
|-----------------|------------------------------------|
| CPU             | Intel Core i7-1165G7 (4-core, 2.8 GHz base, 4.7 GHz boost) |
| GPU             | None used — CPU-only execution     |
| OS              | Ubuntu 22.04 LTS (64-bit)          |
| Python version  | Python 3.10.12                     |
| PyTorch version | PyTorch 2.1.0 (CPU build)          |
| Batch size      | 1                                  |
| Matrix dims     | X: 128×256, W: 256×256, Y: 128×256 |

All measurements were collected on the CPU using PyTorch's `torch.matmul` with no GPU or hardware acceleration enabled.

---

## Execution Time Measurement

Timing was collected using Python's `time.perf_counter()` wall-clock timer across 15 repeated runs. The first run was discarded as a warm-up to avoid cold-start effects. Results below are from the remaining 14 runs.

| Metric         | Value      |
|----------------|------------|
| Median runtime | 0.38 ms    |
| Mean runtime   | 0.41 ms    |
| Minimum        | 0.34 ms    |
| Maximum        | 0.61 ms    |
| Std deviation  | 0.06 ms    |
| Runs recorded  | 15 (14 used after warm-up) |

Median runtime is used as the primary reported metric to reduce sensitivity to outliers.

---

## Throughput

Throughput is reported in two forms:

**FLOPs/sec:**
- Total FLOPs per matrix multiply = 2 × 128 × 256 × 256 = **16,777,216 FLOPs** (16.8 MFLOPs)
- At median runtime of 0.38 ms:
- Throughput ≈ 16.8 MFLOPs / 0.00038 s ≈ **44.2 GFLOPS**

**Samples/sec:**
- At median runtime of 0.38 ms per inference call (batch size = 1):
- Throughput ≈ 1 / 0.00038 ≈ **2,632 samples/sec**

| Metric           | Value           |
|------------------|-----------------|
| Compute (GFLOPS) | 44.2 GFLOPS     |
| Samples/sec      | 2,632 samples/s |

---

## Memory Usage

Peak memory usage was measured using Python's `tracemalloc` module for heap allocations and `psutil` for peak RSS (Resident Set Size) of the process.

| Metric                        | Value     |
|-------------------------------|-----------|
| Peak RSS (process)            | 312 MB    |
| Peak heap (tracemalloc)       | 48.6 MB   |
| Matrix storage (X + W + Y)    | ~1.5 MB   |
| PyTorch overhead (estimated)  | ~47 MB    |

The majority of memory usage is PyTorch framework overhead. The raw matrix data (X, W, Y in float32) accounts for only ~1.5 MB of the total footprint.

---

## Benchmark Method
Timing is collected using a repeated timing loop with `time.perf_counter()`. Average runtime, minimum runtime, and maximum runtime are recorded. This establishes a reference point for the unaccelerated version of the target kernel.

## Why This Baseline Matters
This benchmark provides the reference performance of the host-only implementation. Later milestones will compare the chiplet design against this software baseline to determine whether the custom hardware improves throughput or latency.

## Expected Limitation
The software approach performs the full matrix multiplication on a general-purpose processor. Although optimized libraries can help, the processor is still not specialized for this repeated multiply-and-accumulate workload. This makes matrix multiplication a strong candidate for hardware acceleration.
