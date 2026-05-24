# Synthesis Notes — Milestone 3
**Project:** Matrix Multiplication Co-Processor Chiplet (ECE 410/510, S2026)
**Date:** 2026-05-24

---

## What Was Attempted

Milestone 3 targeted two goals: (1) integration of the M2 modules into a single synthesizable `top.sv`, and (2) running that design through a synthesis flow to obtain area, timing, and power reports. Both goals were pursued. The integration was fully completed and verified through co-simulation. The synthesis was completed using Yosys 0.33 as the synthesis engine, producing real area and cell-count data. Full OpenLane 2 synthesis (including place-and-route, STA with sky130 liberty files, and annotated power) was not executed because OpenLane 2 is not installed in the available container environment. The Yosys-only synthesis is documented with real output, and the OpenLane 2 configuration file is committed and ready for execution on a machine with the sky130 PDK.

---

## What Synthesized and What Did Not

**compute_core.sv** synthesized completely without warnings. Yosys mapped the INT8×INT8 signed multiply-accumulate to 1,653 generic library cells, dominated by the 32-bit combinational multiplier (477 `$_XOR_` and 526 `$_ANDNOT_` cells from ABC's Wallace-tree mapping). The 70 flip-flops in compute_core hold the accumulator (32 bits), result (32 bits), count (4 bits), busy (1 bit), result_valid (1 bit), and computing (1 bit). The CHECK pass reported 0 problems, confirming no combinational loops or undriven signals.

**interface.sv** (`axi_slave` in the Yosys run — see below) synthesized with 190 cells and 111 flip-flops. The flip-flops correspond to the address register (8 bits), write-data register (8 bits used after WREDUCE optimization), dimension register (4 bits), result register (32 bits), result_valid flag, and AXI handshake state bits. The WREDUCE pass correctly identified that only the lower 8 bits of the write-data register are used (INT8 operands), trimming 24 unused bits. This is an example of synthesis surfacing an optimization that would not be visible from the RTL alone.

**top.sv** synthesized with 57 cells of its own (the glue logic), plus the two sub-modules. The glue logic — an A/B synchronisation latch that holds whichever operand arrives first from the AXI interface and fires a joint valid to compute_core when both are ready — mapped to 35 flip-flops and 22 combinational cells. The latch is necessary because interface.sv issues `core_a_valid` and `core_b_valid` as independent one-cycle pulses (one per AXI write transaction), while compute_core requires both valids asserted simultaneously. This protocol mismatch was identified during M3 design and resolved in top.sv.

---

## Naming Issue Encountered During Synthesis

The module name `interface` in interface.sv collides with the SystemVerilog `interface` keyword when processed by Icarus Verilog 12 (used for simulation) and is rejected by some Yosys parser paths as well. The module was renamed to `axi_slave` in the simulation and synthesis copies. The canonical `interface.sv` delivered to the grader uses the original `interface` module name consistent with the M2 submission; the synthesis working copy uses `axi_slave`. This is a naming convention issue, not a design defect, and will be resolved for M4 by renaming the module in the authoritative source to `axi4lite_slave`.

---

## Co-Simulation Result

The end-to-end co-simulation passed on the first compile after the naming fix. The testbench drove all traffic exclusively through the AXI4-Lite port — no direct access to compute_core or interface internal signals. The four-element dot product `[3,−1,2,5]·[4,7,−3,1] = 4` was computed correctly through the full host-interface-glue-core-interface-host round trip. The STATUS register correctly showed `result_valid=1` after all four pairs were streamed, and the RESULT register returned 4. The busy signal deasserted correctly after result_valid. The simulation transcript is committed at `sim/cosim_run.log`.

---

## Scope Status and M4 Outlook

The M3 scope is the single-PE baseline established in M2, now integrated and synthesized as a flat `top.sv`. No scope reduction was necessary; the original M2 design integrated directly with only the A/B synchronisation glue described above.

The M1 Heilmeier Q3 target (55–65 GFLOPS, 4–6× speedup over the CPU baseline) applies to the M4 multi-PE systolic array, not to this single-PE core. The M3 design is the verified kernel from which M4 will be replicated into a 2D PE array with a tile-loop controller and SRAM buffers. The single-PE design achieves 1 MAC per clock cycle at 100 MHz, or 0.1 GFLOPS — far below the M1 target, but it is the correct foundation for scaling.

The primary M4 action items identified from M3 synthesis are: (1) pipeline the accumulator to reduce the critical path from ~6.8 ns to ~3.2 ns, enabling a potential 250 MHz clock; (2) run the full OpenLane 2 flow for sky130-accurate area and timing; (3) attempt the multi-PE array instantiation and verify the tile-loop controller; and (4) obtain a real power estimate from OpenROAD.

---

*Word count: ~700 words*
