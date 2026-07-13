# Tasks
- [x] Task 1: Create Metal GPU Stress Tester: Implement a heavily unrolled FMAC Metal kernel and an Objective-C++ host app to push the GPU to its thermal/power limits and calculate TFLOPS.
  - [x] SubTask 1.1: Write the `.metal` kernel code with unrolled FP16 loops.
  - [x] SubTask 1.2: Write the `gpu_stress_tester.m` host app to dispatch the kernel and measure `mach_absolute_time()`.
  - [x] SubTask 1.3: Compile the kernel and host application.
- [x] Task 2: Create Generic Metal Interceptor: Develop a `DYLD_INTERPOSE` library that hooks `dispatchThreadgroups:` across all Metal encoders.
  - [x] SubTask 2.1: Write `metal_interceptor.m` using Objective-C runtime swizzling.
  - [x] SubTask 2.2: Implement logic to identify large compute payloads and modify grid sizes for the 66/34 split.
  - [x] SubTask 2.3: Compile into `libmetal_interceptor.dylib`.

# Task Dependencies
- [Task 2] depends on the baseline metrics established in [Task 1].
