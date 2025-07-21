import SwiftUI

@main
struct SheetMusicScrollerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowConfiguration()
    }
}

extension Scene {
    /// Platform-specific window configuration
    func windowConfiguration() -> some Scene {
        #if os(macOS)
        self
            .windowResizability(.contentSize)
            .defaultSize(width: 1000, height: 700)
        #else
        self
        #endif
    }
}