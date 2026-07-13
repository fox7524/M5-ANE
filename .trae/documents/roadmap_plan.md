# Ultimate LLM Studio - Execution Plan

## Summary
This plan outlines the step-by-step execution of the `roadmap.md` for the Ultimate LLM Studio project. We will execute the phases one by one, starting with Phase 1. Since you want to learn Swift and be involved, I will assign you specific, well-explained coding tasks.

## Current State Analysis
- **Architecture**: The app uses a SwiftUI `NavigationSplitView` (`ContentView.swift`) and a backend singleton (`BackendManager.swift`).
- **Phase 1 Status**: `start_server.sh` exists but `BackendManager.startServer()` is currently a stub that only prints "Starting local server...". The required binaries (`llama-server` and `libmetal_interceptor.dylib`) are missing from the repository.

## Proposed Changes (Phase 1: Core Engine Integration)

### 1. Update `BackendManager.swift` to use `Process` (Agent Task)
- **What**: I will write the code to spawn `start_server.sh` using Swift's `Process` (formerly `NSTask`).
- **Why**: To run the LLM server in the background and capture its standard output/error.
- **How**: Create a `startLLMServer(modelPath: String)` function in `BackendManager.swift` that sets up pipes and reads the output asynchronously.

### 2. Connect the UI to the Backend (User Task - Guided)
- **What**: You will update `ContentView.swift` to call the new `startLLMServer` function when the user clicks the "Start Local Server" button, passing the selected model path.
- **Why**: To give you hands-on experience with SwiftUI state (`@State`) and action bindings.
- **How**: I will teach you about Swift's `@ObservedObject` or `@StateObject` and give you instructions on how to hook the button to the manager.

### 3. Handle Missing Binaries (Joint Task)
- **What**: We need to create dummy scripts or download actual binaries for `llama-server` and `libmetal_interceptor.dylib` so the app doesn't crash when `start_server.sh` is called.
- **Why**: The bash script expects these files to exist.

## Assumptions & Decisions
- We are using **Direct Process Invocation** for the background server.
- We are focusing *only* on Phase 1 first. We will move to Phase 2 (UI/UX Design) once Phase 1 is fully working and tested.
- I will act as a mentor, explaining Swift concepts before asking you to write or paste code.

## Verification
- We will verify by running the app and checking if clicking "Start Local Server" successfully spawns the bash script and captures its output without crashing.

---
*Once you approve this plan, I will exit Plan Mode and we will begin Phase 1 immediately!*