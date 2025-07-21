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
    
    private var permissionTimer: Timer?
    private var mockTimer: Timer?
    
    // MARK: - Constants
    private let minimumAmplitudeThreshold: Double = 0.005  // Lowered for better sensitivity
    private let frequencySmoothing: Double = 0.7           // Reduced for more responsiveness
    private var smoothedFrequency: Double = 0.0
    
    // MARK: - Initialization
    init() {
        setupAudio()
    }
    
    deinit {
        cleanup()
        permissionTimer?.invalidate()
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
        
        // Perform thread-safe cleanup first
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
    /// Returns a position where 0 is the center of the staff
    func frequencyToStaffPosition(_ frequency: Double) -> CGFloat {
        guard frequency > 0 else { return 0 }
        
        // Convert frequency to MIDI note number
        let midiNote = frequencyToMIDI(frequency)
        
        // Map MIDI note to staff position with expanded range handling
        // Middle C (C4) = MIDI 60, should be around position 0 (center of treble staff)
        // Each semitone is approximately 0.12 staff line spacing (reduced for wider range)
        let middleC: Double = 60
        let rawStaffPosition = (midiNote - middleC) * 0.12
        
        // Constrain to reasonable staff bounds (approximately -4 to +4 staff line spacings)
        // This ensures even very high whistling frequencies stay visible
        let constrainedPosition = max(-4.0, min(4.0, rawStaffPosition))
        
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
            engine = AudioEngine()
            guard let input = engine.input else {
                print("⚠️ AudioKit input node not available, using mock detection")
                setupMockPitchDetection()
                return
            }
            mic = input
            
            tracker = PitchTap(mic) { [weak self] pitch, amplitude in
                DispatchQueue.main.async {
                    guard let self = self, self.isListening else { return }
                    // AudioKit sometimes returns arrays, take the first value
                    let freq = pitch.count > 0 ? pitch[0] : 0.0
                    let amp = amplitude.count > 0 ? amplitude[0] : 0.0
                    self.updatePitchData(frequency: freq, amplitude: amp)
                }
            }
            
            print("🎤 AudioKit pitch detection initialized successfully")
            
        } catch {
            print("❌ Failed to setup AudioKit: \(error)")
            print("🎭 Falling back to mock pitch detection")
            setupMockPitchDetection()
        }
    }
    #endif
    
    private func setupMockPitchDetection() {
        // For development/testing when AudioKit is not available
        // This will generate mock pitch data that simulates varying frequencies
        print("🎤 Using mock pitch detection - squiggle will show animated frequency changes")
        
        mockTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, self.isListening else { return }
            
            // Generate mock frequency data that varies more dramatically to simulate whistling/singing
            let time = Date().timeIntervalSince1970
            let baseFreq = 440.0 + 200.0 * sin(time * 0.5)  // Oscillates between 240-640 Hz
            let highFreq = 880.0 + 400.0 * sin(time * 0.3)  // Occasionally jump to higher frequencies (480-1280 Hz)
            
            // Randomly choose between base and high frequency to simulate varied input
            let mockFrequency = Double.random(in: 0...1) < 0.7 ? baseFreq : highFreq
            let mockAmplitude = 0.4 + 0.3 * sin(time * 2)  // Varying amplitude 0.1-0.7
            
            DispatchQueue.main.async {
                self.updatePitchData(frequency: mockFrequency, amplitude: mockAmplitude)
            }
        }
    }
    
    private func updatePitchData(frequency: Double, amplitude: Double) {
        currentAmplitude = amplitude
        
        // Only update frequency if amplitude is above threshold
        if amplitude > minimumAmplitudeThreshold {
            // Apply smoothing to reduce jitter, but keep it responsive
            smoothedFrequency = (smoothedFrequency * frequencySmoothing) + (frequency * (1.0 - frequencySmoothing))
            currentFrequency = smoothedFrequency
            currentPitch = midiToPitchName(frequencyToMIDI(smoothedFrequency))
            
            // Debug print for very high frequencies that might indicate whistling
            if frequency > 1000 {
                print("🎵 High frequency detected: \(Int(frequency)) Hz -> \(currentPitch)")
            }
        } else {
            // Fade to silence more gradually
            smoothedFrequency *= 0.95
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
            try engine.start()
            isListening = true
            print("🎼 Audio engine started successfully - listening for pitch input")
        } catch {
            print("❌ Failed to start audio engine: \(error)")
            print("🎭 Falling back to mock pitch detection")
            isListening = true
            setupMockPitchDetection()
        }
        #else
        // Mock audio engine start
        isListening = true
        print("🎭 Mock audio engine started - squiggle will show animated frequency changes")
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