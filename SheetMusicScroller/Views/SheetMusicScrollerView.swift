import SwiftUI

/// Main view that orchestrates the scrolling sheet music display
struct SheetMusicScrollerView: View {
    let sheetMusic: SheetMusic
    
    @State private var currentTime: Double = 0
    @State private var isPlaying: Bool = false
    @State private var scrollOffset: CGFloat = 0
    @State private var playbackTimer: Timer?
    
    private let noteSpacing: CGFloat = 60
    private let scrollSpeed: CGFloat = 30 // pixels per second
    
    init(sheetMusic: SheetMusic) {
        self.sheetMusic = sheetMusic
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with title and composer
            headerView
            
            // Main scrolling area
            scrollingMusicView
            
            // Controls
            controlsView
        }
        .padding()
        .background(
            #if os(macOS)
            Color(NSColor.controlBackgroundColor)
            #else
            Color(UIColor.systemGroupedBackground)
            #endif
        )
        .onDisappear {
            stopPlayback()
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(sheetMusic.title)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(sheetMusic.composer)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Text("Tempo: \(Int(sheetMusic.tempo)) BPM")
                Text("•")
                Text(sheetMusic.timeSignature)
                Text("•")
                Text(sheetMusic.keySignature)
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var scrollingMusicView: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(Color.white)
                .border(Color.gray, width: 1)
            
            // Scrolling score
            ScoreView(
                notes: sheetMusic.notes,
                activeNotes: Set(activeNotes.map { $0.id }),
                scrollOffset: scrollOffset
            )
            .frame(height: 200)
            
            // Cursor squiggle at playback position
            HStack {
                SquiggleView(height: 180, animated: isPlaying)
                    .offset(x: 40) // Position it at the "now" line
                
                Spacer()
            }
        }
        .frame(height: 200)
        .clipped()
    }
    
    private var controlsView: some View {
        HStack {
            // Play/Pause button
            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Time display
            VStack(alignment: .trailing) {
                Text(timeString(currentTime))
                    .font(.system(.body, design: .monospaced))
                
                Text("/ \(timeString(sheetMusic.totalDuration))")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Reset button
            Button(action: resetPlayback) {
                Image(systemName: "backward.end.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.gray)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var activeNotes: [Note] {
        sheetMusic.notesAt(time: currentTime)
    }
    
    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }
    
    private func startPlayback() {
        isPlaying = true
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            currentTime += 0.02
            scrollOffset += scrollSpeed * 0.02
            
            // Stop at the end
            if currentTime >= sheetMusic.totalDuration {
                stopPlayback()
                currentTime = sheetMusic.totalDuration
            }
        }
    }
    
    private func stopPlayback() {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func resetPlayback() {
        stopPlayback()
        currentTime = 0
        scrollOffset = 0
    }
    
    private func timeString(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    SheetMusicScrollerView(sheetMusic: BachAllemandeData.bachAllemande)
        .frame(width: 800, height: 600)
}