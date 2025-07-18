import SwiftUI

@main
struct SheetMusicScrollerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        .defaultSize(width: 1000, height: 700)
        #endif
    }
}