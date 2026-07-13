# M5 God-Mode: Metal Interceptor (MI) Architecture Design

## Overview
The Metal Interceptor (MI) is a dynamic library injection mechanism designed to act as a "Middle-Man Processor Layer" between macOS applications and the Apple Silicon GPU. Its primary goal is to establish a "handshake" between the GPU and the Apple Neural Engine (ANE), enabling simultaneous utilization of both hardware components during heavy computational tasks like Local LLM inference (Ollama, LM Studio, LokumAI) and gaming (Minecraft).

## Core Objectives
1.  **Hooking Metal API:** Intercept high-level Metal API calls (`MTLCommandBuffer`, `MTLComputeCommandEncoder`) made by target applications.
2.  **Workload Routing:** Analyze the intercepted workload. If it's a massive matrix multiplication (typical of LLMs), route it to the ANE via the `ANE-main` bridge. If it's standard graphics rendering, pass it to the GPU.
3.  **Zero-Copy Handshake:** Utilize `IOSurface` to allow the GPU and ANE to share the exact same physical memory buffer without costly memory copying.

## Target Applications
*   **Local LLMs (Ollama, LM Studio, LokumAI):** These rely heavily on Metal for tensor operations. MI will intercept these matrix math dispatches and offload them to the ANE, significantly boosting token generation speed.
*   **Minecraft (Gaming):** MI will intercept rendering buffers and utilize the ANE for AI-driven tasks (e.g., real-time upscaling or telemetry analysis) while the GPU handles rasterization.

## Architecture Components

### 1. The Injector (`mi_launcher.sh`)
A shell script that launches the target application (e.g., Ollama) with the `DYLD_INSERT_LIBRARIES` environment variable set. This forces macOS to load our interceptor library into the application's memory space before any other libraries.

### 2. The Interceptor Library (`libane_interceptor.dylib`)
The core C/Objective-C library that performs the actual hooking.
*   **Method Swizzling:** Uses Objective-C runtime features (or `fishhook` for C functions) to replace Apple's original Metal methods with our custom implementations.
*   **The Hook:** Specifically targets `-[MTLComputeCommandEncoder dispatchThreadgroups:threadsPerThreadgroup:]` and `-[MTLCommandBuffer commit]`.

### 3. The Router & Bridge (`MI_Router.mm`)
The brain of the interceptor.
*   **Heuristics:** Analyzes the `MTLComputePipelineState` (the shader being executed). If it looks like a large MatMul (e.g., used in LLM prefill/decode), it triggers the ANE.
*   **ANE-main Integration:** Directs the data to the bare-metal `ane_bridge` (from the ANE-main project) to execute the operation on the Neural Engine using the DART bypassed memory.

## Data Flow (Example: Ollama Inference)
1.  User runs `mi_launcher.sh ollama run llama3`.
2.  Ollama allocates memory and prepares a Metal Command Buffer for a MatMul operation.
3.  Ollama calls `[encoder dispatchThreadgroups:...]`.
4.  **INTERCEPTED!** `libane_interceptor` catches the call.
5.  `MI_Router` recognizes the heavy MatMul signature.
6.  `MI_Router` translates the Metal buffer into an ANE MIL request via `ane_bridge`.
7.  ANE executes the MatMul in < 1ms (as seen in our 27 TOPS tests).
8.  `MI_Router` returns control to Ollama, pretending the GPU did the work.

## Fallback & Safety
If the ANE bridge fails or the workload is unrecognized, the interceptor immediately calls the original, unswizzled Metal function, ensuring the application (e.g., Minecraft) continues running smoothly on the GPU without crashing.