// gemm_naive.cu  –  Naive 1024x1024 FP32 GEMM
// Generated with Claude (claude-sonnet-4-20250514) assistance.
// Compile: nvcc -O2 -arch=sm_80 gemm_naive.cu -o gemm_naive
//          (adjust -arch for your GPU: sm_75 for Turing, sm_86 for Ampere GA102, etc.)

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <cuda_runtime.h>

#define N 1024

// ---------------------------------------------------------------------------
// Kernel: one thread computes one output element C[row][col]
// ---------------------------------------------------------------------------
__global__ void gemm_naive(const float * __restrict__ A,
                            const float * __restrict__ B,
                            float       * __restrict__ C,
                            int n)
{
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    int row = blockIdx.y * blockDim.y + threadIdx.y;

    if (row < n && col < n) {
        float sum = 0.0f;
        for (int k = 0; k < n; ++k)
            sum += A[row * n + k] * B[k * n + col];
        C[row * n + col] = sum;
    }
}

// ---------------------------------------------------------------------------
// Host helpers
// ---------------------------------------------------------------------------
static void fill_random(float *M, int size)
{
    for (int i = 0; i < size; ++i)
        M[i] = (float)rand() / RAND_MAX;
}

static void cpu_gemm_corner(const float *A, const float *B, float *C, int n, int corner)
{
    // Reference: compute only the top-left corner×corner block on CPU
    for (int r = 0; r < corner; ++r)
        for (int c = 0; c < corner; ++c) {
            float s = 0.f;
            for (int k = 0; k < n; ++k) s += A[r*n+k] * B[k*n+c];
            C[r*corner+c] = s;
        }
}

#define CUDA_CHECK(call)                                                        \
    do {                                                                        \
        cudaError_t err = (call);                                               \
        if (err != cudaSuccess) {                                               \
            fprintf(stderr, "CUDA error %s:%d – %s\n",                         \
                    __FILE__, __LINE__, cudaGetErrorString(err));               \
            exit(1);                                                            \
        }                                                                       \
    } while (0)

int main(void)
{
    printf("=== Naive GEMM  (N=%d, FP32) ===\n", N);

    // ---- Print device info ----
    cudaDeviceProp prop;
    CUDA_CHECK(cudaGetDeviceProperties(&prop, 0));
    printf("GPU : %s  (SM %d.%d)\n", prop.name, prop.major, prop.minor);
    double peak_bw   = 2.0 * prop.memoryClockRate * 1e3     // Hz
                       * (prop.memoryBusWidth / 8.0) / 1e9; // GB/s
    double peak_fp32 = 2.0 * prop.multiProcessorCount
                       * prop.clockRate * 1e3 / 1e12;       // TFLOP/s (rough)
    printf("Peak BW  : %.1f GB/s\n", peak_bw);
    printf("Peak FP32: %.2f TFLOP/s (rough)\n\n", peak_fp32);

    size_t bytes = (size_t)N * N * sizeof(float);

    // ---- Host alloc ----
    float *hA = (float*)malloc(bytes);
    float *hB = (float*)malloc(bytes);
    float *hC = (float*)malloc(bytes);
    srand(42);
    fill_random(hA, N*N);
    fill_random(hB, N*N);

    // ---- Device alloc ----
    float *dA, *dB, *dC;
    CUDA_CHECK(cudaMalloc(&dA, bytes));
    CUDA_CHECK(cudaMalloc(&dB, bytes));
    CUDA_CHECK(cudaMalloc(&dC, bytes));
    CUDA_CHECK(cudaMemcpy(dA, hA, bytes, cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(dB, hB, bytes, cudaMemcpyHostToDevice));

    // ---- Launch config ----
    dim3 block(16, 16);
    dim3 grid((N + block.x - 1) / block.x,
              (N + block.y - 1) / block.y);

    // ---- Warm-up ----
    gemm_naive<<<grid, block>>>(dA, dB, dC, N);
    CUDA_CHECK(cudaDeviceSynchronize());

    // ---- Timed run (avg of 5 iterations) ----
    const int NITER = 5;
    cudaEvent_t t0, t1;
    CUDA_CHECK(cudaEventCreate(&t0));
    CUDA_CHECK(cudaEventCreate(&t1));

    CUDA_CHECK(cudaEventRecord(t0));
    for (int i = 0; i < NITER; ++i)
        gemm_naive<<<grid, block>>>(dA, dB, dC, N);
    CUDA_CHECK(cudaEventRecord(t1));
    CUDA_CHECK(cudaEventSynchronize(t1));

    float ms_total;
    CUDA_CHECK(cudaEventElapsedTime(&ms_total, t0, t1));
    float ms = ms_total / NITER;

    // 2*N^3 FLOPs per GEMM
    double flops  = 2.0 * (double)N * N * N;
    double gflops = (flops / (ms * 1e-3)) / 1e9;

    printf("Kernel time : %.3f ms  (avg of %d runs)\n", ms, NITER);
    printf("Achieved    : %.2f GFLOP/s\n", gflops);

    // ---- Correctness check (4×4 corner) ----
    CUDA_CHECK(cudaMemcpy(hC, dC, bytes, cudaMemcpyDeviceToHost));
    const int CRN = 4;
    float ref[CRN*CRN];
    cpu_gemm_corner(hA, hB, ref, N, CRN);
    float maxErr = 0.f;
    for (int r = 0; r < CRN; ++r)
        for (int c = 0; c < CRN; ++c)
            maxErr = fmaxf(maxErr, fabsf(hC[r*N+c] - ref[r*CRN+c]));
    printf("Max abs err (4×4 corner vs CPU): %.6f  %s\n",
           maxErr, maxErr < 1e-2f ? "[PASS]" : "[FAIL]");

    // ---- Bandwidth estimate (naive accesses 2*N^3 floats from DRAM) ----
    double bytes_accessed = 2.0 * (double)N * N * N * sizeof(float); // each A,B element read N times
    double bw_eff = (bytes_accessed / (ms * 1e-3)) / 1e9;
    printf("Est. DRAM BW (naive, no reuse): %.1f GB/s\n", bw_eff);

    // ---- Cleanup ----
    cudaEventDestroy(t0); cudaEventDestroy(t1);
    cudaFree(dA); cudaFree(dB); cudaFree(dC);
    free(hA); free(hB); free(hC);
    return 0;
}
