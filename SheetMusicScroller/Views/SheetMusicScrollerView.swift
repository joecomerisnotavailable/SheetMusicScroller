import SwiftUI

/// Tracks performance data for a note over the time it was active
struct NotePerformanceTracker {
    var accuracySamples: [Double] = []
    var sampleTimes: [Double] = []
    var startTime: Double?
    var endTime: Double?
    
    /// Add a performance sample
    mutating func addSample(accuracy: Double, time: Double) {
        if startTime == nil {
            startTime = time
        }
        accuracySamples.append(accuracy)
        sampleTimes.append(time)
    }
    
    /// Mark the note as finished and calculate final performance
    mutating func finish(at time: Double) {
        endTime = time
    }
    
    /// Calculate time-averaged color based on performance
    var averagePerformanceColor: Color {
        guard !accuracySamples.isEmpty else { return .black }
        
        // Calculate weighted average based on time intervals
        var totalWeight = 0.0
        var weightedSum = 0.0
        
        for i in 0..<accuracySamples.count {
            let weight = i < sampleTimes.count - 1 ? 
                (sampleTimes[i + 1] - sampleTimes[i]) : 0.1 // Default interval for last sample
            totalWeight += weight
            weightedSum += accuracySamples[i] * weight
        }
        
        let averageAccuracy = totalWeight > 0 ? weightedSum / totalWeight : 0.0
        
        // Convert average accuracy to color
        return performanceAccuracyToColor(averageAccuracy)
    }
    
