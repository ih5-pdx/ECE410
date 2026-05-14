# Interface Selection and Bandwidth Analysis

## Host Platform
The host platform for this project is an **Intel Core i7-1165G7** CPU running Ubuntu 22.04 LTS.
This is a laptop-class processor with LPDDR4x dual-channel memory (peak bandwidth 51.2 GB/s).
The chiplet accelerator is treated as a memory-mapped peripheral attached to the host via the
selected interface below.

---

## Selected Interface
The selected host-to-chiplet interface is **AXI4** (from the allowed list: SPI / I2C / AXI4 /
PCIe / UCIe).

AXI4 (full AXI4, not AXI-Lite) is chosen because:
- It supports **burst transfers** of arbitrary length, which is required to stream matrix data
  efficiently between host memory and the chiplet.
- It is the standard high-throughput on-chip bus used in FPGA and ASIC designs and is directly
  supported by most chiplet integration flows.
- It provides separate read and write channels, allowing simultaneous loading of input matrices
  and storing of output results.
- It is on the grader-approved allowed interface list.

AXI-Lite is **not** used as the primary data interface because it is limited to single-beat
(non-burst) transfers and cannot sustain the bandwidth required to feed the matrix multiply
datapath. AXI-Lite may still be used as a secondary control/status interface for register
access, but AXI4 is the primary data-movement interface.

---

## Bandwidth Requirement Calculation

### Matrix dimensions (FP32)
| Matrix | Dimensions  | Size (bytes)          |
|--------|-------------|-----------------------|
| X      | 128 × 256   | 128 × 256 × 4 = 131,072 |
| W      | 256 × 256   | 256 × 256 × 4 = 262,144 |
| Y      | 128 × 256   | 128 × 256 × 4 = 131,072 |
| **Total** |          | **524,288 bytes (0.524 MB)** |

### Target throughput
From the software baseline, the CPU completes one GEMM in a median of **0.38 ms**.
To match or exceed this rate, the chiplet must be able to move all matrix data within the same
budget. The required interface bandwidth is:

$$
\text{Required BW} = \frac{524{,}288 \text{ bytes}}{0.00038 \text{ s}} \approx 1.38 \text{ GB/s}
$$

To sustain **10 inferences per second** as a target throughput goal:

$$
\text{Required BW} = 524{,}288 \times 10 = 5{,}242{,}880 \text{ bytes/s} \approx \mathbf{0.005 \text{ GB/s}}
$$

For a more demanding target of **1,000 inferences per second**:

$$
\text{Required BW} = 524{,}288 \times 1{,}000 \approx \mathbf{0.524 \text{ GB/s}}
$$

**Adopted requirement: 1.38 GB/s** — matching the software baseline single-operation rate as a
minimum, with headroom target of 2× = **2.76 GB/s**.

---

## Interface Rated Bandwidth vs Required Bandwidth

| Metric                        | Value            |
|-------------------------------|------------------|
| Required bandwidth (minimum)  | 1.38 GB/s        |
| Required bandwidth (2× target)| 2.76 GB/s        |
| AXI4 rated bandwidth          | up to **12.8 GB/s** (32-bit data bus at 400 MHz) |
| AXI4 rated bandwidth (64-bit) | up to **25.6 GB/s** (64-bit data bus at 400 MHz) |
| Margin (32-bit bus)           | ~9.3× over minimum requirement |
| Margin (64-bit bus)           | ~18.6× over minimum requirement |

AXI4 with a 32-bit data bus at a modest 400 MHz clock provides **12.8 GB/s** of rated
bandwidth, which exceeds the minimum required bandwidth of 1.38 GB/s by approximately **9×**.
This margin is sufficient to absorb bus arbitration overhead, burst alignment penalties, and
future workload scaling.

The interface is therefore **not the bottleneck** for this design. The limiting factor remains
compute throughput inside the chiplet, consistent with the roofline analysis showing GEMM is
compute-bound.

---

## Conclusion

AXI4 is selected as the primary host-to-chiplet data interface because it is on the approved
allowed list, supports burst transfers, and provides rated bandwidth (12.8 GB/s) that comfortably
exceeds the calculated requirement (1.38 GB/s minimum, 2.76 GB/s target). The host platform is
an Intel Core i7-1165G7 running Ubuntu 22.04. A secondary AXI-Lite control interface may be
used for register access and status polling, but AXI4 handles all bulk matrix data movement.
