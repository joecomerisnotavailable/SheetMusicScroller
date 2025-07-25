import SwiftUI

/// Main view that orchestrates the scrolling sheet music display with marker squiggle
struct SheetMusicScrollerView: View {
    let sheetMusic: SheetMusic
    
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollTimer: Timer?
    @StateObject private var pitchDetector = PitchDetector()
    @State private var scoreTime: Double = 0  // Current time position in the score for tracking active notes
    
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
            .frame(height: 220)  // Increased to accommodate extended staff range
            
            // Historical marker squiggle
            SquiggleView(
                height: 200,  // Increased height to match new frame
                currentYPosition: currentSquiggleYPosition,
                scrollOffset: scrollOffset,
                squiggleX: squiggleX,
                tipColor: squiggleColor
            )
        }
        .frame(height: 220)  // Increased to match ScoreView height
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
            
            // Score position and active note info
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Score Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f s", scoreTime))
                        .font(.system(.body, design: .monospaced))
                }
                
                VStack(alignment: .leading) {
                    Text("Active Note")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(currentlyActiveNote?.note.noteName ?? "—")
                        .font(.system(.body, design: .monospaced))
                }
                
                Spacer()
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
        // In pitch mode, determine active notes based on score time progression
        // For simplicity, we'll track the most recent note that should be playing
        return sheetMusic.notesAt(time: scoreTime)
    }
    
    /// Get the currently active note for squiggle reference
    /// This is the note that should be expected at the current point in the score
    private var currentlyActiveNote: TimedNote? {
        // Get the most recent note that has started by the current score time
        let notesUpToNow = sheetMusic.notesUpTo(time: scoreTime)
        return notesUpToNow.last  // Most recent note that should be active
    }
    
    /// Determines if two note names share the same staff position (enharmonic equivalence)
    /// - Parameters:
    ///   - noteName1: First note name (e.g., "F#4")
    ///   - noteName2: Second note name (e.g., "Gb4")
    ///   - keySignature: The key signature context
    ///   - clef: The clef type
    /// - Returns: True if they share the same staff position
    private func doNotesShareStaffPosition(_ noteName1: String, _ noteName2: String, keySignature: String, clef: Clef) -> Bool {
        let context = MusicContext(keySignature: keySignature, clef: clef)
        let position1 = StaffPositionMapper.noteNameToStaffPosition(noteName1, context: context)
        let position2 = StaffPositionMapper.noteNameToStaffPosition(noteName2, context: context)
        
        // Consider positions the same if they're within a small tolerance (0.1)
        let tolerance: Double = 0.1
        return abs(position1 - position2) <= tolerance
    }
    
    /// Calculate the current Y position of the squiggle tip using the new unified algorithm
    /// that references the currently active note instead of always the nearest detected note.
    /// 
    /// Two cases are implemented:
    /// Case 1: If active note and nearest detected note share staff position (enharmonics),
    ///         use active note frequency for interpolation between active note and next note
    /// Case 2: If they differ in staff position, use active note for color but 
    ///         anchor position at nearest detected note frequency as before
    private var currentSquiggleYPosition: CGFloat {
        let staffHeight: CGFloat = 120
        
        // Step 1: Read detected frequency from microphone
        guard pitchDetector.currentFrequency > 0 && pitchDetector.currentAmplitude > 0.01 else {
            print("🎯 SquigglePosition: No pitch detected, returning center position")
            return staffHeight / 2
        }
        
        let freq = pitchDetector.currentFrequency
        let baseHz = sheetMusic.musicContext.a4Reference
        let keySignature = sheetMusic.musicContext.keySignature
        let clef = sheetMusic.musicContext.clef
        
        // Get the currently active note
        guard let activeNote = currentlyActiveNote else {
            print("🎯 SquigglePosition: No active note found, falling back to center position")
            return staffHeight / 2
        }
        
        let activeNoteName = activeNote.note.noteName
        let freqActiveNote = StaffPositionMapper.noteNameToFrequency(activeNoteName, a4Reference: baseHz)
        
        // Step 2: Use noteNameFromFrequency to get nearest detected note name
        let nearestNoteName = StaffPositionMapper.noteNameFromFrequency(freq, a4Reference: baseHz)
        
        print("🎯 SquigglePosition: Active note: \(activeNoteName) (\(String(format: "%.1f", freqActiveNote))Hz), Nearest detected: \(nearestNoteName), Detected freq: \(String(format: "%.1f", freq))Hz")
        
        // Determine which case we're in
        let shareStaffPosition = doNotesShareStaffPosition(activeNoteName, nearestNoteName, keySignature: keySignature, clef: clef)
        
        if shareStaffPosition {
            // Case 1: Active note and nearest detected note share staff position (enharmonics)
            print("🎯 SquigglePosition: Case 1 - Enharmonic equivalence detected")
            return calculateCase1Position(
                activeNoteName: activeNoteName,
                freqActiveNote: freqActiveNote,
                detectedFreq: freq,
                keySignature: keySignature,
                clef: clef,
                staffHeight: staffHeight,
                baseHz: baseHz
            )
        } else {
            // Case 2: Different staff positions - use active note for color, nearest detected for position anchor
            print("🎯 SquigglePosition: Case 2 - Different staff positions")
            return calculateCase2Position(
                nearestNoteName: nearestNoteName,
                detectedFreq: freq,
                keySignature: keySignature,
                clef: clef,
                staffHeight: staffHeight,
                baseHz: baseHz
            )
        }
    }
    
    /// Calculate squiggle position for Case 1: enharmonic equivalence
    /// Use active note frequency as target and interpolate between active note and next note
    private func calculateCase1Position(
        activeNoteName: String,
        freqActiveNote: Double,
        detectedFreq: Double,
        keySignature: String,
        clef: Clef,
        staffHeight: CGFloat,
        baseHz: Double
    ) -> CGFloat {
        
        // Step 3: Use getYFromNoteAndKey to get Y coordinate for active note (yAnchor)
        let yAnchor = StaffPositionMapper.getYFromNoteAndKey(activeNoteName, keySignature: keySignature, clef: clef, staffHeight: staffHeight)
        
        // Step 4: Apply frequency interpolation using active note frequency as reference
        let freqDelta = detectedFreq - freqActiveNote
        
        print("🎯 Case1: Active note Y: \(String(format: "%.1f", yAnchor)), freq delta: \(String(format: "%.2f", freqDelta))Hz")
        
        // If frequency is very close to the active note, don't interpolate
        if abs(freqDelta) < 0.5 {
            print("🎯 Case1: Close to active note frequency, no interpolation needed")
            return yAnchor
        }
        
        // Find noteNext (next note whose staff position differs from activeNoteName)
        let direction = freqDelta > 0 ? 1 : -1  // 1 for up (higher freq), -1 for down (lower freq)
        let noteNext = StaffPositionMapper.nextNoteWithDifferentStaffPosition(
            from: activeNoteName, 
            direction: direction, 
            keySignature: keySignature, 
            clef: clef
        )
        
        // Calculate yNext using getYFromNoteAndKey
        let yNext = StaffPositionMapper.getYFromNoteAndKey(noteNext, keySignature: keySignature, clef: clef, staffHeight: staffHeight)
        
        // Calculate freqNext (frequency of noteNext)
        let freqNext = StaffPositionMapper.noteNameToFrequency(noteNext, a4Reference: baseHz)
        
        print("🎯 Case1: Next note: \(noteNext), Y: \(String(format: "%.1f", yNext)), freq: \(String(format: "%.1f", freqNext))Hz")
        
        // Apply interpolation: |ySquiggle - yAnchor|/|yAnchor - yNext| = |freq - freqActiveNote|/|freqActiveNote - freqNext|
        let freqRange = abs(freqActiveNote - freqNext)
        let freqOffset = abs(detectedFreq - freqActiveNote)
        
        guard freqRange > 0 else { 
            print("🎯 Case1: Zero frequency range, returning anchor")
            return yAnchor 
        }
        
        let interpolationRatio = min(freqOffset / freqRange, 1.0)  // Clamp to prevent over-interpolation
        let yRange = yNext - yAnchor
        let ySquiggle = yAnchor + yRange * interpolationRatio
        
        print("🎯 Case1: Interpolation ratio: \(String(format: "%.3f", interpolationRatio)), final Y: \(String(format: "%.1f", ySquiggle))")
        
        return ySquiggle
    }
    
    /// Calculate squiggle position for Case 2: different staff positions
    /// Use nearest detected note frequency as anchor (original algorithm)
    private func calculateCase2Position(
        nearestNoteName: String,
        detectedFreq: Double,
        keySignature: String,
        clef: Clef,
        staffHeight: CGFloat,
        baseHz: Double
    ) -> CGFloat {
        
        // Step 3: Use getYFromNoteAndKey to get initial Y coordinate (yAnchor) for nearest detected note
        let yAnchor = StaffPositionMapper.getYFromNoteAndKey(nearestNoteName, keySignature: keySignature, clef: clef, staffHeight: staffHeight)
        
        // Step 4: Apply frequency interpolation using the original algorithm (nearest detected note as reference)
        let freqTrue = StaffPositionMapper.noteNameToFrequency(nearestNoteName, a4Reference: baseHz)
        let freqDelta = detectedFreq - freqTrue
        
        print("🎯 Case2: Nearest note: \(nearestNoteName), Y: \(String(format: "%.1f", yAnchor)), freq delta: \(String(format: "%.2f", freqDelta))Hz")
        
        // If frequency is very close to the exact note, don't interpolate
        if abs(freqDelta) < 0.5 {
            print("🎯 Case2: Close to nearest note frequency, no interpolation needed")
            return yAnchor
        }
        
        // Find noteNext (next note whose staff position differs from nearestNoteName)
        let direction = freqDelta > 0 ? 1 : -1  // 1 for up (higher freq), -1 for down (lower freq)
        let noteNext = StaffPositionMapper.nextNoteWithDifferentStaffPosition(
            from: nearestNoteName, 
            direction: direction, 
            keySignature: keySignature, 
            clef: clef
        )
        
        // Calculate yNext using getYFromNoteAndKey
        let yNext = StaffPositionMapper.getYFromNoteAndKey(noteNext, keySignature: keySignature, clef: clef, staffHeight: staffHeight)
        
        // Find freqTop (frequency of the last note in direction that has same staff position as nearestNoteName)
        let freqTop = findFreqTopForInterpolation(
            nearestNoteName: nearestNoteName,
            direction: direction,
            keySignature: keySignature,
            clef: clef,
            baseHz: baseHz
        )
        
        // Calculate freqNext (frequency of noteNext)
        let freqNext = StaffPositionMapper.noteNameToFrequency(noteNext, a4Reference: baseHz)
        
        print("🎯 Case2: Next note: \(noteNext), Y: \(String(format: "%.1f", yNext)), freqTop: \(String(format: "%.1f", freqTop))Hz, freqNext: \(String(format: "%.1f", freqNext))Hz")
        
        // Apply the exact formula: |ySquiggle - yAnchor|/|yAnchor - yNext| = |freq - freqTop|/|freqTop - freqNext|
        let freqRange = abs(freqTop - freqNext)
        let freqOffset = abs(detectedFreq - freqTop)
        
        guard freqRange > 0 else { 
            print("🎯 Case2: Zero frequency range, returning anchor")
            return yAnchor 
        }
        
        let interpolationRatio = min(freqOffset / freqRange, 1.0)  // Clamp to prevent over-interpolation
        let yRange = yNext - yAnchor
        let ySquiggle = yAnchor + yRange * interpolationRatio
        
        print("🎯 Case2: Interpolation ratio: \(String(format: "%.3f", interpolationRatio)), final Y: \(String(format: "%.1f", ySquiggle))")
        
        return ySquiggle
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
    
    /// Get the current squiggle tip color based on pitch distance from currently active note
    /// This now always references the active note frequency as the target, regardless of case
    private var squiggleColor: Color {
        // If no pitch detected, show gray
        guard pitchDetector.currentAmplitude > 0.01 && pitchDetector.currentFrequency > 0 else {
            print("🎵 SquiggleColor: No pitch detected, showing gray")
            return .gray
        }
        
        // Get the currently active note as target
        guard let activeNote = currentlyActiveNote else {
            print("🎵 SquiggleColor: No active note found, showing gray")
            return .gray
        }
        
        // Get the current detected frequency and target frequency from active note
        let currentFreq = pitchDetector.currentFrequency
        let baseHz = sheetMusic.musicContext.a4Reference
        let targetNoteName = activeNote.note.noteName
        let targetFreq = StaffPositionMapper.noteNameToFrequency(targetNoteName, a4Reference: baseHz)
        
        print("🎵 SquiggleColor: Target note: \(targetNoteName), target freq: \(String(format: "%.1f", targetFreq))Hz, detected freq: \(String(format: "%.1f", currentFreq))Hz")
        
        // Calculate frequency difference
        let freqDiff = currentFreq - targetFreq
        
        // Calculate semitone difference (12 semitones = octave, frequency doubles)
        let semitoneDiff = 12.0 * log2(currentFreq / targetFreq)
        
        print("🎵 SquiggleColor: Semitone difference: \(String(format: "%.2f", semitoneDiff))")
        
        // If very close to target (within 0.1 semitones), show green
        if abs(semitoneDiff) < 0.1 {
            print("🎵 SquiggleColor: In tune - showing green")
            return .green
        }
        
        // Color interpolation based on distance from target
        let maxSemitones: Double = 1.0  // Full color at 1 semitone distance
        let normalizedDistance = min(abs(semitoneDiff) / maxSemitones, 1.0)
        
        if freqDiff < 0 {
            // Below target frequency -> purple
            let purpleIntensity = normalizedDistance
            let greenComponent = max(0, 1.0 - purpleIntensity)
            print("🎵 SquiggleColor: Below target - showing purple (intensity: \(String(format: "%.2f", purpleIntensity)))")
            return Color(red: purpleIntensity * 0.5 + greenComponent * 0.0,
                        green: greenComponent,
                        blue: purpleIntensity * 0.8 + greenComponent * 0.5)
        } else {
            // Above target frequency -> red  
            let redIntensity = normalizedDistance
            let greenComponent = max(0, 1.0 - redIntensity)
            print("🎵 SquiggleColor: Above target - showing red (intensity: \(String(format: "%.2f", redIntensity)))")
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
            
            // Advance score time to track which note should be active
            // Use the music context tempo to advance time realistically
            let secondsPerBeat = 60.0 / sheetMusic.musicContext.tempo
            let timeAdvancementRate = secondsPerBeat * 0.02 // Advance score time based on tempo
            scoreTime += timeAdvancementRate
            
            // Optional: Reset score time if we've exceeded the total duration
            if scoreTime > sheetMusic.totalDuration {
                scoreTime = 0  // Loop back to beginning
            }
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