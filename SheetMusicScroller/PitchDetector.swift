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
    
    // Computed property for current pitch string
    var currentPitch: String {
        if currentFrequency > 0 && currentAmplitude > minimumAmplitudeThreshold {
            return "\(detectedNoteName)\(detectedOctave)"
        } else {
            return ""
        }
    }

    private let minimumAmplitudeThreshold: Double = 0.05 // Increased to reduce ambient noise sensitivity

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
        do {
            // Configure audio session for recording
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
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

        // Start the engine first to initialize the audio graph
        do {
            try engine.start()
            print("AudioKit engine started successfully")
        } catch {
            errorMessage = "Error starting AudioKit engine: \(error.localizedDescription)"
            print("Error starting AudioKit engine: \(error.localizedDescription)")
            isListening = false
            return
        }

        // Now get the input node after the engine is started
        mic = engine.input
        guard let mic = mic else {
            errorMessage = "Could not get AudioKit input node (engine started but no input available)"
            print("Could not get AudioKit input node (engine started but no input available)")
            return
        }
        
        print("Successfully obtained AudioKit input node")

        tracker = PitchTap(mic) { (pitch: [Float], amplitude: [Float]) in
            // For debugging: print detected values
            print("PitchTap detected pitches: \(pitch), amplitudes: \(amplitude)")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let detectedPitch = Double(pitch.first ?? 0)
                let detectedAmplitude = Double(amplitude.first ?? 0)

                if detectedAmplitude > self.minimumAmplitudeThreshold {
                    self.currentFrequency = detectedPitch
                    self.currentAmplitude = detectedAmplitude

                    let (note, octave) = PitchDetector.frequencyToNoteAndOctave(detectedPitch)
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
    }

    @MainActor
    func startListening() {
        print("Starting pitch detection...")
        #if canImport(AudioKit) && canImport(AVFoundation)
        if !isListening {
            checkPermissionsAndSetup()
        } else {
            print("Already listening for pitch")
        }
        #else
        errorMessage = "AudioKit or AVFoundation is not available on this platform"
        #endif
    }
    
    @MainActor
    func stopListening() {
        print("Stopping pitch detection (stopListening called)...")
        tracker?.stop()
        stopAudioEngine()
        isListening = false
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
    
    func frequencyToStaffPosition(_ frequency: Double) -> Double {
        guard frequency > 0 else { return 0.0 }
        
        // Convert frequency to MIDI note number
        let midi = 69 + 12 * log2(frequency / 440.0)
        
        // Reference: Middle C (C4) is MIDI note 60, which should be at position 0
        // Each staff line/space represents a step (0.5 staff positions)
        let middleC = 60.0
        let staffPosition = (midi - middleC) * 0.5
        
        return staffPosition
    }
    #else
    // Stub if AudioKit not available
    func startListening() {
        errorMessage = "AudioKit or AVFoundation is not available on this platform"
    }
    
    func stopListening() {
        // Do nothing
    }
    
    func frequencyToStaffPosition(_ frequency: Double) -> Double {
        return 0.0
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
