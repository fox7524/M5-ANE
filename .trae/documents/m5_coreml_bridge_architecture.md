# M5 Ultimate: CoreML + Metal Hybrid Architecture

To achieve 100% ANE + 100% GPU utilization, we must bypass the limitations of standard `llama.cpp` and `MLX`, neither of which natively support dispatching to the Apple Neural Engine via CoreML while simultaneously keeping the GPU fed with Metal commands for LLMs.

## The Strategy: The CoreML Python Bridge

Instead of trying to hack `llama.cpp`'s C++ codebase (which lacks CoreML LLM support entirely), we will build our ultimate engine using Python, leveraging `coremltools` and `mlx-lm`.

1. **Model Loading & Partitioning:**
   - When a model is loaded, we intercept it.
   - We extract the Feed-Forward Network (FFN) layers (the compute-heavy part).
   - We convert *only* these FFN layers into Apple's `.mlmodelc` (CoreML) format.

2. **Heterogeneous Execution (The Bridge):**
   - We write a custom Python inference loop (acting as the backend for LM Studio).
   - For every token generated:
     - The **Attention / KV Cache** is calculated on the 20-Core GPU using `mlx`.
     - The output of the attention layer is passed to the CoreML model (FFN), which executes on the **Apple Neural Engine (ANE)**.
     - We use Zero-Copy memory sharing (IOSurface / numpy arrays) to pass the data between MLX (GPU) and CoreML (ANE) without CPU overhead.

3. **LM Studio Integration:**
   - We package this Python script into an executable format or use LM Studio's existing Python virtual environment (`_amphibian`).
   - We create a custom `backend-manifest.json` that points to our Python bridge instead of the standard `llama-server`.

This is the *only* way to light up the ANE in Activity Monitor while keeping the GPU drawing 50W.