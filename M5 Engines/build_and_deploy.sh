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

# 3. Deploy to LM Studio Native Extension Folder
LLAMA_BACKEND_DIR="$HOME/.cache/lm-studio/extensions/backends/m5-llama-cpp-mac-arm64-1.0.0"

if [ -d "$LLAMA_BACKEND_DIR" ]; then
    echo "🚀 Deploying to Native LM Studio Backend: $LLAMA_BACKEND_DIR"
    
    # Check if we already renamed the original server
    if [ ! -f "$LLAMA_BACKEND_DIR/llama-server.orig" ]; then
        echo "   -> Backing up original llama-server to llama-server.orig"
        mv "$LLAMA_BACKEND_DIR/llama-server" "$LLAMA_BACKEND_DIR/llama-server.orig"
    fi
    
    # Copy the interceptor
    cp m5_godmode_interceptor.dylib "$LLAMA_BACKEND_DIR/"
    
    # Copy the proxy and rename it to llama-server (which LM Studio calls)
    cp llama-proxy "$LLAMA_BACKEND_DIR/llama-server"
    
    # Ensure execution permissions
    chmod +x "$LLAMA_BACKEND_DIR/llama-server"
    
    echo "🎉 Deployment Complete! You can now select 'M5 llama.cpp' in LM Studio."
else
    echo "❌ Error: M5 backend directory not found at $LLAMA_BACKEND_DIR"
    exit 1
fi
