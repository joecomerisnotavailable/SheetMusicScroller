import Foundation
import SwiftUI

/// Represents a staff line with positioning logic
struct StaffLine {
    let noteName: String  // Exact note name for this staff line
    let clef: Clef
    
    /// Creates staff lines for a given clef with correct note names
    static func createStaffLines(for clef: Clef) -> [StaffLine] {
        switch clef {
        case .treble:
            return [
                StaffLine(noteName: "F5", clef: clef),   // Top line 
                StaffLine(noteName: "D5", clef: clef),   // Fourth line
                StaffLine(noteName: "B4", clef: clef),   // Middle line
                StaffLine(noteName: "G4", clef: clef),   // Second line
                StaffLine(noteName: "E4", clef: clef)    // Bottom line
            ]
        case .bass:
            return [
                StaffLine(noteName: "A3", clef: clef),   // Top line
                StaffLine(noteName: "F3", clef: clef),   // Fourth line
                StaffLine(noteName: "D3", clef: clef),   // Middle line
                StaffLine(noteName: "B2", clef: clef),   // Second line
                StaffLine(noteName: "G2", clef: clef)    // Bottom line
            ]
        case .alto:
            return [
                StaffLine(noteName: "G4", clef: clef),   // Top line
                StaffLine(noteName: "E4", clef: clef),   // Fourth line
                StaffLine(noteName: "C4", clef: clef),   // Middle line
                StaffLine(noteName: "A3", clef: clef),   // Second line
                StaffLine(noteName: "F3", clef: clef)    // Bottom line
            ]
        case .tenor:
            return [
                StaffLine(noteName: "E4", clef: clef),   // Top line
                StaffLine(noteName: "C4", clef: clef),   // Fourth line
                StaffLine(noteName: "A3", clef: clef),   // Middle line
                StaffLine(noteName: "F3", clef: clef),   // Second line
                StaffLine(noteName: "D3", clef: clef)    // Bottom line
            ]
        }
    }
}

/// Represents a key signature accidental with built-in positioning
struct KeySignatureAccidental {
    let accidentalType: AccidentalType
    let noteName: String  // Exact note name for positioning
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
            // Bb is on the B line (middle line in treble clef)
            return [KeySignatureAccidental(accidentalType: .flat, noteName: "B4", clef: clef)]
        case .bass:
            // Bb is on the second line from top in bass clef
            return [KeySignatureAccidental(accidentalType: .flat, noteName: "B2", clef: clef)]
        case .alto:
            // Bb is on the top line in alto clef
            return [KeySignatureAccidental(accidentalType: .flat, noteName: "B4", clef: clef)]
        case .tenor:
            // Bb is on the second line from top in tenor clef
            return [KeySignatureAccidental(accidentalType: .flat, noteName: "B3", clef: clef)]
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
    
    /// Universal function to convert (note name, key signature) to vertical screen position
    /// Used by all objects that need Y coordinates: notes, staff lines, clef, key signature, squiggle
    /// - Parameters:
    ///   - noteName: The note name (e.g., "G4", "C4", "Bb4")
    ///   - keySignature: The active key signature (e.g., "D minor")
    ///   - clef: The clef type (default: treble)
    ///   - staffHeight: The height of the staff in pixels (default: 120)
    /// - Returns: Y coordinate in pixels
    static func getYFromNoteAndKey(_ noteName: String, keySignature: String, clef: Clef = .treble, staffHeight: CGFloat = 120) -> CGFloat {
        let context = MusicContext(keySignature: keySignature, clef: clef)
        let staffPosition = noteNameToStaffPosition(noteName, context: context)
        
        // Ensure staff lines are positioned properly within the frame
        // Use staff line spacing that keeps all 5 lines within the staff height
        let topMargin: CGFloat = 10
        let bottomMargin: CGFloat = 10
        let availableHeight = staffHeight - topMargin - bottomMargin
        let lineSpacing = availableHeight / 4  // 4 spaces between 5 lines
        
        // Staff positions: -4 (top line) to +4 (bottom line)
        // Map to Y coordinates: topMargin to (staffHeight - bottomMargin)
        let yPosition = topMargin + ((staffPosition + 4.0) * lineSpacing / 2.0)
        
        return CGFloat(yPosition)
    }
    
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
    
