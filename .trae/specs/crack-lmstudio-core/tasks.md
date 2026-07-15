# Tasks

- [ ] Task 1: Create the JS Hooking Payload
  - [ ] SubTask 1.1: Write a Javascript payload that overrides `require('child_process').spawn`.
  - [ ] SubTask 1.2: Ensure the hook dynamically injects `--tensor-split 18,20` for `llama-server`.
  - [ ] SubTask 1.3: Make the payload safe to prepend (using IIFE and checking if already hooked).

- [ ] Task 2: Create the Crack Script (`crack_lmstudio.js`)
  - [ ] SubTask 2.1: Write a Node.js script that locates `/Applications/LM Studio.app`.
  - [ ] SubTask 2.2: Read and prepend the payload to `.webpack/main/index.js` and `.webpack/lib/llmworker.js`.
  - [ ] SubTask 2.3: Execute `sudo codesign --force --deep --sign - "/Applications/LM Studio.app"` via `child_process.execSync` to strip Hardened Runtime.

- [ ] Task 3: Integrate with M5 Ultimate App
  - [ ] SubTask 3.1: Update `App.swift` or the build process to call `crack_lmstudio.js` instead of the old `inject_lmstudio.sh`.
  - [ ] SubTask 3.2: Remove or disable the old C++ proxy files since they are no longer needed.
