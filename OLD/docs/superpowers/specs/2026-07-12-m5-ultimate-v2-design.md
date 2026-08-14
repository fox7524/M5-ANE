# M5 Ultimate V2 (M5 Engine) Design Spec

## 1. Overview
A native macOS application (SwiftUI + C++) acting as an integrated LLM ecosystem and hardware control center. It bypasses third-party Hardened Runtime/SIP injection issues by hosting its own `llama-server` and `mlx` engines locally.

## 2. UI/UX Architecture (3-Pane Layout)
- **Left Column (Library & Discovery)**: 
  - HuggingFace search and download functionality.
  - Local Models list (auto-scans `~/.lmstudio/models`, `~/.ollama/models`).
  - Settings to define custom model paths.
- **Center Column (Playground & Chat)**: 
  - Chat interface communicating with the local API.
  - Engine status indicator (Running/Stopped) and model selection.
- **Right Column (Hardware Control Center)**: 
  - Real-time ANE and GPU load rings.
  - **Tensor Split Slider**: 0% to 100% dynamic adjustment (default 68% GPU / 32% ANE).
  - Real-time TFLOPS, TOPS, and Watt (power consumption) metrics.

## 3. Backend & Execution
- **Engines**: The app embeds custom-compiled `llama-server` (for GGUF) and a Python environment wrapper for MLX.
- **Execution Strategy**: The Swift app spawns these engines as child processes with `DYLD_INSERT_LIBRARIES=libmetal_interceptor.dylib` injected into their environment. Because the parent app owns the processes, macOS Library Validation and Hardened Runtime do not block the injection.
- **IPC**: The Chat UI communicates with the spawned engines via local HTTP API (e.g., `localhost:1234`).
- **Hardware Bridge**: Dynamic tensor splitting updates are sent from the UI slider to the Metal interceptor via shared memory or local IPC.

## 4. Engineering Standards
- Subagents will be utilized to parallelize the development of UI, Backend, and Interceptor components.
- All code must include comprehensive inline comments explaining the logic, especially around process spawning and memory mapping.
- A detailed `README.md` will be provided for the new architecture.