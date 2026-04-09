# Interface Selection and Bandwidth Analysis

## Selected Interface
The selected host-to-chiplet interface is **AXI-Lite** for control and configuration.

AXI-Lite was chosen because it is a standard and widely understood hardware interface that is simple to integrate into a custom hardware design. It is well suited for:
- register reads and writes
- control signals
- status reporting
- starting and stopping the accelerator

## Why This Interface Was Chosen
This project focuses on building and verifying a matrix multiplication accelerator, so it is important to keep the host interface manageable. AXI-Lite is simpler than a full high-throughput memory-mapped interface and is a reasonable choice for a first version of the chiplet design.

The host software can use AXI-Lite to:
1. write input/output addresses or configuration values,
2. set matrix dimensions,
3. start the computation,
4. poll for completion,
5. read status or result-ready flags.

## Bandwidth Considerations
The dominant kernel is matrix multiplication. For the chosen example workload:

- \(X \in \mathbb{R}^{128 \times 256}\)
- \(W \in \mathbb{R}^{256 \times 256}\)
- \(Y \in \mathbb{R}^{128 \times 256}\)

Assuming FP32 data:
- Input matrix \(X\): \(128 \cdot 256 \cdot 4 = 131{,}072\) bytes
- Weight matrix \(W\): \(256 \cdot 256 \cdot 4 = 262{,}144\) bytes
- Output matrix \(Y\): \(128 \cdot 256 \cdot 4 = 131{,}072\) bytes

Total data movement per operation:

\[
131{,}072 + 262{,}144 + 131{,}072 = 524{,}288 \text{ bytes}
\]

## Interface Implication
AXI-Lite is appropriate for **control traffic**, but it is not intended to stream all matrix data at high speed. Because matrix multiplication moves a large amount of data, the final accelerator will likely need local buffering or a higher-throughput data path behind the control interface.

For a simple first milestone, AXI-Lite is still a valid interface choice because it defines a standard way for the host to communicate with the chiplet. The interface can control the accelerator even if future revisions require a more efficient mechanism for moving matrix data.

## Conclusion
AXI-Lite is selected because it is simple, standard, and practical for control and configuration. It keeps the initial chiplet integration manageable while still providing a clear host-to-accelerator interface. The bandwidth analysis shows that bulk matrix data movement is significant, so the data path may need to be expanded in later milestones if the target throughput grows.
