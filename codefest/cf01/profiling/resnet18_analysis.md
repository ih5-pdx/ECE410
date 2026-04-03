# ResNet-18 profiling analysis

Input: batch = 1, FP32, tensor shape = 3×224×224.

## Five layers with the highest MAC count

| Layer | MACs | Parameters |
|---|---:|---:|
| Conv2d: 1-1 | 118,013,952 | 9,408 |
| Conv2d: 3-1 | 115,605,504 | 36,864 |
| Conv2d: 3-4 | 115,605,504 | 36,864 |
| Conv2d: 3-7 | 115,605,504 | 36,864 |
| Conv2d: 3-10 | 115,605,504 | 36,864 |

- Input shape: (1, 3, 224, 224) → input bytes = 150,528 × 4 = 602,112 byte
- Output shape: (1, 64, 112, 112) → output bytes = 802,816 × 4 = 3,211,264 byte
- Weights: 9,408 parameters → weight bytes = 9,408 × 4 = 37,632 byte
- Total Memory traffic (no reuse assumption): 602,112 + 3,211,264 + 37,632 = 3,851,008 byte
- FLOPs from MACs: 2 × 118,013,952 = 236,027,904 FLOPs
- Arithmetic intensity: 236,027,904 / 3,851,008 = 61.29 FLOPs/byte
