#!/bin/bash
# M5 Ultimate - LM Studio Proxy Injector
# This script creates a proxy wrapper to hijack LM Studio's subprocesses
# without triggering macOS Hardened Runtime or Library Validation errors.

MODE=$1
USER_HOME=$(eval echo ~$SUDO_USER)

# LM Studio's default paths
LLAMA_SERVER_DIR="$USER_HOME/.cache/lm-studio/bin"

if [ "$MODE" == "restore" ]; then
    echo "Restoring LM Studio to original state..."
    
    # Restore GGUF (llama-server)
    if [ -f "$LLAMA_SERVER_DIR/llama-server.orig" ]; then
        mv -f "$LLAMA_SERVER_DIR/llama-server.orig" "$LLAMA_SERVER_DIR/llama-server"
        echo "llama-server restored."
    fi
    
    # (Optional) Restore MLX if we added a proxy there
    MLX_PYTHON=$(find "/Applications/LM Studio.app" -type f -name "python3.11.orig" 2>/dev/null | head -n 1)
    if [ ! -z "$MLX_PYTHON" ]; then
        mv -f "$MLX_PYTHON" "${MLX_PYTHON%.orig}"
        echo "MLX python restored."
    fi
    
    exit 0
fi

echo "Injecting M5 Ultimate Proxy into LM Studio..."

# --- 1. Proxy GGUF (llama-server) ---
# Find the latest llama-server
LATEST_LLAMA_SERVER=$(find "$LLAMA_SERVER_DIR" -type f -name "llama-server" ! -name "*.orig" 2>/dev/null | sort -V | tail -n 1)

if [ ! -z "$LATEST_LLAMA_SERVER" ]; then
    echo "Found llama-server at: $LATEST_LLAMA_SERVER"
    
    # Backup original if not already backed up
    if [ ! -f "${LATEST_LLAMA_SERVER}.orig" ]; then
        mv "$LATEST_LLAMA_SERVER" "${LATEST_LLAMA_SERVER}.orig"
    fi
    
    # Create the Proxy Script
    cat << 'EOF' > "$LATEST_LLAMA_SERVER"
#!/bin/bash
# M5 Ultimate Proxy Wrapper
# This script intercepts LM Studio's call to llama-server.

ORIGINAL_SERVER="${0}.orig"
CUSTOM_SERVER="/Applications/M5 Ultimate.app/Contents/Resources/payloads/llama/llama-server"
CUSTOM_METAL_DIR="/Applications/M5 Ultimate.app/Contents/Resources/payloads/llama"

# Here you can inject your ANE logic, set environment variables,
# or even redirect the execution to your custom ANE-compiled llama-server!

export M5_ANE_ENABLED="1"
export GGML_METAL_PATH_RESOURCES="$CUSTOM_METAL_DIR"
export DYLD_LIBRARY_PATH="$CUSTOM_METAL_DIR:$DYLD_LIBRARY_PATH"

echo "[M5 Proxy] Intercepted llama-server launch!" > /tmp/m5_proxy.log
echo "[M5 Proxy] Args: $@" >> /tmp/m5_proxy.log

if [ -x "$CUSTOM_SERVER" ]; then
    echo "[M5 Proxy] Redirecting to custom ANE llama-server..." >> /tmp/m5_proxy.log
    exec "$CUSTOM_SERVER" "$@"
else
    echo "[M5 Proxy] Custom server not found! Falling back to original..." >> /tmp/m5_proxy.log
    exec "$ORIGINAL_SERVER" "$@"
fi
EOF

    chmod +x "$LATEST_LLAMA_SERVER"
    echo "GGUF Proxy injected successfully."
else
    echo "llama-server not found. Skipping GGUF."
fi

# --- 2. Proxy MLX (Python) ---
# Find the python binary used by MLX
MLX_PYTHON=$(find "/Applications/LM Studio.app" -type f -name "python3.11" ! -name "*.orig" 2>/dev/null | head -n 1)

if [ ! -z "$MLX_PYTHON" ]; then
    echo "Found MLX Python at: $MLX_PYTHON"
    
    if [ ! -f "${MLX_PYTHON}.orig" ]; then
        mv "$MLX_PYTHON" "${MLX_PYTHON}.orig"
    fi
    
    cat << 'EOF' > "$MLX_PYTHON"
#!/bin/bash
# M5 Ultimate Proxy Wrapper for MLX

ORIGINAL_PYTHON="${0}.orig"

export M5_ANE_ENABLED="1"

echo "[M5 Proxy] Intercepted MLX python launch!" > /tmp/m5_proxy_mlx.log
exec "$ORIGINAL_PYTHON" "$@"
EOF

    chmod +x "$MLX_PYTHON"
    echo "MLX Proxy injected successfully."
else
    echo "MLX Python not found. Skipping MLX."
fi

echo "Injection complete."
exit 0
