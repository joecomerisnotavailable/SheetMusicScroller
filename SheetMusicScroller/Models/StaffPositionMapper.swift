import Foundation

/// Represents a staff line with positioning logic
struct StaffLine {
    let position: Double  // Staff position using same system as notes
    let clef: Clef
    
    /// Creates staff lines for a given clef
    static func createStaffLines(for clef: Clef) -> [StaffLine] {
        // Staff lines are always at positions: -4, -2, 0, 2, 4 (relative to middle line)
        return [
            StaffLine(position: -4.0, clef: clef),  // Top line (F5 in treble clef)
            StaffLine(position: -2.0, clef: clef),  // Fourth line (D5 in treble clef)
            StaffLine(position: 0.0, clef: clef),   // Middle line (B4 in treble clef)
            StaffLine(position: 2.0, clef: clef),   // Second line (G4 in treble clef)
            StaffLine(position: 4.0, clef: clef)    // Bottom line (E4 in treble clef)
        ]
    }
    
    /// Get the note name for this staff line position
    var noteName: String {
        let middleLineMidi = clef.middleLineMidiNote
        let midiNote = middleLineMidi - Int(position * (12.0 / 7.0) * 2.0)
        return StaffPositionMapper.midiNoteToNoteName(midiNote)
    }
}

/// Represents a key signature accidental with built-in positioning
struct KeySignatureAccidental {
    let accidentalType: AccidentalType
    let position: Double  // Staff position
    let clef: Clef
    
    enum AccidentalType {
        case sharp
        case flat
    }
    
    /// Creates key signature accidentals for D minor
    static func createDMinorAccidentals(for clef: Clef) -> [KeySignatureAccidental] {
        // D minor has one flat: Bb
        switch clef {
        case .treble:
            // Bb is on the B line (third line from bottom, position -1.0)
            return [KeySignatureAccidental(accidentalType: .flat, position: -1.0, clef: clef)]
        case .bass:
            // Bb is on the second line from top in bass clef
            return [KeySignatureAccidental(accidentalType: .flat, position: -2.0, clef: clef)]
        case .alto:
            // Bb is on the top line in alto clef
            return [KeySignatureAccidental(accidentalType: .flat, position: -4.0, clef: clef)]
        case .tenor:
            // Bb is on the second line from top in tenor clef
            return [KeySignatureAccidental(accidentalType: .flat, position: -2.0, clef: clef)]
        }
    }
    
    var symbol: String {
        switch accidentalType {
        case .sharp: return "♯"
        case .flat: return "♭"
        }
    }
}

/// Represents different types of musical clefs
enum Clef: String, CaseIterable, Codable {
    case treble = "treble"
    case bass = "bass"
    case alto = "alto"      // C clef on middle line
    case tenor = "tenor"    // C clef on fourth line
    
    /// The MIDI note number that appears on the middle line of the staff for this clef
    var middleLineMidiNote: Int {
        switch self {
        case .treble: return 71  // B4
        case .bass: return 50    // D3  
        case .alto: return 60    // C4 (middle C)
        case .tenor: return 57   // A3
        }
    }
}

/// Context for musical staff rendering and note positioning
struct MusicContext: Codable {
    let keySignature: String    // e.g., "C major", "D minor", "F# major"
    let clef: Clef
    let tempo: Double          // BPM
    let a4Reference: Double    // Reference frequency for A4 (default 440 Hz)
    
    init(keySignature: String, clef: Clef = .treble, tempo: Double = 120, a4Reference: Double = 440.0) {
        self.keySignature = keySignature
        self.clef = clef
        self.tempo = tempo
        self.a4Reference = a4Reference
    }
}

/// Universal utility for mapping frequencies and note names to staff positions
class StaffPositionMapper {
    
    /// Maps a frequency to a staff position for a given musical context
    /// - Parameters:
    ///   - frequency: The frequency in Hz
    ///   - context: The musical context (clef, key signature, etc.)
    /// - Returns: Staff position where 0 = middle line, negative = above, positive = below
    static func frequencyToStaffPosition(_ frequency: Double, context: MusicContext) -> Double {
        guard frequency > 0 else { return 0.0 }
        
        // Convert frequency to MIDI note number using the A4 reference
        let midiNote = 69 + 12 * log2(frequency / context.a4Reference)
        
        return midiNoteToStaffPosition(midiNote, clef: context.clef)
    }
    
    /// Maps a note name to a staff position for a given musical context
    /// - Parameters:
    ///   - noteName: Note name like "C4", "Bb5", "F#3"
    ///   - context: The musical context (clef, key signature, etc.)
    /// - Returns: Staff position where 0 = middle line, negative = above, positive = below
    static func noteNameToStaffPosition(_ noteName: String, context: MusicContext) -> Double {
        let midiNote = noteNameToMidiNote(noteName)
        return midiNoteToStaffPosition(Double(midiNote), clef: context.clef)
    }
    
