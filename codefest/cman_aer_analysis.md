# CMAN CF08 — AER Bandwidth Analysis
**SNN Accelerator Off-Chip Output Interface**
*Parameters: N = 1024 neurons, f = 50 Hz mean firing rate, 20 bits/packet*

---

## Task 1 — Mean Aggregate Spike Rate

**Formula:** `R = N × f`

```
R = 1024 neurons × 50 spikes/s/neuron
R = 51,200 spikes/s
```

**Mean aggregate spike rate: R = 51,200 spikes/s**

---

## Task 2 — Mean AER Bandwidth

**Packet format:**

| Field              | Bits |
|--------------------|------|
| Neuron address     | 10   |
| Timestamp          | 6    |
| Framing/parity     | 4    |
| **Total per packet** | **20** |

**Formula:** `B = R × 20 bits/packet`

```
B = 51,200 spikes/s × 20 bits/spike
B = 1,024,000 bits/s
B = 1.024 Mbit/s
```

**Mean AER bandwidth: B ≈ 1.024 Mbit/s**

---

## Task 3 — Interface Comparison

| Interface  | Rated Bandwidth    | Sustains Mean Rate (1.024 Mbit/s)? | Notes |
|------------|--------------------|------------------------------------|-------|
| I²C        | ≤ 3.4 Mbit/s       | **Yes**                            | Fast-mode+ just barely covers mean; negligible margin for bursts |
| SPI        | ≤ 50 Mbit/s        | **Yes**                            | 49× headroom over mean; ample burst margin |
| AXI4-Lite  | ≈ 100 Mbit/s (eff) | **Yes**                            | 98× headroom; overspecified for mean rate alone |

**Lowest-complexity interface that sustains the mean rate: I²C**

I²C at up to 3.4 Mbit/s (Fast-mode+) technically covers the 1.024 Mbit/s mean, though as shown in Task 4 it cannot absorb burst peaks without buffering. SPI is the lowest-complexity interface with meaningful burst headroom.

---

## Task 4 — Burst-Peak Bandwidth

**Burst scenario:** 25% of 1024 neurons fire within a 1 ms window.

**Number of spikes in burst:**

```
N_burst = 0.25 × 1024 = 256 spikes
```

**Bits to transmit:**

```
Bits_burst = 256 spikes × 20 bits/spike = 5,120 bits
```

**Peak instantaneous bandwidth (over 1 ms window):**

```
B_peak = 5,120 bits / 0.001 s = 5,120,000 bits/s = 5.12 Mbit/s
```

**Burst-to-mean ratio:**

```
Ratio = B_peak / B_mean = 5.12 Mbit/s / 1.024 Mbit/s = 5×
```

**Interface assessment during burst:**

| Interface  | Rated BW       | Can absorb 5.12 Mbit/s burst? | Decision |
|------------|----------------|-------------------------------|----------|
| I²C        | ≤ 3.4 Mbit/s   | **No** (burst exceeds limit)  | Requires FIFO buffer |
| SPI        | ≤ 50 Mbit/s    | **Yes** (9.8× headroom)       | Can absorb directly |
| AXI4-Lite  | ≈ 100 Mbit/s   | **Yes** (19.5× headroom)      | Can absorb directly |

**Buffering requirement for I²C:**

If using I²C, a FIFO buffer is required to absorb the burst. Minimum buffer depth:

```
Excess bits during burst = (5.12 - 3.4) Mbit/s × 0.001 s
                         = 1.72 Mbit/s × 0.001 s
                         = 1,720 bits
                         ≈ 86 packets × 20 bits/packet
```

A FIFO of at least ~128 entries (packets) provides adequate margin. This is readily implementable on-chip, but adds design complexity and latency.

**Recommendation:** Given the 5× burst-to-mean ratio, **SPI** is the lowest-complexity interface that can sustain both mean and peak rates without buffering.

---

## Task 5 — Frame-Based vs AER Comparison

### Frame-based bandwidth

A conventional readout samples all 1024 neurons every 1 ms, sending 1 bit per neuron:

```
B_frame = 1024 bits / 0.001 s = 1,024,000 bits/s = 1.024 Mbit/s
```

### AER-to-frame ratio at f = 50 Hz

At f = 50 Hz mean firing rate, mean AER bandwidth = 1.024 Mbit/s (from Task 2).

```
Ratio = B_AER / B_frame = 1.024 Mbit/s / 1.024 Mbit/s = 1.0
```

At f = 50 Hz, AER and frame-based bandwidths happen to be **equal**.

### Crossover firing rate f_crossover

Set AER bandwidth equal to frame bandwidth:

```
B_AER = B_frame

N × f_crossover × 20 = N × (1/T_frame) × 1 bit

where T_frame = 1 ms = 0.001 s, so 1/T_frame = 1000 samples/s

N × f_crossover × 20 = N × 1000

f_crossover = 1000 / 20 = 50 Hz
```

**f_crossover = 50 Hz**

> This confirms the calculation above: at exactly 50 Hz mean firing rate, AER and frame-based methods consume identical bandwidth. AER provides a bandwidth advantage only when the mean firing rate is **below 50 Hz** — i.e., AER is the right choice for sparse, low-activity spiking networks where most neurons are silent most of the time, making the event-driven approach far more efficient than clocked frame readout.

---

## Summary Reference Card

| Quantity | Formula | Value |
|----------|---------|-------|
| Mean aggregate spike rate | R = N × f | **51,200 spikes/s** |
| Mean AER bandwidth | B = R × 20 | **1.024 Mbit/s** |
| Peak burst bandwidth (25% neurons, 1 ms) | N·0.25·20/T | **5.12 Mbit/s** |
| Burst-to-mean ratio | B_peak / B_mean | **5×** |
| Frame-based bandwidth (1 ms frame) | N × 1/T | **1.024 Mbit/s** |
| AER/frame ratio at f = 50 Hz | B_AER / B_frame | **1.0** |
| Crossover firing rate | f = 1000/20 | **50 Hz** |
| Lowest-complexity interface (mean only) | — | I²C (3.4 Mbit/s) |
| Lowest-complexity interface (with bursts) | — | **SPI (50 Mbit/s)** |

---

*Analysis by: cman | N=1024 neurons, f=50 Hz, 20 bits/packet AER*
