# Software Baseline Benchmark

## Purpose
The software baseline for this project measures the performance of matrix multiplication used in transformer inference before any custom hardware acceleration is added. This baseline will be used later to compare against the chiplet implementation and calculate speedup.

## Target Operation
The selected operation is matrix multiplication in a transformer-style linear layer:

\[
Y = XW
\]

where:
- \(X\) is the input activation matrix
- \(W\) is the weight matrix
- \(Y\) is the output matrix

This operation was chosen because matrix multiplication is one of the dominant computational kernels in transformer inference.

## Baseline Implementation
The software baseline will be implemented in Python using PyTorch on the host processor. The benchmark will run the same matrix multiplication multiple times and record execution time over at least 10 runs.

Example dimensions used for the baseline:
- Batch size = 1
- Sequence length = 128
- Input dimension = 256
- Output dimension = 256

So:
- \(X \in \mathbb{R}^{128 \times 256}\)
- \(W \in \mathbb{R}^{256 \times 256}\)
- \(Y \in \mathbb{R}^{128 \times 256}\)

## Benchmark Method
The baseline timing will be collected using a profiler or repeated timing loop. Average runtime, minimum runtime, and maximum runtime will be recorded. This establishes a reference point for the unaccelerated version of the target kernel.

## Why This Baseline Matters
This benchmark provides the reference performance of the host-only implementation. Later milestones will compare the chiplet design against this software baseline to determine whether the custom hardware improves throughput or latency.

## Expected Limitation
The software approach performs the full matrix multiplication on a general-purpose processor. Although optimized libraries can help, the processor is still not specialized for this repeated multiply-and-accumulate workload. This makes matrix multiplication a strong candidate for hardware acceleration.
