#!/bin/bash
# ==============================================================================
# M5 ULTIMATE ENGINE - BUILD & DEPLOY SCRIPT
# ==============================================================================
set -e

echo "🔨 Building M5 Ultimate God-Mode Interceptor & Proxy..."

cd "$(dirname "$0")"

# 1. Build the Zero-Copy Interceptor (Objective-C++)
clang++ -O3 -shared -fPIC \
    -framework Foundation \
    -framework Metal \
    -framework IOSurface \
    -o m5_godmode_interceptor.dylib \
    m5_godmode_interceptor.mm

echo "✅ m5_godmode_interceptor.dylib built successfully."

# 2. Build the Launcher Proxy (C++)
clang++ -O3 -o llama-proxy llama-proxy.cpp

echo "✅ llama-proxy built successfully."

# Prepare Entitlements for Library Validation Bypass
ENT_XML="/tmp/m5_ents.xml"
cat << 'EOF' > "$ENT_XML"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-dyld-environment-variables</key><true/>
    <key>com.apple.security.cs.allow-jit</key><true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key><true/>
    <key>com.apple.security.device.audio-input</key><true/>
    <key>com.apple.security.cs.disable-library-validation</key><true/>
</dict>
</plist>
EOF

# 2.5. Patch LM Studio's internal Node to bypass Library Validation
LMS_NODE="$HOME/.lmstudio/.internal/utils/node"
if [ -f "$LMS_NODE" ]; then
    echo "🚀 Bypassing Library Validation for LM Studio internal Node worker..."
    codesign --force --options runtime --sign - --entitlements "$ENT_XML" "$LMS_NODE"
fi

# Apply the same entitlement to the actual LM Studio apps and helpers just in case
find "/Applications/LM Studio.app" -type f -name "LM Studio Helper*" -perm +111 -exec codesign --force --options runtime --sign - --entitlements "$ENT_XML" {} \; 2>/dev/null || true
codesign --force --options runtime --sign - --entitlements "$ENT_XML" "/Applications/LM Studio.app/Contents/MacOS/LM Studio" 2>/dev/null || true

# Define GLOBAL_INTERCEPTOR early so it's not empty!
GLOBAL_INTERCEPTOR="$HOME/.lmstudio/extensions/backends/m5_godmode_interceptor.dylib"
cp m5_godmode_interceptor.dylib "$GLOBAL_INTERCEPTOR"
codesign --force --sign - "$GLOBAL_INTERCEPTOR" || true

# 3. Deploy to LM Studio Native Extension Folder
# Deploy to ALL official llama.cpp folders to ensure we hijack whichever one LM Studio is using
for LLAMA_BACKEND_DIR in "$HOME/.lmstudio/extensions/backends/llama.cpp-mac-arm64-apple-metal-advsimd-"* "$HOME/.cache/lm-studio/extensions/backends/llama.cpp-mac-arm64-apple-metal-advsimd-"*; do
    if [ -d "$LLAMA_BACKEND_DIR" ]; then
        echo "🚀 Deploying to Native LM Studio Backend: $LLAMA_BACKEND_DIR"
        
        # Copy the interceptor
        cp m5_godmode_interceptor.dylib "$LLAMA_BACKEND_DIR/"
        
        # LM Studio 0.4.x uses Node-API (.node) files directly instead of spawning llama-server.
        # We must inject our dylib into the .node module to hook Metal API calls in the Node worker process.
        NODE_ENGINE="$LLAMA_BACKEND_DIR/llm_engine.node"
        if [ -f "$NODE_ENGINE" ]; then
            if [ ! -f "${NODE_ENGINE}.orig" ]; then
                echo "   -> Backing up original llm_engine.node"
                cp "$NODE_ENGINE" "${NODE_ENGINE}.orig"
            fi
            
            # Inject dylib (use absolute path to avoid dlopen rpath issues)
            echo "   -> Injecting God-Mode into $NODE_ENGINE"
            "../M5 Ultimate/M5UltimateApp/insert_dylib" --inplace --overwrite --all-yes "$GLOBAL_INTERCEPTOR" "$NODE_ENGINE" || true
            codesign --force --sign - "$NODE_ENGINE" || true
        fi
        
        # Also inject into libllama.dylib just in case
        LIBLLAMA="$LLAMA_BACKEND_DIR/libllama.dylib"
        if [ -f "$LIBLLAMA" ]; then
            if [ ! -f "${LIBLLAMA}.orig" ]; then
                cp "$LIBLLAMA" "${LIBLLAMA}.orig"
            fi
            echo "   -> Injecting God-Mode into $LIBLLAMA"
            "../M5 Ultimate/M5UltimateApp/insert_dylib" --inplace --overwrite --all-yes "$GLOBAL_INTERCEPTOR" "$LIBLLAMA" || true
            codesign --force --sign - "$LIBLLAMA" || true
        fi

        # We keep the llama-proxy just in case they revert to CLI in the future
        if [ ! -f "$LLAMA_BACKEND_DIR/llama-server.orig" ]; then
            mv "$LLAMA_BACKEND_DIR/llama-server" "$LLAMA_BACKEND_DIR/llama-server.orig"
        fi
        cp llama-proxy "$LLAMA_BACKEND_DIR/llama-server"
        chmod +x "$LLAMA_BACKEND_DIR/llama-server"
        
        # Code sign
        codesign --force --sign - "$LLAMA_BACKEND_DIR/m5_godmode_interceptor.dylib" || true
        codesign --force --sign - "$LLAMA_BACKEND_DIR/llama-server" || true
    fi
