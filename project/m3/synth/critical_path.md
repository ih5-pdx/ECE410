# Critical Path Analysis — top.sv integrated design
**Project:** Matrix Multiplication Co-Processor Chiplet (ECE 410/510, S2026)
**File:** project/m3/synth/critical_path.md
**Date:** 2026-05-24

---

## Critical Path Identification

**Start register:** `accumulator[31:0]` — the 32-bit signed accumulation register
inside `compute_core`, implemented as `$_SDFFE_PP0P_` (synchronous D flip-flop,
positive clock edge, active-high reset, clock-enable). Specifically, the Q output
of bit 31 (the sign bit) starts the worst-case path.

**End register:** `accumulator[31:0]` — the same register's D input on the
following clock cycle.

**Logic stages between start and end (in order):**

1. **Sign-extension of `a_data` and `b_data`** — The 8-bit signed inputs are
   extended to 32 bits by replicating `a_data[7]` and `b_data[7]` into the upper
   24 bits. Implemented as `$_NOT_` + `$_ANDNOT_` chains in the ABC mapping (8
   ANDNOT cells per operand). Estimated stage delay: ~0.4 ns.

2. **32×32 unsigned multiply** — The sign-extended operands are multiplied
   combinationally. Yosys maps this to a Wallace-tree-style structure using 477
   `$_XOR_` and 526 `$_ANDNOT_` cells, compressed by ABC's `maccmap` and `alumacc`
   passes. The product is 32 bits (upper 32 bits of the full 64-bit product are
   discarded). This stage dominates the path: the carry-propagation chain through
   the partial-product compression tree is estimated at ~2.8 ns.

3. **32-bit accumulate adder** — The 32-bit product is added to the current
   `accumulator` value using a ripple-carry adder mapped to `$_XOR_` (sum) and
   `$_OR_` (carry) cells. The 32-stage carry chain is the longest single fan-out
   in the design, estimated at ~3.2 ns. This is the most expensive individual
   stage.

4. **`count == dim − 1` comparator** — A 4-bit subtractor (`dim − 1`) feeds a
   4-bit equality check (`count == result`), generating the `last_element` signal
   that muxes `result` vs `accumulator` on the final cycle. Estimated delay: ~0.3 ns.

5. **Setup to `accumulator` D input** — `$_SDFFE_PP0P_` setup time: ~0.1 ns
   (generic library estimate).

**Estimated total combinational delay: ~6.8 ns**
**Estimated slack at 10 ns clock: +3.2 ns (timing is met)**

---

## Why This Is the Critical Path

The multiply-accumulate datapath is the critical path for two compounding reasons.
First, the 32-bit multiplier is fully combinational — the product is computed fresh
every clock cycle from the current `a_data` and `b_data` values, with no registered
intermediate. This was an intentional M2 design choice (fixing the LLM-A bug where
the product was incorrectly registered), but it means the full multiply delay is on
the critical path every cycle. Second, the 32-bit ripple-carry adder that accumulates
the product has no carry-lookahead: 32 serial carry stages each adding roughly 0.1 ns
produce ~3.2 ns of carry-propagation delay, which is the single longest combinational
segment in the design.

The AXI4-Lite interface paths (address decode, register write logic) are significantly
shorter — on the order of 2–3 stages of `$_AND_` / `$_OR_` logic feeding the
`$_SDFFE_PN0P_` registers — and are not timing-critical.

---

## What Would Shorten the Critical Path

Two independent optimizations would directly address the bottleneck:

**1. Pipeline the accumulator.** Split the multiply-accumulate into two pipeline stages:
   - Stage 1: compute `product = a_data × b_data` and register it in a new `product_reg`
     flip-flop. This adds one cycle of latency but cuts the combinational depth of the
     MAC stage from ~6.8 ns to ~3.2 ns (multiply only).
   - Stage 2: compute `accumulator + product_reg`. The 32-bit adder alone takes ~3.2 ns,
     comfortably fitting in a 10 ns period with margin.
   - Net effect: critical path ≈ 3.2 ns, achievable clock period ~4 ns (250 MHz).
   - Cost: 32 additional flip-flops for `product_reg` and 1 extra cycle of latency per
     dot-product computation (negligible for dim=4..8).

**2. Replace the ripple-carry adder with carry-lookahead (CLA) or carry-select.**
   On sky130_fd_sc_hd, a 32-bit CLA adder achieves ~2.5 ns vs ~4.5 ns for ripple.
   This is partially handled automatically by OpenLane's synthesis strategy, but
   explicitly instantiating a CLA adder ensures the optimizer applies it. This alone
   would save ~1–2 ns on the accumulate stage.

For M4, the recommendation is to apply option 1 (pipelining) as the simplest change
that achieves the largest timing improvement and aligns with the systolic-array M3→M4
scaling plan.
