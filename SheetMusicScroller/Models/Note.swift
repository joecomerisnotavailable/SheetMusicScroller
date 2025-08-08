import Foundation

/// Represents note duration values
enum NoteDuration: Double, CaseIterable, Codable {
    case whole = 4.0
    case half = 2.0
    case quarter = 1.0
    case eighth = 0.5
    case sixteenth = 0.25
    case thirtySecond = 0.125
    
    /// Duration in beats (quarter note = 1 beat)
    var beats: Double {
        return self.rawValue
    }
    
    /// Convert to actual time duration given a tempo
    func duration(at tempo: Double) -> Double {
        return (60.0 / tempo) * beats  // tempo is BPM, so 60/tempo gives seconds per beat
    }
}

/// Immutable musical note representation
/// Stores only note name, duration, base Hz reference, and key signature as specified
struct Note: Identifiable, Codable {
    let id = UUID()
    let noteName: String        // e.g., "C4", "F#5", "Bb3"
    let noteValue: NoteDuration // Duration type (quarter, eighth, etc.)
    let a4Reference: Double     // Base Hz reference for A4 (typically 440.0)
    let keySignature: String    // Key signature context for this note
    
    init(noteName: String, noteValue: NoteDuration, a4Reference: Double = 440.0, keySignature: String = "C major") {
        self.noteName = noteName
        self.noteValue = noteValue
        self.a4Reference = a4Reference
        self.keySignature = keySignature
    }
    
    /// Calculate the frequency of this note in Hz
    var frequency: Double {
        let midiNote = StaffPositionMapper.noteNameToMidiNote(noteName)
        // Formula: f = 440 * 2^((n-69)/12) where n is MIDI note number
        return a4Reference * pow(2.0, Double(midiNote - 69) / 12.0)
    }
    
    /// Get the MIDI note number for this note
    var midiNote: Int {
        return StaffPositionMapper.noteNameToMidiNote(noteName)
    }
}

// Extension for easier note creation with common durations
extension Note {
    static func whole(_ noteName: String, a4Reference: Double = 440.0, keySignature: String = "C major") -> Note {
        return Note(noteName: noteName, noteValue: .whole, a4Reference: a4Reference, keySignature: keySignature)
    }
    
    static func half(_ noteName: String, a4Reference: Double = 440.0, keySignature: String = "C major") -> Note {
        return Note(noteName: noteName, noteValue: .half, a4Reference: a4Reference, keySignature: keySignature)
    }
    
    static func quarter(_ noteName: String, a4Reference: Double = 440.0, keySignature: String = "C major") -> Note {
        return Note(noteName: noteName, noteValue: .quarter, a4Reference: a4Reference, keySignature: keySignature)
    }
    
    static func eighth(_ noteName: String, a4Reference: Double = 440.0, keySignature: String = "C major") -> Note {
        return Note(noteName: noteName, noteValue: .eighth, a4Reference: a4Reference, keySignature: keySignature)
    }
    
    static func sixteenth(_ noteName: String, a4Reference: Double = 440.0, keySignature: String = "C major") -> Note {
        return Note(noteName: noteName, noteValue: .sixteenth, a4Reference: a4Reference, keySignature: keySignature)
    }
    
    static func thirtySecond(_ noteName: String, a4Reference: Double = 440.0, keySignature: String = "C major") -> Note {
        return Note(noteName: noteName, noteValue: .thirtySecond, a4Reference: a4Reference, keySignature: keySignature)
    }
}

// MARK: - Semantic engraving helpers
extension NoteDuration {
    /// Eighth and shorter have stems in standard engraving
    var hasStem: Bool {
        return beats <= 0.5
    }
    
    /// Number of beams for beamed notes
    var beamCount: Int {
        if beats <= 0.125 {
            return 3  // 32nd
        } else if beats <= 0.25 {
            return 2  // 16th
        } else if beats <= 0.5 {
            return 1  // 8th
        } else {
            return 0
        }
    }
}