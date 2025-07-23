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
                Text("Tempo: \(Int(sheetMusic.musicContext.tempo)) BPM")
                Text("•")
                Text(sheetMusic.timeSignature)
                Text("•")
                Text(sheetMusic.musicContext.keySignature)
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
                sheetMusic: sheetMusic,
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
    
    private var activeNotes: [TimedNote] {
        // In pitch mode, we don't have "active" notes based on time
        // This could be enhanced in the future to show notes that match current pitch
        return []
    }
    
    /// Calculate the current Y position of the squiggle tip based on live pitch with frequency interpolation
    private var currentSquiggleYPosition: CGFloat {
        let staffHeight: CGFloat = 120
        
        // Use live pitch detection
        guard pitchDetector.currentFrequency > 0 && pitchDetector.currentAmplitude > 0.01 else {
            // No pitch detected, keep at center
            return staffHeight / 2
        }
        
        let freq = pitchDetector.currentFrequency
        let baseHz = sheetMusic.musicContext.a4Reference
        let keySignature = sheetMusic.musicContext.keySignature
        let clef = sheetMusic.musicContext.clef
        
        // Step 1: Get nearest note name from frequency
        let nearestNoteName = StaffPositionMapper.noteNameFromFrequency(freq, a4Reference: baseHz)
        
        // Step 2: Get initial Y position using getYFromNoteAndKey (anchor position)
        let yAnchor = StaffPositionMapper.getYFromNoteAndKey(nearestNoteName, keySignature: keySignature, clef: clef, staffHeight: staffHeight)
        
        // Step 3: Get true frequency of the nearest note
        let freqTrue = StaffPositionMapper.noteNameToFrequency(nearestNoteName, a4Reference: baseHz)
        
        // Step 4: Apply frequency interpolation if frequency differs from true note frequency
        let freqDelta = freq - freqTrue
        
        // If frequency is very close to the note (within 1 cent), don't interpolate
        if abs(freqDelta) < 0.5 {
            return yAnchor
        }
        
        // Step 5: Find the next note in the direction of frequency difference
        let direction = freqDelta > 0 ? 1 : -1  // 1 for up (higher freq), -1 for down (lower freq)
        let noteNext = StaffPositionMapper.nextNoteWithDifferentStaffPosition(
            from: nearestNoteName, 
            direction: direction, 
            keySignature: keySignature, 
            clef: clef
        )
        
        // Step 6: Get Y position of the next note with different staff position
        let yNext = StaffPositionMapper.getYFromNoteAndKey(noteNext, keySignature: keySignature, clef: clef, staffHeight: staffHeight)
        
        // Step 7: Find the frequency of the last note in the direction that has the same staff position as nearestNoteName
        let freqTop = findFreqTopForInterpolation(
            nearestNoteName: nearestNoteName,
            direction: direction,
            keySignature: keySignature,
            clef: clef,
            baseHz: baseHz
        )
        
        // Step 8: Get frequency of noteNext
        let freqNext = StaffPositionMapper.noteNameToFrequency(noteNext, a4Reference: baseHz)
        
        // Step 9: Calculate interpolated Y position using the specified formula
        // |ySquiggle - yAnchor|/|yAnchor - yNext| = |freq - freqTop|/|freqTop - freqNext|
        let freqRange = abs(freqTop - freqNext)
        let freqOffset = abs(freq - freqTop)
        
        guard freqRange > 0 else { return yAnchor }
        
        let interpolationRatio = min(freqOffset / freqRange, 1.0)  // Clamp to prevent over-interpolation
        let yRange = yNext - yAnchor
        let yOffset = yRange * interpolationRatio
        
        return yAnchor + yOffset
    }
    
    /// Find the frequency of the last note in the given direction whose staff position 
    /// does not differ from the nearest note's staff position
    private func findFreqTopForInterpolation(nearestNoteName: String, direction: Int, keySignature: String, clef: Clef, baseHz: Double) -> Double {
        let context = MusicContext(keySignature: keySignature, clef: clef)
        let referenceMidi = StaffPositionMapper.noteNameToMidiNote(nearestNoteName)
        let referencePosition = StaffPositionMapper.noteNameToStaffPosition(nearestNoteName, context: context)
        
        var currentMidi = referenceMidi
        var lastMatchingNoteName = nearestNoteName
        
        // Search in the direction until we find a note with different staff position
        for _ in 0..<12 { // Don't go more than an octave
            currentMidi += direction
            let currentNoteName = StaffPositionMapper.midiNoteToNoteName(currentMidi)
            let currentPosition = StaffPositionMapper.noteNameToStaffPosition(currentNoteName, context: context)
            
            if abs(currentPosition - referencePosition) > 0.1 {
                // Found a note with different staff position, return the last matching note's frequency
                break
            }
            
            lastMatchingNoteName = currentNoteName
        }
        
        return StaffPositionMapper.noteNameToFrequency(lastMatchingNoteName, a4Reference: baseHz)
    }
    
    /// Get the current squiggle tip color based on pitch distance from target
    private var squiggleColor: Color {
        // If no pitch detected, show gray
        guard pitchDetector.currentAmplitude > 0.01 && pitchDetector.currentFrequency > 0 else {
            return .gray
        }
        
        // Get the current detected note and frequency
        let currentFreq = pitchDetector.currentFrequency
        let baseHz = sheetMusic.musicContext.a4Reference
        
        // Find the target frequency (first note in the piece for now - D4)
        guard let firstNote = sheetMusic.timedNotes.first else {
            return .gray
        }
        
        let targetNoteName = firstNote.note.noteName
        let targetFreq = StaffPositionMapper.noteNameToFrequency(targetNoteName, a4Reference: baseHz)
        
        // Calculate frequency difference
        let freqDiff = currentFreq - targetFreq
        
        // Calculate semitone difference (12 semitones = octave, frequency doubles)
        let semitoneDiff = 12.0 * log2(currentFreq / targetFreq)
        
        // If very close to target (within 0.1 semitones), show green
        if abs(semitoneDiff) < 0.1 {
            return .green
        }
        
        // Color interpolation based on distance from target
        let maxSemitones: Double = 1.0  // Full color at 1 semitone distance
        let normalizedDistance = min(abs(semitoneDiff) / maxSemitones, 1.0)
        
        if freqDiff < 0 {
            // Below target frequency -> purple
            let purpleIntensity = normalizedDistance
            let greenComponent = max(0, 1.0 - purpleIntensity)
            return Color(red: purpleIntensity * 0.5 + greenComponent * 0.0,
                        green: greenComponent,
                        blue: purpleIntensity * 0.8 + greenComponent * 0.5)
        } else {
            // Above target frequency -> red  
            let redIntensity = normalizedDistance
            let greenComponent = max(0, 1.0 - redIntensity)
            return Color(red: redIntensity + greenComponent * 0.0,
                        green: greenComponent,
                        blue: greenComponent * 0.0)
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