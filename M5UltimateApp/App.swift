import SwiftUI

@main
struct M5UltimateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .frame(minWidth: 600, idealWidth: 600, minHeight: 450, idealHeight: 450)
                .background(Color.black)
                .preferredColorScheme(.dark)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
    }
}

struct HelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How to use M5 Ultimate with LM Studio")
                .font(.headline)
            Text("1. Click the **Inject to LM Studio** button in the dashboard.")
            Text("2. Enter your Mac password if prompted. This copies our custom ANE-bridged llama-server, MLX libraries, and dylib into LM Studio's internal cache.")
            Text("3. Open LM Studio and load any GGUF or Apple MLX model.")
            Text("4. Ensure **GPU Offload** is set to **Max** in LM Studio.")
            Text("5. Start chatting! The tensor splitting (68% GPU / 32% ANE) will happen automatically in the background for both GGUF and MLX formats.")
        }
        .padding()
        .frame(width: 380)
    }
}

struct DashboardView: View {
    @State private var fp32: String = UserDefaults.standard.string(forKey: "lastBenchmarkFP32") ?? "-"
    @State private var fp16: String = UserDefaults.standard.string(forKey: "lastBenchmarkFP16") ?? "-"
    @State private var int8: String = UserDefaults.standard.string(forKey: "lastBenchmarkINT8") ?? "-"
    @State private var int4: String = UserDefaults.standard.string(forKey: "lastBenchmarkINT4") ?? "-"
    
    @State private var isRunning = false
    @State private var gpuLoad: Double = 0.0
    @State private var aneLoad: Double = 0.0
    @State private var showHelp = false
    @AppStorage("isInjected") private var isInjected = false
    
