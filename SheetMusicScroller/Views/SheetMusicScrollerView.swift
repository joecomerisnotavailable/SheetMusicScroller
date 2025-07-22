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
        ZStack {
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
            
            // 🧪 MOCK MODE DISCLAIMER OVERLAY
            if pitchDetector.isMockMode || pitchDetector.mockModeActive {
                mockModeDisclaimerOverlay
            }
        }
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
            // 🧪 MOCK MODE INDICATOR
            if pitchDetector.isMockMode {
                Text("🧪 MOCK AUDIO DETECTION")
                    .font(.headline)
                    .foregroundColor(.orange)
                    .fontWeight(.bold)
            } else {
                Text("Live Pitch Detection")
                    .font(.headline)
            }
            
            Spacer()
            
            HStack {
                Circle()
                    .fill(pitchDetector.isListening ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(pitchDetector.isListening ? (pitchDetector.isMockMode ? "Mock Active" : "Listening") : "Not Listening")
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
            // 🧪 MOCK MODE TOGGLE (FOR TESTING ONLY)
            Button(action: {
                pitchDetector.toggleMockMode()
            }) {
                HStack {
                    Image(systemName: pitchDetector.isMockMode ? "testtube.2" : "waveform")
                        .font(.title3)
                    Text(pitchDetector.isMockMode ? "Mock" : "Real")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(pitchDetector.isMockMode ? Color.orange : Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer().frame(width: 10)
            
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Add retry button for certain error types
                    if errorMessage.contains("input") || errorMessage.contains("unavailable") {
                        HStack {
                            Button("Retry Audio Setup") {
                                pitchDetector.retryAudioSetup()
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            
                            Spacer()
                        }
                    }
                }
                .padding(.vertical, 4)
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
        // 🧪 MOCK MODE: Special color logic for testing G4 intersection
        if pitchDetector.isMockMode || pitchDetector.mockModeActive {
            if pitchDetector.currentAmplitude > 0.01 && pitchDetector.currentFrequency > 0 {
                let staffPosition = pitchDetector.frequencyToStaffPosition(pitchDetector.currentFrequency)
                
                // G4 is at position 1.5 (second line up from bottom) in our note positioning
                // But frequencyToStaffPosition uses different calculation, so let's check what it returns for G4 (392 Hz)
                let g4Position: Double = 1.5 // Our note position for G4
                let tolerance: Double = 0.2 // Slightly larger tolerance for floating point comparison
                
                // Convert G4 frequency (392 Hz) using the same method as frequencyToStaffPosition
                // G4 = MIDI 67, frequencyToStaffPosition: (67 - 60) * 0.5 = 3.5
                // But this doesn't match our note positioning! Let's use frequency directly
                let g4Frequency = 392.0
                let distanceFromG4 = abs(pitchDetector.currentFrequency - g4Frequency)
                let frequencyTolerance = 10.0 // Hz tolerance for "close enough" to G4
                
                if distanceFromG4 < frequencyTolerance {
                    return .green // Perfect green only near G4 frequency
                } else {
                    // Interpolate colors based on distance from G4 frequency
                    let maxFrequencyDistance = 150.0 // Hz
                    let normalizedDistance = min(distanceFromG4 / maxFrequencyDistance, 1.0)
                    
                    // Red when far from G4, orange when closer, green only at G4
                    if normalizedDistance > 0.8 {
                        return .red
                    } else if normalizedDistance > 0.6 {
                        return Color(red: 1.0, green: 0.3, blue: 0.0) // Red-orange
                    } else if normalizedDistance > 0.4 {
                        return .orange
                    } else if normalizedDistance > 0.2 {
                        return Color(red: 1.0, green: 0.8, blue: 0.0) // Yellow-orange
                    } else {
                        // Close to G4 but not exactly at it - yellow-green
                        return Color(red: 0.5, green: 0.9, blue: 0.2)
                    }
                }
            } else {
                return .gray // No signal detected
            }
        }
        
        // Original logic for non-mock mode
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
    
    // 🧪 MOCK MODE DISCLAIMER OVERLAY (FOR TESTING ONLY)
    private var mockModeDisclaimerOverlay: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 16) {
                // Warning header
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.title2)
                    Text("MOCK AUDIO DETECTION ACTIVE")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Image(systemName: "testtube.2")
                        .foregroundColor(.orange)
                        .font(.title2)
                }
                
                // Explanation
                VStack(spacing: 8) {
                    Text("This is NOT real audio detection")
                        .font(.headline)
                        .foregroundColor(.red)
                        .fontWeight(.bold)
                    
                    Text("Simulating descending C Major scale from D5")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("For testing squiggle trail and note alignment only")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
                
                // Toggle button
                Button("Switch to Real Audio Detection") {
                    pitchDetector.toggleMockMode()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .font(.subheadline)
                .fontWeight(.medium)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.yellow.opacity(0.9))
                    .shadow(radius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange, lineWidth: 3)
            )
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .background(Color.black.opacity(0.3))
        .animation(.easeInOut(duration: 0.3), value: pitchDetector.isMockMode)
    }
}

#Preview {
    SheetMusicScrollerView(sheetMusic: BachAllemandeData.bachAllemande)
        .frame(width: 800, height: 600)
}