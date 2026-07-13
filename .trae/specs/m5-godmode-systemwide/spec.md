# M5 God-Mode System-Wide Spec

## Why
We successfully unlocked 27.6 TFLOPS on the ANE and implemented a concurrent GPU+ANE execution model (66/34 split) for a custom MLX-based Python app. However, this power is isolated. To truly realize the "M6-Killer" initiative, we must make this concurrency system-wide so that mainstream applications (like Chrome, Minecraft, and Ollama) can natively leverage the combined 70+ TFLOPS of the M5 Max. Furthermore, we need to accurately benchmark the upper limits of the 40-core GPU using a raw Metal stress tester.

## What Changes
- Implement a pure Metal (Objective-C++) GPU Stress Tester to push the 40-core GPU to 45W and measure its peak FP16 TFLOPS.
- Develop a `DYLD_INTERPOSE` dynamic library (`libmetal_interceptor.dylib`) to hook Metal compute dispatches (`MTLComputeCommandEncoder`) at the OS level.
- Define the strategy to directly patch `ggml-metal.m` in `llama.cpp` for native Ollama support without DYLD tricks.

## Impact
- Affected specs: System-wide Metal API compute dispatching, local LLM inference engines.
- Affected code: `llama.cpp` (specifically Metal backend), macOS `MTLComputeCommandEncoder` runtime behavior.

## ADDED Requirements
### Requirement: GPU Performance Baseline
The system SHALL provide a raw Metal stress tester capable of executing heavily unrolled FMAC operations to saturate the GPU ALU and measure max TFLOPS.

#### Scenario: Running GPU Stress Test
- **WHEN** user executes `gpu_stress_tester`
- **THEN** the GPU draws maximum power (up to 45W) and outputs real-time TFLOPS metrics.

### Requirement: System-Wide Concurrency Injection
The system SHALL intercept Metal compute commands globally via a dynamic library.

#### Scenario: Running third-party ML apps
- **WHEN** user launches a Metal-heavy app with `DYLD_INSERT_LIBRARIES=libmetal_interceptor.dylib`
- **THEN** compute workloads exceeding 1,000,000 threads are split, with 34% offloaded to the ANE and 66% sent to the GPU.
