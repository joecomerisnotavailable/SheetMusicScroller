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
    /// This is the note that has most recently passed from the right of the squiggle tip to the left
    /// Based on spatial position rather than just score time
    private var currentlyActiveNote: TimedNote? {
        let gutterWidth: CGFloat = 80
        
        // Find the note that has most recently passed the squiggle tip
        var mostRecentPassedNote: TimedNote?
        
        for (index, timedNote) in sheetMusic.timedNotes.enumerated() {
            let noteXPosition = CGFloat(index) * noteSpacing + gutterWidth + 20 - scrollOffset
            let hasPassedSquiggle = noteXPosition <= squiggleX
            
            if hasPassedSquiggle {
                // This note has passed the squiggle, keep track of it as a candidate
                mostRecentPassedNote = timedNote
            } else {
                // This note hasn't passed yet, so we've found our answer
                break
            }
        }
        
        return mostRecentPassedNote
    }
    
    /// Determines if two note names share the same staff position (enharmonic equivalence)
    /// This is used to decide between Case 1 and Case 2 logic for squiggle positioning.
    /// 
    /// Examples of enharmonic equivalents that should return true:
    /// - F#4 and Gb4 (both occupy the same staff line/space)
    /// - C#4 and Db4 (both occupy the same staff line/space)
    /// - A#4 and Bb4 (both occupy the same staff line/space)
    /// 
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
        // This accounts for floating point precision and ensures enharmonic equivalents
        // are correctly identified as sharing the same staff position
        let tolerance: Double = 0.1
        let sharePosition = abs(position1 - position2) <= tolerance
        
        print("🎼 StaffPosition: \(noteName1)=\(String(format: "%.2f", position1)), \(noteName2)=\(String(format: "%.2f", position2)), share=\(sharePosition)")
        
        return sharePosition
    }
    
    /// Calculate the current Y position of the squiggle tip using the unified algorithm
    /// that references the currently active note instead of always the nearest detected note.
    /// 
    /// REFACTORED to address feedback:
    /// - freqTop no longer exists as a separate entity
    /// - Case 1: freqTop replaced with freqActiveNote (active note frequency)  
    /// - Case 2: freqTop replaced with freqTrue (nearest detected note frequency)
    /// - No active note: treated as Case 2 (same note scenario)
    /// - Active note: determined spatially by squiggle tip position, not score time
    /// - Unified single function instead of separate case functions
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
        
        // Step 2: Use noteNameFromFrequency to get nearest detected note name
        let nearestNoteName = StaffPositionMapper.noteNameFromFrequency(freq, a4Reference: baseHz)
        
        // Determine which case we're in
        let activeNote = currentlyActiveNote
        let isCase1: Bool
        let anchorNoteName: String
        let freqTop: Double  // This replaces the old freqTop with appropriate value
        
        if let activeNote = activeNote {
            let activeNoteName = activeNote.note.noteName
            let shareStaffPosition = doNotesShareStaffPosition(activeNoteName, nearestNoteName, keySignature: keySignature, clef: clef)
            
            if shareStaffPosition {
                // Case 1: Enharmonic equivalence - use active note frequency as freqTop
                isCase1 = true
                anchorNoteName = activeNoteName
                freqTop = StaffPositionMapper.noteNameToFrequency(activeNoteName, a4Reference: baseHz)
                print("🎯 SquigglePosition: Case 1 - Using active note \(activeNoteName) as anchor (freqTop=\(String(format: "%.1f", freqTop))Hz)")
            } else {
                // Case 2: Different staff positions - use nearest detected note frequency as freqTop
                isCase1 = false
                anchorNoteName = nearestNoteName
                freqTop = StaffPositionMapper.noteNameToFrequency(nearestNoteName, a4Reference: baseHz)
                print("🎯 SquigglePosition: Case 2 - Using nearest note \(nearestNoteName) as anchor (freqTop=\(String(format: "%.1f", freqTop))Hz)")
            }
        } else {
            // No active note - treat as same note scenario (Case 2 logic with nearest note)
            isCase1 = false
            anchorNoteName = nearestNoteName
            freqTop = StaffPositionMapper.noteNameToFrequency(nearestNoteName, a4Reference: baseHz)
            print("🎯 SquigglePosition: No active note - Using nearest note \(nearestNoteName) as anchor (freqTop=\(String(format: "%.1f", freqTop))Hz)")
        }
        
        // Step 3: Use getYFromNoteAndKey to get initial Y coordinate (yAnchor)
        let yAnchor = StaffPositionMapper.getYFromNoteAndKey(anchorNoteName, keySignature: keySignature, clef: clef, staffHeight: staffHeight)
        
        // Step 4: Apply frequency interpolation using the original algorithm with appropriate freqTop
        let freqDelta = freq - freqTop
        
        // If frequency is very close to the anchor note, don't interpolate
        if abs(freqDelta) < 0.5 {
            print("🎯 SquigglePosition: Close to anchor frequency, no interpolation needed")
            return yAnchor
        }
        
        // Find noteNext (next note whose staff position differs from anchorNoteName)
        let direction = freqDelta > 0 ? 1 : -1  // 1 for up (higher freq), -1 for down (lower freq)
        let noteNext = StaffPositionMapper.nextNoteWithDifferentStaffPosition(
            from: anchorNoteName, 
            direction: direction, 
            keySignature: keySignature, 
            clef: clef
        )
        
        // Safety check: ensure we got a valid next note
        guard !noteNext.isEmpty && noteNext != anchorNoteName else {
            print("🎯 SquigglePosition: Could not find valid next note, returning anchor position")
            return yAnchor
        }
        
        // Calculate yNext using getYFromNoteAndKey
        let yNext = StaffPositionMapper.getYFromNoteAndKey(noteNext, keySignature: keySignature, clef: clef, staffHeight: staffHeight)
        
        // For Case 1, freqTop is already set to freqActiveNote
        // For Case 2, we need to find the actual freqTop (last note with same staff position)
        let finalFreqTop: Double
        if isCase1 {
            finalFreqTop = freqTop  // Already set to active note frequency
        } else {
            finalFreqTop = findFreqTopForInterpolation(
                nearestNoteName: anchorNoteName,
                direction: direction,
                keySignature: keySignature,
                clef: clef,
                baseHz: baseHz
            )
        }
        
        // Calculate freqNext (frequency of noteNext)
        let freqNext = StaffPositionMapper.noteNameToFrequency(noteNext, a4Reference: baseHz)
        
        print("🎯 SquigglePosition: Anchor note: \(anchorNoteName), Y: \(String(format: "%.1f", yAnchor)), Next note: \(noteNext), Y: \(String(format: "%.1f", yNext))")
        print("🎯 SquigglePosition: finalFreqTop: \(String(format: "%.1f", finalFreqTop))Hz, freqNext: \(String(format: "%.1f", freqNext))Hz")
        
        // Safety checks: ensure frequencies are valid and different
        guard finalFreqTop > 0 && freqNext > 0 && abs(finalFreqTop - freqNext) > 0.1 else {
            print("🎯 SquigglePosition: Invalid frequency range, returning anchor position")
            return yAnchor
        }
        
        // Apply the exact formula: |ySquiggle - yAnchor|/|yAnchor - yNext| = |freq - finalFreqTop|/|finalFreqTop - freqNext|
        let freqRange = abs(finalFreqTop - freqNext)
        let freqOffset = abs(freq - finalFreqTop)
        
        let interpolationRatio = min(freqOffset / freqRange, 1.0)  // Clamp to prevent over-interpolation
        let yRange = yNext - yAnchor
        let ySquiggle = yAnchor + yRange * interpolationRatio
        
        print("🎯 SquigglePosition: Interpolation ratio: \(String(format: "%.3f", interpolationRatio)), final Y: \(String(format: "%.1f", ySquiggle))")
        
        // Safety check: ensure Y position is within reasonable bounds
        let clampedY = max(0, min(staffHeight, ySquiggle))
        if clampedY != ySquiggle {
            print("🎯 SquigglePosition: Y position clamped from \(String(format: "%.1f", ySquiggle)) to \(String(format: "%.1f", clampedY))")
        }
        
        return clampedY
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
    /// If no active note exists, shows grey color
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