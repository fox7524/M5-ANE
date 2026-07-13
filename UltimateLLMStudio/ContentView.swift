import SwiftUI

struct ContentView: View {
    @State private var splitRatio: Double = 68.0
    @State private var localModels: [String] = []
    
    // Chat state
    @State private var chatText: String = ""
    @State private var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, content: "Merhaba! Ben senin yerel yapay zeka asistanınım. Bugün sana nasıl yardımcı olabilirim?"),
        ChatMessage(role: .user, content: "Basit bir Swift fonksiyonu yazabilir misin?"),
        ChatMessage(role: .assistant, content: "Elbette! İşte iki sayıyı toplayan basit bir fonksiyon:\n\n```swift\nfunc add(_ a: Int, _ b: Int) -> Int {\n    return a + b\n}\n```")
    ]
    
    var body: some View {
        NavigationSplitView {
            // Left: Discovery
            List {
                Section(header: Text("Local Models")) {
                    if localModels.isEmpty {
                        Text("No models found")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(localModels, id: \.self) { model in
                            Text(model)
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .onAppear {
                localModels = scanLocalModels()
            }
        } content: {
            // Center: Chat & Engine Status
            VStack(spacing: 0) {
                // Top Toolbar Area
                HStack {
                    Text("Engine: Stopped")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: {
                        startServer()
                    }) {
                        Label("Start Local Server", systemImage: "play.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
                
                Divider()
                
                // Chat Message List
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
                            withAnimation {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Input Area
                HStack(alignment: .bottom, spacing: 12) {
                    TextField("Mesaj gönder...", text: $chatText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 1)
                        )
                        .lineLimit(1...5)
                        .onSubmit {
                            sendMessage()
                        }
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .foregroundColor(chatText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(chatText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
            }
            .navigationTitle("Playground")
        } detail: {
            // Right: Hardware Control
            VStack(spacing: 20) {
                Text("Hardware Control")
                    .font(.headline)
                
                VStack {
                    Text("GPU: \(Int(splitRatio))% / ANE: \(Int(100 - splitRatio))%")
                        .font(.subheadline)
                    Slider(value: $splitRatio, in: 0...100, step: 1.0) {
                        Text("Split Ratio")
                    }
                    .onChange(of: splitRatio) { oldValue, newValue in
                        updateSplitRatio(newValue)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Metrics")
        }
    }
    
    func startServer() {
        // NSTask / Process execution for start_server.sh
        print("Starting local server...")
    }
    
    func updateSplitRatio(_ value: Double) {
        // Shared memory / IPC update logic
        print("Updated split ratio to GPU: \(Int(value))% / ANE: \(Int(100 - value))%")
    }
    
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
    
    func sendMessage() {
        let trimmed = chatText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        messages.append(ChatMessage(role: .user, content: trimmed))
        chatText = ""
        
        // Mock response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            messages.append(ChatMessage(role: .assistant, content: "Bu asistanın örnek bir yanıtıdır. Mesajını aldım: \"\(trimmed)\""))
        }
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
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Avatar
            Group {
                if message.role == .user {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "cpu")
                        .resizable()
                        .scaledToFit()
                        .padding(6)
                        .frame(width: 30, height: 30)
                        .background(Color.accentColor.opacity(0.2))
                        .foregroundColor(.accentColor)
                        .clipShape(Circle())
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(message.role == .user ? "Sen" : "Asistan")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Text(message.content)
                    .font(.body)
                    .textSelection(.enabled)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