    /// Converts a MIDI note number to staff position for a given clef
    /// - Parameters:
    ///   - midiNote: MIDI note number (60 = C4)
    ///   - clef: The clef type
    /// - Returns: Staff position where 0 = middle line, negative = above, positive = below
    static func midiNoteToStaffPosition(_ midiNote: Double, clef: Clef) -> Double {
        let intMidiNote = Int(round(midiNote))
        
        switch clef {
        case .treble:
            // In treble clef, correct staff line positions are:
            // F5 (77) = top line (position -4.0)
            // D5 (74) = fourth line (position -2.0)  
            // B4 (71) = middle line (position 0.0)
            // G4 (67) = second line (position 2.0)
            // E4 (64) = bottom line (position 4.0)
            switch intMidiNote {
            case 77: return -4.0  // F5 - top line
            case 76: return -3.0  // E5 - space between D5 and F5
            case 74: return -2.0  // D5 - fourth line
            case 72: return -1.0  // C5 - space between B4 and D5
            case 71: return 0.0   // B4 - middle line
            case 70: return 0.0   // Bb4 - middle line (same as B4)
            case 69: return 1.0   // A4 - space between G4 and B4
            case 67: return 2.0   // G4 - second line from bottom
            case 65: return 3.0   // F4 - space between E4 and G4
            case 64: return 4.0   // E4 - bottom line
            case 62: return 5.0   // D4 - space below bottom line
            case 61: return 6.0   // C#4 - first ledger line below staff
            case 60: return 6.0   // C4 - first ledger line below staff
            default:
                // For other notes, calculate relative to B4 (71) on middle line
                let semitoneDiff = intMidiNote - 71
                // Convert semitones to staff positions (7 semitones = 4 staff positions)
                return Double(-semitoneDiff) * (4.0 / 7.0)
            }
            
        case .bass:
            // In bass clef, D3 (50) is on the middle line
            let referenceMidi = 50 // D3 on middle line
            let semitoneDiff = intMidiNote - referenceMidi
            return Double(-semitoneDiff) * (7.0 / 12.0)
            
        case .alto:
            // In alto clef, C4 (60) is on the middle line
            let referenceMidi = 60 // C4 on middle line
            let semitoneDiff = intMidiNote - referenceMidi
            return Double(-semitoneDiff) * (7.0 / 12.0)
            
        case .tenor:
            // In tenor clef, A3 (57) is on the middle line
            let referenceMidi = 57 // A3 on middle line
            let semitoneDiff = intMidiNote - referenceMidi
            return Double(-semitoneDiff) * (7.0 / 12.0)
        }
    }
    
    /// Converts a note name like "C4", "Bb5", "F#3" to MIDI note number
    /// - Parameter noteName: The note name string
    /// - Returns: MIDI note number
    static func noteNameToMidiNote(_ noteName: String) -> Int {
        guard noteName.count >= 2 else { return 60 } // Default to C4
        
        let noteString = String(noteName.dropLast())
        let octaveString = String(noteName.suffix(1))
        
        guard let octave = Int(octaveString) else { return 60 }
        
        // Note name to chromatic index mapping
        let noteMap: [String: Int] = [
            "C": 0, "C#": 1, "Db": 1,
            "D": 2, "D#": 3, "Eb": 3,
            "E": 4,
            "F": 5, "F#": 6, "Gb": 6,
            "G": 7, "G#": 8, "Ab": 8,
            "A": 9, "A#": 10, "Bb": 10,
            "B": 11
        ]
        
        guard let noteIndex = noteMap[noteString] else { return 60 }
        
        // MIDI note number = (octave + 1) * 12 + noteIndex
        // C4 = 60, so C4 is octave 4, which gives us (4 + 1) * 12 + 0 = 60
        return (octave + 1) * 12 + noteIndex
    }
    
    /// Converts MIDI note number to note name with octave
    /// - Parameter midiNote: MIDI note number
    /// - Returns: Note name like "C4", "F#5", etc.
    static func midiNoteToNoteName(_ midiNote: Int) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let noteIndex = midiNote % 12
        let octave = midiNote / 12 - 1
        return "\(noteNames[noteIndex])\(octave)"
    }
    
    /// Determines if a note should display an accidental given the key signature
    /// - Parameters:
    ///   - noteName: The note name
    ///   - keySignature: The key signature
    /// - Returns: The accidental to display (empty string if none needed)
    static func getAccidentalDisplay(for noteName: String, in keySignature: String) -> String {
        // For now, return the accidental from the note name itself
        // A more sophisticated implementation would check against the key signature
        if noteName.contains("#") {
            return "♯"
        } else if noteName.contains("b") {
            return "♭"
        }
        return ""
    }
    
    /// Calculates the number of ledger lines needed for a staff position
    /// - Parameter position: Staff position (0 = middle line)
    /// - Returns: Number of ledger lines needed (0 if none)
    static func getLedgerLinesCount(for position: Double) -> Int {
        let absPosition = abs(position)
        if absPosition > 4.0 {  // Beyond the 5-line staff
            return Int((absPosition - 4.0) / 2.0) + 1
        }
        return 0
    }
    
    /// Gets ledger line positions for a given staff position
    /// - Parameter position: Staff position
    /// - Returns: Array of ledger line positions
    static func getLedgerLinePositions(for position: Double) -> [Double] {
        var positions: [Double] = []
        
        if position > 4.0 {  // Below staff
            var ledgerPos = 6.0
            while ledgerPos <= position + 1.0 {
                positions.append(ledgerPos)
                ledgerPos += 2.0
            }
        } else if position < -4.0 {  // Above staff
            var ledgerPos = -6.0
            while ledgerPos >= position - 1.0 {
                positions.append(ledgerPos)
                ledgerPos -= 2.0
            }
        }
        
        return positions
    }
}