import Foundation
import AVFoundation
import Combine

#if canImport(AudioKit)
import AudioKit
import AudioKitEX
#endif

/// Real-time pitch detection service using AudioKit
/// Provides live pitch information for musical applications
@MainActor
class PitchDetector: ObservableObject {
    // MARK: - Published Properties
    @Published var currentFrequency: Double = 0.0
    @Published var currentPitch: String = ""
    @Published var currentAmplitude: Double = 0.0
    @Published var isListening: Bool = false
    @Published var microphonePermissionGranted: Bool = false
    
    // MARK: - Private Properties
    #if canImport(AudioKit)
    nonisolated(unsafe) private var engine: AudioEngine!
    private var tracker: PitchTap!
    nonisolated(unsafe) private var mic: AudioEngine.InputNode!
    #endif
    
    private var mockTimer: Timer?
    private var lastMockUpdate: Date?
    
    // MARK: - Constants
    private let minimumAmplitudeThreshold: Double = 0.001  // Lowered for much better sensitivity
    private let frequencySmoothing: Double = 0.5           // Reduced for more responsiveness
    private var smoothedFrequency: Double = 0.0
    
    // MARK: - Initialization
    init() {
        setupAudio()
    }
    
    deinit {
        cleanup()
        lastMockUpdate = nil
        mockTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Start listening for pitch input from the microphone
    func startListening() {
        guard !isListening else { return }
        
        checkMicrophonePermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.microphonePermissionGranted = granted
                
                if granted {
                    self.startAudioEngine()
                } else {
                    print("Microphone permission denied")
                }
            }
        }
    }
    
    /// Stop listening for pitch input
    func stopListening() {
        guard isListening else { return }
        
        // Stop the pitch tracker first (main actor context)
        #if canImport(AudioKit)
        tracker?.stop()
        #endif
        
        // Perform thread-safe cleanup
        cleanup()
        
        // Stop mock timer if it exists
        mockTimer?.invalidate()
        mockTimer = nil
        
        // Update main actor-isolated state
        isListening = false
        currentFrequency = 0.0
        currentPitch = ""
        currentAmplitude = 0.0
    }
    
    /// Convert frequency to staff position for sheet music display
    /// Returns a position where 0 is the center line of the treble staff (B4)
    /// Negative values are higher on the staff, positive are lower
    func frequencyToStaffPosition(_ frequency: Double) -> CGFloat {
        guard frequency > 0 else { return 0 }
        
        // Convert frequency to MIDI note number
        let midiNote = frequencyToMIDI(frequency)
        
        // For treble clef staff positioning:
        // B4 (MIDI 71) = center line of staff (position 0)
        // Each staff line/space = 1 position unit
        // D4 (MIDI 62) should be at position 4.5 (just below the staff)
        let trebleStaffCenter: Double = 71  // B4 is the middle line of treble staff
        let staffPosition = (trebleStaffCenter - midiNote) * 0.5  // Each semitone = 0.5 staff spacing
        
        // Constrain to reasonable staff bounds for display
        // Allow range from about 2 octaves above to 1 octave below the staff
        let constrainedPosition = max(-8.0, min(8.0, staffPosition))
        
        return CGFloat(constrainedPosition)
    }
    
    /// Convert frequency to MIDI note number
    private func frequencyToMIDI(_ frequency: Double) -> Double {
        // A4 (440 Hz) = MIDI note 69
        let a4Frequency: Double = 440.0
        let a4MIDI: Double = 69.0
        
        return a4MIDI + 12 * log2(frequency / a4Frequency)
    }
    
    /// Convert MIDI note number to pitch name
    private func midiToPitchName(_ midiNote: Double) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = Int(midiNote / 12) - 1
        let noteIndex = Int(midiNote) % 12
        
        guard noteIndex >= 0 && noteIndex < noteNames.count else { return "" }
        return "\(noteNames[noteIndex])\(octave)"
    }
    
    // MARK: - Private Methods
    
    /// Thread-safe cleanup that can be called from deinit
    /// Only performs operations that don't require main actor isolation
    nonisolated private func cleanup() {
        #if canImport(AudioKit)
        engine?.stop()
        // Note: tracker.stop() should be called from main actor context in stopListening()
        #endif
        // Note: mockTimer invalidation happens in deinit since Timer.invalidate() is main-actor safe
    }
    
    private func setupAudio() {
        #if canImport(AudioKit)
        setupAudioKit()
        #else
        // Fallback for when AudioKit is not available
        print("AudioKit not available - using mock pitch detection")
        setupMockPitchDetection()
        #endif
    }
    
    #if canImport(AudioKit)
    private func setupAudioKit() {
        do {
            // Configure audio session for recording
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            
            print("🎤 Audio session configured successfully")
            
            engine = AudioEngine()
            guard let input = engine.input else {
                print("⚠️ AudioKit input node not available")
                return
            }
            mic = input
            
            tracker = PitchTap(mic) { [weak self] pitch, amplitude in
                DispatchQueue.main.async {
                    guard let self = self, self.isListening else { return }
                    
                    // AudioKit sometimes returns arrays, take the first value
                    let freq = pitch.count > 0 ? pitch[0] : 0.0
                    let amp = amplitude.count > 0 ? amplitude[0] : 0.0
                    
                    // Only log when we have actual audio input
                    if amp > 0.0001 {
                        print("🎵 AudioKit input: \(String(format: "%.1f", freq)) Hz, amplitude: \(String(format: "%.4f", amp))")
                    }
                    
                    self.updatePitchData(frequency: freq, amplitude: amp)
                }
            }
            
            print("🎤 AudioKit pitch detection initialized successfully")
            
        } catch {
            print("❌ Failed to setup AudioKit: \(error)")
        }
    }
    #endif
    
    private func setupMockPitchDetection() {
        // Only use as absolute fallback when AudioKit completely fails
        print("🎭 Warning: Using mock pitch detection - real microphone input is not available")
        lastMockUpdate = Date()
        
        mockTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.isListening else { return }
            
            // More conservative mock behavior - less random movement  
            let now = Date()
            let timeElapsed = now.timeIntervalSince(lastMockUpdate ?? now)
            lastMockUpdate = now
            
            // Generate subtle frequency variation around D4
            let baseFreq = 293.0  // D4
            let variation = 10.0 * sin(timeElapsed * 0.5)  // Much smaller variation
            let mockFrequency = baseFreq + variation
            let mockAmplitude = 0.02  // Low but above threshold
            
            print("🎭 Mock pitch: \(String(format: "%.1f", mockFrequency)) Hz")
            
            DispatchQueue.main.async {
                self.updatePitchData(frequency: mockFrequency, amplitude: mockAmplitude)
            }
        }
    }
    
    private func updatePitchData(frequency: Double, amplitude: Double) {
        currentAmplitude = amplitude
        
        // Only update frequency if amplitude is above threshold and frequency is reasonable
        if amplitude > minimumAmplitudeThreshold && frequency > 50 && frequency < 4000 {
            // Apply smoothing to reduce jitter, but keep it responsive
            smoothedFrequency = (smoothedFrequency * frequencySmoothing) + (frequency * (1.0 - frequencySmoothing))
            currentFrequency = smoothedFrequency
            currentPitch = midiToPitchName(frequencyToMIDI(smoothedFrequency))
            
            // Log detected pitches with staff position
            print("🎵 Pitch: \(Int(smoothedFrequency)) Hz -> \(currentPitch) (staff pos: \(String(format: "%.1f", frequencyToStaffPosition(smoothedFrequency))))")
        } else {
            // Fade to silence more gradually
            smoothedFrequency *= 0.9
            if smoothedFrequency < 50 {  // Completely fade out below 50 Hz
                currentFrequency = 0.0
                currentPitch = ""
            } else {
                currentFrequency = smoothedFrequency
                currentPitch = midiToPitchName(frequencyToMIDI(smoothedFrequency))
            }
        }
    }
    
    private func startAudioEngine() {
        #if canImport(AudioKit)
        do {
            // Only proceed if we have properly initialized components
            guard let engine = engine, let tracker = tracker else {
                print("⚠️ Audio components not properly initialized")
                isListening = true
                setupMockPitchDetection()
                return
            }
            
            try engine.start()
            tracker.start()
            isListening = true
            print("🎼 Audio engine and pitch tracker started - listening for microphone input")
            
        } catch {
            print("❌ Failed to start audio engine: \(error)")
            print("🎭 Using mock detection as fallback")
            isListening = true
            setupMockPitchDetection()
        }
        #else
        // No AudioKit available
        isListening = true
        setupMockPitchDetection()
        print("🎭 AudioKit not available - using mock audio detection")
        #endif
    }
    
    private func checkMicrophonePermission(completion: @escaping (Bool) -> Void) {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            completion(true)
        case .denied:
            completion(false)
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                completion(granted)
            }
        @unknown default:
            completion(false)
        }
    }
}

// MARK: - Extensions for Future Chord Detection

extension PitchDetector {
    /// Placeholder for future chord detection functionality
    /// This structure allows for easy extension to support chord recognition
    func detectChords() -> [String] {
        // TODO: Implement chord detection using multiple pitch detection
        // This could analyze frequency spectrum for multiple simultaneous pitches
        return []
    }
    
    /// Get harmonic analysis of current input
    /// Useful for future chord detection implementation
    func getHarmonicContent() -> [Double] {
        // TODO: Implement FFT analysis for harmonic content
        // This would return an array of harmonic amplitudes
        return []
    }
}