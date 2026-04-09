import matplotlib.pyplot as plt
import numpy as np

# -----------------------------
# Replace these with your real hardware specs
# -----------------------------
peak_gflops = 500      # Example: 500 GFLOP/s
peak_bandwidth = 50    # Example: 50 GB/s

# Ridge point
ridge_point = peak_gflops / peak_bandwidth

# Software kernel point
kernel_ai = 32         # FLOPs/byte from calculation
kernel_perf = min(peak_gflops, peak_bandwidth * kernel_ai)

# Hypothetical hardware accelerator point
accel_ai = 64          # Example design point
accel_peak = 200       # Example target throughput in GFLOP/s
accel_bw = 100         # Example on-chip bandwidth in GB/s
accel_perf = min(accel_peak, accel_bw * accel_ai)

# X range
x = np.logspace(-1, 3, 500)
roofline = np.minimum(peak_gflops, peak_bandwidth * x)

plt.figure(figsize=(9, 6))
plt.loglog(x, roofline, label="CPU/GPU Roofline", linewidth=2)
plt.scatter(kernel_ai, kernel_perf, s=100, label="Software Kernel")
plt.scatter(accel_ai, accel_perf, s=100, label="Hypothetical HW Accelerator")

plt.text(kernel_ai * 1.05, kernel_perf, "SW Kernel")
plt.text(accel_ai * 1.05, accel_perf, "HW Accelerator")
plt.text(ridge_point * 1.05, peak_gflops * 0.5, f"Ridge = {ridge_point:.2f}")

plt.xlabel("Arithmetic Intensity (FLOPs/byte)")
plt.ylabel("Performance (GFLOP/s)")
plt.title("Roofline Model for Transformer Matrix Multiplication Kernel")
plt.grid(True, which="both", linestyle="--", alpha=0.5)
plt.legend()
plt.tight_layout()
plt.savefig("codefest/cf02/profiling/roofline_project.png", dpi=300)
plt.show()
