# M5 Ultimate App Fixes Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the MLX "Team ID mismatch" error by properly stripping and resigning the Python executable, lower the GGUF ANE threshold to 16 to ensure ANE triggers for small token generation, configure `.gitignore` & Git LFS for the compiled app, and ensure everything builds via terminal scripts without Xcode.

**Architecture:** 
- GGUF: Modify `ggml-metal-ops.cpp` in `llama.cpp` to lower the ANE thread threshold, recompile via CMake, and bundle the artifacts.
- MLX: Update `inject_lmstudio.sh` to forcefully kill any running `python3.11` instances, completely remove the existing Apple Developer signature, and resign it with an ad-hoc signature + `disable-library-validation` entitlements.
- Git: Adjust `.gitignore` to allow `M5 Ultimate.app` and configure `git lfs` for large binaries.

**Tech Stack:** Bash, C++, macOS `codesign`, Git LFS.

---

### Task 1: Lower GGUF ANE Threshold

**Files:**
- Modify: `llama.cpp/ggml/src/ggml-metal/ggml-metal-ops.cpp`

- [ ] **Step 1: Modify `dispatch_with_ane` threshold**
  Change the threshold from 100 to 16 in `ggml-metal-ops.cpp` so that small matrix multiplications (like token generation) are routed to ANE.

```cpp
// In llama.cpp/ggml/src/ggml-metal/ggml-metal-ops.cpp
// Find:
static void dispatch_with_ane(ggml_metal_encoder_t enc, int tg0, int tg1, int tg2, int tptg0, int tptg1, int tptg2, struct ggml_tensor * weights) {
    size_t total_threads = (size_t)tg0 * tg1 * tg2;
    if (total_threads > 100) {
        
// Change to:
static void dispatch_with_ane(ggml_metal_encoder_t enc, int tg0, int tg1, int tg2, int tptg0, int tptg1, int tptg2, struct ggml_tensor * weights) {
    size_t total_threads = (size_t)tg0 * tg1 * tg2;
    if (total_threads > 16) {
```

- [ ] **Step 2: Recompile `llama.cpp`**
  Run CMake build to compile the changes.

```bash
cd /Users/fox/Documents/PROJECTS/M5/llama.cpp
mkdir -p build && cd build
cmake .. -DGGML_METAL=ON
cmake --build . --config Release -j $(sysctl -n hw.logicalcpu)
cd /Users/fox/Documents/PROJECTS/M5
```

### Task 2: Fix MLX Python Code Signing & Build Script

**Files:**
- Modify: `M5UltimateApp/inject_lmstudio.sh`
- Modify: `M5UltimateApp/build.sh`

- [ ] **Step 1: Update `inject_lmstudio.sh` to fix Team ID mismatch**
  We must kill the Python process, remove the old signature, and properly log the `codesign` output.

```bash
// In M5UltimateApp/inject_lmstudio.sh
// Find the Python patch section and replace it with:
    # Fix Python Executable Signature for Library Validation
    MLX_PYTHON_BIN=$(find "$USER_HOME/.lmstudio/extensions/backends" -type f -name "python3.11" | head -n 1)
    if [ ! -z "$MLX_PYTHON_BIN" ]; then
        if [ ! -f "${MLX_PYTHON_BIN}.orig" ]; then
            cp "$MLX_PYTHON_BIN" "${MLX_PYTHON_BIN}.orig"
        fi
        
        echo "Killing any running python3.11 to avoid Text file busy..." >> /tmp/m5_inject.log
        pkill -9 python3.11 2>/dev/null || true
        sleep 1
        
        cat << 'ENT' > /tmp/python_entitlements.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-dyld-environment-variables</key>
    <true/>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.device.audio-input</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
ENT
        echo "Removing original Apple signature..." >> /tmp/m5_inject.log
        codesign --remove-signature "$MLX_PYTHON_BIN" >> /tmp/m5_inject.log 2>&1 || true
        echo "Applying ad-hoc signature with entitlements..." >> /tmp/m5_inject.log
        codesign --force --sign - --entitlements /tmp/python_entitlements.plist "$MLX_PYTHON_BIN" >> /tmp/m5_inject.log 2>&1
        echo "Patched Python executable to disable library validation."
    fi
```

- [ ] **Step 2: Update `core.cpython-311-darwin.so` signing in `inject_lmstudio.sh`**
  Also ensure the `.so` file has its signature removed before resigning.

```bash
// In M5UltimateApp/inject_lmstudio.sh
// Find the MLX_PYTHON_SO section and modify the codesign part:
            install_name_tool -change @rpath/libmlx.dylib @loader_path/lib/libmlx.dylib "$MLX_PYTHON_SO" 2>/dev/null || true
            install_name_tool -change @loader_path/libmlx.dylib @loader_path/lib/libmlx.dylib "$MLX_PYTHON_SO" 2>/dev/null || true
            
            # Create entitlements to disable library validation
            cat << 'ENT' > /tmp/mlx_entitlements.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
ENT
            codesign --remove-signature "$MLX_PYTHON_SO" >> /tmp/m5_inject.log 2>&1 || true
            codesign --force --sign - --entitlements /tmp/mlx_entitlements.plist "$MLX_PYTHON_SO" >> /tmp/m5_inject.log 2>&1
```

- [ ] **Step 3: Update `build.sh` to copy `ggml-metal.metal`**
  Just in case `llama.cpp` needs the raw metal source file at runtime.

```bash
// In M5UltimateApp/build.sh
// Add this line below the other cp commands for llama:
cp -f ../llama.cpp/ggml/src/ggml-metal/ggml-metal.metal "$APP_DIR/Contents/Resources/payloads/llama/" 2>/dev/null || true
```

### Task 3: Git Ignore and Git LFS Setup

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Fix `.gitignore` to allow the App bundle**

```gitignore
// In .gitignore
// Change the M5UltimateApp build ignores to:
# Un-ignore M5 Ultimate App build artifacts so we can commit the compiled app
!M5UltimateApp/build/
!M5UltimateApp/build/M5\ Ultimate.app/
!M5UltimateApp/build/M5\ Ultimate.app/**/*
```

- [ ] **Step 2: Initialize and Configure Git LFS**
  Run these commands to configure Git LFS for the large binaries in the repository.

```bash
cd /Users/fox/Documents/PROJECTS/M5
git lfs install
git lfs track "*.dylib"
git lfs track "*.metallib"
git lfs track "llama-server"
git lfs track "M5 Ultimate"
git add .gitattributes
```

### Task 4: Final Build

- [ ] **Step 1: Run `build.sh`**
  Execute the terminal build script. No Xcode is required.

```bash
cd /Users/fox/Documents/PROJECTS/M5/M5UltimateApp
./build.sh
```
