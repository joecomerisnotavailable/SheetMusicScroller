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

#if canImport(UIKit)
import UIKit
#endif

/// Configuration for pitch detection parameters
struct PitchDetectionConfig {
    /// Window size for median filtering (number of samples to keep for smoothing) - DISABLED by default
    var medianFilterWindowSize: Int = 1  // Set to 1 to effectively disable
    /// Frame size for analysis window (AudioKit buffer size) - Optimized for realtime response
    var analysisFrameSize: Int = 512  // Fast analysis window (~11.6ms at 44.1kHz)
    /// Hop size for overlapping analysis windows (samples to advance between analyses)
    var hopSize: Int = 64  // 87.5% overlap for 8x more frequent analysis (~1.45ms between analyses)
    /// Minimum amplitude threshold for valid pitch detection
    var minimumAmplitudeThreshold: Double = 0.005  // Lowered for moderate volume detection
    /// Whether to enable median filtering for pitch stability - DISABLED for raw response
    var enableMedianFiltering: Bool = false
    /// Whether to enable frequency smoothing - DISABLED for raw response
    var enableFrequencySmoothing: Bool = false
    /// Smoothing factor for frequency values (0.0 = no smoothing, 1.0 = maximum smoothing) - DISABLED
    var frequencySmoothingFactor: Double = 0.0
    /// Whether to use optimized YIN algorithm instead of AudioKit's default PitchTap
    var useYIN: Bool = true
    /// YIN threshold for pitch detection quality (lower = more sensitive, higher = more selective)
    var yinThreshold: Double = 0.05  // Lowered from 0.1 for better sensitivity
    /// Maximum search range for YIN (supports cello C string to highest piano note)
    var yinMaxPeriod: Int = 674  // Supports down to ~65.4 Hz (cello C string)
    /// Skip factor for initial YIN computation (disabled for accuracy)
    var yinDecimationFactor: Int = 1  // No decimation for stable detection
    /// Confidence threshold for accepting detected pitch
    var confidenceThreshold: Double = 0.2  // Lower threshold with hysteresis
    /// Hysteresis: once pitch is detected, use lower threshold to maintain it
    var confidenceHysteresisThreshold: Double = 0.15  // Prevents rapid on/off oscillation
    /// Minimum and maximum frequency range (cello C string to highest piano key)
    var minFrequency: Double = 65.0   // Cello C string (~65.4 Hz)
    var maxFrequency: Double = 4200.0 // Highest piano note (~4186 Hz)
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
    
    // Computed property for device maximum refresh rate (for debugging)
    var deviceMaximumRefreshRate: Int {
        return deviceMaxRefreshRate
    }

    // AudioKit variables
    #if canImport(AudioKit)
    private var engine: AudioEngine?
    private var mic: AudioEngine.InputNode?
    private var tracker: PitchTap?
    private var audioTapInstalled: Bool = false
    #endif

    // Performance optimization: reusable buffers to avoid allocations
    private var yinDifferenceBuffer: [Double] = []
    private var yinCumulativeBuffer: [Double] = []
    private var audioProcessingQueue = DispatchQueue(label: "PitchDetection", qos: .userInteractive)
    
    // Overlapping window analysis for higher frequency updates
    private var audioRingBuffer: [Float] = []
    private var ringBufferIndex: Int = 0
    private var isRingBufferFilled: Bool = false
    
    // Device capability info for debugging/monitoring only
    private let deviceMaxRefreshRate: Int
    
    // Hysteresis state for stable pitch detection (minimal frames for responsiveness)
    private var isPitchCurrentlyDetected: Bool = false
    private var lastValidFrequency: Double = 0.0
    private var consecutiveValidFrames: Int = 0
    private var consecutiveInvalidFrames: Int = 0
    private let requiredConsecutiveFrames: Int = 1  // Immediate response - no delay

    // Timer for permission check
    private var permissionTimer: Timer?
    
    // Performance monitoring for adaptive optimization
    private var uiUpdateCount: Int = 0
    private var lastPerformanceLog: TimeInterval = 0
    
