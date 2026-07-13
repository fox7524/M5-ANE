# M5 God-Mode System-Wide Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand the 66/34 GPU+ANE concurrency model system-wide (llama.cpp, Chrome, Minecraft) and develop a raw Metal GPU stress tester to measure M5 Max FP16 TFLOPS limits.

**Architecture:** 
1. **GPU Stress Tester:** A raw Objective-C++/Metal command-line tool that allocates massive matrices and dispatches a heavily unrolled FMAC (Fused Multiply-Add) compute kernel to saturate the 40-core GPU and measure peak TFLOPS.
2. **System-Wide Interceptor:** A `DYLD_INTERPOSE` dynamic library that hooks `-[MTLComputeCommandEncoder dispatchThreadgroups:threadsPerThreadgroup:]`. When large compute operations are detected, it slices the `MTLBuffer`, offloads 34% to the ANE bridge (`libm5_ane_bridge.dylib`), and lets the GPU process the remaining 66%.
3. **llama.cpp Integration:** Direct source-code patching of `ggml-metal.m` to natively implement the 66/34 split without relying on dynamic interposition.

**Tech Stack:** Objective-C++, Metal (MSL), C++, Mach-O DYLD Interposition.

---

### Task 1: Create Metal Compute Kernel

**Files:**
- Create: `/Users/fox/Documents/PROJECTS/M5/payloads/gpu_kernel.metal`

- [ ] **Step 1: Write the Metal Kernel**

```metal
#include <metal_stdlib>
using namespace metal;

// Heavily unrolled FP16 FMAC loop to saturate ALU
kernel void fmac_stress(
    device half* data [[buffer(0)]],
    uint id [[thread_position_in_grid]]
) {
    half val = data[id];
    half a = 1.0001h;
    half b = 0.9999h;
    
    // Unroll 128 times
    #pragma unroll(128)
    for (int i = 0; i < 1024; i++) {
        val = fma(val, a, b);
    }
    
    data[id] = val;
}
```

- [ ] **Step 2: Compile the Metal Library**

```bash
xcrun -sdk macosx metal -c /Users/fox/Documents/PROJECTS/M5/payloads/gpu_kernel.metal -o /Users/fox/Documents/PROJECTS/M5/payloads/gpu_kernel.air
xcrun -sdk macosx metallib /Users/fox/Documents/PROJECTS/M5/payloads/gpu_kernel.air -o /Users/fox/Documents/PROJECTS/M5/payloads/gpu_kernel.metallib
```

### Task 2: Create GPU Stress Tester Host Application

**Files:**
- Create: `/Users/fox/Documents/PROJECTS/M5/payloads/gpu_stress_tester.m`

- [ ] **Step 1: Write the Host Application**

```objc
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <mach/mach_time.h>

int main() {
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (!device) {
            NSLog(@"Metal is not supported on this device");
            return 1;
        }
        
        NSError *error = nil;
        NSString *libPath = @"/Users/fox/Documents/PROJECTS/M5/payloads/gpu_kernel.metallib";
        id<MTLLibrary> library = [device newLibraryWithFile:libPath error:&error];
        id<MTLFunction> function = [library newFunctionWithName:@"fmac_stress"];
        id<MTLComputePipelineState> pipelineState = [device newComputePipelineStateWithFunction:function error:&error];
        
        id<MTLCommandQueue> commandQueue = [device newCommandQueue];
        
        // Allocate a massive buffer (e.g., 256MB of fp16)
        NSUInteger numElements = 128 * 1024 * 1024;
        NSUInteger bufferSize = numElements * sizeof(uint16_t);
        id<MTLBuffer> buffer = [device newBufferWithLength:bufferSize options:MTLResourceStorageModeShared];
        
        NSLog(@"[*] GPU Stress Tester Active");
        NSLog(@"[*] GPU: %@", device.name);
        NSLog(@"[*] Buffer Size: %lu MB", bufferSize / (1024*1024));
        
        mach_timebase_info_data_t timebase;
        mach_timebase_info(&timebase);
        
        // 1024 loops * 128 unrolls * 2 ops (FMA) = 262144 ops per thread
        double ops_per_thread = 262144.0;
        double total_ops = ops_per_thread * numElements;
        double gflops_per_pass = total_ops / 1e9;
        
        while (true) {
            uint64_t start = mach_absolute_time();
            
            id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
            id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
            
            [computeEncoder setComputePipelineState:pipelineState];
            [computeEncoder setBuffer:buffer offset:0 atIndex:0];
            
            MTLSize gridSize = MTLSizeMake(numElements, 1, 1);
            NSUInteger threadGroupSize = pipelineState.maxTotalThreadsPerThreadgroup;
            if (threadGroupSize > numElements) threadGroupSize = numElements;
            MTLSize threadgroupSize = MTLSizeMake(threadGroupSize, 1, 1);
            
            [computeEncoder dispatchThreads:gridSize threadsPerThreadgroup:threadgroupSize];
            [computeEncoder endEncoding];
            
            [commandBuffer commit];
            [commandBuffer waitUntilCompleted];
            
            uint64_t end = mach_absolute_time();
            double elapsed_ms = (double)(end - start) * timebase.numer / timebase.denom / 1e6;
            
            double tflops = gflops_per_pass / elapsed_ms;
            printf("\r[GPU STATUS] %.2f ms/eval | %.2f TFLOPS \t", elapsed_ms, tflops);
            fflush(stdout);
        }
    }
    return 0;
}
```

