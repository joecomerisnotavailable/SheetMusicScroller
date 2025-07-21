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
    @Published var errorMessage: String? = nil
    
    // MARK: - Private Properties
    #if canImport(AudioKit)
    nonisolated(unsafe) private var engine: AudioEngine!
    private var tracker: PitchTap!
    nonisolated(unsafe) private var mic: AudioEngine.InputNode!
    #endif
    
    // MARK: - Constants
    private let minimumAmplitudeThreshold: Double = 0.0005  // More sensitive threshold
    private let frequencySmoothing: Double = 0.3            // More responsive smoothing
    private var smoothedFrequency: Double = 0.0
    private var smoothedAmplitude: Double = 0.0
    
    // MARK: - Initialization
    init() {
        setupAudio()
    }
    
    deinit {
        cleanup()
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
        
        // Update main actor-isolated state
        isListening = false
        currentFrequency = 0.0
        currentPitch = ""
        currentAmplitude = 0.0
        errorMessage = nil
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
    }
    
    private func setupAudio() {
        #if canImport(AudioKit)
        setupAudioKit()
        #else
        // AudioKit is not available (e.g., in simulator)
        errorMessage = "AudioKit is not available on this platform. Real-time pitch detection requires AudioKit and is only supported on physical devices."
        print("❌ AudioKit not available - pitch detection unavailable")
        #endif
    }
    
    #if canImport(AudioKit)
    private func setupAudioKit() {
        do {
            // Reset any existing audio session configuration
            let audioSession = AVAudioSession.sharedInstance()
            
            // Configure audio session for high-quality recording
            try audioSession.setCategory(.playAndRecord, 
                                       mode: .measurement, 
                                       options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true)
            
            // Set a high sample rate for better pitch detection accuracy
            try audioSession.setPreferredSampleRate(44100.0)
            try audioSession.setPreferredIOBufferDuration(0.005) // 5ms buffer for low latency
            
            print("🎤 Audio session configured: sample rate \(audioSession.sampleRate), buffer duration \(audioSession.ioBufferDuration)")
            
            // Initialize AudioKit engine
            engine = AudioEngine()
            guard let input = engine.input else {
                print("❌ AudioKit input node unavailable")
                return
            }
            mic = input
            
            // Create pitch tracker with optimized settings
            tracker = PitchTap(mic) { [weak self] pitch, amplitude in
                DispatchQueue.main.async {
                    guard let self = self, self.isListening else { return }
                    
                    // Handle both single values and arrays from AudioKit
                    let freq = pitch.count > 0 ? pitch[0] : 0.0
                    let amp = amplitude.count > 0 ? amplitude[0] : 0.0
                    
                    // Debug actual microphone input detection
                    if amp > 0.0001 {
                        print("🎤 Raw input: \(String(format: "%.1f", freq)) Hz, \(String(format: "%.4f", amp)) amplitude")
                    }
                    
                    self.updatePitchData(frequency: freq, amplitude: amp)
                }
            }
            
            print("✅ AudioKit pitch detection initialized successfully")
            
        } catch {
            print("❌ Failed to setup AudioKit: \(error.localizedDescription)")
            print("   Error details: \(error)")
        }
    }
    #endif
    
    private func updatePitchData(frequency: Double, amplitude: Double) {
        // Apply smoothing to amplitude for more stable signal detection
        smoothedAmplitude = (smoothedAmplitude * 0.7) + (amplitude * 0.3)
        currentAmplitude = smoothedAmplitude
        
        // Only process frequencies in a reasonable musical range
        if smoothedAmplitude > minimumAmplitudeThreshold && frequency > 80 && frequency < 2000 {
            // Apply frequency smoothing for stable pitch detection
            smoothedFrequency = (smoothedFrequency * frequencySmoothing) + (frequency * (1.0 - frequencySmoothing))
            currentFrequency = smoothedFrequency
            currentPitch = midiToPitchName(frequencyToMIDI(smoothedFrequency))
            
            // Log successful pitch detection with less spam
            if Int(smoothedFrequency) % 10 == 0 || smoothedFrequency != frequency {
                print("🎵 Detected: \(Int(smoothedFrequency)) Hz → \(currentPitch) (amp: \(String(format: "%.3f", smoothedAmplitude)))")
            }
        } else {
            // Gradual fade when signal drops
            smoothedFrequency *= 0.85
            if smoothedFrequency < 80 {
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
        guard let engine = engine, let tracker = tracker else {
            let error = "Audio components not initialized. AudioKit setup failed."
            print("❌ \(error)")
            errorMessage = error
            return
        }
        
        do {
            // Ensure audio session is still active
            try AVAudioSession.sharedInstance().setActive(true)
            
            // Start the audio engine
            try engine.start()
            
            // Start pitch tracking
            tracker.start()
            
            isListening = true
            errorMessage = nil
            print("🎼 ✅ Audio engine started successfully - microphone is now active")
            
            // Give a moment for the audio engine to stabilize
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("🎼 Audio engine should now be detecting microphone input")
            }
            
        } catch {
            let errorMsg = "Failed to start audio engine: \(error.localizedDescription)"
            print("❌ \(errorMsg)")
            errorMessage = errorMsg
        }
        #else
        // AudioKit not available
        let error = "AudioKit not available on this platform. Real-time pitch detection requires AudioKit."
        print("❌ \(error)")
        errorMessage = error
        #endif
    }
    
    private func checkMicrophonePermission(completion: @escaping (Bool) -> Void) {
        let recordPermission = AVAudioSession.sharedInstance().recordPermission
        print("🎤 Current microphone permission status: \(recordPermission)")
        
        switch recordPermission {
        case .granted:
            print("✅ Microphone permission already granted")
            completion(true)
        case .denied:
            print("❌ Microphone permission denied")
            completion(false)
        case .undetermined:
            print("🎤 Requesting microphone permission...")
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        print("✅ Microphone permission granted by user")
                    } else {
                        print("❌ Microphone permission denied by user")
                    }
                    completion(granted)
                }
            }
        @unknown default:
            print("⚠️ Unknown microphone permission state")
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