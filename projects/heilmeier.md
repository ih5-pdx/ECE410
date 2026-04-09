## Heilmeier Catechism

### 1. What are you trying to do?
We are trying to build a small hardware unit that speeds up matrix multiplication used in transformer inference. The goal is to improve the performance of one of the main mathematical operations used in modern AI systems. We will design the hardware, verify that it works correctly, connect it to a host system through a standard interface, and compare its performance against a software-only baseline.

### 2. How is it done today, and what are the limits of current practice?
Today, this work is usually done on general-purpose processors or larger accelerators that execute matrix multiplication in software libraries or highly optimized hardware platforms. Our profiling shows that matrix multiplication in the transformer linear layer accounts for the largest share of runtime in the selected workload. The main limit of the current software-only approach is that the same multiply-and-add pattern must be repeated many times, which creates a performance bottleneck and makes execution depend heavily on available compute throughput and memory bandwidth.

### 3. What is new in your approach and why do you think it will be successful?
Our approach is to build a custom hardware block that focuses only on matrix multiplication rather than relying on a general-purpose processor to handle the full workload. This is expected to work well because profiling identified matrix multiplication as the dominant kernel, and the roofline analysis shows that it is a strong candidate for acceleration. By dedicating hardware resources to this one repeated operation, the design can provide a more efficient path for the part of transformer inference that consumes the most runtime.
