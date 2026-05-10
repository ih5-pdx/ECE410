# CMAN CF06 — Sneak Paths in a Resistive Crossbar

**Array:** 2×2 resistive crossbar, row-major input, column current sensing  
**Cell resistances:** R[0][0] = 1 kΩ (ON), R[0][1] = 2 kΩ (OFF), R[1][0] = 2 kΩ (OFF), R[1][1] = 1 kΩ (ON)

---

## Circuit Topology

```
              Col 0 (V_col0)      Col 1 (V_col1)
               │                   │
V_row0 ──── R[0][0]=1kΩ ────── R[0][1]=2kΩ
               │                   │
V_row1 ──── R[1][0]=2kΩ ────── R[1][1]=1kΩ
               │                   │
            (sense)            (floating)
```

---

## (a) Ideal Read — I_col0 (all unused terminals grounded)

**Conditions:**
- V_row0 = 1 V (driven)
- V_col0 = 0 V (virtual ground, current-sensing)
- V_row1 = 0 V (grounded)
- V_col1 = 0 V (grounded)

**Analysis:**  
With row 1 and col 1 both held at 0 V, R[0][1] has 1 V across it but its current flows into the col 1 ground, *not* into col 0. R[1][0] has 0 V across it (both terminals at 0 V). The only current reaching col 0 is through R[0][0]:

```
I_col0_ideal = V_row0 / R[0][0]
             = 1 V / 1 kΩ
             = 1.000 mA
```

This correctly encodes the weight w[0][0] = 1/R[0][0] = 1 mS. ✓

---

## (b) KCL Solution for Floating Node Voltages

**Conditions:**
- V_row0 = 1 V (driven)
- V_col0 = 0 V (virtual ground)
- V_row1 = floating → unknown **V_r**
- V_col1 = floating → unknown **V_c**

No external current source or sink is attached to V_row1 or V_col1, so by KCL the net current into each floating node must be zero.

### KCL at V_row1

Currents leaving V_row1 through its two cells (positive = current out):

```
(V_r − 0) / R[1][0]  +  (V_r − V_c) / R[1][1]  =  0

(V_r) / 2  +  (V_r − V_c) / 1  =  0        [kΩ, mA]

V_r/2 + V_r − V_c  =  0

(3/2) V_r − V_c  =  0                        … (1)
```

### KCL at V_col1

Currents entering V_col1 through its two cells (positive = current in) must sum to zero (no load):

```
(V_row0 − V_c) / R[0][1]  +  (V_r − V_c) / R[1][1]  =  0

(1 − V_c) / 2  +  (V_r − V_c) / 1  =  0

0.5 − V_c/2 + V_r − V_c  =  0

V_r − (3/2) V_c  =  −0.5                     … (2)
```

### Solving the 2 × 2 System

From equation (1):

```
V_c  =  (3/2) V_r
```

Substituting into equation (2):

```
V_r − (3/2)(3/2) V_r  =  −0.5
V_r − (9/4) V_r  =  −0.5
−(5/4) V_r  =  −0.5
V_r  =  0.4 V
```

Back-substituting:

```
V_c  =  (3/2) × 0.4  =  0.6 V
```

**Result:**

| Node    | Voltage |
|---------|---------|
| V_row1  | **0.4 V** |
| V_col1  | **0.6 V** |

---

## (c) Actual I_col0 Including Sneak Path

Col 0 is held at virtual ground (0 V). Two resistors terminate on col 0:

| Contribution    | Path                          | Calculation                        | Current    |
|-----------------|-------------------------------|------------------------------------|------------|
| **Direct**      | Row 0 → R[0][0] → Col 0      | (1 V − 0 V) / 1 kΩ                | +1.000 mA  |
| **Sneak**       | Row 1 → R[1][0] → Col 0      | (0.4 V − 0 V) / 2 kΩ              | +0.200 mA  |

```
I_col0_actual  =  1.000 mA + 0.200 mA  =  1.200 mA
```

**Error introduced by sneak path:**

```
ΔI  =  I_actual − I_ideal  =  1.200 − 1.000  =  +0.200 mA   (+20%)
```

The sneak current flows via the path:

```
V_row0 (1 V) → R[0][1] (2 kΩ) → V_col1 (0.6 V) → R[1][1] (1 kΩ) → V_row1 (0.4 V) → R[1][0] (2 kΩ) → V_col0 (0 V)
```

This is the classical sneak path: two "OFF" cells in series (R[0][1] + R[1][1] + R[1][0]) that create an unintended conduction route from the driven row to the sensed column.

---

## (d) How Sneak Paths Corrupt MVM and Implications for Large Arrays

In analog crossbar MVM, each output column is supposed to sum only the currents from the selected row's cells, encoding the dot product between the input voltage vector and the column of conductance weights. Sneak paths introduce parasitic current that routes through unselected cells, inflating the sensed column current with contributions that do not correspond to any intended weight-input product; in this 2×2 example, a 20% error appears even with just one undriven row floating. In large arrays, the problem compounds severely: an N×N crossbar has O(N²) cells and each floating row-column junction can contribute a sneak path, so the spurious current grows roughly proportional to N while the signal grows proportionally, causing the signal-to-noise ratio in the analog domain to degrade and eventually making it impossible to distinguish "ON" from "OFF" cells without mitigation strategies such as 1T1R (one-transistor one-resistor) selector devices, active row clamping, or row-by-row sequential access that grounds all unselected rows.

---

*Analysis: CMAN | CF06 | Spring 2026*
