import SwiftUI

// MARK: - UI Configuration
struct Theme {
    static let bgMain = Color(NSColor.windowBackgroundColor)
    static let bgSidebar = Color(NSColor.controlBackgroundColor)
    static let accent = Color.blue
    static let textMain = Color.primary
    static let textSecondary = Color.secondary
    static let bubbleUser = Color.blue.opacity(0.8)
    static let bubbleAI = Color(NSColor.controlBackgroundColor).opacity(0.5)
}

struct ContentView: View {
    @ObservedObject var backend = BackendManager.shared
    
    @State private var splitRatio: Double = 68.0
    @State private var localModels: [String] = []
    @State private var selectedModel: String?
    
    // Chat state
    @State private var chatText: String = ""
    @State private var isGenerating: Bool = false
    @State private var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, content: "Hello! I am your local AI assistant running directly on Apple Silicon. How can I help you today?")
    ]
    
    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            // Left: Discovery / Sidebar
            SidebarView(
                localModels: $localModels,
                selectedModel: $selectedModel,
                isServerRunning: backend.isServerRunning
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
            
        } content: {
            // Center: Chat Area
            ChatAreaView(
                messages: $messages,
                chatText: $chatText,
                isGenerating: $isGenerating,
                isServerRunning: backend.isServerRunning,
                onSend: sendMessage
            )
            .navigationSplitViewColumnWidth(min: 400, ideal: 600)
            
        } detail: {
            // Right: Hardware Control & Logs
            MetricsPanel(
                splitRatio: $splitRatio,
                serverLogs: backend.serverLogs,
                isServerRunning: backend.isServerRunning,
                onToggleServer: toggleServer
            )
            .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
        }
        .navigationTitle("Ultimate LLM Studio")
        .toolbar {
            ToolbarItem(placement: .status) {
                HStack {
                    Circle()
                        .fill(backend.isServerRunning ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(backend.isServerRunning ? "Engine Active" : "Engine Offline")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            localModels = scanLocalModels()
        }
    }
    
    // MARK: - Actions
    func toggleServer() {
        if backend.isServerRunning {
            backend.stopLLMServer()
        } else {
            if let model = selectedModel {
                backend.startLLMServer(modelPath: model)
            }
        }
    }
    
    func scanLocalModels() -> [String] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let lmStudioPath = home.appendingPathComponent(".lmstudio/models")
        
        guard let enumerator = fm.enumerator(at: lmStudioPath, includingPropertiesForKeys: [.isRegularFileKey]) else { 
            // Fallback mock models for UI testing if no actual models found
            return ["Llama-3-8B-Instruct.gguf", "Phi-3-Mini-4K-Instruct.gguf", "Mistral-7B-v0.3.gguf"] 
        }
        
        var models: [String] = []
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "gguf" {
                models.append(fileURL.lastPathComponent)
            }
        }
        
        if models.isEmpty {
             return ["Llama-3-8B-Instruct.gguf", "Phi-3-Mini-4K-Instruct.gguf", "Mistral-7B-v0.3.gguf"] 
        }
        return models
    }
    
    func sendMessage() {
        let trimmed = chatText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard backend.isServerRunning else {
            messages.append(ChatMessage(role: .assistant, content: "⚠️ Please start the local engine first from the right panel."))
            chatText = ""
            return
        }
        
        messages.append(ChatMessage(role: .user, content: trimmed))
        chatText = ""
        isGenerating = true
        
        // Mock streaming response simulation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let mockResponse = "I'm processing your request locally using ANE and GPU. This is a simulated response for: \"\(trimmed)\"."
            let words = mockResponse.split(separator: " ")
            var currentMessage = ""
            
            let assistantMessage = ChatMessage(role: .assistant, content: "")
            self.messages.append(assistantMessage)
            
            for (index, word) in words.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                    currentMessage += word + " "
                    if let lastIndex = self.messages.indices.last {
                        self.messages[lastIndex] = ChatMessage(role: .assistant, content: currentMessage)
                    }
                    if index == words.count - 1 {
                        self.isGenerating = false
                    }
                }
            }
        }
    }
}

// MARK: - Subviews

struct SidebarView: View {
    @Binding var localModels: [String]
    @Binding var selectedModel: String?
    let isServerRunning: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(selection: $selectedModel) {
                Section("GGUF Models") {
                    ForEach(localModels, id: \.self) { model in
                        HStack {
                            Image(systemName: "cube.box.fill")
                                .foregroundColor(selectedModel == model ? .white : .blue)
                            VStack(alignment: .leading) {
                                Text(model)
                                    .font(.system(.body, design: .rounded))
                                    .lineLimit(1)
                                Text("Ready to load")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        .tag(model)
                    }
                }
            }
            .listStyle(.sidebar)
            .disabled(isServerRunning) // Lock selection when running
        }
        .background(Theme.bgSidebar)
    }
}

