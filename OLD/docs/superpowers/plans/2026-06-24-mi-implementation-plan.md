# M5 God-Mode: Metal Interceptor (MI) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a dynamic library (`libane_interceptor.dylib`) that hooks into macOS applications' Metal API calls, routing heavy compute workloads to the ANE (Neural Engine) while letting the GPU handle standard tasks.

**Architecture:** We will use Objective-C runtime method swizzling to intercept `MTLComputeCommandEncoder` dispatches. The intercepted calls will be routed to our existing `ane_bridge` (from ANE-main) for bare-metal ANE execution. A launcher script will use `DYLD_INSERT_LIBRARIES` to inject this library into target apps (Ollama, LM Studio, LokumAI, Minecraft).

**Tech Stack:** Objective-C++, Metal framework, DYLD injection, C++ (ane_bridge).

---

### Task 1: Create the Interceptor Core (Swizzling Setup)

**Files:**
- Create: `MI/lib/MI_Interceptor.h`
- Create: `MI/lib/MI_Interceptor.mm`

- [ ] **Step 1: Define the interceptor header**
```objc
// MI/lib/MI_Interceptor.h
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

@interface MI_Interceptor : NSObject
+ (void)installHooks;
@end
```

- [ ] **Step 2: Implement basic swizzling for MTLComputeCommandEncoder**
```objc
// MI/lib/MI_Interceptor.mm
#import "MI_Interceptor.h"
#import <objc/runtime.h>
#import <iostream>

// This will hold the original implementation
static void (*original_dispatchThreadgroups)(id, SEL, MTLSize, MTLSize);

// Our custom replacement function
static void hooked_dispatchThreadgroups(id self, SEL _cmd, MTLSize threadgroupsPerGrid, MTLSize threadsPerThreadgroup) {
    std::cout << "[MI-Hook] Intercepted GPU Compute Dispatch! Grid: " 
              << threadgroupsPerGrid.width << "x" << threadgroupsPerGrid.height << std::endl;
    
    // TODO: Route to ANE here in future tasks.
    // For now, pass execution back to the real GPU to prevent crashing.
    original_dispatchThreadgroups(self, _cmd, threadgroupsPerGrid, threadsPerThreadgroup);
}

@implementation MI_Interceptor

+ (void)installHooks {
    std::cout << "[MI-Core] Installing Metal API Hooks..." << std::endl;
    
    // We need to hook the concrete class that implements MTLComputeCommandEncoder.
    // Apple often uses private subclasses like IAGXMetalComputeCommandEncoder.
    // A robust way is to hook the base class or use a proxy, but for simplicity in this PoC, 
    // we'll hook the protocol adoption if possible, or wait until runtime to find the exact class.
    
    // NOTE: Hooking Metal objects directly requires finding the specific vendor class (e.g., AGXComputeCommandEncoder).
    // We will simulate the hook installation structure here.
    
    Class targetClass = NSClassFromString(@"AGXComputeCommandEncoder"); // Target Apple Silicon GPU encoder
    if (!targetClass) {
        std::cout << "[MI-Core] Warning: AGXComputeCommandEncoder not found. Hook might fail." << std::endl;
        return;
    }

    SEL originalSelector = @selector(dispatchThreadgroups:threadsPerThreadgroup:);
    Method originalMethod = class_getInstanceMethod(targetClass, originalSelector);
    
    if (originalMethod) {
        original_dispatchThreadgroups = (void (*)(id, SEL, MTLSize, MTLSize))method_getImplementation(originalMethod);
        method_setImplementation(originalMethod, (IMP)hooked_dispatchThreadgroups);
        std::cout << "[MI-Core] Successfully hooked dispatchThreadgroups!" << std::endl;
    }
}

@end

// Constructor function that runs automatically when the dylib is injected via DYLD
__attribute__((constructor))
static void mi_initializer() {
    std::cout << "\n========================================" << std::endl;
    std::cout << "🚀 M5 God-Mode: Metal Interceptor Loaded" << std::endl;
    std::cout << "========================================\n" << std::endl;
    [MI_Interceptor installHooks];
}
```

### Task 2: Build System for the Dylib

**Files:**
- Create: `MI/build_interceptor.sh`

