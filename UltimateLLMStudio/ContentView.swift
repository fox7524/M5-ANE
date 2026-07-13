import SwiftUI

// MARK: - LM Studio Color Palette
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue:  Double(b) / 255, opacity: Double(a) / 255)
    }
}

struct LM {
    static let activityBarBg = Color(hex: "#181818")
    static let sidebarBg     = Color(hex: "#1E1E1E")
    static let mainBg        = Color(hex: "#232323")
    static let panelBg       = Color(hex: "#1E1E1E")
    
    static let border        = Color(hex: "#333333")
    static let borderLight   = Color(hex: "#444444")
    
    static let text          = Color(hex: "#E0E0E0")
    static let textMuted     = Color(hex: "#888888")
    
    static let purple        = Color(hex: "#635BFF")
    static let purpleHover   = Color(hex: "#7A73FF")
    
    static let inputBg       = Color(hex: "#2D2D2D")
    static let messageUserBg = Color(hex: "#2A2A2A")
    static let green         = Color(hex: "#4ADE80")
}

// MARK: - Main View
struct ContentView: View {
    @ObservedObject var backend = BackendManager.shared
    private let scanner = ModelScanner()
    
    @State private var activeTab = 1
    @State private var selectedModel: String? = nil
    @State private var localModels: [String] = []
    @State private var chatText = ""
    @State private var isGenerating = false
    
    @State private var messages: [ChatMessage] = [
        ChatMessage(role: .system, content: "System: You are a helpful AI assistant running locally on Apple Silicon."),
        ChatMessage(role: .assistant, content: "Hello! I am ready to assist you. What would you like to do today?")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            // 1. Leftmost Activity Bar
            LMActivityBar(activeTab: $activeTab)
            
            Divider().background(LM.border)
            
            // 2. Chat List Sidebar
            if activeTab == 1 {
                LMSidebar()
                Divider().background(LM.border)
            }
            
            // 3. Main Chat Area
            LMMainContent(
                selectedModel: $selectedModel,
                localModels: $localModels,
                chatText: $chatText,
                messages: $messages,
                isGenerating: $isGenerating,
                isRunning: backend.isServerRunning,
                onToggleServer: toggleServer,
                onSend: sendMessage
            )
            
            Divider().background(LM.border)
            
            // 4. Right Configuration Panel
            LMRightPanel()
        }
        .frame(minWidth: 1200, minHeight: 800)
        .background(LM.mainBg)
        .colorScheme(.dark)
        .onAppear {
            let models = scanner.scanForGGUFModels(in: "~/.cache/lm-studio/models")
            localModels = models.map { ($0 as NSString).lastPathComponent }
            selectedModel = localModels.first
        }
    }
    
    private func toggleServer() {
        if backend.isServerRunning {
            backend.stopLLMServer()
        } else if let model = selectedModel {
            backend.startLLMServer(modelPath: model)
        }
    }
    
    private func sendMessage() {
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
}

// MARK: - 1. Activity Bar
struct LMActivityBar: View {
    @Binding var activeTab: Int
    
    var body: some View {
        VStack(spacing: 20) {
            ActivityBtn(icon: "house", index: 0, activeTab: $activeTab)
            ActivityBtn(icon: "message", index: 1, activeTab: $activeTab)
            ActivityBtn(icon: "magnifyingglass", index: 2, activeTab: $activeTab)
            ActivityBtn(icon: "server.rack", index: 3, activeTab: $activeTab)
            ActivityBtn(icon: "folder", index: 4, activeTab: $activeTab)
            
            Spacer()
            
            ActivityBtn(icon: "gearshape", index: 5, activeTab: $activeTab)
        }
        .padding(.top, 30)
        .padding(.bottom, 20)
        .frame(width: 54)
        .background(LM.activityBarBg)
    }
}

struct ActivityBtn: View {
    let icon: String
    let index: Int
    @Binding var activeTab: Int
    @State private var hover = false
    