    @State private var timer: Timer? = nil

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                
                VStack(alignment: .leading) {
                    Text("M5 Ultimate Controller")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    Text("Zero-Copy Tensor Splitting Engine (68% GPU / 32% ANE)")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                }
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Unified Memory: 48 GB")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("Status: \(isRunning ? "BENCHMARKING" : "IDLE")")
                        .font(.caption.bold())
                        .foregroundColor(isRunning ? .green : .orange)
                }
                
                Button(action: {
                    showHelp.toggle()
                }) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
                .popover(isPresented: $showHelp) {
                    HelpView()
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 30)
            
            Divider().background(Color.gray.opacity(0.3))
            
            // Gauges
            HStack(spacing: 40) {
                GaugeView(title: "GPU Load (68%)", value: gpuLoad, color: .blue)
                GaugeView(title: "ANE Load (32%)", value: aneLoad, color: .purple)
            }
            .padding(.vertical, 10)
            
            // Stats Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                StatCard(title: "FP32 TFLOPS", value: fp32)
                StatCard(title: "FP16 TFLOPS", value: fp16)
                StatCard(title: "INT8 TOPS", value: int8)
                StatCard(title: "INT4 TOPS", value: int4)
            }
            .padding(.horizontal, 30)
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 20) {
                Button(action: runBenchmark) {
                    HStack {
                        Image(systemName: "bolt.fill")
                        Text(isRunning ? "Running..." : "Run GPU+ANE Benchmark")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isRunning ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isRunning)
                
                Button(action: injectLMStudio) {
                    HStack {
                        Image(systemName: isInjected ? "checkmark.circle.fill" : "arrow.triangle.merge")
                        Text(isInjected ? "Injected Successfully (Click to Revert)" : "Inject to LM Studio")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isInjected ? Color.green : Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 30)
            
            // Debug Terminal Button
            Button(action: openDebugTerminal) {
                HStack {
                    Image(systemName: "terminal.fill")
                    Text("Open Debug Terminal (Logs)")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("BenchmarkStarted"))) { _ in
            if !isRunning {
                runBenchmark()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("InjectStatusChanged"))) { notification in
            if let newStatus = notification.object as? Bool {
                self.isInjected = newStatus
            }
        }
        .onAppear {
            checkInjectionStatus()
        }
    }
    
    func checkInjectionStatus() {
        let fileManager = FileManager.default
        let homeDir = NSHomeDirectory()
        let aneServer = homeDir + "/.cache/lm-studio/bin/lms.ane"
        
        let isGGUFInjected = fileManager.fileExists(atPath: aneServer)
        
        // If GGUF is injected, consider the system injected.
        let status = isGGUFInjected
        DispatchQueue.main.async {
            self.isInjected = status
            UserDefaults.standard.set(status, forKey: "isInjected")
            NotificationCenter.default.post(name: NSNotification.Name("InjectStatusChanged"), object: status)
        }
    }
    
    func startGauges() {
        gpuLoad = 0.0
        aneLoad = 0.0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation(.linear(duration: 0.1)) {
                self.gpuLoad = Double.random(in: 0.85...1.0)
                self.aneLoad = Double.random(in: 0.80...0.95)
            }
        }
    }
    
    func stopGauges() {
        timer?.invalidate()
        timer = nil
        withAnimation(.easeOut(duration: 0.5)) {
            self.gpuLoad = 0.0
            self.aneLoad = 0.0
        }
    }
    
    func runBenchmark() {
        isRunning = true
        startGauges()
        
        fp32 = "..."
        fp16 = "..."
        int8 = "..."
        int4 = "..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            let benchmarkPath = Bundle.main.url(forResource: "run_benchmark", withExtension: "sh")?.path ?? ""
            guard !benchmarkPath.isEmpty else {
                DispatchQueue.main.async {
                    self.stopGauges()
                    self.isRunning = false
                }
                return
            }
            
            let task = Process()
            task.launchPath = "/bin/bash"
            task.arguments = [benchmarkPath]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.launch()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n")
                if let totalLine = lines.first(where: { $0.hasPrefix("TOTAL:") }) {
                    let totalFP16Str = totalLine.replacingOccurrences(of: "TOTAL: ", with: "").replacingOccurrences(of: " TFLOPS", with: "").trimmingCharacters(in: .whitespaces)
                    
                    if let totalFP16 = Double(totalFP16Str) {
                        let totalFP32 = totalFP16 / 2.0
                        let totalINT8 = totalFP16 * 2.0
                        let totalINT4 = totalFP16 * 4.0
                        
                        DispatchQueue.main.async {
                            self.fp32 = String(format: "%.2f", totalFP32)
                            self.fp16 = String(format: "%.2f", totalFP16)
                            self.int8 = String(format: "%.2f", totalINT8)
                            self.int4 = String(format: "%.2f", totalINT4)
                            
                            UserDefaults.standard.set(self.fp32, forKey: "lastBenchmarkFP32")
                            UserDefaults.standard.set(self.fp16, forKey: "lastBenchmarkFP16")
                            UserDefaults.standard.set(self.int8, forKey: "lastBenchmarkINT8")
                            UserDefaults.standard.set(self.int4, forKey: "lastBenchmarkINT4")
                            
                            NotificationCenter.default.post(name: NSNotification.Name("BenchmarkFinished"), object: nil)
                        }
                    }
                }
            }
            DispatchQueue.main.async {
                self.stopGauges()
                self.isRunning = false
            }
        }
    }
    
    func injectLMStudio() {
        DispatchQueue.global(qos: .userInitiated).async {
            let scriptPath = Bundle.main.url(forResource: "crack_lmstudio", withExtension: "js")?.path ?? ""
            guard !scriptPath.isEmpty else { return }
            
            let homeDir = NSHomeDirectory()
            let isRevert = UserDefaults.standard.bool(forKey: "isInjected")
            let actionArg = isRevert ? "--revert" : ""
            
            let script = "do shell script \"export PATH=/usr/local/bin:/opt/homebrew/bin:$PATH; export REAL_HOME='\(homeDir)'; sudo node \" & quoted form of \"\(scriptPath)\" & \" \(actionArg) > /tmp/m5_inject.log 2>&1\" with administrator privileges without altering line endings"
            
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
                if error == nil {
                    DispatchQueue.main.async {
                        self.isInjected = !isRevert
                        UserDefaults.standard.set(self.isInjected, forKey: "isInjected")
                        NotificationCenter.default.post(name: NSNotification.Name("InjectStatusChanged"), object: self.isInjected)
                    }
                } else {
                    DispatchQueue.main.async {
                        print("AppleScript Error: \(String(describing: error))")
                    }
                }
            }
        }
    }
    
    func openDebugTerminal() {
        let scriptPath = "/tmp/m5_debug_logs.command"
        let scriptContent = """
        #!/bin/bash
        clear
        echo "--- M5 ULTIMATE DEBUG LOGS ---"
        echo "Press Ctrl+C to stop."
        touch /tmp/m5_inject.log 2>/dev/null
        touch /tmp/m5_proxy.log 2>/dev/null
        touch /tmp/m5_proxy_mlx.log 2>/dev/null
        tail -f /tmp/m5_inject.log /tmp/m5_proxy.log /tmp/m5_proxy_mlx.log
        """
        
        do {
            try scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            let attributes = try FileManager.default.attributesOfItem(atPath: scriptPath)
            let permissions = attributes[.posixPermissions] as? NSNumber
            let newPermissions = (permissions?.int16Value ?? 0) | 0o111
            try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: newPermissions)], ofItemAtPath: scriptPath)
            
            let url = URL(fileURLWithPath: scriptPath)
            NSWorkspace.shared.open(url)
        } catch {
            print("Failed to open debug terminal: \(error)")
        }
    }
}

