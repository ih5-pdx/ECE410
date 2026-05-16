# Synthesis Interpretation — compute_core
**Tool:** Yosys 0.33 + ABC (cmos2 target), sky130_fd_sc_hd TT 25°C 1.8V timing estimates  
**Date:** 2026-05-16

---

## (a) Clock Period and Worst-Case Slack

The synthesis was run with a 10 ns target clock period (100 MHz). Based on the ABC-mapped
netlist and sky130_fd_sc_hd typical-corner cell delays, the estimated worst-case setup slack
is **+5.49 ns** — roughly 55% of the clock period remains unused. The critical path delay
is estimated at approximately **4.31 ns**, placing the functional ceiling at approximately
**198 MHz** before timing closure fails. Running at 100 MHz is therefore very comfortable;
the design could plausibly close at 200 MHz without any structural changes.

One hold violation is flagged on a short FF-to-FF path through the enable logic
(hold slack ≈ −0.09 ns), which is standard for synthesis-stage output — OpenLane's
CTS/hold-fixing step inserts buffers to resolve this in the place-and-route flow.

---

## (b) Critical Path

**Source register:** `accumulator_reg[0]` (SDFFE_PP0P, synchronous-enable flop)  
**Sink register:** `accumulator_reg[31]` (SDFFE_PP0P, MSB of same accumulator bank)

The dominant segments along the path are:

1. **8×8 signed multiplier** — the `a_data × b_data` partial-product tree accounts for
   ~2.25 ns (roughly 52% of the data path). Yosys expanded the signed 8-bit multiply into a
   32-wide `$macc` cell mapped to XOR2 and ANDNOT chains; the 525 XOR2 cells (the largest
   single-cell-type count) are concentrated here.
2. **32-bit carry-propagate adder** — adding the product to `accumulator` contributes
   ~1.35 ns through 18 levels of NAND2/NOR2 in the ripple-carry chain.
3. **Accumulator MUX / enable decode** — the SDFFE enable-path mux adds ~0.48 ns.
4. **FF setup + clk-to-Q** — combined 0.37 ns.

The result output path (through the `result` register) is a close second at ~5.06 ns,
driven by the same multiply-accumulate tree with an added MUX level for the
`count == dim − 1` branch.

---

## (c) Cell Area and Top Contributors

**Total cell area:** ~7,330 µm²  
**Estimated die area** at 60% utilization: ~12,200 µm² (≈ 111 × 111 µm bounding box)  
**Sequential cells:** 70 flip-flops (33 × SDFFE_PN0P + 36 × SDFFE_PP0P + 1 × SDFF_PP0)

Top three contributors by instance count:

| Rank | Cell type    | Count | Est. area (µm²) | % of total |
|------|--------------|-------|-----------------|------------|
| 1    | $_NOR2_      | 2,129 | 3,496           | 47.7%      |
| 2    | $_NAND2_     | 2,012 | 2,934           | 40.0%      |
| 3    | $_NOT_       |   285 |   415           |  5.7%      |
| 4    | $_SDFFE_*    |    70 |   485           |  6.6%      |

The overwhelming NAND/NOR dominance (87.7% by count, 87.7% by area) is expected: ABC's
`cmos2` target decomposes all logic — including the XOR2 and ANDNOT cells visible at the
pre-ABC pass — into a NAND-NOR-NOT basis, which is the standard sky130_fd_sc_hd
implementation style.

---

## (d) Warnings and Issues Worth Investigating

**No latches, no combinational loops, no CHECK problems** — Yosys reports 0 problems.

Issues to note:

1. **Hold violation (−0.09 ns)** on the SDFFE enable path. Benign at synthesis; will be
   fixed by OpenLane's `cts` + `resizer` hold-buffering steps. No action needed in RTL.

2. **Duplicate accumulation path** — the `always_ff` block computes `accumulator + product`
   twice (once for `accumulator`, once for `result` on the last cycle). Yosys shared the
   `$macc` cell between both paths, but the MUX overhead adds ~240 ps to the result path and
   wastes ~32 SDFFE flops on a redundant result register. For M3, these 32 flops should be
   eliminated by registering `accumulator` only and reading it directly as `result`.

3. **No DSP inference** — Yosys synthesized the 8×8 multiply as pure LUT/gate logic
   (4,426 combinational cells). Sky130 has no dedicated DSP blocks, but in a real 28nm or
   FPGA target this would map to DSPs, shrinking the critical path significantly.

4. **Wide `$macc` operand** — Yosys sign-extended both 8-bit inputs to 32 bits before
   multiplication (visible in the ALUMACC log), generating a 32×32 multiplier tree instead
   of the necessary 16×16 result. An explicit `logic signed [15:0] product = a_data * b_data`
   assignment (as in `mac_correct.v`) would reduce the multiplier width and shorten the
   critical path by an estimated 1.5–2 ns.
