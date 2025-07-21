//
//  PitchDetector.swift
//  SheetMusicScroller
//
//  Created by Joe Comer on 2/22/24.
//

import Foundation

#if canImport(AudioKit)
import AudioKit
import AudioKitEX
import SoundpipeAudioKit
#endif

import AVFoundation

final class PitchDetector: ObservableObject {
    // Published properties for UI updates
    @Published var currentFrequency: Double = 0.0
    @Published var currentAmplitude: Double = 0.0
    @Published var isListening: Bool = false

    // For debugging: show detected note name, etc.
    @Published var detectedNoteName: String = "--"
    @Published var detectedOctave: Int = 0

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
        #if canImport(AudioKit)
        checkPermissionsAndSetup()
        #else
        print("AudioKit is not available on this platform. Pitch detection will not work.")
        #endif
    }

    deinit {
        // Only cleanup non-main-actor, thread-safe resources here
        permissionTimer?.invalidate()
        // Do NOT call @MainActor methods from deinit
        #if canImport(AudioKit)
        stopAudioEngine()
        #endif
    }

    // MARK: - AudioKit Setup and Permission

    #if canImport(AudioKit)
    private func checkPermissionsAndSetup() {
        switch AVAudioApplication.sharedInstance().recordPermission {
        case .granted:
            setupAudioKit()
        case .denied:
            print("Microphone access denied")
        case .undetermined:
            AVAudioApplication.sharedInstance().requestRecordPermission { [weak self] granted in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if granted {
                        self.setupAudioKit()
                    } else {
                        print("Microphone access denied")
                    }
                }
            }
        @unknown default:
            print("Unknown record permission state")
        }
    }

    private func setupAudioKit() {
        engine = AudioEngine()
        guard let engine = engine else { return }

        mic = engine.input
        guard let mic = mic else {
            print("Could not get AudioKit input node.")
            return
        }

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

        tracker?.isNormalized = false
        tracker?.start()

        do {
            try engine.start()
            isListening = true
            print("AudioKit engine started")
        } catch {
            print("Error starting AudioKit engine: \(error.localizedDescription)")
            isListening = false
        }
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
        tracker?.stop()
        do {
            try engine?.stop()
        } catch {
            print("Error stopping AudioKit engine: \(error.localizedDescription)")
        }
        engine = nil
        mic = nil
        tracker = nil
    }
    #else
    // Stub if AudioKit not available
    func stopListening() {
        // Do nothing
    }
    #endif

    // MARK: - Helper: Frequency to Note

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
