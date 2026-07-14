#!/bin/bash
# M5 Ultimate - LM Studio Proxy Injector

exec >> /tmp/m5_inject.log 2>&1
echo "--- Starting M5 Ultimate (${1:-inject}) at $(date) ---"

MODE=$1
USER_HOME=$(eval echo ~$SUDO_USER)
M5_RESOURCES_DIR="$(cd "$(dirname "$0")" && pwd)"

# Paths
LLAMA_SERVER_DIR="$USER_HOME/.cache/lm-studio/bin"

if [ "$MODE" == "restore" ]; then
    echo "Restoring LM Studio to original state..."
    
    # 1. Restore GGUF
    if [ -f "$LLAMA_SERVER_DIR/llama-server.orig" ]; then
        mv -f "$LLAMA_SERVER_DIR/llama-server.orig" "$LLAMA_SERVER_DIR/llama-server"
        echo "llama-server restored."
    fi
    
    # 2. Restore MLX
    MLX_PATHS=$(find "$USER_HOME/.lmstudio/extensions/backends" -type d -name "lib" | grep "mlx/lib" 2>/dev/null || true)
    for MLX_DIR in $MLX_PATHS; do
        if [ -f "$MLX_DIR/libmlx.dylib.orig" ]; then
            mv -f "$MLX_DIR/libmlx.dylib.orig" "$MLX_DIR/libmlx.dylib"
        fi
        if [ -f "$MLX_DIR/mlx.metallib.orig" ]; then
            mv -f "$MLX_DIR/mlx.metallib.orig" "$MLX_DIR/mlx.metallib"
        fi
        
        # Restore python module dynamic link path
        MLX_PYTHON_SO=$(dirname "$MLX_DIR")/core.cpython-311-darwin.so
        if [ -f "$MLX_PYTHON_SO" ]; then
            install_name_tool -change @loader_path/lib/libmlx.dylib @rpath/libmlx.dylib "$MLX_PYTHON_SO" 2>/dev/null || true
            codesign --force --sign - "$MLX_PYTHON_SO" 2>/dev/null || true
        fi
        echo "Restored MLX files in $MLX_DIR"
    done
    
    exit 0
fi

echo "Injecting M5 Ultimate Proxy into LM Studio..."

# --- 1. Proxy GGUF (llama-server) ---
# Find the latest llama-server
LATEST_LLAMA_SERVER=$(find "$LLAMA_SERVER_DIR" -type f -name "llama-server" ! -name "*.orig" 2>/dev/null | sort -V | tail -n 1)

if [ ! -z "$LATEST_LLAMA_SERVER" ]; then
    echo "Found llama-server at: $LATEST_LLAMA_SERVER"
    
    # Check if the original is actually our broken insert_dylib patched version from yesterday
    # If llama-server-bin exists, that's the true original!
    if [ -f "$LLAMA_SERVER_DIR/llama-server-bin" ]; then
        echo "Found true original llama-server-bin. Using it as backup."
        cp -f "$LLAMA_SERVER_DIR/llama-server-bin" "$LLAMA_SERVER_DIR/llama-server.orig"
    elif [ ! -f "${LATEST_LLAMA_SERVER}.orig" ]; then
        mv "$LATEST_LLAMA_SERVER" "${LATEST_LLAMA_SERVER}.orig"
    fi
    
    # Create the Proxy Script
    cat << EOF > "$LATEST_LLAMA_SERVER"
#!/bin/bash
# M5 Ultimate Proxy Wrapper

ORIGINAL_SERVER="\${0}.orig"
CUSTOM_SERVER="$M5_RESOURCES_DIR/payloads/llama/llama-server"
CUSTOM_METAL_DIR="$M5_RESOURCES_DIR/payloads/llama"

export M5_ANE_ENABLED="1"
export GGML_METAL_PATH_RESOURCES="\$CUSTOM_METAL_DIR"
export DYLD_LIBRARY_PATH="\$CUSTOM_METAL_DIR:\$DYLD_LIBRARY_PATH"

echo "[M5 Proxy] Intercepted llama-server launch!" > /tmp/m5_proxy.log
echo "[M5 Proxy] Args: \$@" >> /tmp/m5_proxy.log

if [ -x "\$CUSTOM_SERVER" ]; then
    echo "[M5 Proxy] Redirecting to custom ANE llama-server..." >> /tmp/m5_proxy.log
    exec "\$CUSTOM_SERVER" "\$@"
else
    echo "[M5 Proxy] Custom server not found at \$CUSTOM_SERVER ! Falling back to original..." >> /tmp/m5_proxy.log
    exec "\$ORIGINAL_SERVER" "\$@"
fi
EOF

    chmod +x "$LATEST_LLAMA_SERVER"
    echo "GGUF Proxy injected successfully."
else
    echo "llama-server not found. Skipping GGUF."
fi

# --- 2. Inject MLX ---
MLX_PATHS=$(find "$USER_HOME/.lmstudio/extensions/backends" -type d -name "lib" | grep "mlx/lib" 2>/dev/null || true)
if [ ! -z "$MLX_PATHS" ]; then
    for MLX_DIR in $MLX_PATHS; do
        echo "Injecting MLX payload into: $MLX_DIR"
        
        # Backup original MLX files
        if [ ! -f "$MLX_DIR/libmlx.dylib.orig" ]; then
            mv "$MLX_DIR/libmlx.dylib" "$MLX_DIR/libmlx.dylib.orig"
        fi
        if [ ! -f "$MLX_DIR/mlx.metallib.orig" ]; then
            mv "$MLX_DIR/mlx.metallib" "$MLX_DIR/mlx.metallib.orig"
        fi
        
        # Copy custom MLX files
        cp -f "$M5_RESOURCES_DIR/payloads/mlx/libmlx.dylib" "$MLX_DIR/"
        cp -f "$M5_RESOURCES_DIR/payloads/mlx/mlx.metallib" "$MLX_DIR/"
        
        # Fix dynamic link path for python module
        MLX_PYTHON_SO=$(dirname "$MLX_DIR")/core.cpython-311-darwin.so
        if [ -f "$MLX_PYTHON_SO" ]; then
            install_name_tool -change @rpath/libmlx.dylib @loader_path/lib/libmlx.dylib "$MLX_PYTHON_SO" 2>/dev/null || true
            codesign --force --sign - "$MLX_PYTHON_SO" 2>/dev/null || true
        fi
    done
    echo "MLX Injection successfully completed."
else
    echo "MLX backend not found. Skipping MLX."
fi

echo "Injection complete."
exit 0
