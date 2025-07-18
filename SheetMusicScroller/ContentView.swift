import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack {
                #if os(iOS)
                Text("Sheet Music Scroller")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                #endif
                
                SheetMusicScrollerView(sheetMusic: BachAllemandeData.bachAllemande)
            }
            .navigationTitle("Sheet Music Scroller")
            #if os(macOS)
            .navigationSubtitle("Bach Partita No. 2 - Allemande")
            #endif
        }
        #if os(iOS)
        .navigationViewStyle(StackNavigationViewStyle())
        #endif
    }
}

#Preview {
    ContentView()
}