- [ ] **Step 1: Create the build script for the dynamic library**
```bash
# MI/build_interceptor.sh
#!/bin/bash
set -e

echo "[*] Building Metal Interceptor Library..."
mkdir -p build

# Compile the interceptor into a dynamic library (.dylib)
clang++ -dynamiclib -std=c++11 -fobjc-arc -O2 \
    -framework Foundation -framework Metal \
    lib/MI_Interceptor.mm -o build/libane_interceptor.dylib

echo "[+] Build complete: build/libane_interceptor.dylib"
```

- [ ] **Step 2: Make it executable**
Run: `chmod +x MI/build_interceptor.sh`

### Task 3: The Launcher Script (DYLD Injector)

**Files:**
- Create: `MI/mi_launcher.sh`

- [ ] **Step 1: Create the launcher script to inject the library**
```bash
# MI/mi_launcher.sh
#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: ./mi_launcher.sh <path_to_executable_or_command>"
    echo "Example: ./mi_launcher.sh ollama run llama3"
    exit 1
fi

# Get absolute path to our interceptor
INTERCEPTOR_PATH="$(pwd)/build/libane_interceptor.dylib"

if [ ! -f "$INTERCEPTOR_PATH" ]; then
    echo "[!] Error: Interceptor library not found. Run build_interceptor.sh first."
    exit 1
fi

echo "[*] Launching target with ANE Metal Interceptor..."
echo "[*] Target: $@"

# Set DYLD_INSERT_LIBRARIES to force our dylib into the target process
env DYLD_INSERT_LIBRARIES="$INTERCEPTOR_PATH" "$@"
```

- [ ] **Step 2: Make it executable**
Run: `chmod +x MI/mi_launcher.sh`

### Task 4: Integrate ANE-Bridge Routing

**Files:**
- Modify: `MI/lib/MI_Interceptor.mm`

- [ ] **Step 1: Connect the hooked call to the ANE bridge**
Update `MI/lib/MI_Interceptor.mm` to include the `ane_bridge` routing logic.
```objc
// Update in MI/lib/MI_Interceptor.mm
#import "MI_Interceptor.h"
#import <objc/runtime.h>
#import <iostream>

// Declare external C function from ANE-main bridge
extern "C" int ane_bridge_init(void);

static void (*original_dispatchThreadgroups)(id, SEL, MTLSize, MTLSize);

static void hooked_dispatchThreadgroups(id self, SEL _cmd, MTLSize threadgroupsPerGrid, MTLSize threadsPerThreadgroup) {
    // Calculate total threads requested
    NSUInteger totalThreads = threadgroupsPerGrid.width * threadgroupsPerGrid.height * threadgroupsPerGrid.depth *
                              threadsPerThreadgroup.width * threadsPerThreadgroup.height * threadsPerThreadgroup.depth;
    
    // Heuristic: If it's a massive operation, route to ANE
    if (totalThreads > 1000000) {
        std::cout << "[MI-Router] Heavy MatMul detected (" << totalThreads << " threads). Routing to ANE!" << std::endl;
        
        // Ensure ANE bridge is initialized
        static bool aneInitialized = false;
        if (!aneInitialized) {
            if (ane_bridge_init() == 0) {
                aneInitialized = true;
                std::cout << "[MI-Router] ANE Bridge initialized successfully." << std::endl;
            }
        }
        
        // TODO: Map Metal Buffer to IOSurface and call ane_bridge_eval
        // For this PoC phase, we just log the routing and fallback to GPU
        std::cout << "[MI-Router] <Simulated ANE Execution: 27 TOPS>" << std::endl;
    } else {
        // Small workload, let GPU handle it
        // std::cout << "[MI-Router] Light workload. Sending to GPU." << std::endl;
    }
    
    // Always execute the original to prevent app crash during PoC
    original_dispatchThreadgroups(self, _cmd, threadgroupsPerGrid, threadsPerThreadgroup);
}

// ... rest of the file remains the same ...
```

### Task 5: Build and Test on a Simple Target

- [ ] **Step 1: Build the updated interceptor**
Run: `cd MI && ./build_interceptor.sh`

- [ ] **Step 2: Test injection on a simple macOS binary (e.g., Python or a basic Metal app)**
Run: `cd MI && ./mi_launcher.sh python3 -c "print('Testing Injection')"`
Expected output: The terminal should print the "M5 God-Mode: Metal Interceptor Loaded" banner before the python output.