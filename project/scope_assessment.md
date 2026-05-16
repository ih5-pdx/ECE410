# Project Scope Assessment — M3 Update
**Project:** Matrix Multiplication Co-Processor Chiplet  
**Course:** ECE 410/510 — Hardware for AI/ML, Spring 2026  
**Updated:** 2026-05-16 (post CF07 synthesis)

---

## Scope Confirmation

The M2 scope — a single-PE sequential MAC engine with AXI4-Lite interface,
INT8 inputs, INT32 accumulation, MAX_DIM=8 — is **confirmed unchanged** for M3.

---

## Synthesis Results Supporting This Decision

The Yosys synthesis of `compute_core.sv` produced:

- **4,496 cells** total (4,426 combinational + 70 sequential)
- **Cell area:** ~7,330 µm² (~12,200 µm² die estimate at 60% utilization)
- **Critical path:** ~4.31 ns, dominated by the 8×8 multiplier tree (~52% of path)
- **Slack at 100 MHz:** +5.49 ns — timing constraint met with wide margin
- **No latches, no loops, 0 CHECK errors**

These numbers confirm the design is synthesizable, correctly inferred (70 DFFs
match the 32 accumulator + 32 result + 4 count + 1 computing + 1 busy = 70
expected flops), and fits well within sky130 area budgets.

---

## Changes Planned for M3

Two RTL fixes are planned before the OpenLane 2 full-flow run:

1. **Explicit 16-bit product wire** — Yosys inferred a 32×32 multiplier due to
   implicit sign extension. Constraining the product to `logic signed [15:0]`
   (as in `mac_correct.v`) will shrink the critical path by an estimated 1.5–2 ns.

2. **Eliminate duplicate accumulation** — the redundant `result` computation on
   the last cycle costs 32 SDFFE flops; removing it reduces area by ~7%.

The M3 deliverable will include the corrected RTL, a complete OpenLane 2 run
targeting sky130_fd_sc_hd at 100 MHz, and post-route timing and area reports.

---

## What Is NOT Changing

- The single-PE architecture (multi-PE systolic array remains an M3+ stretch goal).
- INT8 inputs / INT32 accumulation (validated correct in M2 precision analysis).
- AXI4-Lite interface (passes all 5 testbench checks per `interface_run.log`).
- MAX_DIM=8 testbench scope.

The synthesis result demonstrates the kernel is both functionally correct and
physically realizable on sky130 at the target frequency, providing confidence
that the full OpenLane flow in M3 will close timing without architectural changes.
