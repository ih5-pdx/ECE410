# CMAN CF04 — Symmetric Per-Tensor INT8 Quantization

**Weight Matrix W (FP32):**

```
W = [  0.85,  -1.20,   0.34,   2.10 ]
    [ -0.07,   0.91,  -1.88,   0.12 ]
    [  1.55,   0.03,  -0.44,  -2.31 ]
    [ -0.18,   1.03,   0.77,   0.55 ]
```

---

## (a) Scale Factor — Symmetric Per-Tensor Quantization

**Formula:** `S = max(|W|) / 127`

Scanning all 16 absolute values, the maximum is:

```
max(|W|) = |-2.31| = 2.31
```

```
S = 2.31 / 127 = 0.018189
```

---

## (b) INT8 Quantization Matrix W_q

**Formula:** `W_q = clamp( round(W / S), −128, 127 )`

Each element is divided by S, rounded to the nearest integer, and clamped to the INT8 range [−128, 127].

```
W_q = [   47,  -66,   19,  115 ]
      [   -4,   50, -103,    7 ]
      [   85,    2,  -24, -127 ]
      [  -10,   57,   42,   30 ]
```

> Note: The element W[2][3] = −2.31 maps to round(−2.31 / 0.018189) = round(−127.0) = −127
> (not −128), preserving the symmetric range exactly.

---

## (c) Dequantized Matrix W_deq (FP32)

**Formula:** `W_deq = W_q × S`

```
W_deq = [  0.8549,  -1.2005,   0.3456,   2.0917 ]
        [ -0.0728,   0.9094,  -1.8735,   0.1273 ]
        [  1.5461,   0.0364,  -0.4365,  -2.3100 ]
        [ -0.1819,   1.0368,   0.7639,   0.5457 ]
```

---

## (d) Error Analysis

**Per-element absolute error |W − W_deq|:**

```
|W - W_deq| = [ 0.00488,  0.00047,  0.00559,  0.00827 ]
              [ 0.00276,  0.00055,  0.00654,  0.00732 ]
              [ 0.00394,  0.00638,  0.00346,  0.00000 ]
              [ 0.00189,  0.00677,  0.00606,  0.00433 ]
```

**Largest error element:**

| Location | W value | W_deq value | Absolute Error |
|----------|---------|-------------|----------------|
| Row 0, Col 3 | 2.1000 | 2.0917 | **0.00827** |

**Mean Absolute Error (MAE):**

```
MAE = sum(|W − W_deq|) / 16 = 0.069220 / 16 = 0.004326
```

---

## (e) Bad Scale Experiment — S_bad = 0.01

Using S_bad = 0.01 (too small — about 1.8× smaller than the correct S):

**Quantization with S_bad:**

```
W_q_bad = clamp( round(W / 0.01), −128, 127 )
```

Because W / 0.01 produces values up to 231, which far exceeds INT8 range, many elements
**saturate (clamp) at ±127/−128**:

```
W_q_bad = [   85,  -120,   34,  127 ]
           [   -7,    91, -128,   12 ]
           [  127,     3,  -44, -128 ]
           [  -18,   103,   77,   55 ]
```

**Dequantized with S_bad:**

```
W_deq_bad = [  0.85,  -1.20,   0.34,   1.27 ]
            [ -0.07,   0.91,  -1.28,   0.12 ]
            [  1.27,   0.03,  -0.44,  -1.28 ]
            [ -0.18,   1.03,   0.77,   0.55 ]
```

**MAE (S_bad):**

```
MAE_bad = 0.171250   (≈ 40× worse than correct MAE of 0.004326)
```

**Explanation:**
When S is too small, large-magnitude weights overflow the INT8 representable range and
**saturate at ±127/−128**, causing catastrophic clipping errors that cannot be recovered
during dequantization — the original magnitude information is permanently lost.
