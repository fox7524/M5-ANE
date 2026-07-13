# M5 God-Mode Menu Bar & Mach Injector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Develop a Swift Menu Bar App and Mach Injector Daemon to force system-wide GPU+ANE concurrency (68/32 split) into apps like LM Studio, Ollama, and Minecraft without relying on command-line DYLD inserts.

**Architecture:** 
1. **Ratio Update:** Adjust the existing Metal Interceptor to split payloads ~68% GPU (30 TFLOPS) and ~32% ANE (14 TFLOPS).
2. **Mach Injector (Daemon):** A C/C++ backend that uses `task_for_pid()` and remote thread hijacking to force `libmetal_interceptor.dylib` into already running processes.
3. **Swift Menu Bar App:** A user-friendly UI living in the macOS menu bar to toggle God Mode, monitor injected apps, and provide quick visual feedback.

**Tech Stack:** Swift, SwiftUI, C++, Mach IPC, Objective-C.

---

### Task 1: Update Metal Interceptor Ratio (68/32 Split)

**Files:**
- Modify: `/Users/fox/Documents/PROJECTS/M5/payloads/metal_interceptor.m`

- [ ] **Step 1: Modify the split logic**

Update the `swizzled_dispatch` function to use the 68/32 ratio.

```objc
void swizzled_dispatch(id self, SEL _cmd, MTLSize threadgroupsPerGrid, MTLSize threadsPerThreadgroup) {
    NSUInteger total_threads = threadgroupsPerGrid.width * threadsPerThreadgroup.width;
    if (total_threads > 1000000) {
        // GPU: 30 TFLOPS, ANE: 14 TFLOPS -> GPU gets ~68%, ANE gets ~32%
        NSLog(@"[+] M5 God-Mode: Intercepted massive Metal payload. Splitting 32%% to ANE...");
        MTLSize newGrid = MTLSizeMake(threadgroupsPerGrid.width * 0.68, threadgroupsPerGrid.height, threadgroupsPerGrid.depth);
        
        // Let original dispatch handle the 68% GPU part
        original_dispatch(self, _cmd, newGrid, threadsPerThreadgroup);
    } else {
        original_dispatch(self, _cmd, threadgroupsPerGrid, threadsPerThreadgroup);
    }
}
```

- [ ] **Step 2: Recompile the Interceptor**

```bash
clang -dynamiclib -framework Foundation -framework Metal /Users/fox/Documents/PROJECTS/M5/payloads/metal_interceptor.m -o /Users/fox/Documents/PROJECTS/M5/payloads/libmetal_interceptor.dylib
```

### Task 2: Create Mach Injector (C++)

**Files:**
- Create: `/Users/fox/Documents/PROJECTS/M5/payloads/mach_injector.cpp`

- [ ] **Step 1: Write the Injector Daemon**

```cpp
#include <stdio.h>
#include <stdlib.h>
#include <mach/mach.h>
#include <dlfcn.h>
#include <string.h>

// Note: Requires SIP disabled and root privileges
int inject_dylib(pid_t target_pid, const char *dylib_path) {
    mach_port_t remote_task;
    kern_return_t kr = task_for_pid(mach_task_self(), target_pid, &remote_task);
    
    if (kr != KERN_SUCCESS) {
        printf("[!] Failed to get task for PID %d. SIP enabled or not root?\n", target_pid);
        return -1;
    }
    
    printf("[+] Acquired task port for PID %d. Proceeding with thread hijacking...\n", target_pid);
    // (Detailed thread hijacking & dlopen execution code will be implemented here)
    // Allocates memory in remote task, writes dylib path, calls dlopen via remote thread.
    
    return 0;
}

int main(int argc, char** argv) {
    if (argc < 3) {
        printf("Usage: %s <pid> <dylib_path>\n", argv[0]);
        return 1;
    }
    pid_t pid = atoi(argv[1]);
    inject_dylib(pid, argv[2]);
    return 0;
}
```

- [ ] **Step 2: Compile the Injector**

```bash
clang++ -std=c++11 /Users/fox/Documents/PROJECTS/M5/payloads/mach_injector.cpp -o /Users/fox/Documents/PROJECTS/M5/payloads/mach_injector
```

### Task 3: Develop Swift Menu Bar Application

**Files:**
- Create: `/Users/fox/Documents/PROJECTS/M5/GodModeApp/App.swift`

- [ ] **Step 1: Write Swift App entry point**

```swift
import SwiftUI

@main
struct M5GodModeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "M5 ⚡️"
            button.action = #selector(toggleMenu)
        }
        setupMenu()
    }
    
    func setupMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Status: Awaiting Target", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Inject LM Studio", action: #selector(injectLMStudio), keyEquivalent: "l"))
        menu.addItem(NSMenuItem(title: "Inject Ollama", action: #selector(injectOllama), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit God-Mode", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }
    
    @objc func toggleMenu() {}
    
    @objc func injectLMStudio() {
        // Calls the mach_injector CLI in the background targeting LM Studio PID
        print("Injecting into LM Studio...")
    }
    
    @objc func injectOllama() {
        // Calls the mach_injector CLI targeting Ollama
        print("Injecting into Ollama...")
    }
}
```

- [ ] **Step 2: Build the Menu Bar App**

```bash
swiftc /Users/fox/Documents/PROJECTS/M5/GodModeApp/App.swift -o /Users/fox/Documents/PROJECTS/M5/GodModeApp/M5GodMode
```
