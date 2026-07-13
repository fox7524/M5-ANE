# M5 Ultimate V2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a standalone Native macOS (SwiftUI) application that hosts its own GGUF/MLX engines with direct `libmetal_interceptor.dylib` injection to bypass Apple Hardened Runtime.
**Architecture:** 3-pane SwiftUI layout (Discovery, Chat, Hardware Control). The app spawns local API servers (`llama-server`, `python3.11`) as child processes, injecting the custom Metal interceptor directly to enable dynamic Zero-Copy Tensor Splitting.
**Tech Stack:** Swift, SwiftUI, bash, Python, C++, Metal.

---

### Task 1: Setup V2 Project Structure & Remove Legacy Injection Code

**Files:**
- Modify: `M5UltimateV2/build.sh`
- Create: `M5UltimateV2/start_server.sh`
- Delete: `M5UltimateV2/inject_lmstudio.sh` (if exists)

- [ ] **Step 1: Clean legacy code**
```bash
cd M5UltimateV2
rm -f inject_lmstudio.sh
```

- [ ] **Step 2: Update build script**
Modify `M5UltimateV2/build.sh` to package `start_server.sh` instead of injection payloads.
```bash
# In M5UltimateV2/build.sh
# Replace injection copying with:
cp start_server.sh "$RESOURCES_DIR/"
chmod +x "$RESOURCES_DIR/start_server.sh"
```

- [ ] **Step 3: Create Server Launcher Script**
```bash
cat << 'EOF' > M5UltimateV2/start_server.sh
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
EOF
chmod +x M5UltimateV2/start_server.sh
```

- [ ] **Step 4: Commit**
```bash
git add M5UltimateV2/build.sh M5UltimateV2/start_server.sh
git commit -m "chore: setup v2 server launcher and remove legacy injection"
```

### Task 2: Implement 3-Pane SwiftUI Architecture

**Files:**
- Modify: `M5UltimateV2/App.swift`

- [ ] **Step 1: Define UI Layout**
Replace the current single-view UI with an `HSplitView` or `NavigationSplitView`.
```swift
struct ContentView: View {
    @State private var splitRatio: Double = 68.0
    
    var body: some View {
        NavigationSplitView {
            // Left: Discovery
            List {
                Text("Local Models")
                // Model scanning logic later
            }
            .navigationTitle("Library")
        } content: {
            // Center: Chat & Engine Status
            VStack {
                Text("Engine: Stopped")
                Button("Start Local Server") {
                    startServer()
                }
            }
            .navigationTitle("Playground")
        } detail: {
            // Right: Hardware Control
            VStack {
                Text("Hardware Control")
                Slider(value: $splitRatio, in: 0...100, step: 1.0) {
                    Text("GPU: \(Int(splitRatio))% / ANE: \(Int(100 - splitRatio))%")
                }
                .onChange(of: splitRatio) { newValue in
                    updateSplitRatio(newValue)
                }
            }
            .navigationTitle("Metrics")
        }
    }
    
    func startServer() {
        // NSTask / Process execution for start_server.sh
    }
    
    func updateSplitRatio(_ value: Double) {
        // Shared memory / IPC update logic
    }
}
```

- [ ] **Step 2: Commit**
```bash
git add M5UltimateV2/App.swift
git commit -m "feat: implement 3-pane ui architecture for v2"
```

### Task 3: Local Model Scanner

**Files:**
- Modify: `M5UltimateV2/App.swift`

- [ ] **Step 1: Implement File Scanning**
Add a function to scan `~/.lmstudio/models`.
```swift
func scanLocalModels() -> [String] {
    let fm = FileManager.default
    let home = fm.homeDirectoryForCurrentUser
    let lmStudioPath = home.appendingPathComponent(".lmstudio/models")
    
    guard let enumerator = fm.enumerator(at: lmStudioPath, includingPropertiesForKeys: [.isRegularFileKey]) else { return [] }
    
    var models: [String] = []
    for case let fileURL as URL in enumerator {
        if fileURL.pathExtension == "gguf" {
            models.append(fileURL.lastPathComponent)
        }
    }
    return models
}
```

- [ ] **Step 2: Update UI State**
Bind the scanned models to the Left Column list.

- [ ] **Step 3: Commit**
```bash
git add M5UltimateV2/App.swift
git commit -m "feat: add local model discovery for lmstudio folder"
```