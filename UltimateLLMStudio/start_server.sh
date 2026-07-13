#!/bin/bash
# Spawns the local API server with Metal Interceptor

ENGINE_TYPE=$1
MODEL_PATH=$2

DYLIB_PATH="$(dirname "$0")/libmetal_interceptor.dylib"
export DYLD_INSERT_LIBRARIES="$DYLIB_PATH"

if [ "$ENGINE_TYPE" == "GGUF" ]; then
    LLAMA_SERVER="$(dirname "$0")/payloads/llama/llama-server"
    exec "$LLAMA_SERVER" -m "$MODEL_PATH" --port 1234
elif [ "$ENGINE_TYPE" == "MLX" ]; then
    # MLX implementation placeholder for V2
    python3 -m mlx_server --model "$MODEL_PATH" --port 1234
fi
