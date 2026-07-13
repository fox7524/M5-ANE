#!/bin/bash

# Mode: 'inject' or 'restore'
MODE="${1:-inject}"

# Log file for debugging
LOG_FILE="/tmp/m5_inject.log"
echo "--- Starting M5 Ultimate ($MODE) at $(date) ---" >> "$LOG_FILE"

# Ensure LM Studio is closed so files aren't locked in memory
killall "LM Studio" 2>/dev/null || true
killall "llama-server" 2>/dev/null || true

# Make sure we run as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root." >> "$LOG_FILE"
  exit 1
fi

USER_HOME=$(eval echo "~${SUDO_USER:-$USER}")
echo "Resolved USER_HOME: $USER_HOME" >> "$LOG_FILE"

# Get the path where this script is running from (inside the .app bundle)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "Script running from: $SCRIPT_DIR" >> "$LOG_FILE"

PAYLOAD_DIR="$SCRIPT_DIR/payloads"
LM_BIN="$USER_HOME/.cache/lm-studio/bin"
MLX_LIB_PATHS=$(find "$USER_HOME/.lmstudio/extensions/backends/vendor/_amphibian" -type d -name "lib" -path "*/mlx/lib" 2>/dev/null)

if [ "$MODE" = "inject" ]; then
    # ==========================================
    # INJECT MODE
    # ==========================================
    
    # 1. GGUF (Llama.cpp) Inject
    echo "Injecting GGUF using insert_dylib with preserved entitlements..." >> "$LOG_FILE"
    
    LATEST_LLAMA_SERVER=$(find "$USER_HOME/.cache/lm-studio/bin" -type f -name "llama-server" 2>/dev/null | sort -V | tail -n 1)
    if [ -z "$LATEST_LLAMA_SERVER" ]; then
        # Fallback to extensions/backends
        LATEST_LLAMA_SERVER=$(find "$USER_HOME/.lmstudio/extensions/backends" -type f -name "llama-server" 2>/dev/null | sort -V | tail -n 1)
    fi
    
    if [ -n "$LATEST_LLAMA_SERVER" ]; then
        echo "Found llama-server at: $LATEST_LLAMA_SERVER" >> "$LOG_FILE"
        
        # Swap files (backup original and set proxy as the active one)
        if [ ! -f "${LATEST_LLAMA_SERVER}.orig" ]; then
            mv "$LATEST_LLAMA_SERVER" "${LATEST_LLAMA_SERVER}.orig"
        else
            rm "$LATEST_LLAMA_SERVER"
        fi
        
        # 3. Create a bash proxy wrapper instead of dylib injection
        cat > "$LATEST_LLAMA_SERVER" <<EOF
#!/bin/bash
# Proxy script injected by M5 Ultimate
# This forwards the execution to our own custom llama-server

LOG="/tmp/m5_proxy_wrapper.log"
echo "\$(date) - Proxy wrapper started" >> "\$LOG"
echo "Arguments: \$@" >> "\$LOG"

M5_SERVER="\$SCRIPT_DIR/payloads/llama/llama-server"
DYLIB="\$SCRIPT_DIR/libmetal_interceptor.dylib"

if [ ! -f "\$M5_SERVER" ]; then
    echo "ERROR: Custom server not found at \$M5_SERVER" >> "\$LOG"
    exit 1
fi

if [ ! -f "\$DYLIB" ]; then
    echo "ERROR: Interceptor dylib not found at \$DYLIB" >> "\$LOG"
    exit 1
fi

echo "Setting DYLD_INSERT_LIBRARIES=\$DYLIB" >> "\$LOG"
export DYLD_INSERT_LIBRARIES="\$DYLIB"

