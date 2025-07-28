import SwiftUI

struct ContentView: View {
    /// Platform-specific title view
    @ViewBuilder
    private var platformTitleView: some View {
        #if os(iOS)
        Text("Sheet Music Scroller")
            .font(.largeTitle)
            .fontWeight(.bold)
            .padding()
        #endif
    }
    
    /// Platform-specific navigation subtitle
    private var navigationSubtitle: String? {
        #if os(macOS)
        "Bach Partita No. 2 - Allemande"
        #else
        nil
        #endif
    }
    
    var body: some View {
        NavigationView {
            VStack {
                platformTitleView
                
                SheetMusicScrollerView(sheetMusic: BachAllemandeData.bachAllemande)
            }
            .navigationTitle("Sheet Music Scroller")
            .modifier(NavigationSubtitleModifier(subtitle: navigationSubtitle))
        }
        .modifier(NavigationStyleModifier())
    }
}

/// View modifier for platform-specific navigation subtitle
struct NavigationSubtitleModifier: ViewModifier {
    let subtitle: String?
    
    func body(content: Content) -> some View {
        #if os(macOS)
        if let subtitle = subtitle {
            content.navigationSubtitle(subtitle)
        } else {
            content
        }
        #else
        content
        #endif
    }
}

/// View modifier for platform-specific navigation style
struct NavigationStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content.navigationViewStyle(StackNavigationViewStyle())
        #else
        content
        #endif
    }
}

#Preview {
    ContentView()
}