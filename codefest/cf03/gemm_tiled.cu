// gemm_tiled.cu  –  Shared-memory tiled 1024x1024 FP32 GEMM  (TILE_SIZE = 8)
// Generated with Claude (claude-sonnet-4-20250514) assistance.
// Compile: nvcc -O2 -arch=sm_80 gemm_tiled.cu -o gemm_tiled

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <cuda_runtime.h>

#define N         1024
#define TILE_SIZE 8

// ---------------------------------------------------------------------------
// Kernel: each (TILE_SIZE×TILE_SIZE) thread block computes one output tile.
// Shared memory tiles As, Bs stage one K-strip at a time.
// ---------------------------------------------------------------------------
__global__ void gemm_tiled(const float * __restrict__ A,
                             const float * __restrict__ B,
                             float       * __restrict__ C,
                             int n)
{
    __shared__ float As[TILE_SIZE][TILE_SIZE];
    __shared__ float Bs[TILE_SIZE][TILE_SIZE];

    int tx = threadIdx.x, ty = threadIdx.y;
    int row = blockIdx.y * TILE_SIZE + ty;   // global row of C/A
    int col = blockIdx.x * TILE_SIZE + tx;   // global col of C/B

    float sum = 0.0f;
    int numTiles = (n + TILE_SIZE - 1) / TILE_SIZE;

    for (int t = 0; t < numTiles; ++t) {
        // Load one tile of A (row, t*TILE+tx) and B (t*TILE+ty, col)
        int aCol = t * TILE_SIZE + tx;
        int bRow = t * TILE_SIZE + ty;

        As[ty][tx] = (row < n && aCol < n) ? A[row * n + aCol] : 0.0f;
        Bs[ty][tx] = (bRow < n && col < n) ? B[bRow * n + col] : 0.0f;

        __syncthreads();   // wait for tile to be fully loaded

        #pragma unroll
        for (int k = 0; k < TILE_SIZE; ++k)
            sum += As[ty][k] * Bs[k][tx];

        __syncthreads();   // wait before overwriting shared mem
    }

    if (row < n && col < n)
        C[row * n + col] = sum;
}

// ---------------------------------------------------------------------------
// Host helpers
// ---------------------------------------------------------------------------
static void fill_random(float *M, int size)
{
    for (int i = 0; i < size; ++i)
        M[i] = (float)rand() / RAND_MAX;
}

static void cpu_gemm_corner(const float *A, const float *B, float *C,
                             int n, int corner)
{
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
    printf("=== Tiled GEMM  (N=%d, TILE_SIZE=%d, FP32) ===\n", N, TILE_SIZE);

    // ---- Device info ----
    cudaDeviceProp prop;
    CUDA_CHECK(cudaGetDeviceProperties(&prop, 0));
    printf("GPU : %s  (SM %d.%d)\n", prop.name, prop.major, prop.minor);
    double peak_bw   = 2.0 * prop.memoryClockRate * 1e3
                       * (prop.memoryBusWidth / 8.0) / 1e9;
    double peak_fp32 = 2.0 * prop.multiProcessorCount
                       * prop.clockRate * 1e3 / 1e12;
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
    dim3 block(TILE_SIZE, TILE_SIZE);
    dim3 grid((N + TILE_SIZE - 1) / TILE_SIZE,
              (N + TILE_SIZE - 1) / TILE_SIZE);

    // ---- Warm-up ----
    gemm_tiled<<<grid, block>>>(dA, dB, dC, N);
    CUDA_CHECK(cudaDeviceSynchronize());

    // ---- Timed run (avg of 5 iterations) ----
    const int NITER = 5;
    cudaEvent_t t0, t1;
    CUDA_CHECK(cudaEventCreate(&t0));
    CUDA_CHECK(cudaEventCreate(&t1));

    CUDA_CHECK(cudaEventRecord(t0));
    for (int i = 0; i < NITER; ++i)
        gemm_tiled<<<grid, block>>>(dA, dB, dC, N);
    CUDA_CHECK(cudaEventRecord(t1));
    CUDA_CHECK(cudaEventSynchronize(t1));

    float ms_total;
    CUDA_CHECK(cudaEventElapsedTime(&ms_total, t0, t1));
    float ms = ms_total / NITER;

    double flops  = 2.0 * (double)N * N * N;
    double gflops = (flops / (ms * 1e-3)) / 1e9;

    printf("Kernel time : %.3f ms  (avg of %d runs)\n", ms, NITER);
    printf("Achieved    : %.2f GFLOP/s\n", gflops);

    // Theoretical DRAM traffic with tiling: each element loaded N/TILE_SIZE times
    // (once per tile-strip instead of N times in naive)
    double bytes_dram = 2.0 * (double)N * N * ((double)N / TILE_SIZE) * sizeof(float);
    double bw_eff     = (bytes_dram / (ms * 1e-3)) / 1e9;
    printf("Est. DRAM BW (tiled, with reuse): %.1f GB/s\n", bw_eff);
    printf("Arithmetic intensity: %.2f FLOP/byte\n",
           flops / (bytes_dram));

    // ---- Correctness check ----
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

    // ---- Cleanup ----
    cudaEventDestroy(t0); cudaEventDestroy(t1);
    cudaFree(dA); cudaFree(dB); cudaFree(dC);
    free(hA); free(hB); free(hC);
    return 0;
}
