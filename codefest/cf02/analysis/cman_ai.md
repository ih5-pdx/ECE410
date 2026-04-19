# Arithmetic Intensity Calculation for Dominant Kernel

## Kernel

Transformer linear projection:

Y = X * W

with:
- X: 128 x 256
- W: 256 x 256
- Y: 128 x 256

## FLOPs

For matrix multiplication, FLOPs = 2 * M * N * K

Substituting values:

```
FLOPs = 2 * M * N * K
FLOPs = 2 * 128 * 256 * 256
FLOPs = 16,777,216
```

## Bytes Transferred

Assume FP32 data (4 bytes per element), all operands loaded/stored from DRAM with no reuse.

### Input matrix X

```
Bytes(X) = 128 * 256 * 4 = 131,072 bytes
```

### Weight matrix W

```
Bytes(W) = 256 * 256 * 4 = 262,144 bytes
```

### Output matrix Y

```
Bytes(Y) = 128 * 256 * 4 = 131,072 bytes
```

### Total bytes

```
Bytes(total) = 131,072 + 262,144 + 131,072 = 524,288 bytes
```

## Arithmetic Intensity

```
AI = FLOPs / Bytes
AI = 16,777,216 / 524,288
AI = 32 FLOPs/byte
```

## Result

The arithmetic intensity of the dominant kernel is **32 FLOPs/byte**.
