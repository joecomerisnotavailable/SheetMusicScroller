import SwiftUI

/// Main view that orchestrates the scrolling sheet music display with marker squiggle
struct SheetMusicScrollerView: View {
    let sheetMusic: SheetMusic
    
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollTimer: Timer?
    @StateObject private var pitchDetector = PitchDetector()
    
    private let noteSpacing: CGFloat = 60
    private let scrollSpeed: CGFloat = 30 // pixels per second
    private let squiggleX: CGFloat = 100   // Fixed x position of squiggle (about 1/8 from left edge)
    
    init(sheetMusic: SheetMusic) {
        self.sheetMusic = sheetMusic
    }
    
    /// Platform-specific background color
    private var platformBackgroundColor: Color {
        #if os(macOS)
        Color(NSColor.controlBackgroundColor)
        #else
        Color(UIColor.systemGroupedBackground)
        #endif
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with title and composer
            headerView
            
            // Mode info
            modeInfoView
            
            // Main scrolling area
            scrollingMusicView
            
            // Controls
            controlsView
            
            // Pitch detection info
            pitchInfoView
        }
        .padding()
        .background(platformBackgroundColor)
        .onDisappear {
            stopScrolling()
            pitchDetector.stopListening()
        }
        .onAppear {
            pitchDetector.startListening()
            startScrolling()
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
    
    private var modeInfoView: some View {
        HStack {
            Text("Live Pitch Detection")
                .font(.headline)
            
            Spacer()
            
            HStack {
                Circle()
                    .fill(pitchDetector.isListening ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(pitchDetector.isListening ? "Listening" : "Not Listening")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
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
            // Microphone button for pitch mode
            Button(action: togglePitchListening) {
                Image(systemName: pitchDetector.isListening ? "mic.fill" : "mic.slash.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .background(pitchDetector.isListening ? Color.green : Color.red)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
        }
    }
    
    private var pitchInfoView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Live Pitch Detection")
                    .font(.headline)
                Spacer()
                if !pitchDetector.microphonePermissionGranted {
                    Text("Microphone permission required")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            // Show error message if there is one
            if let errorMessage = pitchDetector.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Frequency")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f Hz", pitchDetector.currentFrequency))
                        .font(.system(.body, design: .monospaced))
                }
                
                VStack(alignment: .leading) {
                    Text("Note")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(pitchDetector.currentPitch.isEmpty ? "—" : pitchDetector.currentPitch)
                        .font(.system(.body, design: .monospaced))
                }
                
                VStack(alignment: .leading) {
                    Text("Amplitude")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f", pitchDetector.currentAmplitude))
                        .font(.system(.body, design: .monospaced))
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color.primary.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var activeNotes: [Note] {
        // In pitch mode, we don't have "active" notes based on time
        // This could be enhanced in the future to show notes that match current pitch
        return []
    }
    
    /// Calculate the current Y position of the squiggle tip based on live pitch
    private var currentSquiggleYPosition: CGFloat {
        let staffHeight: CGFloat = 120
        let staffCenter = staffHeight / 2
        let lineSpacing = staffHeight / 6
        
        // Use live pitch detection
        if pitchDetector.currentFrequency > 0 {
            let pitchPosition = pitchDetector.frequencyToStaffPosition(pitchDetector.currentFrequency)
            return staffCenter + (CGFloat(pitchPosition) * lineSpacing)
        } else {
            // No pitch detected, keep at center
            return staffCenter
        }
    }
    
    /// Get the current squiggle tip color based on pitch and musical context
    private var squiggleColor: Color {
        // Color based on live pitch detection - vary by frequency and signal strength
        if pitchDetector.currentAmplitude > 0.01 && pitchDetector.currentFrequency > 0 {
            // Color mapping based on detected frequency
            let staffPosition = pitchDetector.frequencyToStaffPosition(pitchDetector.currentFrequency)
            
            if staffPosition < -3.0 {
                return .purple  // Very high frequencies
            } else if staffPosition < -1.0 {
                return .blue    // High frequencies  
            } else if staffPosition < 1.0 {
                return .green   // Medium frequencies
            } else if staffPosition < 3.0 {
                return .orange  // Lower frequencies
            } else {
                return .red     // Very low frequencies
            }
        } else {
            return .gray // No signal detected
        }
    }
    
    private func togglePitchListening() {
        if pitchDetector.isListening {
            pitchDetector.stopListening()
        } else {
            pitchDetector.startListening()
        }
    }
    
    private func startScrolling() {
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            // Continuous scrolling for the squiggle history
            scrollOffset += scrollSpeed * 0.02
        }
    }
    
    private func stopScrolling() {
        scrollTimer?.invalidate()
        scrollTimer = nil
    }
}

#Preview {
    SheetMusicScrollerView(sheetMusic: BachAllemandeData.bachAllemande)
        .frame(width: 800, height: 600)
}