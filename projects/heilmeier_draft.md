## Heilmeier Catechism

### 1. What are you trying to do?
We are trying to build a small hardware unit that can multiply matrices faster than a normal software program running on a general-purpose processor. The goal is to speed up one of the most common math operations used in artificial intelligence and machine learning. We will design the hardware, test that it works correctly, connect it to a host system, and compare its performance against a software-only version.

### 2. How is it done today, and what are the limits of current practice?
Today, matrix multiplication is usually done in software on a CPU or on larger accelerators such as GPUs. A CPU can do this work, but it is not always the fastest or most efficient choice when the same multiply-and-add steps must be repeated many times. GPUs can perform this operation much faster, but they are more complex, require more resources, and are outside the scope of a small custom chiplet design project.

### 3. What is new in your approach and why do you think it will be successful?
Our approach is to build a custom hardware block that is dedicated only to matrix multiplication instead of relying on a general-purpose processor to handle the entire task. Because the hardware is focused on one repeated operation, it can perform the work in a more direct and efficient way. We believe this approach will be successful because matrix multiplication has a clear and regular pattern, is easy to verify for correctness, and is widely known to benefit from hardware acceleration.