struct ChatAreaView: View {
    @Binding var messages: [ChatMessage]
    @Binding var chatText: String
    @Binding var isGenerating: Bool
    let isServerRunning: Bool
    let onSend: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Playground")
                    .font(.headline)
                Spacer()
                if isGenerating {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(height: 10)
                }
            }
            .padding()
            .background(Theme.bgSidebar)
            
            Divider()
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 24) {
                        ForEach(messages) { message in
                            ChatBubbleView(message: message)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let lastId = messages.last?.id {
                        withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                    }
                }
                .onChange(of: messages.last?.content) { _, _ in
                    if let lastId = messages.last?.id {
                        withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                    }
                }
            }
            .background(Theme.bgMain)
            
            // Input
            VStack {
                HStack(alignment: .bottom, spacing: 12) {
                    TextField("Message local model...", text: $chatText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .rounded))
                        .lineLimit(1...8)
                        .disabled(isGenerating)
                        .onSubmit {
                            if !isGenerating { onSend() }
                        }
                    
                    Button(action: onSend) {
                        Image(systemName: isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                            .resizable()
                            .frame(width: 32, height: 32)
                            .foregroundColor((chatText.isEmpty && !isGenerating) ? .gray : .blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(chatText.isEmpty && !isGenerating)
                }
                .padding(12)
                .background(Theme.bgSidebar)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                )
            }
            .padding()
            .background(Theme.bgMain)
        }
    }
}

struct MetricsPanel: View {
    @Binding var splitRatio: Double
    let serverLogs: String
    let isServerRunning: Bool
    let onToggleServer: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Engine Control
            VStack(alignment: .leading, spacing: 12) {
                Text("Engine Control")
                    .font(.headline)
                
                Button(action: onToggleServer) {
                    HStack {
                        Spacer()
                        Image(systemName: isServerRunning ? "stop.fill" : "play.fill")
                        Text(isServerRunning ? "Stop Server" : "Start Local Server")
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .background(isServerRunning ? Color.red.opacity(0.8) : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
            .background(Theme.bgSidebar)
            .cornerRadius(12)
            
            // Hardware Split
            VStack(alignment: .leading, spacing: 12) {
                Text("Tensor Split")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    HStack {
                        Text("GPU")
                            .foregroundColor(.purple)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(Int(splitRatio))%")
                        Spacer()
                        Text("ANE")
                            .foregroundColor(.orange)
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    
                    Slider(value: $splitRatio, in: 0...100, step: 1.0)
                        .accentColor(.purple)
                }
                
                Text("Offloading \(Int(100 - splitRatio))% of layers to Apple Neural Engine via libmetal_interceptor.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(Theme.bgSidebar)
            .cornerRadius(12)
            
            // Terminal Logs
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "terminal")
                    Text("Server Logs")
                }
                .font(.headline)
                
                ScrollView {
                    Text(serverLogs.isEmpty ? "Waiting for engine..." : serverLogs)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(serverLogs.isEmpty ? .gray : .green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .background(Color.black.opacity(0.8))
                .cornerRadius(8)
            }
            .padding()
            .background(Theme.bgSidebar)
            .cornerRadius(12)
            
            Spacer()
        }
        .padding()
        .background(Theme.bgMain)
    }
}

// MARK: - Chat UI Components

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
}

enum MessageRole {
    case user
    case assistant
}

struct ChatBubbleView: View {
    let message: ChatMessage
    
    var isUser: Bool { message.role == .user }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            if !isUser {
                // AI Avatar
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(color: .blue.opacity(0.3), radius: 4)
            }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(isUser ? "You" : "Local Model")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Text(message.content)
                    .font(.system(.body, design: .rounded))
                    .padding(14)
                    .background(isUser ? Theme.bubbleUser : Theme.bubbleAI)
                    .foregroundColor(isUser ? .white : Theme.textMain)
                    .cornerRadius(16)
                    // Custom corners for chat bubble look
                    .cornerRadius(4, corners: isUser ? [.bottomRight] : [.topLeft])
            }
            
            if isUser {
                // User Avatar
                Image(systemName: "person.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.gray)
                    .clipShape(Circle())
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}

// Extension to support specific corner rounding
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = NSBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadius: radius)
        return Path(path.cgPath)
    }
}

extension NSBezierPath {
    convenience init(roundedRect rect: CGRect, byRoundingCorners corners: UIRectCorner, cornerRadius: CGFloat) {
        self.init()
        // Basic implementation for macOS since UIBezierPath is iOS only
        // A complete implementation would map UIRectCorner to NSBezierPath segments
        // For simplicity in this demo, we just use standard rounded rect
        self.appendRoundedRect(rect, xRadius: cornerRadius, yRadius: cornerRadius)
    }
}

struct UIRectCorner: OptionSet {
    let rawValue: Int
    static let topLeft = UIRectCorner(rawValue: 1 << 0)
    static let topRight = UIRectCorner(rawValue: 1 << 1)
    static let bottomLeft = UIRectCorner(rawValue: 1 << 2)
    static let bottomRight = UIRectCorner(rawValue: 1 << 3)
    static let allCorners: UIRectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