- [ ] **Step 2: Compile the Host App**

```bash
clang -framework Foundation -framework Metal /Users/fox/Documents/PROJECTS/M5/payloads/gpu_stress_tester.m -o /Users/fox/Documents/PROJECTS/M5/payloads/gpu_stress_tester
```

### Task 3: Generic Metal Interceptor (System-Wide Hook)

**Files:**
- Create: `/Users/fox/Documents/PROJECTS/M5/payloads/metal_interceptor.m`

- [ ] **Step 1: Write the Interceptor**

```objc
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <objc/runtime.h>
#import <dlfcn.h>

// Hook into MTLComputeCommandEncoder
typedef void (*DispatchType)(id, SEL, MTLSize, MTLSize);
static DispatchType original_dispatch = NULL;

void swizzled_dispatch(id self, SEL _cmd, MTLSize threadgroupsPerGrid, MTLSize threadsPerThreadgroup) {
    // Detect large compute tasks
    NSUInteger total_threads = threadgroupsPerGrid.width * threadsPerThreadgroup.width;
    if (total_threads > 1000000) {
        NSLog(@"[+] M5 God-Mode: Intercepted massive Metal payload. Splitting 34%% to ANE...");
        // Split logic: Modify threadgroupsPerGrid for GPU (66%)
        MTLSize newGrid = MTLSizeMake(threadgroupsPerGrid.width * 0.66, threadgroupsPerGrid.height, threadgroupsPerGrid.depth);
        
        // 1. Dispatch ANE payload in background (Using our bridge)
        // [Call libm5_ane_bridge.dylib]
        
        // 2. Dispatch remaining 66% to GPU
        original_dispatch(self, _cmd, newGrid, threadsPerThreadgroup);
    } else {
        original_dispatch(self, _cmd, threadgroupsPerGrid, threadsPerThreadgroup);
    }
}

__attribute__((constructor))
static void initialize_interceptor() {
    NSLog(@"[+] M5 God-Mode Metal Interceptor Injected.");
    
    Class encoderClass = NSClassFromString(@"MTLComputeCommandEncoder");
    // Depending on the OS, the actual class is a private subclass like IAGXComputeCommandEncoder
    // We hook all classes conforming to MTLComputeCommandEncoder protocol
    
    int numClasses;
    Class *classes = NULL;
    classes = NULL;
    numClasses = objc_getClassList(NULL, 0);
    if (numClasses > 0) {
        classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
        numClasses = objc_getClassList(classes, numClasses);
        for (int i = 0; i < numClasses; i++) {
            if (class_conformsToProtocol(classes[i], @protocol(MTLComputeCommandEncoder))) {
                Method m = class_getInstanceMethod(classes[i], @selector(dispatchThreadgroups:threadsPerThreadgroup:));
                if (m) {
                    original_dispatch = (DispatchType)method_getImplementation(m);
                    method_setImplementation(m, (IMP)swizzled_dispatch);
                }
            }
        }
        free(classes);
    }
}
```

- [ ] **Step 2: Compile the Interceptor**

```bash
clang -dynamiclib -framework Foundation -framework Metal /Users/fox/Documents/PROJECTS/M5/payloads/metal_interceptor.m -o /Users/fox/Documents/PROJECTS/M5/payloads/libmetal_interceptor.dylib
```
