import SwiftUI

/// Main view that orchestrates the scrolling sheet music display with marker squiggle
struct SheetMusicScrollerView: View {
    let sheetMusic: SheetMusic
    
    @State private var currentTime: Double = 0
    @State private var isPlaying: Bool = false
    @State private var scrollOffset: CGFloat = 0
    @State private var playbackTimer: Timer?
    @State private var isPitchMode: Bool = false
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
            
            // Mode toggle
            modeToggleView
            
            // Main scrolling area
            scrollingMusicView
            
            // Controls
            controlsView
            
            // Pitch detection info (when in pitch mode)
            if isPitchMode {
                pitchInfoView
            }
        }
        .padding()
        .background(platformBackgroundColor)
        .onDisappear {
            stopPlayback()
            pitchDetector.stopListening()
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
    
    private var modeToggleView: some View {
        HStack {
            Text("Mode:")
                .font(.headline)
            
            Picker("Playback Mode", selection: $isPitchMode) {
                Text("Time-based").tag(false)
                Text("Live Pitch").tag(true)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: isPitchMode) { _, newMode in
                if newMode {
                    // Switch to pitch mode
                    stopPlayback()
                    pitchDetector.startListening()
                } else {
                    // Switch to time-based mode
                    pitchDetector.stopListening()
                }
            }
            
            Spacer()
            
            if isPitchMode {
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
                tipColor: squiggleColor,
                isPitchMode: isPitchMode
            )
        }
        .frame(height: 200)
        .clipped()
    }
    
    private var controlsView: some View {
        HStack {
            // Play/Pause button (only in time-based mode)
            if !isPitchMode {
                Button(action: togglePlayback) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            } else {
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
            }
            
            // Time display (only in time-based mode)
            if !isPitchMode {
                VStack(alignment: .trailing) {
                    Text(timeString(currentTime))
                        .font(.system(.body, design: .monospaced))
                    
                    Text("/ \(timeString(sheetMusic.totalDuration))")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Reset button (only in time-based mode)
            if !isPitchMode {
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
        sheetMusic.notesAt(time: currentTime)
    }
    
    /// Calculate the current Y position of the squiggle tip based on active notes or live pitch
    private var currentSquiggleYPosition: CGFloat {
        let staffHeight: CGFloat = 120
        let staffCenter = staffHeight / 2
        let lineSpacing = staffHeight / 6
        
        if isPitchMode {
            // Use live pitch detection
            if pitchDetector.currentFrequency > 0 {
                let pitchPosition = pitchDetector.frequencyToStaffPosition(pitchDetector.currentFrequency)
                return staffCenter + (pitchPosition * lineSpacing)
            } else {
                // No pitch detected, keep at center
                return staffCenter
            }
        } else {
            // Use time-based positioning (original logic)
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
    }
    
    /// Get the current squiggle tip color based on pitch and musical context
    private var squiggleColor: Color {
        if isPitchMode {
            // Color based on live pitch detection strength
            if pitchDetector.currentAmplitude > 0.1 {
                return .green // Strong signal
            } else if pitchDetector.currentAmplitude > 0.05 {
                return .orange // Weak signal
            } else {
                return .red // No signal
            }
        } else {
            // Color varies based on pitch range and musical expression (original logic)
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
    }
    
    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }
    
    private func togglePitchListening() {
        if pitchDetector.isListening {
            pitchDetector.stopListening()
        } else {
            pitchDetector.startListening()
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