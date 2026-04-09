# Arithmetic Intensity Calculation for Dominant Kernel

## Kernel
Transformer linear projection:
\[
Y = XW
\]

with:
- \(X \in \mathbb{R}^{128 \times 256}\)
- \(W \in \mathbb{R}^{256 \times 256}\)
- \(Y \in \mathbb{R}^{128 \times 256}\)

## FLOPs
For matrix multiplication:
\[
\text{FLOPs} = 2MNK
\]

Substituting:
\[
\text{FLOPs} = 2 \cdot 128 \cdot 256 \cdot 256
\]

\[
= 16{,}777{,}216 \text{ FLOPs}
\]

## Bytes Transferred
Assume FP32 data, so each element is 4 bytes, and assume all operands are loaded/stored from DRAM with no reuse.

### Input matrix \(X\)
\[
128 \cdot 256 \cdot 4 = 131{,}072 \text{ bytes}
\]

### Weight matrix \(W\)
\[
256 \cdot 256 \cdot 4 = 262{,}144 \text{ bytes}
\]

### Output matrix \(Y\)
\[
128 \cdot 256 \cdot 4 = 131{,}072 \text{ bytes}
\]

### Total bytes
\[
131{,}072 + 262{,}144 + 131{,}072 = 524{,}288 \text{ bytes}
\]

## Arithmetic Intensity
\[
\text{AI} = \frac{\text{FLOPs}}{\text{Bytes}} =
\frac{16{,}777{,}216}{524{,}288}
\]

\[
= 32 \text{ FLOPs/byte}
\]

## Result
The arithmetic intensity of the dominant kernel is:

\[
\boxed{32 \text{ FLOPs/byte}}
\]