    /// Converts staff position back to MIDI note number for a given clef
    /// - Parameters:
    ///   - staffPosition: Staff position where 0 = middle line, negative = above, positive = below
    ///   - clef: The clef type
    /// - Returns: MIDI note number
    static func staffPositionToMidiNote(_ staffPosition: Double, clef: Clef) -> Int {
        let referenceMidi = clef.middleLineMidiNote  // MIDI note on middle line
        
        switch clef {
        case .treble:
            // In treble clef, B4 (71) is on the middle line (position 0)
            // Each staff position represents (7/4) semitones
            let semitoneDiff = -staffPosition * (7.0 / 4.0)
            return referenceMidi + Int(round(semitoneDiff))
        case .bass:
            // In bass clef, D3 (50) is on the middle line
            let semitoneDiff = -staffPosition * (7.0 / 4.0)
            return referenceMidi + Int(round(semitoneDiff))
        case .alto:
            // In alto clef, C4 (60) is on the middle line
            let semitoneDiff = -staffPosition * (7.0 / 4.0)
            return referenceMidi + Int(round(semitoneDiff))
        case .tenor:
            // In tenor clef, A3 (57) is on the middle line
            let semitoneDiff = -staffPosition * (7.0 / 4.0)
            return referenceMidi + Int(round(semitoneDiff))
        }
    }
    
    /// Converts MIDI note number to staff position for a given clef
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
    
    /// Convert frequency to nearest note name
    /// - Parameters:
    ///   - frequency: The frequency in Hz
    ///   - a4Reference: Base Hz reference for A4 (default 440.0)
    /// - Returns: Nearest note name like "A4", "C#5", etc.
    static func noteNameFromFrequency(_ frequency: Double, a4Reference: Double = 440.0) -> String {
        guard frequency > 0 else { return "C4" }
        
        // Convert frequency to MIDI note number
        let midiNote = 69 + 12 * log2(frequency / a4Reference)
        let roundedMidiNote = Int(round(midiNote))
        
        return midiNoteToNoteName(roundedMidiNote)
    }
    
    /// Get the true frequency of a note name
    /// - Parameters:
    ///   - noteName: The note name (e.g., "A4", "C#5")
    ///   - a4Reference: Base Hz reference for A4 (default 440.0)
    /// - Returns: The exact frequency in Hz
    static func noteNameToFrequency(_ noteName: String, a4Reference: Double = 440.0) -> Double {
        let midiNote = noteNameToMidiNote(noteName)
        return a4Reference * pow(2.0, Double(midiNote - 69) / 12.0)
    }
    
    /// Find the next note in a direction whose staff position differs from the reference note
    /// - Parameters:
    ///   - fromNoteName: The reference note name
    ///   - direction: Direction to search (1 for up, -1 for down)
    ///   - keySignature: The key signature context
    ///   - clef: The clef type
    /// - Returns: Note name of the next note with different staff position
    static func nextNoteWithDifferentStaffPosition(from fromNoteName: String, direction: Int, keySignature: String, clef: Clef = .treble) -> String {
        let context = MusicContext(keySignature: keySignature, clef: clef)
        let referenceMidi = noteNameToMidiNote(fromNoteName)
        let referencePosition = noteNameToStaffPosition(fromNoteName, context: context)
        
        var currentMidi = referenceMidi + direction
        
        // Search for the next note with a different staff position
        while abs(currentMidi - referenceMidi) <= 12 { // Don't go more than an octave
            let currentNoteName = midiNoteToNoteName(currentMidi)
            let currentPosition = noteNameToStaffPosition(currentNoteName, context: context)
            
            if abs(currentPosition - referencePosition) > 0.1 { // Different staff position
                return currentNoteName
            }
            
            currentMidi += direction
        }
        
        // Fallback: return a note one semitone away
        return midiNoteToNoteName(referenceMidi + direction)
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