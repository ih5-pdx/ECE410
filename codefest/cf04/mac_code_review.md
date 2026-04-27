# mac_code_review.md — CMAN CF04 HDL Review

---

## LLM Identification

| File | Model | Version |
|------|-------|---------|
| `mac_llm_A.v` | Claude Sonnet | claude-sonnet-4-20250514 |
| `mac_llm_B.v` | GPT-4o | gpt-4o-2024-08-06 |

---

## Specification (identical prompt sent to both)

```
Module name: mac
Inputs: clk (1-bit), rst (1-bit, active-high synchronous reset),
        a (8-bit signed), b (8-bit signed)
Output: out (32-bit signed accumulator)
Behavior: On each rising clock edge: if rst is high, set out to 0;
          else add a×b to out.
Constraints: Synthesizable SystemVerilog only. No initial blocks,
             no $display, no delays (#). Use always_ff.
```

---

## Compilation Results

### LLM A — `mac_llm_A.v`
```
$ iverilog -g2012 -o /tmp/mac_a_check mac_llm_A.v
Exit: 0
(no errors — the bug is functional, not syntactic)
```

### LLM B — `mac_llm_B.v`
```
$ iverilog -g2012 -o /tmp/mac_b_check mac_llm_B.v
Exit: 0
(no errors — the bug is functional, not syntactic)
```

Both files compile without errors. Bugs only surface at simulation time.

---

## Simulation Results

### Test sequence applied
| Cycle | a    | b | rst | Expected `out` |
|-------|------|---|-----|----------------|
| 0     | 0    | 0 | 1   | 0              |
| 1     | 3    | 4 | 0   | 12             |
| 2     | 3    | 4 | 0   | 24             |
| 3     | 3    | 4 | 0   | 36             |
| 4     | —    | — | 1   | 0 (reset)      |
| 5     | −5   | 2 | 0   | −10            |
| 6     | −5   | 2 | 0   | −20            |

### LLM A simulation log
```
PASS  [rst_init]      cycle=6000   out=0
FAIL  [cycle1 a=3 b=4] cycle=16000  out=x  expected=12
FAIL  [cycle2 a=3 b=4] cycle=26000  out=x  expected=24
FAIL  [cycle3 a=3 b=4] cycle=36000  out=x  expected=36
PASS  [rst_asserted]  cycle=46000  out=0
FAIL  [cycle5 a=-5 b=2] cycle=56000  out=12  expected=-10
FAIL  [cycle6 a=-5 b=2] cycle=66000  out=2   expected=-20

5 TEST(S) FAILED
```

### LLM B simulation log
```
FAIL  [rst_init]      cycle=6000   out=x  expected=0
FAIL  [cycle1 a=3 b=4] cycle=16000  out=0   expected=12
FAIL  [cycle2 a=3 b=4] cycle=26000  out=0   expected=24
FAIL  [cycle3 a=3 b=4] cycle=36000  out=0   expected=36
FAIL  [rst_asserted]  cycle=46000  out=12  expected=0
FAIL  [cycle5 a=-5 b=2] cycle=56000  out=0   expected=-10
FAIL  [cycle6 a=-5 b=2] cycle=66000  out=0   expected=-20

7 TEST(S) FAILED
```

### mac_correct.v simulation log
```
PASS  [rst_init]        cycle=6000   out=0
PASS  [cycle1 a=3 b=4]  cycle=16000  out=12
PASS  [cycle2 a=3 b=4]  cycle=26000  out=24
PASS  [cycle3 a=3 b=4]  cycle=36000  out=36
PASS  [rst_asserted]    cycle=46000  out=0
PASS  [cycle5 a=-5 b=2] cycle=56000  out=-10
PASS  [cycle6 a=-5 b=2] cycle=66000  out=-20

ALL TESTS PASSED
```

---

## Issue Review

### Issue 1 — LLM A: Registered intermediate breaks accumulation (one-cycle lag + X propagation)

#### (a) Offending lines
```systemverilog
    logic signed [15:0] product;

    always_ff @(posedge clk) begin
        if (rst) begin
            out <= 32'sd0;
        end else begin
            product <= a * b;        // ← BUG: product is registered
            out <= out + product;    // ← reads product from PREVIOUS cycle
        end
    end
```

#### (b) Why this is wrong
`product` is declared as `logic` and assigned inside `always_ff`, making it a **registered flop**.
On cycle 1, `out` is updated using the *uninitialized* value of `product` (unknown `x`), not the
current `a*b`. On cycle 2, `out` uses cycle 1's product — always one cycle behind. This means:
- During the first accumulation cycle, `out` reads `x` → all subsequent values are `x` until reset.
- After reset, the pipeline lag causes the wrong cycle-1 product (the last pre-reset value) to be
  accumulated into the new `out` in cycle 5.

