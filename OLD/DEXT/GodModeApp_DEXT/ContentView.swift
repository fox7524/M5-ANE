import SwiftUI

struct ContentView: View {
    @ObservedObject var backend = BackendManager()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("ANE App")
                .font(.headline)
                .padding(.bottom, 5)
                
            HStack {
                Text("Total Power:")
                Spacer()
                Text(String(format: "%.1f W", backend.currentPowerW))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(backend.currentPowerW > 50 ? .red : .green)
                    .bold()
            }
            
            Divider()
            
            Toggle("God-Mode (SMC Spoof)", isOn: $backend.isGodModeActive)
                .toggleStyle(SwitchToggleStyle(tint: .red))
            
            Toggle("ANE/GPU Bridge", isOn: $backend.isANEBridgeActive)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
            
            Divider()
            
            Button(action: {
                backend.sendPayload()
            }) {
                Text(backend.isStressTestRunning ? "Stop ANE Stress Test" : "Execute ANE Stress Test")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(backend.isStressTestRunning ? .red : .blue)
            
            Button("Quit") {
                backend.cleanupAndExit()
            }
            .buttonStyle(.plain)
            .foregroundColor(.gray)
        }
        .padding()
        .frame(width: 250)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(BackendManager.shared)
    }
}