echo "Executing: \$M5_SERVER" >> "\$LOG"
# Use exec to replace the bash process with the llama-server
exec "\$M5_SERVER" "\$@" 2>>"\$LOG"
EOF
        chmod +x "$LATEST_LLAMA_SERVER"
        
        echo "Successfully deployed proxy wrapper to $LATEST_LLAMA_SERVER" >> "$LOG_FILE"
    else
        echo "Could not find LM Studio llama-server executable." >> "$LOG_FILE"
    fi

    # 2. MLX (Safetensors) Inject
    echo "Injecting MLX from embedded payloads..." >> "$LOG_FILE"
    
    if [ -n "$MLX_LIB_PATHS" ]; then
        for MLX_LIB_PATH in $MLX_LIB_PATHS; do
            echo "Found MLX path: $MLX_LIB_PATH" >> "$LOG_FILE"
            
            # Unlock
            chflags -R nouchg "$MLX_LIB_PATH" 2>> "$LOG_FILE" || true
            chflags -R nouchg "$MLX_LIB_PATH/.." 2>> "$LOG_FILE" || true
            
            # Backup original MLX files
            if [ -f "$MLX_LIB_PATH/mlx.metallib" ] && [ ! -f "$MLX_LIB_PATH/mlx.metallib.orig" ]; then
                mv "$MLX_LIB_PATH/mlx.metallib" "$MLX_LIB_PATH/mlx.metallib.orig" 2>> "$LOG_FILE" || true
            fi
            if [ -f "$MLX_LIB_PATH/../libmlx.dylib" ] && [ ! -f "$MLX_LIB_PATH/../libmlx.dylib.orig" ]; then
                mv "$MLX_LIB_PATH/../libmlx.dylib" "$MLX_LIB_PATH/../libmlx.dylib.orig" 2>> "$LOG_FILE" || true
            fi
            
            # Deploy payload
            rm -f "$MLX_LIB_PATH/mlx.metallib" 2>> "$LOG_FILE" || true
            rm -f "$MLX_LIB_PATH/../libmlx.dylib" 2>> "$LOG_FILE" || true
            
            cp -f "$PAYLOAD_DIR/mlx/mlx.metallib" "$MLX_LIB_PATH/" 2>> "$LOG_FILE" || true
            cp -f "$PAYLOAD_DIR/mlx/libmlx.dylib" "$MLX_LIB_PATH/../" 2>> "$LOG_FILE" || true
            
            # Restore libmlx original for DYLD approach
            if [ -f "$MLX_LIB_PATH/../libmlx.dylib.orig" ]; then
                cp -f "$MLX_LIB_PATH/../libmlx.dylib.orig" "$MLX_LIB_PATH/../libmlx.dylib"
            fi
            
            # Copy interceptor
            cp -f "$SCRIPT_DIR/libmetal_interceptor.dylib" "$MLX_LIB_PATH/../" 2>> "$LOG_FILE" || true
            
            # Find python binary
            PYTHON_BIN=$(find "$MLX_LIB_PATH/../../../../../" -name "python3.11" -type f | head -n 1)
            if [ -n "$PYTHON_BIN" ]; then
                echo "Patching Python binary: $PYTHON_BIN" >> "$LOG_FILE"
                
                # Backup python
                if [ ! -f "${PYTHON_BIN}.orig" ]; then
                    cp "$PYTHON_BIN" "${PYTHON_BIN}.orig"
                fi
                
                # Extract and merge entitlements for python
                TMP_ENT="/tmp/python_ent.plist"
                cp "${PYTHON_BIN}.orig" "${PYTHON_BIN}.patched"
                
                codesign -d --entitlements :- "${PYTHON_BIN}.orig" > "$TMP_ENT" 2>/dev/null
                if [ ! -s "$TMP_ENT" ]; then
                    echo '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict></dict></plist>' > "$TMP_ENT"
                fi
                
                plutil -replace "com.apple.security.cs.disable-library-validation" -bool YES "$TMP_ENT" 2>/dev/null || true
                plutil -replace "com.apple.security.cs.allow-dyld-environment-variables" -bool YES "$TMP_ENT" 2>/dev/null || true
                plutil -replace "com.apple.security.get-task-allow" -bool YES "$TMP_ENT" 2>/dev/null || true
                
                # Sign patched python
                codesign --force --options runtime --entitlements "$TMP_ENT" --sign - "${PYTHON_BIN}.patched" >> "$LOG_FILE" 2>&1
                rm -f "$TMP_ENT"
                
                # Create wrapper script in place of original python
                cat > "$PYTHON_BIN" <<EOF
#!/bin/bash
export DYLD_INSERT_LIBRARIES="$MLX_LIB_PATH/../libmetal_interceptor.dylib"
exec "${PYTHON_BIN}.patched" "\$@"
EOF
                chmod +x "$PYTHON_BIN"
                echo "Created Python wrapper with DYLD_INSERT_LIBRARIES" >> "$LOG_FILE"
            fi
        done
    else
        echo "MLX paths NOT found" >> "$LOG_FILE"
    fi

    echo "Injection completed." >> "$LOG_FILE"

elif [ "$MODE" = "restore" ]; then
    # ==========================================
    # RESTORE (DE-INJECT) MODE
    # ==========================================
    echo "Restoring original files..." >> "$LOG_FILE"
    
    # 1. Restore GGUF
    LATEST_LLAMA_SERVER=$(find "$USER_HOME/.cache/lm-studio/bin" -type f -name "llama-server" 2>/dev/null | sort -V | tail -n 1)
    if [ -z "$LATEST_LLAMA_SERVER" ]; then
        LATEST_LLAMA_SERVER=$(find "$USER_HOME/.lmstudio/extensions/backends" -type f -name "llama-server" 2>/dev/null | sort -V | tail -n 1)
    fi
    
    if [ -n "$LATEST_LLAMA_SERVER" ] && [ -f "${LATEST_LLAMA_SERVER}.orig" ]; then
        mv -f "${LATEST_LLAMA_SERVER}.orig" "$LATEST_LLAMA_SERVER"
        rm -f "${LATEST_LLAMA_SERVER}.patched"
        TARGET_DIR=$(dirname "$LATEST_LLAMA_SERVER")
        rm -f "$TARGET_DIR/libmetal_interceptor.dylib"
        echo "Restored GGUF llama-server" >> "$LOG_FILE"
    fi
    
    # 2. Restore MLX
    if [ -n "$MLX_LIB_PATHS" ]; then
        for MLX_LIB_PATH in $MLX_LIB_PATHS; do
            if [ -f "$MLX_LIB_PATH/mlx.metallib.orig" ]; then
                mv -f "$MLX_LIB_PATH/mlx.metallib.orig" "$MLX_LIB_PATH/mlx.metallib"
            fi
            if [ -f "$MLX_LIB_PATH/../libmlx.dylib.orig" ]; then
                mv -f "$MLX_LIB_PATH/../libmlx.dylib.orig" "$MLX_LIB_PATH/../libmlx.dylib"
            fi
            rm -f "$MLX_LIB_PATH/../libmetal_interceptor.dylib"
            
            # Restore Python wrapper
            PYTHON_BIN=$(find "$MLX_LIB_PATH/../../../../../" -name "python3.11" -type f | head -n 1)
            if [ -n "$PYTHON_BIN" ] && [ -f "${PYTHON_BIN}.orig" ]; then
                mv -f "${PYTHON_BIN}.orig" "$PYTHON_BIN"
                echo "Restored Python binary at $PYTHON_BIN" >> "$LOG_FILE"
            fi
            
            echo "Restored MLX files in $MLX_LIB_PATH" >> "$LOG_FILE"
        done
    fi
    
    echo "Restore completed." >> "$LOG_FILE"
fi

echo "Done!"