    /// Convert performance accuracy to color (similar to squiggle color logic)
    private func performanceAccuracyToColor(_ accuracy: Double) -> Color {
        // accuracy is in semitones: 0 = perfect, positive = sharp, negative = flat
        
        // If very close to perfect (within 0.1 semitones), show green
        if abs(accuracy) < 0.1 {
            return .green
        }
        
        // Color interpolation based on distance from perfect
        let maxSemitones: Double = 1.0  // Full color at 1 semitone distance
        let normalizedDistance = min(abs(accuracy) / maxSemitones, 1.0)
        
        if accuracy < 0 {
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
}

/// Main view that orchestrates the scrolling sheet music display with marker squiggle
struct SheetMusicScrollerView: View {
    let sheetMusic: SheetMusic
    
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollTimer: Timer?
    @StateObject private var pitchDetector = PitchDetector()
    @State private var scoreTime: Double = 0  // Current wall-clock elapsed time for performance tracking
    @State private var lastTimerTime: Date = Date()  // Track real time for delta calculations
    @State private var noteColors: [UUID: Color] = [:]  // Track persistent color for each note after it passes
    @State private var notePerformanceData: [UUID: NotePerformanceTracker] = [:]  // Track performance over time for each note
    
    /// Configuration for squiggle drawing appearance - smaller, more precise crayon style
    @State private var squiggleDrawingConfig = SquiggleDrawingConfig(
        lineWidth: 2.5,
        tipSize: 4.5,
        useRoundLineCaps: true
    )
    
    // Tempo and scroll speed controls - independent sliders
    @State private var tempoBPM: Double = 72.0  // Default to sheet's tempo
    @State private var scrollSpeedPxPerSec: Double = 30.0  // Visual scroll speed in pixels per second
    
    private let gutterWidth: CGFloat = 80
    
    /// Calculate the X position for a note based on its start time (now in beats)
    func calculateNoteXPosition(for timedNote: TimedNote) -> CGFloat {
        // Compute pixelsPerBeat dynamically from scroll speed and tempo
        let pixelsPerBeat = scrollSpeedPxPerSec * (60.0 / tempoBPM)
        return CGFloat(timedNote.startTime * pixelsPerBeat) + gutterWidth + 20 - scrollOffset
    }
    
    /// Computes the note nearest to the left of the fixed vertical bar.
    private func activeNoteByBarPosition() -> TimedNote? {
        let candidates = sheetMusic.timedNotes.filter { timedNote in
            calculateNoteXPosition(for: timedNote) <= squiggleX
        }
        return candidates.max(by: { a, b in
            calculateNoteXPosition(for: a) < calculateNoteXPosition(for: b)
        })
    }
    
    /// Returns the set containing the active note ID (by bar), or empty if none.
    private var activeNotesByBar: Set<UUID> {
        if let n = activeNoteByBarPosition() { return [n.id] } else { return [] }
    }
    private let squiggleX: CGFloat = 100   // Fixed x position of squiggle aligned with gutter (gutterWidth + leftMargin)
    
    init(sheetMusic: SheetMusic) {
        self.sheetMusic = sheetMusic
        // Initialize tempo from sheet music
        self._tempoBPM = State(initialValue: sheetMusic.musicContext.tempo)
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
            
            // Tempo and scroll speed controls
            tempoScrollControlsView
            
            // Pitch detection info
            pitchInfoView
            
            // Pitch detection controls
            pitchControlsView
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
                Text("Tempo: \(Int(tempoBPM)) BPM")
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
                activeNotes: activeNotesByBar,
                scrollOffset: scrollOffset,
                squiggleX: squiggleX,
                squiggleColor: squiggleColor,
                noteColors: noteColors,
                tempoBPM: tempoBPM,
                scrollSpeedPxPerSec: scrollSpeedPxPerSec
            )
            .frame(height: 220)  // Increased to accommodate extended staff range
            
            // Squiggle tip anchored to the bar, vertical position tracks detected pitch
            // Made invisible but logic preserved for crossing evaluations
            SquiggleView(
                fixedX: squiggleX,
                y: currentSquiggleYPosition,
                color: squiggleColor,
                drawingConfig: squiggleDrawingConfig
            )
            .opacity(0)  // Hide the squiggle line but preserve logic
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
    
    /// Tempo and scroll speed controls for independent adjustment
    private var tempoScrollControlsView: some View {
        VStack(spacing: 12) {
            Text("Playback Controls")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                // Tempo control
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Tempo: \(Int(tempoBPM)) BPM")
                            .font(.caption)
                        Spacer()
                        Text("🎵 Musical timing - affects note spacing")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: $tempoBPM,
                        in: 30...240,
                        step: 1
                    ) {
                        Text("Tempo")
                    }
                }
                
                // Scroll speed control
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Scroll Speed: \(Int(scrollSpeedPxPerSec)) px/s")
                            .font(.caption)
                        Spacer()
                        Text("📜 Visual speed - affects staff movement")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: $scrollSpeedPxPerSec,
                        in: 10...300,
                        step: 5
                    ) {
                        Text("Scroll Speed")
                    }
                }
            }
        }
        .padding()
        .background(Color.primary.opacity(0.05))
        .cornerRadius(8)
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
    
    /// Pitch detection configuration controls for runtime adjustment
    private var pitchControlsView: some View {
        VStack(spacing: 12) {
            Text("Pitch Detection Settings")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                // Frame size control
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Analysis Frame Size: \(pitchDetector.config.analysisFrameSize)")
                            .font(.caption)
                        Spacer()
                        Text("⚙️ Affects latency vs accuracy")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: Binding(
                            get: { Double(pitchDetector.config.analysisFrameSize) },
                            set: { pitchDetector.updateAnalysisFrameSize(Int($0)) }
                        ),
                        in: 256...4096,
                        step: 256
                    ) {
                        Text("Frame Size")
                    }
                }
                
                // YIN algorithm toggle
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Toggle("Use YIN Algorithm", isOn: Binding(
                            get: { pitchDetector.config.useYIN },
                            set: { newValue in
                                pitchDetector.config.useYIN = newValue
                                // Restart pitch detection to apply new algorithm
                                if pitchDetector.isListening {
                                    pitchDetector.stopListening()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        pitchDetector.startListening()
                                    }
                                }
                            }
                        ))
                            .font(.caption)
                        
                        Spacer()
                        
                        Text("🎯 Higher fidelity pitch detection")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if pitchDetector.config.useYIN {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("YIN Threshold: \(pitchDetector.config.yinThreshold, specifier: "%.2f")")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Slider(
                                value: $pitchDetector.config.yinThreshold,
                                in: 0.05...0.5,
                                step: 0.05
                            ) {
                                Text("YIN Threshold")
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                
                Divider()
                
                // Squiggle drawing style controls
                VStack(alignment: .leading, spacing: 4) {
                    Text("Squiggle Drawing Style")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 16) {
                        Toggle("Round Caps", isOn: $squiggleDrawingConfig.useRoundLineCaps)
                            .font(.caption)
                        
                        Spacer()
                    }
                    
                    // Quick style presets for different line widths
                    HStack(spacing: 8) {
                        Button("Fine") {
                            squiggleDrawingConfig = SquiggleDrawingConfig(
                                lineWidth: 1.5,
                                tipSize: 3.5,
                                useRoundLineCaps: true
                            )
                        }
                        .font(.caption2)
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        
                        Button("Default") {
                            squiggleDrawingConfig = SquiggleDrawingConfig(
                                lineWidth: 2.5,
                                tipSize: 4.5,
                                useRoundLineCaps: true
                            )
                        }
                        .font(.caption2)
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        
                        Button("Bold") {
                            squiggleDrawingConfig = SquiggleDrawingConfig(
                                lineWidth: 3.5,
                                tipSize: 6.0,
                                useRoundLineCaps: true
                            )
                        }
                        .font(.caption2)
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        
                        Spacer()
                    }
                }
                
                Text("Smoothing disabled for raw, responsive pitch detection")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color.primary.opacity(0.03))
        .cornerRadius(8)
    }
    
    /// Get the currently active note based on bar position (nearest note to the left of the bar)
    /// This is the note that should be considered for pitch comparison
    private var currentlyActiveNote: TimedNote? {
        return activeNoteByBarPosition()
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
        let totalFrameHeight: CGFloat = 220  // Match the frame height used in the UI
        
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
        let yAnchor = StaffPositionMapper.getYFromNoteAndKey(anchorNoteName, keySignature: keySignature, clef: clef, staffHeight: staffHeight, totalFrameHeight: totalFrameHeight)
        
        // Step 4: Apply frequency interpolation using the original algorithm with appropriate freqTop
        let freqDelta = freq - freqTop
        
        // Determine interpolation direction based on the actual detected frequency vs anchor frequency
        let anchorFreq = StaffPositionMapper.noteNameToFrequency(anchorNoteName, a4Reference: baseHz)
        let directionDelta = freq - anchorFreq
        
        // If frequency is very close to the anchor note, don't interpolate
        if abs(directionDelta) < 0.5 {
            print("🎯 SquigglePosition: Close to anchor frequency, no interpolation needed")
            return yAnchor
        }
        
        // Find noteNext (next note whose staff position differs from anchorNoteName)
        let direction = directionDelta > 0 ? 1 : -1  // 1 for up (higher freq), -1 for down (lower freq)
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
        let yNext = StaffPositionMapper.getYFromNoteAndKey(noteNext, keySignature: keySignature, clef: clef, staffHeight: staffHeight, totalFrameHeight: totalFrameHeight)
        
        // In both cases, freqTop is already correctly set:
        // Case 1: freqTop = active note frequency
        // Case 2: freqTop = detected note frequency (already set correctly above)
        let finalFreqTop = freqTop
        
        // Calculate freqNext (frequency of noteNext)
        let freqNext = StaffPositionMapper.noteNameToFrequency(noteNext, a4Reference: baseHz)
        
        print("🎯 SquigglePosition: Anchor note: \(anchorNoteName), Y: \(String(format: "%.1f", yAnchor)), Next note: \(noteNext), Y: \(String(format: "%.1f", yNext))")
        print("🎯 SquigglePosition: finalFreqTop: \(String(format: "%.1f", finalFreqTop))Hz, freqNext: \(String(format: "%.1f", freqNext))Hz")
        
        // Safety checks: ensure frequencies are valid and different
        guard finalFreqTop > 0 && freqNext > 0 && abs(finalFreqTop - freqNext) > 0.1 else {
            print("🎯 SquigglePosition: Invalid frequency range, returning anchor position")
            return yAnchor
        }
        
        // Apply interpolation formula with proper direction handling
        let freqRange = freqNext - finalFreqTop  // Maintain sign for direction
        let freqOffset = freq - finalFreqTop     // Maintain sign for direction
        
        // Only interpolate if frequency is between finalFreqTop and freqNext
        let interpolationRatio: Double
        if abs(freqRange) > 0.1 {
            interpolationRatio = max(0.0, min(1.0, freqOffset / freqRange))  // Clamp between 0 and 1
        } else {
            interpolationRatio = 0.0  // No interpolation if range is too small
        }
        
        let yRange = yNext - yAnchor
        let ySquiggle = yAnchor + yRange * interpolationRatio
        
        print("🎯 SquigglePosition: Interpolation ratio: \(String(format: "%.3f", interpolationRatio)), final Y: \(String(format: "%.1f", ySquiggle))")
        
        // Safety check: ensure Y position is within reasonable bounds
        // Use totalFrameHeight instead of staffHeight to allow for notes below staff
        let clampedY = max(0, min(totalFrameHeight, ySquiggle))
        if clampedY != ySquiggle {
            print("🎯 SquigglePosition: Y position clamped from \(String(format: "%.1f", ySquiggle)) to \(String(format: "%.1f", clampedY))")
        }
        
        return clampedY
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
        lastTimerTime = Date()
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            let currentTime = Date()
            let deltaTime = currentTime.timeIntervalSince(lastTimerTime)
            lastTimerTime = currentTime
            
            // Update scroll position using real delta time and scroll speed
            scrollOffset += CGFloat(scrollSpeedPxPerSec * deltaTime)
            
            // Update score time as wall-clock elapsed time for performance tracking
            scoreTime += deltaTime
            
            // Optional: Reset if we've scrolled too far (based on content length)
            let totalContentWidth = calculateTotalContentWidth()
            if scrollOffset > totalContentWidth {
                scrollOffset = 0
                scoreTime = 0
            }
            
            // Track performance data for the currently active note
            trackCurrentNotePerformance()
            
            // Update persistent note colors for notes that have just passed the squiggle
            updateNoteColorsForPassedNotes()
        }
    }
    
    /// Calculate total content width based on all notes
    private func calculateTotalContentWidth() -> CGFloat {
        guard let lastNote = sheetMusic.timedNotes.max(by: { $0.startTime < $1.startTime }) else {
            return 1000  // Default width
        }
        
        let pixelsPerBeat = scrollSpeedPxPerSec * (60.0 / tempoBPM)
        return CGFloat(lastNote.startTime * pixelsPerBeat) + 200  // Add some padding
    }
    
    private func stopScrolling() {
        scrollTimer?.invalidate()
        scrollTimer = nil
    }
    
    /// Track performance data for the currently active note
    private func trackCurrentNotePerformance() {
        guard let activeNote = currentlyActiveNote,
              pitchDetector.currentAmplitude > 0.01 && pitchDetector.currentFrequency > 0 else {
            return
        }
        
        // Calculate performance accuracy (in semitones)
        let currentFreq = pitchDetector.currentFrequency
        let baseHz = sheetMusic.musicContext.a4Reference
        let targetNoteName = activeNote.note.noteName
        let targetFreq = StaffPositionMapper.noteNameToFrequency(targetNoteName, a4Reference: baseHz)
        
        // Calculate semitone difference (12 semitones = octave, frequency doubles)
        let semitoneDiff = 12.0 * log2(currentFreq / targetFreq)
        
        // Initialize performance tracker if needed
        if notePerformanceData[activeNote.id] == nil {
            notePerformanceData[activeNote.id] = NotePerformanceTracker()
        }
        
        // Add performance sample
        notePerformanceData[activeNote.id]?.addSample(accuracy: semitoneDiff, time: scoreTime)
    }
    
    /// Update coloring only when a note passes the fixed bar.
    private func updateNoteColorsForPassedNotes() {
        for timedNote in sheetMusic.timedNotes {
            let noteXPosition = calculateNoteXPosition(for: timedNote)
            let hasPassedBar = noteXPosition <= squiggleX
            if hasPassedBar && noteColors[timedNote.id] == nil {
                notePerformanceData[timedNote.id]?.finish(at: scoreTime)
                let colorToStore: Color
                if let tracker = notePerformanceData[timedNote.id], !tracker.accuracySamples.isEmpty {
                    colorToStore = tracker.averagePerformanceColor
                } else {
                    colorToStore = .black // fallback; could be neutral gray
                }
                noteColors[timedNote.id] = colorToStore
            }
        }
    }
}

#Preview {
    SheetMusicScrollerView(sheetMusic: BachAllemandeData.bachAllemande)
        .frame(width: 800, height: 600)
}