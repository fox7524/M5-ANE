import SwiftUI

@main
struct M5UltimateApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, idealWidth: 1000, minHeight: 600, idealHeight: 700)
                .background(Color.black)
                .preferredColorScheme(.dark)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
    }
}
