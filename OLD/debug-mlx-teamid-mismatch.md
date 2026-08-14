# Debug Session: mlx-teamid-mismatch

## Status
[OPEN]

## Bug Description
- **Symptoms**: 
  1. MLX Python process crashes with `Team ID mismatch` when loading `core.cpython-311-darwin.so`.
  2. GGUF `llama-server` does not start (proxy logs are empty), likely because LM Studio cannot execute a bash script via `posix_spawn`.
  3. User cannot revert injection from UI.
- **Environment**: macOS Apple Silicon, LM Studio, Hardened Runtime.

## Hypotheses
1. **GGUF Proxy Failure**: LM Studio uses `posix_spawn` without a shell, meaning our `llama-server` bash script proxy is instantly rejected by the OS. A compiled Mach-O binary proxy is required.
2. **MLX Team ID Mismatch**: Ad-hoc signatures on ARM64 ignore the `disable-library-validation` entitlement if Hardened Runtime is enabled. Removing the signature, clearing quarantine (`xattr -cr`), and signing without entitlements disables Hardened Runtime entirely, fixing the issue.
3. **UI Restore Failure**: The `restore` script fails because of leftover permissions or incorrect state management in `App.swift`.

## Instrumentation & Execution Plan
- Replace bash script proxy with a C++ Mach-O proxy for `llama-server`.
- Update `inject_lmstudio.sh` to use `xattr -cr` and raw `codesign` without entitlements for MLX.
- Fix UI logic in `App.swift` to ensure manual-only injection/restoration.
