# Roofline Analysis — Gap Diagnosis
**Project:** Matrix Multiplication Co-Processor Chiplet (ECE 410/510, S2026)

---

## Accelerator Placement vs. Expectation

The M2 accelerator (simulation-measured) lands at **160–178 MFLOP/s** on the
roofline, plotted at AI_high = 2.667 FLOP/B. The sky130 single-PE compute
ceiling is 200 MFLOP/s (1 MAC/cycle × 100 MHz × 2 FLOP/MAC). The measured
throughput is therefore at **80–89% of the theoretical compute ceiling** —
extremely close, with the remaining gap explained entirely by the one-cycle
start overhead per dot-product (1 idle cycle out of every N+1 cycles, so
1/5 = 20% overhead for N=4, 1/9 = 11% for N=8).

The accelerator does **not** fall into the memory-bound region because the
simulation testbench holds data in registers (no off-chip traffic between
consecutive dot-products), placing it near AI_high. In a real system, the
AXI4-Lite interface (0.4 GB/s) would throttle input delivery: feeding one
INT8 pair per cycle at 100 MHz requires 200 MB/s, comfortably within the
AXI4-Lite limit, so the compute ceiling remains the true bottleneck at N≥4.

## Dominant Uncertainty in the Projection

The only meaningful uncertainty is **clock frequency**: the 100 MHz figure is
a conservative sky130 estimate for a datapath including a signed 8-bit
multiplier and a 32-bit adder. Synthesis timing analysis (OpenSTA post-Yosys)
is needed to confirm the achievable Fmax; a shorter critical path could push
Fmax to 150–200 MHz, proportionally raising both ceiling and measured points.
Physical P&R with sky130 standard cells would resolve this and convert all
projected area/power figures to measurements.