#### (c) Corrected version
```systemverilog
    logic signed [15:0] product;
    assign product = a * b;   // combinational — no flop

    always_ff @(posedge clk) begin
        if (rst)
            out <= 32'sd0;
        else
            out <= out + 32'(signed'(product));   // sign-extended in same cycle
    end
```

---

### Issue 2 — LLM B: Inverted reset polarity (active-low instead of active-high)

#### (a) Offending lines
```systemverilog
    // Active-low reset: clear accumulator when rst is deasserted
    always @(posedge clk) begin
        if (!rst) begin          // ← BUG: inverts the reset condition
            out <= 32'd0;
        end else begin
            out <= out + (a * b);
        end
    end
```

#### (b) Why this is wrong
The specification says **active-high synchronous reset** — the accumulator should clear when
`rst == 1`. LLM B inverts it with `!rst`, clearing when `rst == 0` and accumulating when `rst == 1`.
The comment even contradicts itself ("active-low reset" / "when rst is deasserted"), showing the
model confused active-high vs active-low conventions. Additionally, `always @(posedge clk)` should
be `always_ff @(posedge clk)` per the spec; the plain `always` form is accepted by simulators
but lacks the synthesis-intent semantics required by the constraint.

#### (c) Corrected version
```systemverilog
    always_ff @(posedge clk) begin
        if (rst) begin           // active-high: clear when rst == 1
            out <= 32'sd0;
        end else begin
            out <= out + 32'(signed'(a * b));
        end
    end
```

---

### Issue 3 — LLM B: `wire`/`reg` instead of `logic`; unsigned reset literal

#### (a) Offending lines
```systemverilog
    input  wire        clk,
    input  wire        rst,
    input  wire signed [7:0]  a,
    input  wire signed [7:0]  b,
    output reg  signed [31:0] out
```
and:
```systemverilog
    out <= 32'd0;    // ← unsigned literal for signed port
```

#### (b) Why this is wrong
`wire` and `reg` are Verilog-1995/2001 constructs. The spec explicitly requires **SystemVerilog**,
where `logic` is the correct unified net/variable type for both ports and internal signals.
Using `reg` on an output is legal but semantically misleading — `reg` does not guarantee a
physical register; `logic` inside `always_ff` does. Additionally, `32'd0` is an **unsigned**
literal; assigning it to a `signed [31:0]` output is harmless here but signals sloppy handling
of sign semantics that could matter in more complex designs.

#### (c) Corrected version
```systemverilog
    input  logic        clk,
    input  logic        rst,
    input  logic signed [7:0]  a,
    input  logic signed [7:0]  b,
    output logic signed [31:0] out
    ...
    out <= 32'sd0;   // signed literal
```

---

## Yosys Synthesis — `mac_correct.v`

```
$ yosys -p 'read_verilog -sv mac_correct.v; synth -top mac; stat'

=== mac ===

   Number of wires:               1039
   Number of wire bits:           1301
   Number of public wires:           5
   Number of public wire bits:      50
   Number of memories:               0
   Number of memory bits:            0
   Number of processes:              0
   Number of cells:               1091
     $_ANDNOT_                     351
     $_AND_                         61
     $_NAND_                        46
     $_NOR_                         33
     $_NOT_                         47
     $_ORNOT_                       18
     $_OR_                         133
     $_SDFF_PP0_                    32    ← 32 synchronous DFFs, one per output bit
     $_XNOR_                        97
     $_XOR_                        273

Checking module mac...
Found and reported 0 problems.
```

Yosys infers exactly 32 `$_SDFF_PP0_` (synchronous D flip-flop, positive clock, active-high reset)
cells — one per accumulator bit — confirming correct synthesis of the intended behavior.
No combinational loops, no latches, no problems.

---

## File Inventory

| File | Purpose | Status |
|------|---------|--------|
| `hdl/mac_llm_A.v` | Claude Sonnet 4.6 output | 5 tests FAILED (registered product bug) |
| `hdl/mac_llm_B.v` | GPT-4o output | 7 tests FAILED (inverted reset + wrong process type) |
| `hdl/mac_tb.v` | Shared testbench | — |
| `hdl/mac_correct.v` | Corrected synthesizable module | ALL TESTS PASSED, Yosys clean |
| `review/mac_code_review.md` | This document | 3 issues documented |
