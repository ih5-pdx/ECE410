# M3 Synthesis Plan — compute_core
**Based on:** Yosys synthesis results, 2026-05-16

---

## Changes for M3

**1. Fix the 32-bit multiplier width** (highest priority).  
Yosys sign-extended both 8-bit inputs to 32 bits before multiplying, inflating the
multiplier from the required 16-bit output to a 32×32 tree. The synthesis log confirms
this via the `$macc` operand trace. Inserting `logic signed [15:0] product = a_data * b_data`
as a combinational wire (matching `mac_correct.v`) will reduce the partial-product tree
and is expected to shorten the critical path by 1.5–2 ns, pushing fmax toward 300+ MHz.

**2. Eliminate the duplicate accumulation path.**  
The two computations of `accumulator + product` (lines 47 and 52 in `compute_core.sv`)
cost 32 extra SDFFE flops and one MUX level (~240 ps). For M3, `result` will be
read directly from `accumulator` on the same cycle `result_valid` is asserted, removing
the redundant register bank and the MUX from the critical path.

**3. Maintain 100 MHz clock target.**  
Current slack of +5.49 ns at 100 MHz is generous. After fix #1 the slack narrows to
an estimated +3.5–4 ns — still comfortable. Stretching to 200 MHz is a post-M3 goal
once the OpenLane full flow (floorplan, placement, CTS, routing) is run and wire-load
effects are visible in the actual OpenSTA timing report.

**4. Run OpenLane 2 full flow for M3.**  
This CF08 synthesis was Yosys-only. M3 will target the complete OpenLane 2 sky130_fd_sc_hd
flow to obtain post-route STA, real hold-fixing, and a DRC-clean GDS.
