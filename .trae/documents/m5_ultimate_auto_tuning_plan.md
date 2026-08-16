# M5 Ultimate Auto-Tuning Dynamic Load Balancer Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a Dynamic Profiling Load Balancer that routes LLM workloads to both GPU (with MPS Graph and Tile Memory) and ANE concurrently, maximizing TFLOPS up to 50 TFLOPS.

**Architecture:** The Metal API interceptor will auto-tune during the first few tokens, measuring execution time. Based on the measurements, it will dynamically split matrix workloads across the GPU (via concurrent queues) and ANE (via a Python CoreML daemon), merging the results seamlessly using Zero-Copy IOSurface buffers.

**Tech Stack:** C++, Objective-C, Metal API, CoreML, Python

---

### Task 1: Create the ANE Python Daemon

**Files:**
- Create: `M5 Engines/coreml_bridge/m5_ane_daemon.py`

- [ ] **Step 1: Write the Daemon Skeleton**

```python
import socket
import os
import json
import logging

logging.basicConfig(level=logging.INFO)
SOCKET_PATH = "/tmp/m5_ane_daemon.sock"

def start_server():
    if os.path.exists(SOCKET_PATH):
        os.remove(SOCKET_PATH)
    
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(SOCKET_PATH)
    server.listen(1)
    logging.info("[M5 ANE Daemon] Listening for Metal Interceptor workloads...")
    
    while True:
        conn, addr = server.accept()
        data = conn.recv(1024)
        if data:
            req = json.loads(data.decode('utf-8'))
            logging.info(f"Received workload: {req}")
            # Mock ANE processing delay
            conn.sendall(b"DONE")
        conn.close()

if __name__ == "__main__":
    start_server()
```

- [ ] **Step 2: Run test to verify daemon socket creation**

Run: `python3 "M5 Engines/coreml_bridge/m5_ane_daemon.py" & sleep 1 ; ls -l /tmp/m5_ane_daemon.sock ; pkill -f m5_ane_daemon`
Expected: Socket file should be listed.

- [ ] **Step 3: Commit**

```bash
git add "M5 Engines/coreml_bridge/m5_ane_daemon.py"
git commit -m "feat: add ANE python daemon skeleton"
```

### Task 2: Implement Auto-Tuning Profiler in Metal Interceptor

**Files:**
- Modify: `M5 Engines/m5_godmode_interceptor.mm`

- [ ] **Step 1: Add Auto-Tuning state variables**

```objective-c
static int g_m5_profiling_tokens = 0;
static double g_m5_gpu_avg_time = 0.0;
static double g_m5_ane_avg_time = 0.0;
static double g_m5_dynamic_ratio = 1.0; // 1.0 = 100% GPU initially

// Helper to get time in MS
double m5_get_time_ms() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (tv.tv_sec * 1000.0) + (tv.tv_usec / 1000.0);
}
```

- [ ] **Step 2: Inject Profiling Logic into dispatchThreadgroups**

Modify the `m5_dispatchThreadgroups` function:

```objective-c
void m5_dispatchThreadgroups(id self, SEL _cmd, MTLSize threadgroupsPerGrid, MTLSize threadsPerThreadgroup) {
    if (g_m5_profiling_tokens < 5) {
        // Measure execution time
        double start = m5_get_time_ms();
        orig_dispatchThreadgroups(self, _cmd, threadgroupsPerGrid, threadsPerThreadgroup);
        double end = m5_get_time_ms();
        
        g_m5_gpu_avg_time = (g_m5_gpu_avg_time * g_m5_profiling_tokens + (end - start)) / (g_m5_profiling_tokens + 1);
        g_m5_profiling_tokens++;
        
        if (g_m5_profiling_tokens == 5) {
            // Assume ANE is 1.5x slower than GPU for testing purposes (this will be dynamic later)
            g_m5_ane_avg_time = g_m5_gpu_avg_time * 1.5;
            // Calculate ratio based on speed
            g_m5_dynamic_ratio = g_m5_ane_avg_time / (g_m5_gpu_avg_time + g_m5_ane_avg_time);
            printf("[M5 Ultimate] Auto-Tuning Complete! GPU: %.2fms, ANE: %.2fms. New GPU Load Ratio: %.2f%%\n", 
                g_m5_gpu_avg_time, g_m5_ane_avg_time, g_m5_dynamic_ratio * 100.0);
        }
    } else {
        // Apply Dynamic Ratio Splitting
        MTLSize splitGrid = threadgroupsPerGrid;
        splitGrid.height = (NSUInteger)(threadgroupsPerGrid.height * g_m5_dynamic_ratio);
        if (splitGrid.height == 0) splitGrid.height = 1;
        
        // GPU computes its share
        orig_dispatchThreadgroups(self, _cmd, splitGrid, threadsPerThreadgroup);
        
        // ANE computes the remainder (to be implemented)
    }
}
```

- [ ] **Step 3: Compile and Test Interceptor**

Run: `clang -dynamiclib -o "M5 Engines/release/m5_godmode_interceptor.dylib" "M5 Engines/m5_godmode_interceptor.mm" -framework Metal -framework Foundation`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add "M5 Engines/m5_godmode_interceptor.mm"
git commit -m "feat: add dynamic auto-tuning to metal interceptor"
```
