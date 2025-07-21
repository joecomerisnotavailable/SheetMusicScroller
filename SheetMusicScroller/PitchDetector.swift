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
    private var engine: AudioEngine!
    private var tracker: PitchTap!
    private var mic: AudioEngine.InputNode!
    #endif
    
    private var permissionTimer: Timer?
    
    // MARK: - Constants
    private let minimumAmplitudeThreshold: Double = 0.01
    private let frequencySmoothing: Double = 0.8
    private var smoothedFrequency: Double = 0.0
    
    // MARK: - Initialization
    init() {
        setupAudio()
    }
    
    deinit {
        stopListening()
        permissionTimer?.invalidate()
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
        
        #if canImport(AudioKit)
        engine?.stop()
        #endif
        
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
        
        // Map MIDI note to staff position
        // Middle C (C4) = MIDI 60, should be around position 0 (center of treble staff)
        // Each semitone is approximately 0.15 staff line spacing
        let middleC: Double = 60
        let staffPosition = (midiNote - middleC) * 0.15
        
        return CGFloat(staffPosition)
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
            mic = engine.input
            
            tracker = PitchTap(mic) { [weak self] pitch, amplitude in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.updatePitchData(frequency: pitch[0], amplitude: amplitude[0])
                }
            }
            
        } catch {
            print("Failed to setup AudioKit: \(error)")
            setupMockPitchDetection()
        }
    }
    #endif
    
    private func setupMockPitchDetection() {
        // For development/testing when AudioKit is not available
        // This will generate mock pitch data
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.isListening else { return }
            
            // Generate some mock frequency data (440 Hz A4 with some variation)
            let baseFreq = 440.0
            let variation = Double.random(in: -50...50)
            let mockFrequency = baseFreq + variation
            let mockAmplitude = 0.3
            
            DispatchQueue.main.async {
                self.updatePitchData(frequency: mockFrequency, amplitude: mockAmplitude)
            }
        }
    }
    
    private func updatePitchData(frequency: Double, amplitude: Double) {
        currentAmplitude = amplitude
        
        // Only update frequency if amplitude is above threshold
        if amplitude > minimumAmplitudeThreshold {
            // Apply smoothing to reduce jitter
            smoothedFrequency = (smoothedFrequency * frequencySmoothing) + (frequency * (1.0 - frequencySmoothing))
            currentFrequency = smoothedFrequency
            currentPitch = midiToPitchName(frequencyToMIDI(smoothedFrequency))
        } else {
            // Fade to silence
            currentFrequency = 0.0
            currentPitch = ""
        }
    }
    
    private func startAudioEngine() {
        #if canImport(AudioKit)
        do {
            try engine.start()
            isListening = true
            print("Audio engine started successfully")
        } catch {
            print("Failed to start audio engine: \(error)")
            isListening = false
        }
        #else
        // Mock audio engine start
        isListening = true
        print("Mock audio engine started")
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