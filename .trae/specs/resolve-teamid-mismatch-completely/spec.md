# Resolve Team ID Mismatch Completely Spec

## Why
The previous injection attempts failed to fully bypass macOS Hardened Runtime for MLX and GGUF. Although the files were ad-hoc signed, `codesign` was executed without the proper XML entitlements. As a result, macOS Library Validation still blocked `core.cpython-311-darwin.so` and `libmlx.dylib` from being loaded into the Python mapping process, causing a "Team ID mismatch" crash. Additionally, GGUF (`llama-proxy` and `llama-server.ane`) failed to load properly likely due to similar signature/entitlement restrictions.

## What Changes
- Update `inject_lmstudio.sh` to dynamically generate an `entitlements.xml` file containing `<key>com.apple.security.cs.disable-library-validation</key>` and `<key>com.apple.security.cs.allow-unsigned-executable-memory</key>`.
- Apply these explicit entitlements during the `codesign` step for `python3.11`, `core.cpython-311-darwin.so`, and `libmlx.dylib`.
- Update `build.sh` to apply the same entitlements to the compiled `llama-proxy` and `llama-server.ane` payloads.

## Impact
- Affected specs: MLX model loading, GGUF model loading, ANE injection proxy.
- Affected code: `M5UltimateApp/inject_lmstudio.sh`, `M5UltimateApp/build.sh`.

## MODIFIED Requirements
### Requirement: MLX and GGUF Injection
All injected executables and dynamic libraries MUST be signed with an ad-hoc signature that explicitly disables macOS Library Validation, ensuring that processes with different original Team IDs (like LM Studio's Python interpreter) can load them without crashing.