# UI and Backend Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect the LM Studio SwiftUI clone to the actual llama.cpp backend via a direct Objective-C++ bridge, allowing real model loading and streaming generation.

**Architecture:** We will create a `ModelScanner` to fetch models from `~/.cache/lm-studio/models`. We will introduce an Objective-C++ wrapper (`LLMEngine`) around `llama.cpp` to handle memory management, model loading, and streaming inference. `BackendManager.swift` will act as the high-level coordinator bridging SwiftUI and `LLMEngine`.

**Tech Stack:** Swift, SwiftUI, Objective-C++, C++, llama.cpp, XCTest

---

### Task 1: Model Scanner Implementation

**Files:**
- Create: `UltimateLLMStudio/ModelScanner.swift`
- Create: `UltimateLLMStudio/ModelScannerTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import UltimateLLMStudio

final class ModelScannerTests: XCTestCase {
    func testScanningModels() {
        let scanner = ModelScanner()
        // We assume there's at least one model in the local LM Studio cache or we mock the path
        let models = scanner.scanForGGUFModels(in: "~/.cache/lm-studio/models")
        XCTAssertNotNil(models)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project UltimateLLMStudio.xcodeproj -scheme UltimateLLMStudio`
Expected: FAIL (Cannot find ModelScanner)

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

public class ModelScanner {
    public init() {}
    
    public func scanForGGUFModels(in path: String) -> [String] {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let fileManager = FileManager.default
        var ggufFiles: [String] = []
        
        guard let enumerator = fileManager.enumerator(atPath: expandedPath) else {
            return []
        }
        
        while let file = enumerator.nextObject() as? String {
            if file.hasSuffix(".gguf") {
                ggufFiles.append(file)
            }
        }
        
        return ggufFiles
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project UltimateLLMStudio.xcodeproj -scheme UltimateLLMStudio`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add UltimateLLMStudio/ModelScanner.swift UltimateLLMStudio/ModelScannerTests.swift
git commit -m "feat: add ModelScanner to find local gguf files"
```

### Task 2: Create Objective-C++ Bridge Interface (LLMEngine)

**Files:**
- Create: `UltimateLLMStudio/LLMEngine.h`
- Create: `UltimateLLMStudio/LLMEngine.mm`
- Modify: `UltimateLLMStudio/M5Ultimate-Bridging-Header.h`

- [ ] **Step 1: Define the ObjC Interface**

```objc
// UltimateLLMStudio/LLMEngine.h
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LLMEngine : NSObject

- (BOOL)loadModelAtPath:(NSString *)path gpuLayers:(int)gpuLayers;
- (void)generateResponseForPrompt:(NSString *)prompt onToken:(void (^)(NSString *token))onToken onComplete:(void (^)(void))onComplete;
- (void)unloadModel;

@end

NS_ASSUME_NONNULL_END
```

- [ ] **Step 2: Expose in Bridging Header**

```objc
// UltimateLLMStudio/M5Ultimate-Bridging-Header.h
// Add this line:
#import "LLMEngine.h"
```

- [ ] **Step 3: Implement Stub LLMEngine**

```objc
// UltimateLLMStudio/LLMEngine.mm
#import "LLMEngine.h"

@implementation LLMEngine

- (BOOL)loadModelAtPath:(NSString *)path gpuLayers:(int)gpuLayers {
    // Stub: Real llama.cpp integration will be done after pulling the library
    NSLog(@"[LLMEngine] Mock loading model at %@ with %d layers", path, gpuLayers);
    return YES;
}

- (void)generateResponseForPrompt:(NSString *)prompt onToken:(void (^)(NSString *))onToken onComplete:(void (^)(void))onComplete {
    // Stub: Simulate token streaming
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *words = @[@"This", @"is", @"a", @"mock", @"C++", @"engine", @"response."];
        for (NSString *word in words) {
            [NSThread sleepForTimeInterval:0.1];
            dispatch_async(dispatch_get_main_queue(), ^{
                onToken([NSString stringWithFormat:@"%@ ", word]);
            });
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            onComplete();
        });
    });
}

- (void)unloadModel {
    NSLog(@"[LLMEngine] Mock unloading model");
}

@end
```

- [ ] **Step 4: Commit**

```bash
git add UltimateLLMStudio/LLMEngine.h UltimateLLMStudio/LLMEngine.mm UltimateLLMStudio/M5Ultimate-Bridging-Header.h
git commit -m "feat: create ObjC++ LLMEngine bridge stub"
```

### Task 3: Update BackendManager to use LLMEngine

**Files:**
- Modify: `UltimateLLMStudio/BackendManager.swift`

- [ ] **Step 1: Replace Bash Process with LLMEngine**

```swift
// UltimateLLMStudio/BackendManager.swift
import Foundation

class BackendManager: ObservableObject {
    static let shared = BackendManager()
    
    @Published var isServerRunning = false
    @Published var serverLogs = ""
    
    private let engine = LLMEngine()
    
    func startLLMServer(modelPath: String, gpuLayers: Int = 32) {
        serverLogs += "Loading model via C++ Engine...\n"
        DispatchQueue.global(qos: .userInitiated).async {
            let success = self.engine.loadModel(atPath: modelPath, gpuLayers: Int32(gpuLayers))
            DispatchQueue.main.async {
                if success {
                    self.isServerRunning = true
                    self.serverLogs += "Model loaded successfully.\n"
                } else {
                    self.serverLogs += "Failed to load model.\n"
                }
            }
        }
    }
    
    func stopLLMServer() {
        engine.unloadModel()
        isServerRunning = false
        serverLogs += "Model unloaded.\n"
    }
    
    func generate(prompt: String, onToken: @escaping (String) -> Void, onComplete: @escaping () -> Void) {
        engine.generateResponse(forPrompt: prompt, onToken: onToken, onComplete: onComplete)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add UltimateLLMStudio/BackendManager.swift
git commit -m "refactor: migrate BackendManager to use ObjC++ LLMEngine"
```

### Task 4: Connect SwiftUI UI to BackendManager and ModelScanner

**Files:**
- Modify: `UltimateLLMStudio/ContentView.swift`

- [ ] **Step 1: Update UI to Use Real Data**

```swift
// In ContentView.swift
// 1. Add ModelScanner
let scanner = ModelScanner()

// 2. Change `localModels` initialization:
@State private var localModels: [String] = []

// 3. Add .onAppear to load models:
.onAppear {
    let models = scanner.scanForGGUFModels(in: "~/.cache/lm-studio/models")
    localModels = models.map { ($0 as NSString).lastPathComponent }
    selectedModel = localModels.first
}

// 4. Update `sendMessage` to use real streaming:
func sendMessage() {
    let text = chatText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }
    
    messages.append(ChatMessage(role: .user, content: text))
    chatText = ""
    isGenerating = true
    
    self.messages.append(ChatMessage(role: .assistant, content: ""))
    
    backend.generate(prompt: text) { token in
        if let last = self.messages.indices.last {
            self.messages[last] = ChatMessage(role: .assistant, content: self.messages[last].content + token)
        }
    } onComplete: {
        self.isGenerating = false
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add UltimateLLMStudio/ContentView.swift
git commit -m "feat: connect UI to BackendManager streaming and ModelScanner"
```
