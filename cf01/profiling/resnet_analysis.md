
# ResNet-18 profiling analysis

Input: batch = 1, FP32, tensor shape = `3×224×224`.

## Five layers with the highest MAC count

| Rank | Layer name | Layer type | MACs | Parameters |
|---:|---|---|---:|---:|
| 1 | `conv1`          | Conv2d | 118,013,952 | 9,408 |
| 2 | `layer1.0.conv1` | Conv2d | 115,605,504 | 36,864 |
| 3 | `layer1.0.conv2` | Conv2d | 115,605,504 | 36,864 |
| 4 | `layer1.1.conv1` | Conv2d | 115,605,504 | 36,864 |
| 5 | `layer1.1.conv2` | Conv2d | 115,605,504 | 36,864 |

## Arithmetic intensity for the most MAC-intensive layer

Most MAC-intensive layer: `conv1` (Conv2d)

- Input shape: `(1, 3, 224, 224)` → input bytes = `150,528 × 4 = 602,112` B
- Output shape: `(1, 64, 112, 112)` → output bytes = `802,816 × 4 = 3,211,264` B
- Weights: `9,408` parameters → weight bytes = `9,408 × 4 = 37,632` B
- Total DRAM traffic (no reuse assumption): `602,112 + 3,211,264 + 37,632 = 3,851,008` B
- FLOPs from MACs: `2 × 118,013,952 = 236,027,904` FLOPs
- Arithmetic intensity: `236,027,904 / 3,851,008 = 61.29` FLOPs/byte