    // UI update throttling for optimal performance
    private var lastUIUpdate: TimeInterval = 0
    private var lastUpdateFrequency: Double = 0
    private var lastUpdateAmplitude: Double = 0
    private var lastUpdateNote: String = "--"
    private let minUIUpdateInterval: TimeInterval = 1.0/60.0  // Maximum 60 FPS UI updates

    init() {
        // Detect device capabilities for monitoring purposes only
        #if canImport(UIKit)
        self.deviceMaxRefreshRate = UIScreen.main.maximumFramesPerSecond
        #else
        self.deviceMaxRefreshRate = 60  // Default for non-iOS platforms
        #endif
        
        print("PitchDetector initialized for realtime response - Device max refresh: \(deviceMaxRefreshRate) FPS")
        
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

    // MARK: - YIN Pitch Detection Algorithm
    
    /// Optimized YIN pitch detection algorithm implementation with overlapping analysis
    /// Based on "YIN, a fundamental frequency estimator for speech and music" by de Cheveigné & Kawahara (2002)
    /// This provides higher fidelity pitch detection optimized for musical instrument stability
    private func yinPitchDetection(audioBuffer: [Float], sampleRate: Double) -> (frequency: Double, confidence: Double) {
        let bufferSize = audioBuffer.count
        let maxPeriod = min(config.yinMaxPeriod, bufferSize / 2)
        
        // Ensure buffers are properly sized to avoid reallocations
        if yinDifferenceBuffer.count != maxPeriod {
            yinDifferenceBuffer = Array(repeating: 0.0, count: maxPeriod)
            yinCumulativeBuffer = Array(repeating: 0.0, count: maxPeriod)
        }
        
        // Step 1: Difference function calculation (optimized with early termination)
        let searchEnd = min(maxPeriod, bufferSize / 2)
        
        for tau in 0..<searchEnd {
            var sum = 0.0
            let maxJ = min(searchEnd, bufferSize - tau)
            
            // Optimized calculation with stride for better performance on larger buffers
            let stride = max(1, maxJ / 512)  // Adaptive stride for performance
            for j in Swift.stride(from: 0, to: maxJ, by: stride) {
                let diff = Double(audioBuffer[j]) - Double(audioBuffer[j + tau])
                sum += diff * diff
            }
            
            // Normalize by actual number of samples used
            if stride > 1 {
                sum *= Double(stride)
            }
            
            yinDifferenceBuffer[tau] = sum
        }
        
        // Step 2: Cumulative mean normalized difference function
        yinCumulativeBuffer[0] = 1.0
        var runningSum = 0.0
        
        for tau in 1..<searchEnd {
            runningSum += yinDifferenceBuffer[tau]
            let meanValue = runningSum / Double(tau)
            yinCumulativeBuffer[tau] = meanValue > 0 ? yinDifferenceBuffer[tau] / meanValue : 1.0
        }
        
        // Step 3: Find period with absolute threshold (early termination)
        let threshold = config.yinThreshold
        var pitchPeriod = 0
        
        // Calculate minimum period based on maximum frequency
        let minPeriod = max(2, Int(sampleRate / config.maxFrequency))  // Highest piano note limit
        // Calculate maximum period based on minimum frequency  
        let maxSearchPeriod = min(searchEnd, Int(sampleRate / config.minFrequency)) // Cello C string limit
        
        for tau in minPeriod..<maxSearchPeriod {
            if yinCumulativeBuffer[tau] < threshold {
                // Found candidate - look for local minimum in smaller window for speed
                var bestTau = tau
                var bestValue = yinCumulativeBuffer[tau]
                let windowEnd = min(tau + 10, maxSearchPeriod)  // Smaller window for faster processing
                
                for checkTau in tau..<windowEnd {
                    if yinCumulativeBuffer[checkTau] < bestValue {
                        bestValue = yinCumulativeBuffer[checkTau]
                        bestTau = checkTau
                    }
                }
                pitchPeriod = bestTau
                break
            }
        }
        
        // If no pitch found with threshold, find global minimum within frequency range
        if pitchPeriod == 0 {
            var minValue = yinCumulativeBuffer[minPeriod]
            pitchPeriod = minPeriod
            
            for tau in (minPeriod + 1)..<maxSearchPeriod {
                if yinCumulativeBuffer[tau] < minValue {
                    minValue = yinCumulativeBuffer[tau]
                    pitchPeriod = tau
                }
            }
        }
        
        // Step 4: Parabolic interpolation for sub-sample precision
        let betterPeriod: Double
        if pitchPeriod > minPeriod && pitchPeriod < maxSearchPeriod - 1 {
            let s0 = yinCumulativeBuffer[pitchPeriod - 1]
            let s1 = yinCumulativeBuffer[pitchPeriod]
            let s2 = yinCumulativeBuffer[pitchPeriod + 1]
            
            let a = (s0 - 2 * s1 + s2) / 2
            let b = (s2 - s0) / 2
            
            if abs(a) > 1e-6 {
                let betterTau = -b / (2 * a)
                betterPeriod = Double(pitchPeriod) + betterTau
            } else {
                betterPeriod = Double(pitchPeriod)
            }
        } else {
            betterPeriod = Double(pitchPeriod)
        }
        
        // Calculate frequency and confidence
        let frequency = betterPeriod > 0 ? sampleRate / betterPeriod : 0.0
        let confidence = pitchPeriod > 0 && pitchPeriod < maxSearchPeriod ? 1.0 - yinCumulativeBuffer[pitchPeriod] : 0.0
        
        return (frequency, confidence)
    }
    
    /// Process overlapping audio windows for higher frequency analysis
    /// This allows more frequent pitch detection without changing the window size
    private func processOverlappingWindows(newAudioData: [Float], sampleRate: Double) {
        let frameSize = config.analysisFrameSize
        let hopSize = config.hopSize
        
        // Initialize ring buffer if needed
        if audioRingBuffer.count != frameSize {
            audioRingBuffer = Array(repeating: 0.0, count: frameSize)
            ringBufferIndex = 0
            isRingBufferFilled = false
        }
        
        // Add new audio data to ring buffer
        for sample in newAudioData {
            audioRingBuffer[ringBufferIndex] = sample
            ringBufferIndex = (ringBufferIndex + 1) % frameSize
            
            if ringBufferIndex == 0 {
                isRingBufferFilled = true
            }
        }
        
        // Only process if we have enough data
        guard isRingBufferFilled else { return }
        
        // Process analysis every hop_size samples
        let samplesProcessed = newAudioData.count
        let analysisCount = max(1, samplesProcessed / hopSize)
        
        for i in 0..<analysisCount {
            // Create analysis window starting at different positions
            var analysisWindow = Array<Float>(repeating: 0.0, count: frameSize)
            let startIndex = (ringBufferIndex - frameSize + (i * hopSize) + frameSize) % frameSize
            
            // Copy data from ring buffer to analysis window (handle wrap-around)
            for j in 0..<frameSize {
                let bufferIndex = (startIndex + j) % frameSize
                analysisWindow[j] = audioRingBuffer[bufferIndex]
            }
            
            // Perform YIN analysis on this window
            let (frequency, confidence) = yinPitchDetection(audioBuffer: analysisWindow, sampleRate: sampleRate)
            let amplitude = calculateRMSAmplitude(audioBuffer: analysisWindow)
            
            // Process results with hysteresis (on audio thread for minimal latency)
            processAnalysisResults(frequency: frequency, confidence: confidence, amplitude: amplitude)
        }
    }
    
    /// Process analysis results with hysteresis and update UI (optimized for performance)
    private func processAnalysisResults(frequency: Double, confidence: Double, amplitude: Double) {
        // Apply hysteresis for stable pitch detection
        let (shouldDetectPitch, finalFrequency) = applyHysteresis(
            frequency: frequency, 
            confidence: confidence, 
            amplitude: amplitude
        )
        
        // Check if we should update UI - throttle updates AND only update on meaningful changes
        let now = CFAbsoluteTimeGetCurrent()
        let timeSinceLastUpdate = now - lastUIUpdate
        
        // Determine if there's a meaningful change worth updating the UI for
        let (note, octave) = shouldDetectPitch ? PitchDetector.frequencyToNoteAndOctave(finalFrequency) : ("--", 0)
        let noteString = shouldDetectPitch ? "\(note)\(octave)" : "--"
        
        let frequencyChanged = abs(finalFrequency - lastUpdateFrequency) > 1.0  // 1 Hz threshold
        let amplitudeChanged = abs(amplitude - lastUpdateAmplitude) > 0.001     // Small amplitude threshold
        let noteChanged = noteString != lastUpdateNote
        let hasSignificantChange = frequencyChanged || amplitudeChanged || noteChanged
        
        // Only update UI if enough time has passed AND there's a meaningful change
        let shouldUpdateUI = timeSinceLastUpdate >= minUIUpdateInterval && hasSignificantChange
        
        if shouldUpdateUI {
            lastUIUpdate = now
            lastUpdateFrequency = finalFrequency
            lastUpdateAmplitude = amplitude
            lastUpdateNote = noteString
            
            // Update UI on main thread with batched changes
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                if shouldDetectPitch {
                    self.currentFrequency = finalFrequency
                    self.currentAmplitude = amplitude
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
        
        // Performance monitoring (much less frequent to avoid overhead)
        uiUpdateCount += 1
        if now - lastPerformanceLog >= 10.0 { // Log every 10 seconds
            let actualRefreshRate = Double(uiUpdateCount) / (now - lastPerformanceLog)
            print("PitchDetector Performance - Analysis: \(String(format: "%.0f", actualRefreshRate)) Hz, UI Updates: \(String(format: "%.1f", 1.0/minUIUpdateInterval)) FPS max")
            uiUpdateCount = 0
            lastPerformanceLog = now
        }
        
        // For debugging: print detected values occasionally
        if Int(now) % 5 == 0 && Int(now * 10) % 10 == 0 { // Print roughly every 5 seconds
            print("YIN detected frequency: \(String(format: "%.1f", frequency))Hz, confidence: \(String(format: "%.3f", confidence)), amplitude: \(String(format: "%.3f", amplitude))")
        }
    }
    /// Calculate RMS amplitude for the audio buffer - optimized version
    private func calculateRMSAmplitude(audioBuffer: [Float]) -> Double {
        guard !audioBuffer.isEmpty else { return 0.0 }
        
        // Use stride for faster computation on large buffers
        let stepSize = max(1, audioBuffer.count / 64)  // Sample every nth element for speed
        var sum: Double = 0.0
        var count = 0
        
        for i in stride(from: 0, to: audioBuffer.count, by: stepSize) {
            let sample = Double(audioBuffer[i])
            sum += sample * sample
            count += 1
        }
        
        return count > 0 ? sqrt(sum / Double(count)) : 0.0
    }

    /// Apply hysteresis to prevent pitch detection oscillation
    /// Uses different thresholds for detecting vs. losing pitch to create stability
    private func applyHysteresis(frequency: Double, confidence: Double, amplitude: Double) -> (shouldDetectPitch: Bool, finalFrequency: Double) {
        let isAmplitudeValid = amplitude > config.minimumAmplitudeThreshold
        let isFrequencyInRange = frequency >= config.minFrequency && frequency <= config.maxFrequency
        
        // Determine confidence threshold based on current state (hysteresis)
        let currentThreshold = isPitchCurrentlyDetected ? 
            config.confidenceHysteresisThreshold : config.confidenceThreshold
        
        let isConfidenceValid = confidence > currentThreshold
        let isCurrentFrameValid = isAmplitudeValid && isFrequencyInRange && isConfidenceValid
        
        if isCurrentFrameValid {
            consecutiveValidFrames += 1
            consecutiveInvalidFrames = 0
            
            // If we have enough consecutive valid frames, or we're already detecting
            if consecutiveValidFrames >= requiredConsecutiveFrames || isPitchCurrentlyDetected {
                if !isPitchCurrentlyDetected {
                    print("🎵 Pitch detection started: \(String(format: "%.1f", frequency))Hz")
                }
                isPitchCurrentlyDetected = true
                lastValidFrequency = frequency
                return (true, frequency)
            }
        } else {
            consecutiveInvalidFrames += 1
            consecutiveValidFrames = 0
            
            // If we have enough consecutive invalid frames, stop detecting
            if consecutiveInvalidFrames >= requiredConsecutiveFrames {
                if isPitchCurrentlyDetected {
                    print("🔇 Pitch detection stopped")
                }
                isPitchCurrentlyDetected = false
                lastValidFrequency = 0.0
                return (false, 0.0)
            }
        }
        
        // If we're in a transition state, maintain current state
        if isPitchCurrentlyDetected {
            return (true, lastValidFrequency)  // Hold last known good frequency
        } else {
            return (false, 0.0)
        }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.setupPitchTap()
        }
    }
    
    private func setupPitchTap() {
        guard let mic = mic else {
            print("No microphone input available for pitch detection")
            return
        }
        
        // Clean up any existing pitch detection setup first
        cleanupExistingPitchDetection()
        
        if config.useYIN {
            // Use custom audio tap with YIN algorithm
            setupYINAudioTap(mic)
        } else {
            // Use AudioKit's default PitchTap
            setupAudioKitPitchTap(mic)
        }
    }
    
    private func cleanupExistingPitchDetection() {
        // Stop and clean up existing tracker
        if let tracker = tracker {
            tracker.stop()
            self.tracker = nil
            print("Stopped existing AudioKit PitchTap")
        }
        
        // Remove existing audio tap if installed
        if audioTapInstalled, let mic = mic {
            do {
                mic.avAudioNode.removeTap(onBus: 0)
                audioTapInstalled = false
                print("Removed existing custom audio tap")
            } catch {
                print("Warning: Error removing audio tap: \(error.localizedDescription)")
                // Still mark as not installed since we tried to remove it
                audioTapInstalled = false
            }
        }
    }
    
    private func setupAudioKitPitchTap(_ mic: AudioEngine.InputNode) {
        // Set up the pitch tracker using AudioKit's PitchTap
        tracker = PitchTap(mic) { (pitch: [Float], amplitude: [Float]) in
            // Process immediately on audio callback thread for minimal latency
            let detectedPitch = Double(pitch.first ?? 0)
            let detectedAmplitude = Double(amplitude.first ?? 0)

            // Apply validation and hysteresis on audio thread for speed
            let isAmplitudeValid = detectedAmplitude > self.config.minimumAmplitudeThreshold
            let isFrequencyInRange = detectedPitch >= self.config.minFrequency && detectedPitch <= self.config.maxFrequency
            
            // Check if we should update UI - throttle updates AND only update on meaningful changes
            let now = CFAbsoluteTimeGetCurrent()
            let timeSinceLastUpdate = now - self.lastUIUpdate
            
            // Determine if there's a meaningful change worth updating the UI for
            let shouldDetectPitch = isAmplitudeValid && isFrequencyInRange && detectedPitch > 0
            let (note, octave) = shouldDetectPitch ? PitchDetector.frequencyToNoteAndOctave(detectedPitch) : ("--", 0)
            let noteString = shouldDetectPitch ? "\(note)\(octave)" : "--"
            
            let frequencyChanged = abs(detectedPitch - self.lastUpdateFrequency) > 1.0  // 1 Hz threshold
            let amplitudeChanged = abs(detectedAmplitude - self.lastUpdateAmplitude) > 0.001     // Small amplitude threshold
            let noteChanged = noteString != self.lastUpdateNote
            let hasSignificantChange = frequencyChanged || amplitudeChanged || noteChanged
            
            // Only update UI if enough time has passed AND there's a meaningful change
            let shouldUpdateUI = timeSinceLastUpdate >= self.minUIUpdateInterval && hasSignificantChange
            
            if shouldUpdateUI {
                self.lastUIUpdate = now
                self.lastUpdateFrequency = detectedPitch
                self.lastUpdateAmplitude = detectedAmplitude
                self.lastUpdateNote = noteString
                
                // Update UI on main thread with batched changes
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    if shouldDetectPitch {
                        self.currentFrequency = detectedPitch
                        self.currentAmplitude = detectedAmplitude
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
            
            // Performance monitoring (less frequent)
            self.uiUpdateCount += 1
            if now - self.lastPerformanceLog >= 10.0 { // Log every 10 seconds
                let actualRefreshRate = Double(self.uiUpdateCount) / (now - self.lastPerformanceLog)
                print("AudioKit PitchTap Performance - Analysis: \(String(format: "%.0f", actualRefreshRate)) Hz, UI Updates: \(String(format: "%.1f", 1.0/self.minUIUpdateInterval)) FPS max")
                self.uiUpdateCount = 0
                self.lastPerformanceLog = now
            }
            
            // For debugging: print detected values occasionally (not every frame to reduce spam)
            if Int(now) % 5 == 0 && Int(now * 10) % 10 == 0 { // Print roughly every 5 seconds
                print("PitchTap detected pitch: \(String(format: "%.1f", detectedPitch))Hz, amplitude: \(String(format: "%.3f", detectedAmplitude))")
            }
        }

        tracker?.start()
        isListening = true
        errorMessage = nil
        print("AudioKit PitchTap started successfully with intelligent UI updates")
        print("Audio graph completed - microphone input connected to silent output")
    }
    
    private func setupYINAudioTap(_ mic: AudioEngine.InputNode) {
        // Create a custom audio tap for YIN processing with overlapping analysis
        let bufferSize = config.analysisFrameSize
        let sampleRate = 44100.0  // Standard sample rate
        
        // Try to access the underlying AVAudioNode for installing a tap
        // AudioKit's InputNode should have an underlying AVAudioNode
        let avAudioNode = mic.avAudioNode
        
        // Remove any existing tap first to prevent conflicts
        if audioTapInstalled {
            avAudioNode.removeTap(onBus: 0)
            audioTapInstalled = false
            print("Removed existing audio tap before installing new one")
        }
        
        // Install tap on the microphone input to get raw audio data
        // Use smallest possible buffer size for minimal latency
        let tapBufferSize = AVAudioFrameCount(64)  // Minimal buffer for ~1.45ms latency at 44.1kHz
        
        do {
            avAudioNode.installTap(onBus: 0, bufferSize: tapBufferSize, format: nil) { [weak self] (buffer: AVAudioPCMBuffer, time: AVAudioTime) in
                guard let self = self else { return }
                
                // Convert AVAudioPCMBuffer to Float array
                guard let channelData = buffer.floatChannelData?[0] else { return }
                let frameLength = Int(buffer.frameLength)
                let audioBuffer = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
                
                // Process overlapping windows for high-frequency analysis (on audio thread for minimal latency)
                self.processOverlappingWindows(newAudioData: audioBuffer, sampleRate: sampleRate)
            }
            
            audioTapInstalled = true
            isListening = true
            errorMessage = nil
            print("YIN pitch detection started successfully with ultra-low latency")
            print("Audio graph completed - microphone input connected to silent output")
            print("Tap buffer size: \(tapBufferSize) samples (~\(String(format: "%.1f", Double(tapBufferSize) / sampleRate * 1000))ms latency)")
            print("Analysis frequency: ~\(Int(sampleRate / Double(config.hopSize))) Hz (every ~\(String(format: "%.1f", Double(config.hopSize) / sampleRate * 1000))ms)")
            
        } catch {
            errorMessage = "Failed to install audio tap for YIN processing: \(error.localizedDescription)"
            print("Error installing audio tap: \(error.localizedDescription)")
            isListening = false
            return
        }
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
        
        // Reset hysteresis state
        isPitchCurrentlyDetected = false
        lastValidFrequency = 0.0
        consecutiveValidFrames = 0
        consecutiveInvalidFrames = 0
        
        // Reset overlapping analysis state
        audioRingBuffer.removeAll()
        ringBufferIndex = 0
        isRingBufferFilled = false
        
        // Reset performance monitoring and UI throttling
        uiUpdateCount = 0
        lastPerformanceLog = CFAbsoluteTimeGetCurrent()
        lastUIUpdate = 0
        lastUpdateFrequency = 0
        lastUpdateAmplitude = 0
        lastUpdateNote = "--"
    }

    private func stopAudioEngine() {
        print("Stopping AudioKit engine...")
        
        // Clean up pitch detection first
        cleanupExistingPitchDetection()
        
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
