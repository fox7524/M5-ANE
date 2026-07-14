# Proxy and MLX Team ID Fix Spec

## Why
1. **GGUF ANE Usage:** The previous solution replaced the proxy script with the original `llama-server` binary directly. This bypassed the Mach-O restriction but lost the ability to inject ANE-specific arguments (like tensor split). As a result, GGUF models load but do not use the Apple Neural Engine.
2. **MLX Team ID Error:** The `python3.11` binary patching logic used `head -n 1`, which only patched one of the many Python environments created by LM Studio. When LM Studio runs a different environment (e.g. `@31`), the Team ID error persists.
3. **UI / Restore Issues:** The injection state gets stuck because `restore` doesn't properly restore all environments, and the user wants strict manual control over injection without any automatic background behavior.

## What Changes
- **C++ Mach-O Proxy for GGUF:** Create a true compiled C++ proxy (`llama-proxy.cpp`) that acts as a wrapper. It will intercept the arguments from LM Studio, inject ANE tensor splitting flags, and `execv` the original `llama-server.orig`.
- **Comprehensive MLX Patching:** Update `inject_lmstudio.sh` to iterate through *all* `python3.11` binaries in the backends directory and patch them all (remove signature, clear quarantine, ad-hoc sign). Do the same for `restore`.
- **UI & State Management:** Refactor `App.swift` to ensure injection and restoration are strictly manual. Provide clear error handling and ensure the UI correctly reflects the true state of the file system.

## Impact
- Affected code: `M5UltimateApp/inject_lmstudio.sh`, `M5UltimateApp/App.swift`, `M5UltimateApp/build.sh`
- New files: `M5UltimateApp/payloads/llama/llama-proxy.cpp`

## MODIFIED Requirements
### Requirement: GGUF ANE Injection
The system SHALL intercept LM Studio's call to `llama-server` using a compiled Mach-O proxy that modifies arguments to enable ANE, rather than just replacing the binary.

### Requirement: MLX Library Validation
The system SHALL disable Library Validation on ALL `python3.11` binaries used by LM Studio MLX backends to prevent Team ID mismatch errors when loading the custom `core.cpython-311-darwin.so`.

### Requirement: Manual Injection Control
The UI SHALL NOT perform any injection or restoration operations automatically on startup or shutdown. It SHALL accurately reflect the disk state and allow the user to explicitly trigger Inject or Restore.
