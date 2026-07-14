#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
GPU_TESTER="$SCRIPT_DIR/gpu_stress_tester"
ANE_TESTER="$SCRIPT_DIR/ane_stress_tester"

echo "[*] M5 M5 Ultimate: Starting Concurrent Hardware Benchmark (20 Seconds)..."

rm -f /tmp/gpu_bench.log
rm -f /tmp/ane_bench.log

# Start testers in background
if [ -f "$GPU_TESTER" ]; then
    "$GPU_TESTER" > /tmp/gpu_bench.log 2>&1 &
    GPU_PID=$!
fi

if [ -f "$ANE_TESTER" ]; then
    "$ANE_TESTER" > /tmp/ane_bench.log 2>&1 &
    ANE_PID=$!
fi

# Wait for 20 seconds
sleep 20

# Kill testers gracefully
kill -INT $GPU_PID 2>/dev/null
kill -INT $ANE_PID 2>/dev/null
sleep 2
kill -9 $GPU_PID 2>/dev/null
kill -9 $ANE_PID 2>/dev/null
killall gpu_stress_tester ane_stress_tester 2>/dev/null

# Parse results
# GPU base is FP16 natively now
GPU_FP16=$(cat /tmp/gpu_bench.log | grep -o -E "[0-9]+(\.[0-9]+)? TFLOPS" | tail -n 1 | awk '{print $1}')
# ANE base is also FP16 in our logs
ANE_FP16=$(cat /tmp/ane_bench.log | grep -o -E "[0-9]+(\.[0-9]+)? TFLOPS" | tail -n 1 | awk '{print $1}')

if [ -z "$GPU_FP16" ]; then GPU_FP16="0.00"; fi
if [ -z "$ANE_FP16" ]; then ANE_FP16="0.00"; fi

# Calculate Total TOPS natively based on INT8 (approx 2x FP16 on Apple Silicon)
# Note: The Swift app parses TOTAL_FP16, so we feed it the combined baseline.
TOTAL_FP16=$(echo "$GPU_FP16 + $ANE_FP16" | bc)
echo "TOTAL: $TOTAL_FP16 TFLOPS"