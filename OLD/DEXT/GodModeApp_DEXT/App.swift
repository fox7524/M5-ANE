import SwiftUI

@main
struct GodModeApp: App {
    var body: some Scene {
        MenuBarExtra("ANE App", systemImage: "cpu.fill") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
