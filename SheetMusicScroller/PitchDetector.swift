//
//  PitchDetector.swift
//  SheetMusicScroller
//
//  Created by Joe Comer on 2/22/24.
//

import Foundation

#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(AudioKit)
import AudioKit
import AudioKitEX
import SoundpipeAudioKit
#endif

#if canImport(AVFoundation)
import AVFoundation
#endif

/// Configuration for pitch detection parameters
struct PitchDetectionConfig {
    /// Window size for median filtering (number of samples to keep for smoothing)
    var medianFilterWindowSize: Int = 5
    /// Frame size for analysis window (AudioKit buffer size)
    var analysisFrameSize: Int = 1024
    /// Minimum amplitude threshold for valid pitch detection
    var minimumAmplitudeThreshold: Double = 0.05
    /// Whether to enable median filtering for pitch stability
    var enableMedianFiltering: Bool = true
    /// Whether to enable frequency smoothing
    var enableFrequencySmoothing: Bool = true
    /// Smoothing factor for frequency values (0.0 = no smoothing, 1.0 = maximum smoothing)
    var frequencySmoothingFactor: Double = 0.7
}

// Define protocol for when SwiftUI is not available
#if !canImport(SwiftUI)
protocol ObservableObject: AnyObject {
}

@propertyWrapper
struct Published<Value> {
    var wrappedValue: Value
    
    init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }
}
#endif

final class PitchDetector: ObservableObject {
    // Published properties for UI updates
    @Published var currentFrequency: Double = 0.0
    @Published var currentAmplitude: Double = 0.0
    @Published var isListening: Bool = false
    @Published var microphonePermissionGranted: Bool = false
    @Published var errorMessage: String? = nil

    // For debugging: show detected note name, etc.
    @Published var detectedNoteName: String = "--"
    @Published var detectedOctave: Int = 0
    
    /// Configuration for pitch detection parameters - exposed for runtime adjustment
    @Published var config: PitchDetectionConfig = PitchDetectionConfig()
    
    // Median filtering for pitch stability
    private var frequencyHistory: [Double] = []
    private var amplitudeHistory: [Double] = []
    
    // Frequency smoothing
    private var smoothedFrequency: Double = 0.0
    
    // Computed property for current pitch string
    var currentPitch: String {
        if currentFrequency > 0 && currentAmplitude > config.minimumAmplitudeThreshold {
            return "\(detectedNoteName)\(detectedOctave)"
        } else {
            return ""
        }
    }

    // AudioKit variables
    #if canImport(AudioKit)
    private var engine: AudioEngine?
    private var mic: AudioEngine.InputNode?
    private var tracker: PitchTap?
    #endif

    // Timer for permission check
    private var permissionTimer: Timer?

    init() {
        #if canImport(AudioKit) && canImport(AVFoundation)
        checkPermissionsAndSetup()
        #else
        print("AudioKit or AVFoundation is not available on this platform. Pitch detection will not work.")
        errorMessage = "AudioKit or AVFoundation is not available on this platform"
        #endif
    }

    deinit {
        // Only cleanup non-main-actor, thread-safe resources here
        permissionTimer?.invalidate()
        // Do NOT call @MainActor methods from deinit
        #if canImport(AudioKit) && canImport(AVFoundation)
        stopAudioEngine()
        #endif
    }

    // MARK: - Pitch Filtering and Smoothing
    
    /// Apply median filtering and frequency smoothing for improved pitch stability
    /// Reduces jitter from spurious outliers and provides configurable smoothing
    private func applyFiltering(frequency: Double, amplitude: Double) -> (frequency: Double, amplitude: Double) {
        var filteredFrequency = frequency
        var filteredAmplitude = amplitude
        
        // Apply median filtering if enabled
        if config.enableMedianFiltering {
            filteredFrequency = applyMedianFilter(value: frequency, history: &frequencyHistory, windowSize: config.medianFilterWindowSize)
            filteredAmplitude = applyMedianFilter(value: amplitude, history: &amplitudeHistory, windowSize: config.medianFilterWindowSize)
        }
        
        // Apply frequency smoothing if enabled
        if config.enableFrequencySmoothing && filteredFrequency > 0 {
            smoothedFrequency = applyExponentialSmoothing(newValue: filteredFrequency, previousValue: smoothedFrequency, factor: config.frequencySmoothingFactor)
            filteredFrequency = smoothedFrequency
        }
        
        return (filteredFrequency, filteredAmplitude)
    }
    
