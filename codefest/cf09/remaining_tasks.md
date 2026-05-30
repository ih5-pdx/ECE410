# Remaining Tasks Before M4
**Project:** Matrix Multiplication Co-Processor Chiplet (ECE 410/510, S2026)
| Updated: 2026-05-30

These are the three highest-priority concrete changes required before M4.
Each is stated as a specific design action with a measurable success criterion.

---

## Task 1 — Replace the sequential single-PE datapath with a 4×4 systolic PE array, sharing a 512-byte on-chip SRAM tile buffer

**Problem:** The M2 `compute_core.sv` executes one MAC per cycle using a single PE,
delivering 200 MFLOP/s peak at 100 MHz. The M3 throughput target (55–65 GFLOP/s
from the Heilmeier Q3) requires roughly 300 PEs active in parallel. A 4×4 array
(16 PEs) is the minimum viable step toward that goal, raising peak throughput to
3.2 GFLOP/s and validating the systolic control logic before scaling further.

**Specific action:** Add a `pe_array.sv` module instantiating 16 `mac_correct.v`
MAC units in a weight-stationary 4×4 topology, connected by a
`tile_controller.sv` FSM that loads a 4×4 tile of A and B from a dual-port
256-byte SRAM (sky130 `sky130_sram_1kbyte_1rw1r_32x256_8` or equivalent)
and broadcasts weights to PE columns while streaming activations across rows.

**Success criterion:** `tb_pe_array.sv` testbench computes a 4×4 INT8 matrix
multiply and asserts `result_valid` within 8 cycles of the last input pair,
with all 16 output elements matching a NumPy INT32 reference. Yosys synthesis
reports no combinational loops and infers the SRAM macro correctly.

---

## Task 2 — Run OpenSTA post-synthesis timing analysis on `compute_core.sv` to confirm or correct the 100 MHz clock target

**Problem:** All M2 performance numbers (200 MFLOP/s peak, cycle latencies,
speedup table) assume a 100 MHz clock. The critical path through the signed
8×8 multiplier and 32-bit accumulator adder has not been formally timed.
If Fmax is lower than 100 MHz, every measured and projected figure must be
rescaled; if Fmax exceeds 100 MHz, the design is being under-clocked.

**Specific action:** Run `yosys -p 'synth_sky130 -top compute_core' compute_core.sv`
followed by `opensta` with the sky130 liberty file (`sky130_fd_sc_hd__tt_025C_1v80.lib`),
targeting a 10 ns (100 MHz) constraint. Report worst negative slack (WNS) and
the exact critical path (gate names and delays). If WNS > 1 ns, tighten the
constraint until the design fails, establishing the true Fmax.

**Success criterion:** A timing report showing WNS and the critical path
is committed to `project/m3/timing/compute_core_sta.rpt`. If Fmax differs
from 100 MHz by more than ±10%, update all throughput and speedup tables
in `codefest/cf09/benchmarks/benchmark_results.md` accordingly and remove
the "projected" label from the clock frequency row.

---

## Task 3 — Replace the AXI4-Lite control interface with a burst-capable AXI4 data channel that can sustain one INT8 operand pair per cycle at 100 MHz

**Problem:** The M2 `interface.sv` uses AXI4-Lite, which is a single-beat
non-burst protocol. At 100 MHz, the compute core consumes one (a_data, b_data)
pair every cycle — 2 bytes per cycle = 200 MB/s. AXI4-Lite with a 32-bit bus
can sustain at most one 4-byte transaction per 2+ cycles (~200 MB/s peak), but
the address and response handshakes add at minimum 3 cycles per beat, dropping
effective data bandwidth to under 70 MB/s and stalling the PE on every cycle.

**Specific action:** Replace the write-data path in `interface.sv` with an
AXI4 burst slave (`AWBURST=INCR`, `AWLEN` configurable up to 255 beats).
The burst controller should fill a 2×N-byte ping-pong FIFO (two 8-byte
dual-port registers for N=8), asserting `core_a_valid` and `core_b_valid`
only when a full operand pair is available in the FIFO, eliminating
per-element handshake stalls.

**Success criterion:** `tb_interface_burst.sv` issues a single AXI4 write
burst of `2×N` bytes (N=8 → 16-byte burst), and the simulation log shows
`core_a_valid && core_b_valid` asserted for N consecutive cycles with no gaps
between operand pairs, matching the back-to-back cadence confirmed in the M2
`tb_bench_final.sv` cycle trace. Throughput measured by the testbench must
equal `N / (N+1)` of peak (≥88% utilization) for N=8.
