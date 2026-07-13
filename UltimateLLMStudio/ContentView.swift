import SwiftUI

// MARK: - LM Studio Theme
struct LMTheme {
    static let bgMain = Color(red: 0.12, green: 0.12, blue: 0.12)
    static let bgSidebar = Color(red: 0.08, green: 0.08, blue: 0.08)
    static let bgSecondary = Color(red: 0.16, green: 0.16, blue: 0.16)
    static let textMain = Color.white
    static let textMuted = Color(red: 0.6, green: 0.6, blue: 0.6)
    static let accent = Color(red: 0.4, green: 0.3, blue: 0.9) // Purple-ish LM Studio accent
    static let userBubble = Color(red: 0.2, green: 0.2, blue: 0.25)
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
        VStack(spacing: 0) {
            // Top Bar
            TopBarView(selectedModel: $selectedModel, models: localModels, isRunning: backend.isServerRunning, onToggle: toggleServer)
            
            Divider().background(Color.black)
            
            HSplitView {
                // Left Sidebar (History / Nav)
                VStack(spacing: 20) {
                    Image(systemName: "message.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(.top, 20)
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundColor(LMTheme.textMuted)
                    Image(systemName: "folder")
                        .font(.title2)
                        .foregroundColor(LMTheme.textMuted)
                    Spacer()
                    Image(systemName: "gearshape")
                        .font(.title2)
                        .foregroundColor(LMTheme.textMuted)
                        .padding(.bottom, 20)
                }
                .frame(width: 60)
                .background(LMTheme.bgSidebar)
                
                // Center Chat Area
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
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
                    .background(LMTheme.bgMain)
                    
                    // Input Area
                    VStack {
                        HStack(alignment: .bottom) {
                            TextField("Type a message...", text: $chatText, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1...10)
                                .padding(12)
                                .onSubmit {
                                    if !isGenerating { sendMessage() }
                                }
                            
                            Button(action: sendMessage) {
                                Image(systemName: isGenerating ? "stop.fill" : "paperplane.fill")
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(chatText.isEmpty && !isGenerating ? LMTheme.textMuted : LMTheme.accent)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .disabled(chatText.isEmpty && !isGenerating)
                            .padding(8)
                        }
                        .background(LMTheme.bgSecondary)
                        .cornerRadius(12)
                        .padding()
                    }
                    .background(LMTheme.bgMain)
                }
                .frame(minWidth: 400, maxWidth: .infinity)
                
                // Right Sidebar (Settings & Metrics)
                VStack(alignment: .leading, spacing: 20) {
                    Text("Hardware Settings")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tensor Split (GPU / ANE)")
                            .font(.subheadline)
                            .foregroundColor(LMTheme.textMuted)
                        
                        Slider(value: $splitRatio, in: 0...100, step: 1.0)
                            .accentColor(LMTheme.accent)
                        
                        HStack {
                            Text("GPU: \(Int(splitRatio))%")
                            Spacer()
                            Text("ANE: \(Int(100 - splitRatio))%")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                    }
                    .padding()
                    .background(LMTheme.bgSecondary)
                    .cornerRadius(8)
                    
                    Text("Server Logs")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top)
                    
                    ScrollView {
                        Text(backend.serverLogs.isEmpty ? "Ready to start..." : backend.serverLogs)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .background(Color.black)
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                .frame(width: 300)
                .background(LMTheme.bgSidebar)
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
        .background(LMTheme.bgMain)
        .onAppear {
            localModels = scanLocalModels()
        }
    }
    
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
            return ["Llama-3-8B-Instruct.gguf", "Mistral-7B-v0.3.gguf"] 
        }
        
        var models: [String] = []
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "gguf" {
                models.append(fileURL.lastPathComponent)
            }
        }
        if models.isEmpty { return ["Llama-3-8B-Instruct.gguf", "Mistral-7B-v0.3.gguf"] }
        return models
    }
    
    func sendMessage() {
        let trimmed = chatText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        messages.append(ChatMessage(role: .user, content: trimmed))
        chatText = ""
        isGenerating = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let mockResponse = "This is a simulated response generated by the local model. Hardware split is currently working perfectly."
            let words = mockResponse.split(separator: " ")
            var currentMessage = ""
            
            self.messages.append(ChatMessage(role: .assistant, content: ""))
            
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
struct TopBarView: View {
    @Binding var selectedModel: String?
    let models: [String]
    let isRunning: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            Text("Ultimate LLM Studio")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.leading, 20)
            
            Spacer()
            
            // Model Selector
            Menu {
                ForEach(models, id: \.self) { model in
                    Button(model) { selectedModel = model }
                }
            } label: {
                HStack {
                    Text(selectedModel ?? "Select a model to load")
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(LMTheme.textMuted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(width: 400)
                .background(LMTheme.bgSecondary)
                .cornerRadius(8)
            }
            .menuStyle(.borderlessButton)
            
            Spacer()
            
            Button(action: onToggle) {
                Text(isRunning ? "Eject Model" : "Load Model")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(isRunning ? Color.red.opacity(0.8) : LMTheme.accent)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
        }
        .frame(height: 60)
        .background(LMTheme.bgSidebar)
    }
}

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
                Image(systemName: "cpu.fill")
                    .foregroundColor(LMTheme.accent)
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(isUser ? "You" : "Local AI")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(isUser ? .white : LMTheme.accent)
                
                Text(message.content)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(14)
                    .background(isUser ? LMTheme.userBubble : Color.clear)
                    .cornerRadius(8)
            }
            
            if isUser {
                Spacer()
                Image(systemName: "person.circle.fill")
                    .foregroundColor(LMTheme.textMuted)
                    .font(.title2)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 20)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