    var body: some View {
        Button(action: { activeTab = index }) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: activeTab == index ? .semibold : .regular))
                .foregroundColor(activeTab == index ? .white : (hover ? .white : LM.textMuted))
                .frame(width: 44, height: 44)
                .background(activeTab == index ? LM.sidebarBg : Color.clear)
                .cornerRadius(8)
                .overlay(
                    HStack {
                        if activeTab == index {
                            Rectangle().fill(LM.purple).frame(width: 3, height: 24).cornerRadius(1.5)
                        }
                        Spacer()
                    }
                )
        }
        .buttonStyle(.plain)
        .onHover { h in hover = h }
    }
}

// MARK: - 2. Sidebar
struct LMSidebar: View {
    @State private var hoverNew = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Local Chats")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "plus.square.on.square")
                        .foregroundColor(LM.textMuted)
                }.buttonStyle(.plain)
            }
            .padding(16)
            
            Button(action: {}) {
                HStack {
                    Image(systemName: "plus")
                    Text("New Chat")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(hoverNew ? LM.purpleHover : LM.purple)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .onHover { h in hoverNew = h }
            
            ScrollView {
                VStack(spacing: 4) {
                    ChatListItem(title: "SwiftUI Implementation", date: "Today", isActive: true)
                    ChatListItem(title: "Apple Metal Optimization", date: "Yesterday", isActive: false)
                }
                .padding(16)
            }
        }
        .frame(width: 260)
        .background(LM.sidebarBg)
    }
}

struct ChatListItem: View {
    let title: String
    let date: String
    let isActive: Bool
    @State private var hover = false
    
    var body: some View {
        HStack {
            Image(systemName: "message")
                .foregroundColor(isActive ? .white : LM.textMuted)
                .font(.system(size: 12))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(isActive ? .white : LM.text)
                    .lineLimit(1)
                Text(date)
                    .font(.system(size: 11))
                    .foregroundColor(LM.textMuted)
            }
            Spacer()
        }
        .padding(8)
        .background(isActive ? LM.border : (hover ? LM.border.opacity(0.5) : Color.clear))
        .cornerRadius(6)
        .onHover { h in hover = h }
    }
}

// MARK: - 3. Main Content
struct LMMainContent: View {
    @Binding var selectedModel: String?
    @Binding var localModels: [String]
    @Binding var chatText: String
    @Binding var messages: [ChatMessage]
    @Binding var isGenerating: Bool
    let isRunning: Bool
    let onToggleServer: () -> Void
    let onSend: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack {
                Spacer()
                
                // Model Selector
                Menu {
                    if localModels.isEmpty {
                        Button("No models found") {}
                    } else {
                        ForEach(localModels, id: \.self) { model in
                            Button(model) { selectedModel = model }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "cpu")
                            .foregroundColor(LM.purple)
                        Text(selectedModel ?? "Select a model...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(LM.textMuted)
                            .font(.system(size: 10))
                    }
                    .padding(.horizontal, 12)
                    .frame(width: 400, height: 36)
                    .background(LM.inputBg)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(LM.border, lineWidth: 1))
                }
                .menuStyle(.borderlessButton)
                
                Spacer()
                
                // Hardware Stats
                HStack(spacing: 16) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("RAM")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(LM.textMuted)
                        Text("4.2 GB")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(LM.green)
                    }
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("CPU")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(LM.textMuted)
                        Text("12%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(LM.green)
                    }
                    
                    Button(action: onToggleServer) {
                        Text(isRunning ? "Eject" : "Load")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isRunning ? Color(hex: "#D94A4A") : LM.borderLight)
                            .cornerRadius(4)
                    }.buttonStyle(.plain)
                }
                .padding(.trailing, 20)
            }
            .frame(height: 60)
            .background(LM.mainBg)
            
            Divider().background(LM.border)
            
            // Chat Area
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(messages) { msg in
                            LMMessageRow(message: msg)
                        }
                    }
                    .padding(.bottom, 20)
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last?.id { withAnimation { proxy.scrollTo(last, anchor: .bottom) } }
                }
            }
            
            // Input Area
            VStack(spacing: 0) {
                HStack(alignment: .bottom, spacing: 12) {
                    Button(action: {}) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 16))
                            .foregroundColor(LM.textMuted)
                    }.buttonStyle(.plain).padding(.bottom, 10)
                    
                    TextField("Type a message...", text: $chatText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .lineLimit(1...10)
                        .padding(.vertical, 10)
                        .onSubmit { if !isGenerating { onSend() } }
                    
                    Button(action: onSend) {
                        Image(systemName: isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(chatText.isEmpty && !isGenerating ? LM.textMuted : LM.purple)
                    }
                    .buttonStyle(.plain)
                    .disabled(chatText.isEmpty && !isGenerating)
                    .padding(.bottom, 6)
                }
                .padding(.horizontal, 16)
                .background(LM.inputBg)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LM.border, lineWidth: 1))
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
                .padding(.top, 10)
                
                Text("Press Shift + Enter for a new line")
                    .font(.system(size: 11))
                    .foregroundColor(LM.textMuted)
                    .padding(.bottom, 20)
            }
            .background(LM.mainBg)
        }
    }
}

