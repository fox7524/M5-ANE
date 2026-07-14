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
        rm -f "$LLAMA_SERVER_DIR/llama-server.ane" 2>/dev/null || true
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
        
        MLX_PYTHON_SO=$(dirname "$MLX_DIR")/core.cpython-311-darwin.so
        if [ -f "${MLX_PYTHON_SO}.orig" ]; then
            mv -f "${MLX_PYTHON_SO}.orig" "$MLX_PYTHON_SO"
            echo "Restored MLX python module in $MLX_PYTHON_SO"
        elif [ -f "$MLX_PYTHON_SO" ]; then
            install_name_tool -change @loader_path/lib/libmlx.dylib @loader_path/libmlx.dylib "$MLX_PYTHON_SO" 2>/dev/null || true
            install_name_tool -change @loader_path/lib/libmlx.dylib @rpath/libmlx.dylib "$MLX_PYTHON_SO" 2>/dev/null || true
            codesign --force --sign - "$MLX_PYTHON_SO" 2>/dev/null || true
        fi
        echo "Restored MLX files in $MLX_DIR"
    done
    
    # 3. Restore Python Executable Signatures
    PYTHON_BINS=$(find "$USER_HOME/.lmstudio/extensions/backends" -type f -name "python3.11" 2>/dev/null || true)
    for PY_BIN in $PYTHON_BINS; do
        if [ -f "${PY_BIN}.orig" ]; then
            mv -f "${PY_BIN}.orig" "$PY_BIN"
            echo "Restored Python binary in $PY_BIN"
        fi
    done
    
    exit 0
fi

echo "Injecting M5 Ultimate Proxy into LM Studio..."

# --- 1. Proxy GGUF (llama-server) ---
# Find the latest llama-server
LATEST_LLAMA_SERVER=$(find "$LLAMA_SERVER_DIR" -type f -name "llama-server" ! -name "*.orig" 2>/dev/null | sort -V | tail -n 1)

if [ ! -z "$LATEST_LLAMA_SERVER" ]; then
    echo "Found llama-server at: $LATEST_LLAMA_SERVER"
    
    if [ ! -f "${LATEST_LLAMA_SERVER}.orig" ]; then
        cp "$LATEST_LLAMA_SERVER" "${LATEST_LLAMA_SERVER}.orig"
    fi
    
    # Replace the llama-server and copy dylibs
    cp -f "$M5_RESOURCES_DIR/payloads/llama/llama-proxy" "$LATEST_LLAMA_SERVER"
    cp -f "$M5_RESOURCES_DIR/payloads/llama/llama-server.ane" "${LATEST_LLAMA_SERVER}.ane"
    cp -f "$M5_RESOURCES_DIR/payloads/llama/"*.dylib "$LLAMA_SERVER_DIR/" 2>/dev/null || true
    cp -f "$M5_RESOURCES_DIR/payloads/llama/ggml-metal.metal" "$LLAMA_SERVER_DIR/" 2>/dev/null || true
    
    chmod +x "$LATEST_LLAMA_SERVER"
    chmod +x "${LATEST_LLAMA_SERVER}.ane"
    echo "GGUF Payload injected successfully."
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
        
        # Remove quarantine
        xattr -cr "$MLX_DIR" 2>/dev/null || true
        
        # Fix dynamic link path for python module
        MLX_PYTHON_SO=$(dirname "$MLX_DIR")/core.cpython-311-darwin.so
        if [ -f "$MLX_PYTHON_SO" ]; then
            if [ ! -f "${MLX_PYTHON_SO}.orig" ]; then
                cp "$MLX_PYTHON_SO" "${MLX_PYTHON_SO}.orig"
            fi
            
            # Since the original expected @rpath/libmlx.dylib and we want to load our injected one in lib/libmlx.dylib
            install_name_tool -change @rpath/libmlx.dylib @loader_path/lib/libmlx.dylib "$MLX_PYTHON_SO" 2>/dev/null || true
            install_name_tool -change @loader_path/libmlx.dylib @loader_path/lib/libmlx.dylib "$MLX_PYTHON_SO" 2>/dev/null || true
            
            xattr -cr "$MLX_PYTHON_SO" 2>/dev/null || true
            codesign --remove-signature "$MLX_PYTHON_SO" >> /tmp/m5_inject.log 2>&1 || true
            codesign --force --sign - "$MLX_PYTHON_SO" >> /tmp/m5_inject.log 2>&1
        fi
    done
    # Fix Python Executable Signatures for Library Validation
    PYTHON_BINS=$(find "$USER_HOME/.lmstudio/extensions/backends" -type f -name "python3.11" 2>/dev/null || true)
    if [ ! -z "$PYTHON_BINS" ]; then
        echo "Killing any running python3.11 to avoid Text file busy..." >> /tmp/m5_inject.log
        pkill -9 python3.11 2>/dev/null || true
        sleep 1
        
        for PY_BIN in $PYTHON_BINS; do
            if [ ! -f "${PY_BIN}.orig" ]; then
                cp "$PY_BIN" "${PY_BIN}.orig"
            fi
            
            echo "Removing original Apple signature and clearing quarantine for $PY_BIN..." >> /tmp/m5_inject.log
            xattr -cr "$PY_BIN" 2>/dev/null || true
            codesign --remove-signature "$PY_BIN" >> /tmp/m5_inject.log 2>&1 || true
            
            echo "Applying plain ad-hoc signature for $PY_BIN..." >> /tmp/m5_inject.log
            codesign --force --sign - "$PY_BIN" >> /tmp/m5_inject.log 2>&1
            echo "Patched Python executable to disable Hardened Runtime: $PY_BIN"
        done
    fi

    echo "MLX Injection successfully completed."
else
    echo "MLX backend not found. Skipping MLX."
fi

echo "Injection complete."
exit 0
