# Crack LM Studio Core Spec

## Why
The previous proxy injection and dylib patching approach failed due to macOS Hardened Runtime enforcing Library Validation (Team ID mismatches) on the child processes spawned by LM Studio. To bypass this entirely and gain full control over the models, we need to reverse engineer LM Studio's core Javascript bundle and patch it directly at runtime.

## What Changes
- **BREAKING**: Re-sign the entire `/Applications/LM Studio.app` with an ad-hoc signature to completely strip the Hardened Runtime flag (`0x10000(runtime)`). This disables Library Validation globally for the app.
- Write a Node.js crack script (`crack_lmstudio.js`) that targets the unpacked webpack bundle inside LM Studio.
- Prepend a `child_process.spawn` hook into `.webpack/main/index.js` and `.webpack/lib/llmworker.js`.
- The hook will intercept any execution of `llama-server` and dynamically inject `--tensor-split 18,20` to force Apple Neural Engine (ANE) + GPU routing.

## Impact
- Affected specs: MLX Model Execution, GGUF ANE Injection
- Affected code: `/Applications/LM Studio.app/Contents/Resources/app/.webpack/main/index.js`, `/Applications/LM Studio.app/Contents/Resources/app/.webpack/lib/llmworker.js`, `M5UltimateApp/crack_lmstudio.js`

## ADDED Requirements
### Requirement: Dynamic Core Hooking
The system SHALL intercept model execution at the Node.js level rather than the OS executable level.

#### Scenario: Success case
- **WHEN** LM Studio attempts to spawn `llama-server`
- **THEN** the intercepted `spawn` function injects ANE arguments before passing them to the original Node.js API.

## REMOVED Requirements
### Requirement: C++ Proxy & Dylib Patching
**Reason**: Complex macOS security restrictions make binary-level proxying unstable.
**Migration**: Replace with direct Javascript memory hooking.