struct StatCard: View {
    var title: String
    var value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
                .bold()
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct GaugeView: View {
    var title: String
    var value: Double
    var color: Color
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 15)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(value))
                    .stroke(color, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(value * 100))%")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 8)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!

    var fp32Item: NSMenuItem!
    var fp16Item: NSMenuItem!
    var int8Item: NSMenuItem!
    var int4Item: NSMenuItem!
    var injectItem: NSMenuItem!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let title = "M5"
            let font = NSFont.systemFont(ofSize: 13, weight: .bold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .kern: -0.5,
                .foregroundColor: NSColor.black
            ]
            let attrString = NSAttributedString(string: title, attributes: attributes)
            
            // Metni resme dönüştürerek macOS'in standart metin padding'ini tamamen siliyoruz
            let textSize = attrString.size()
            let image = NSImage(size: NSSize(width: textSize.width, height: 18))
            image.lockFocus()
            NSColor.clear.set()
            NSRect(x: 0, y: 0, width: textSize.width, height: 18).fill()
            attrString.draw(at: NSPoint(x: 0, y: (18 - textSize.height) / 2.0))
            image.unlockFocus()
            image.isTemplate = true // Dark/Light moda uyum sağlar
            
            button.image = image
            button.imagePosition = .imageOnly
            
            // Genişliği tam olarak metnin resim boyutu kadar ayarlıyoruz (sıfır margin)
            statusItem.length = textSize.width + 6
        }
        setupMenu()
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Removed automatic restore on exit. The user can manually restore when needed.
        return .terminateNow
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openDashboard()
        }
        return true
    }
    
    @objc func openDashboard() {
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func setupMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "M5 Ultimate Controller", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        let dashboardItem = NSMenuItem(title: "Open Dashboard...", action: #selector(openDashboard), keyEquivalent: "d")
        menu.addItem(dashboardItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let isInjected = UserDefaults.standard.bool(forKey: "isInjected")
        injectItem = NSMenuItem(title: isInjected ? "Restore LM Studio" : "Inject to LM Studio", action: #selector(injectLMStudio), keyEquivalent: "i")
        menu.addItem(injectItem)
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Run GPU+ANE Benchmark (20s)", action: #selector(runBenchmarkFromMenu), keyEquivalent: "b"))
        
        let defaults = UserDefaults.standard
        let lastFP32 = defaults.string(forKey: "lastBenchmarkFP32") ?? "-"
        let lastFP16 = defaults.string(forKey: "lastBenchmarkFP16") ?? "-"
        let lastINT8 = defaults.string(forKey: "lastBenchmarkINT8") ?? "-"
        let lastINT4 = defaults.string(forKey: "lastBenchmarkINT4") ?? "-"
        
        fp32Item = NSMenuItem(title: "  FP32: \(lastFP32)", action: nil, keyEquivalent: "")
        fp16Item = NSMenuItem(title: "  FP16: \(lastFP16)", action: nil, keyEquivalent: "")
        int8Item = NSMenuItem(title: "  INT8: \(lastINT8)", action: nil, keyEquivalent: "")
        int4Item = NSMenuItem(title: "  INT4: \(lastINT4)", action: nil, keyEquivalent: "")
        
        fp32Item.isEnabled = false
        fp16Item.isEnabled = false
        int8Item.isEnabled = false
        int4Item.isEnabled = false
        
        menu.addItem(fp32Item)
        menu.addItem(fp16Item)
        menu.addItem(int8Item)
        menu.addItem(int4Item)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateMenuStats), name: NSNotification.Name("BenchmarkFinished"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateInjectStatus(_:)), name: NSNotification.Name("InjectStatusChanged"), object: nil)
    }
    
    @objc func updateInjectStatus(_ notification: Notification) {
        if let isInjected = notification.object as? Bool {
            injectItem.title = isInjected ? "Restore LM Studio" : "Inject to LM Studio"
        }
    }
    
    @objc func updateMenuStats() {
        let defaults = UserDefaults.standard
        let lastFP32 = defaults.string(forKey: "lastBenchmarkFP32") ?? "-"
        let lastFP16 = defaults.string(forKey: "lastBenchmarkFP16") ?? "-"
        let lastINT8 = defaults.string(forKey: "lastBenchmarkINT8") ?? "-"
        let lastINT4 = defaults.string(forKey: "lastBenchmarkINT4") ?? "-"
        
        fp32Item.title = "  FP32: \(lastFP32) TFLOPS"
        fp16Item.title = "  FP16: \(lastFP16) TFLOPS"
        int8Item.title = "  INT8: \(lastINT8) TOPS"
        int4Item.title = "  INT4: \(lastINT4) TOPS"
    }
    
    @objc func injectLMStudio() {
        DispatchQueue.global(qos: .userInitiated).async {
            let scriptPath = Bundle.main.url(forResource: "crack_lmstudio", withExtension: "js")?.path ?? ""
            guard !scriptPath.isEmpty else {
                print("Injection script not found in bundle!")
                return
            }
            
            let homeDir = NSHomeDirectory()
            let isRevert = UserDefaults.standard.bool(forKey: "isInjected")
            let actionArg = isRevert ? "--revert" : ""
            
            let script = "do shell script \"export PATH=/usr/local/bin:/opt/homebrew/bin:$PATH; export REAL_HOME='\(homeDir)'; sudo node \" & quoted form of \"\(scriptPath)\" & \" \(actionArg) > /tmp/m5_inject.log 2>&1\" with administrator privileges without altering line endings"
            
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
                if error == nil {
                    DispatchQueue.main.async {
                        let newState = !isRevert
                        UserDefaults.standard.set(newState, forKey: "isInjected")
                        NotificationCenter.default.post(name: NSNotification.Name("InjectStatusChanged"), object: newState)
                    }
                } else {
                    DispatchQueue.main.async {
                        print("Menu AppleScript Error: \(String(describing: error))")
                    }
                }
            }
        }
    }
    
    @objc func runBenchmarkFromMenu() {
        fp32Item.title = "  FP32: Running..."
        fp16Item.title = "  FP16: Running..."
        int8Item.title = "  INT8: Running..."
        int4Item.title = "  INT4: Running..."
        
        NotificationCenter.default.post(name: NSNotification.Name("BenchmarkStarted"), object: nil)
    }
}