struct LMMessageRow: View {
    let message: ChatMessage
    
    var body: some View {
        if message.role == .system {
            HStack {
                Spacer()
                Text(message.content)
                    .font(.system(size: 12))
                    .foregroundColor(LM.textMuted)
                    .padding(8)
                    .background(LM.border)
                    .cornerRadius(6)
                Spacer()
            }
            .padding(.vertical, 16)
        } else {
            HStack(alignment: .top, spacing: 16) {
                if message.role == .assistant {
                    Image(systemName: "sparkles")
                        .foregroundColor(LM.purple)
                        .font(.system(size: 18))
                        .frame(width: 32, height: 32)
                        .background(LM.border)
                        .cornerRadius(6)
                } else {
                    Spacer()
                }
                
                Text(message.content)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .lineSpacing(4)
                    .padding(16)
                    .background(message.role == .user ? LM.messageUserBg : Color.clear)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(message.role == .user ? LM.border : Color.clear, lineWidth: 1)
                    )
                
                if message.role == .user {
                    Image(systemName: "person.fill")
                        .foregroundColor(LM.textMuted)
                        .font(.system(size: 16))
                        .frame(width: 32, height: 32)
                        .background(LM.border)
                        .cornerRadius(6)
                } else {
                    Spacer()
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - 4. Right Panel
struct LMRightPanel: View {
    @State private var isHardwareExpanded = true
    @State private var isContextExpanded = true
    @State private var offloadValue: Double = 32.0
    @State private var appleMetal = true
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Configuration")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(16)
            .background(LM.panelBg)
            
            Divider().background(LM.border)
            
            ScrollView {
                VStack(spacing: 0) {
                    // Hardware
                    DisclosureGroup(isExpanded: $isHardwareExpanded) {
                        VStack(alignment: .leading, spacing: 16) {
                            Toggle("Apple Metal (GPU/ANE)", isOn: $appleMetal)
                                .toggleStyle(SwitchToggleStyle(tint: LM.purple))
                                .font(.system(size: 13))
                                .foregroundColor(LM.text)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("GPU Offload")
                                        .font(.system(size: 12))
                                        .foregroundColor(LM.textMuted)
                                    Spacer()
                                    Text("\(Int(offloadValue)) layers")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(LM.purple)
                                }
                                Slider(value: $offloadValue, in: 0...100, step: 1)
                                    .accentColor(LM.purple)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                    } label: {
                        Text("Hardware Settings")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(LM.textMuted)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                    }
                    .accentColor(LM.textMuted)
                    
                    Divider().background(LM.border)
                    
                    // Context Length
                    DisclosureGroup(isExpanded: $isContextExpanded) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Context Length")
                                    .font(.system(size: 13))
                                    .foregroundColor(LM.text)
                                Spacer()
                                Text("4096")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(LM.inputBg)
                                    .cornerRadius(4)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(LM.border, lineWidth: 1))
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                    } label: {
                        Text("Model Settings")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(LM.textMuted)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                    }
                    .accentColor(LM.textMuted)
                    
                    Divider().background(LM.border)
                }
            }
        }
        .frame(width: 320)
        .background(LM.panelBg)
    }
}

// MARK: - Models
struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    
    enum Role {
        case system, user, assistant
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
