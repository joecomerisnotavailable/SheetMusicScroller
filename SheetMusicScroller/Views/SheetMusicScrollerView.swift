import SwiftUI

/// Main view that orchestrates the scrolling sheet music display with marker squiggle
struct SheetMusicScrollerView: View {
    let sheetMusic: SheetMusic
    
    @State private var currentTime: Double = 0
    @State private var isPlaying: Bool = false
    @State private var scrollOffset: CGFloat = 0
    @State private var playbackTimer: Timer?
    
    private let noteSpacing: CGFloat = 60
    private let scrollSpeed: CGFloat = 30 // pixels per second
    private let squiggleX: CGFloat = 100   // Fixed x position of squiggle (about 1/8 from left edge)
    
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
            
            // Scrolling score with fixed gutter
            ScoreView(
                notes: sheetMusic.notes,
                activeNotes: Set(activeNotes.map { $0.id }),
                scrollOffset: scrollOffset,
                squiggleX: squiggleX,
                squiggleColor: squiggleColor
            )
            .frame(height: 200)
            
            // Historical marker squiggle
            SquiggleView(
                height: 180,
                currentYPosition: currentSquiggleYPosition,
                scrollOffset: scrollOffset,
                squiggleX: squiggleX,
                tipColor: squiggleColor
            )
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
    
    /// Calculate the current Y position of the squiggle tip based on active notes
    private var currentSquiggleYPosition: CGFloat {
        let staffHeight: CGFloat = 120
        let staffCenter = staffHeight / 2
        let lineSpacing = staffHeight / 6
        
        // If there are active notes, use the first one's position
        if let firstActiveNote = activeNotes.first {
            return staffCenter + (firstActiveNote.position * lineSpacing)
        }
        
        // If no active notes, interpolate between nearby notes or use a default position
        let nearbyNotes = sheetMusic.notes.filter { note in
            abs(note.startTime - currentTime) < 0.5 // Within 0.5 seconds
        }.sorted { abs($0.startTime - currentTime) < abs($1.startTime - currentTime) }
        
        if let nearestNote = nearbyNotes.first {
            return staffCenter + (nearestNote.position * lineSpacing)
        }
        
        // Default to middle of staff
        return staffCenter
    }
    
    /// Get the current squiggle tip color based on pitch and musical context
    private var squiggleColor: Color {
        // Color varies based on pitch range and musical expression
        if let activeNote = activeNotes.first {
            let pitch = activeNote.position
            
            // Color mapping based on pitch height
            if pitch < -2.5 {
                return .purple  // Very high notes
            } else if pitch < -1.5 {
                return .blue    // High notes
            } else if pitch < -0.5 {
                return .green   // Medium-high notes
            } else if pitch < 0.5 {
                return .orange  // Medium notes
            } else {
                return .red     // Lower notes
            }
        }
        
        // Default red when no active notes
        return .red
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