done

echo "🎉 Deployment Complete! You can now select the official 'llama.cpp' in LM Studio to use God-Mode."

# 4. MLX Engine God-Mode Injection
echo "🚀 Injecting God-Mode into MLX Engine Python & Node Environment..."

for MLX_PYTHON in "$HOME/.lmstudio/extensions/backends/vendor/_amphibian/app-mlx-generate-mac26-arm64"*"/bin/python" "$HOME/.cache/lm-studio/extensions/backends/vendor/_amphibian/app-mlx-generate-mac26-arm64"*"/bin/python"; do
    if [ -f "$MLX_PYTHON" ]; then
        echo "   -> Patching $MLX_PYTHON"
        
        # Check if already patched
        if grep -q "DYLD_INSERT_LIBRARIES" "$MLX_PYTHON"; then
            echo "      (Already patched)"
        else
            # Insert DYLD_INSERT_LIBRARIES before the exec line
            sed -i '' 's|exec -a|export DYLD_INSERT_LIBRARIES="'"$GLOBAL_INTERCEPTOR"'"\nexec -a|' "$MLX_PYTHON"
            echo "      (Patch applied successfully)"
        fi
    fi
done

# We also must resign the actual python binary that the wrapper points to!
for MLX_PYTHON_BIN in "$HOME/.lmstudio/extensions/backends/vendor/_amphibian/"*"/bin/python3"* "$HOME/.cache/lm-studio/extensions/backends/vendor/_amphibian/"*"/bin/python3"*; do
    if [ -f "$MLX_PYTHON_BIN" ]; then
        # Check if it's a real executable, not a script/wrapper
        if file "$MLX_PYTHON_BIN" | grep -q "Mach-O"; then
            echo "   -> Bypassing Library Validation for MLX Python ($MLX_PYTHON_BIN)..."
            codesign --force --options runtime --sign - --entitlements "$ENT_XML" "$MLX_PYTHON_BIN"
        fi
    fi
done

for MLX_PYTHON_BIN_ in "$HOME/.lmstudio/extensions/backends/vendor/_amphibian/"*"/bin/python_"*; do
    if [ -f "$MLX_PYTHON_BIN_" ]; then
        if file "$MLX_PYTHON_BIN_" | grep -q "Mach-O"; then
            echo "   -> Bypassing Library Validation for MLX Python ($MLX_PYTHON_BIN_)..."
            codesign --force --options runtime --sign - --entitlements "$ENT_XML" "$MLX_PYTHON_BIN_"
        fi
    fi
done

for MLX_BACKEND_DIR in "$HOME/.lmstudio/extensions/backends/mlx-llm-mac-arm64-apple-metal-nax-advsimd-"* "$HOME/.cache/lm-studio/extensions/backends/mlx-llm-mac-arm64-apple-metal-nax-advsimd-"*; do
    if [ -d "$MLX_BACKEND_DIR" ]; then
        cp m5_godmode_interceptor.dylib "$MLX_BACKEND_DIR/"
        
        MLX_NODE="$MLX_BACKEND_DIR/llm_engine_mlx_amphibian.node"
        if [ -f "$MLX_NODE" ]; then
            if [ ! -f "${MLX_NODE}.orig" ]; then
                cp "$MLX_NODE" "${MLX_NODE}.orig"
            fi
            echo "   -> Injecting God-Mode into $MLX_NODE"
            "../M5 Ultimate/M5UltimateApp/insert_dylib" --inplace --overwrite --all-yes "$GLOBAL_INTERCEPTOR" "$MLX_NODE" || true
            
            # Fix Python linking issue in MLX node by providing an rpath to the local python framework if missing
            install_name_tool -add_rpath "$HOME/.lmstudio/extensions/backends/vendor/_amphibian/cpython3.11-mac-arm64@10/lib" "$MLX_NODE" 2>/dev/null || true
            
            codesign --force --sign - "$MLX_NODE" || true
        fi
        
        MLX_LIB="$MLX_BACKEND_DIR/libllm_engine.dylib"
        if [ -f "$MLX_LIB" ]; then
            if [ ! -f "${MLX_LIB}.orig" ]; then
                cp "$MLX_LIB" "${MLX_LIB}.orig"
            fi
            echo "   -> Injecting God-Mode into $MLX_LIB"
            "../M5 Ultimate/M5UltimateApp/insert_dylib" --inplace --overwrite --all-yes "$GLOBAL_INTERCEPTOR" "$MLX_LIB" || true
            
            install_name_tool -add_rpath "$HOME/.lmstudio/extensions/backends/vendor/_amphibian/cpython3.11-mac-arm64@10/lib" "$MLX_LIB" 2>/dev/null || true
            
            codesign --force --sign - "$MLX_LIB" || true
        fi
    fi
done

echo "🚀 Ensuring 'nax' target in MLX backend manifests..."
for MLX_MANIFEST in "$HOME/.cache/lm-studio/extensions/backends/mlx-llm-mac-arm64-apple-metal-nax-advsimd-"*"/backend-manifest.json"; do
    if [ -f "$MLX_MANIFEST" ]; then
        if ! grep -q '"nax"' "$MLX_MANIFEST"; then
            sed -i '' 's|"M5"|"M5", "nax"|g' "$MLX_MANIFEST"
            echo "   -> Added 'nax' to $MLX_MANIFEST"
        else
            echo "   -> 'nax' already present in $MLX_MANIFEST"
        fi
    fi
done

echo "🎉 MLX God-Mode Injection Complete!"