    /// Apply median filter to reduce outliers and jitter
    private func applyMedianFilter(value: Double, history: inout [Double], windowSize: Int) -> Double {
        // Add new value to history
        history.append(value)
        
        // Maintain window size
        if history.count > windowSize {
            history.removeFirst()
        }
        
        // Return median of current window
        guard !history.isEmpty else { return value }
        let sortedHistory = history.sorted()
        let middleIndex = sortedHistory.count / 2
        
        if sortedHistory.count % 2 == 0 {
            // Even number of elements - average of two middle values
            return (sortedHistory[middleIndex - 1] + sortedHistory[middleIndex]) / 2.0
        } else {
            // Odd number of elements - middle value
            return sortedHistory[middleIndex]
        }
    }
    
    /// Apply exponential smoothing for frequency stability
    /// factor: 0.0 = no smoothing, 1.0 = maximum smoothing
    private func applyExponentialSmoothing(newValue: Double, previousValue: Double, factor: Double) -> Double {
        if previousValue == 0.0 {
            return newValue // First value, no smoothing needed
        }
        
        // Exponential smoothing formula: smoothed = factor * previous + (1 - factor) * new
        return factor * previousValue + (1.0 - factor) * newValue
    }

    // MARK: - AudioKit Setup and Permission

    #if canImport(AudioKit) && canImport(AVFoundation)
    private func checkPermissionsAndSetup() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            microphonePermissionGranted = true
            setupAudioKit()
        case .denied:
            microphonePermissionGranted = false
            errorMessage = "Microphone access denied"
            print("Microphone access denied")
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.microphonePermissionGranted = granted
                    if granted {
                        self.errorMessage = nil
                        self.setupAudioKit()
                    } else {
                        self.errorMessage = "Microphone access denied"
                        print("Microphone access denied")
                    }
                }
            }
        @unknown default:
            microphonePermissionGranted = false
            errorMessage = "Unknown record permission state"
            print("Unknown record permission state")
        }
    }

    private func setupAudioKit() {
        #if canImport(AVFoundation)
        // First check if we have any available audio inputs
        let session = AVAudioSession.sharedInstance()
        let hasInputs = session.availableInputs?.count ?? 0 > 0
        let hasCurrentInputs = session.currentRoute.inputs.count > 0
        
        print("Audio system check - Available inputs: \(session.availableInputs?.count ?? 0), Current inputs: \(session.currentRoute.inputs.count)")
        
        if !hasInputs && !hasCurrentInputs {
            errorMessage = "No audio input devices available on this system"
            print("No audio input devices found - pitch detection unavailable")
            return
        }
        
        do {
            // Configure audio session for recording
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            print("Audio session configured successfully")
        } catch {
            errorMessage = "Failed to setup audio session: \(error.localizedDescription)"
            print("Failed to setup audio session: \(error.localizedDescription)")
            return
        }
        #endif
        
        engine = AudioEngine()
        guard let engine = engine else { 
            errorMessage = "Failed to create AudioEngine"
            print("Failed to create AudioEngine")
            return 
        }

        // Try to get the input node first (before starting the engine)
        mic = engine.input
        guard let mic = mic else {
            // Provide more detailed error information
            #if canImport(AVFoundation)
            let session = AVAudioSession.sharedInstance()
            let inputInfo = session.currentRoute.inputs.map { "\($0.portName) (\($0.portType))" }.joined(separator: ", ")
            let availableInfo = session.availableInputs?.map { "\($0.portName) (\($0.portType))" }.joined(separator: ", ") ?? "none"
            
            errorMessage = "AudioKit input node unavailable. Current inputs: \(inputInfo.isEmpty ? "none" : inputInfo). Available: \(availableInfo)"
            print("AudioKit input node unavailable - Current route inputs: \(inputInfo.isEmpty ? "none" : inputInfo)")
            print("Available inputs: \(availableInfo)")
            #else
            errorMessage = "AudioKit input node unavailable (no audio input detected)"
            print("AudioKit input node unavailable - no audio input detected")
            #endif
            
            // Set up a mock/stub mode for environments without audio input
            setupMockMode()
            return
        }
        
        print("Successfully obtained AudioKit input node: \(mic)")

        // Set up the audio graph: Create a proper output chain
        // AudioKit requires an output node connected to the system output
        let silenceOutput = Mixer()
        silenceOutput.volume = 0.0  // Silent mixer so we don't hear any feedback
        
        // Connect the microphone input to our silent output to complete the audio graph
        silenceOutput.addInput(mic)
        print("Connected microphone input to silent output mixer")
        
        engine.output = silenceOutput
        
        // Start the engine with proper audio graph configured
        do {
            try engine.start()
            print("AudioKit engine started successfully")
        } catch {
            errorMessage = "Error starting AudioKit engine: \(error.localizedDescription)"
            print("Error starting AudioKit engine: \(error.localizedDescription)")
            isListening = false
            return
        }

        // Give the engine a moment to fully initialize before setting up pitch detection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.setupPitchTap()
        }
    }
    
    private func setupPitchTap() {
        guard let mic = mic else {
            print("No microphone input available for pitch detection")
            return
        }
        
        // Set up the pitch tracker
        tracker = PitchTap(mic) { (pitch: [Float], amplitude: [Float]) in
            // For debugging: print detected values occasionally (not every frame to reduce spam)
            let now = Date().timeIntervalSince1970
            if Int(now) % 5 == 0 && Int(now * 10) % 10 == 0 { // Print roughly every 5 seconds
                print("PitchTap detected pitches: \(pitch.prefix(3)), amplitudes: \(amplitude.prefix(3))")
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let detectedPitch = Double(pitch.first ?? 0)
                let detectedAmplitude = Double(amplitude.first ?? 0)

                // Apply median filtering and smoothing for stability
                let (filteredFrequency, filteredAmplitude) = self.applyFiltering(frequency: detectedPitch, amplitude: detectedAmplitude)

                if filteredAmplitude > self.config.minimumAmplitudeThreshold {
                    self.currentFrequency = filteredFrequency
                    self.currentAmplitude = filteredAmplitude

                    let (note, octave) = PitchDetector.frequencyToNoteAndOctave(filteredFrequency)
                    self.detectedNoteName = note
                    self.detectedOctave = octave
                } else {
                    self.currentFrequency = 0
                    self.currentAmplitude = 0
                    self.detectedNoteName = "--"
                    self.detectedOctave = 0
                }
            }
        }

        tracker?.start()
        isListening = true
        errorMessage = nil
        print("AudioKit PitchTap started successfully")
        print("Audio graph completed - microphone input connected to silent output")
    }
    
    private func setupMockMode() {
        // For environments without audio input, provide a visual indication but no errors
        print("Setting up mock mode - pitch detection will show placeholder values")
        isListening = false
        errorMessage = "Audio input not available - pitch detection disabled"
        
        // Reset all values to defaults
        currentFrequency = 0
        currentAmplitude = 0
        detectedNoteName = "--"
        detectedOctave = 0
    }

    @MainActor
    func startListening() {
        print("Starting pitch detection...")
        #if canImport(AudioKit) && canImport(AVFoundation)
        if !isListening {
            if microphonePermissionGranted {
                setupAudioKit()
            } else {
                checkPermissionsAndSetup()
            }
        } else {
            print("Already listening for pitch")
        }
        #else
        errorMessage = "AudioKit or AVFoundation is not available on this platform"
        print("AudioKit/AVFoundation not available - platform not supported")
        #endif
    }
    
    @MainActor
    func stopListening() {
        print("Stopping pitch detection (stopListening called)...")
        tracker?.stop()
        stopAudioEngine()
        isListening = false
    }
    
    @MainActor
    func retryAudioSetup() {
        print("Retrying audio setup...")
        stopListening()
        
        // Clear previous error
        errorMessage = nil
        
        // Wait a moment then try again
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startListening()
        }
    }
    
    /// Update frame size for pitch analysis window
    /// Note: This requires restarting the audio engine to take effect
    @MainActor
    func updateAnalysisFrameSize(_ newFrameSize: Int) {
        config.analysisFrameSize = newFrameSize
        
        // Clear filtering history when changing frame size
        clearFilteringHistory()
        
        // Restart audio engine if currently listening to apply new frame size
        if isListening {
            stopListening()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.startListening()
            }
        }
    }
    
    /// Update median filter window size for pitch stability
    @MainActor
    func updateMedianFilterWindowSize(_ newWindowSize: Int) {
        config.medianFilterWindowSize = max(1, newWindowSize) // Ensure minimum of 1
        clearFilteringHistory() // Clear history when changing window size
    }
    
    /// Clear filtering history - useful when changing parameters or restarting
    @MainActor
    func clearFilteringHistory() {
        frequencyHistory.removeAll()
        amplitudeHistory.removeAll()
        smoothedFrequency = 0.0
    }

    private func stopAudioEngine() {
        print("Stopping AudioKit engine...")
        
        // Stop tracker first
        tracker?.stop()
        tracker = nil
        
        // Stop engine
        if let engine = engine {
            do {
                try engine.stop()
                print("AudioKit engine stopped successfully")
            } catch {
                print("Error stopping AudioKit engine: \(error.localizedDescription)")
            }
        }
        
        // Clean up audio session
        #if canImport(AVFoundation)
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("Audio session deactivated successfully")
        } catch {
            print("Error deactivating audio session: \(error.localizedDescription)")
        }
        #endif
        
        // Clear references
        engine = nil
        mic = nil
    }
    
    func frequencyToStaffPosition(_ frequency: Double, clef: Clef = .treble) -> Double {
        guard frequency > 0 else { return 0.0 }
        
        // Use the same musical context as the sheet music for consistency
        let context = MusicContext(keySignature: "D minor", clef: clef, a4Reference: 440.0)
        return StaffPositionMapper.frequencyToStaffPosition(frequency, context: context)
    }
    #else
    // Stub if AudioKit not available
    func startListening() {
        errorMessage = "AudioKit or AVFoundation is not available on this platform"
    }
    
    func stopListening() {
        // Do nothing
    }
    
    func frequencyToStaffPosition(_ frequency: Double, clef: Clef = .treble) -> Double {
        let context = MusicContext(keySignature: "D minor", clef: clef, a4Reference: 440.0)
        return StaffPositionMapper.frequencyToStaffPosition(frequency, context: context)
    }
    #endif

    // MARK: - Helper: Frequency to Note and Staff Position

    static func frequencyToNoteAndOctave(_ frequency: Double) -> (note: String, octave: Int) {
        guard frequency > 0 else { return ("--", 0) }
        let noteFrequencies = [
            "C", "C#", "D", "D#", "E", "F",
            "F#", "G", "G#", "A", "A#", "B"
        ]
        let midi = 69 + 12 * log2(frequency / 440.0)
        let midiNote = Int(round(midi))
        let noteIndex = midiNote % 12
        let octave = midiNote / 12 - 1
        let note = noteFrequencies[(noteIndex + 12) % 12] // ensure non-negative index
        return (note, octave)
    }
}
