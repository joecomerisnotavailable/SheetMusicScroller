import Foundation

/// Mock data for Bach's Partita No. 2 in D minor, Allemande
class BachAllemandeData {
    
    static let bachAllemande: SheetMusic = {
        // Create a simplified excerpt from Bach's Partita No. 2 Allemande using the new structure
        let keySignature = "D minor"
        let a4Reference = 440.0
        
        // Create immutable notes with the new Note structure
        let notes: [Note] = [
            // First 8 notes as specified: D4, D4, E4, F4, G4, A4, Bb4, C#4
            Note.sixteenth("D4", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("D4", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("E4", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("F4", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("G4", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("A4", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("Bb4", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("C#4", a4Reference: a4Reference, keySignature: keySignature),
            
            // Measure 2 - F4 held with ornamentation
            Note.eighth("F4", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("E4", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("F4", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("G4", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("A4", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("Bb4", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("A4", a4Reference: a4Reference, keySignature: keySignature),
            
            // Measure 3 - Continue the melodic line
            Note.quarter("G4", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("F4", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("E4", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("D4", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("C4", a4Reference: a4Reference, keySignature: keySignature),
            
            // Measure 4 - Bb3 with ornamental figures
            Note.eighth("Bb3", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("A3", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("Bb3", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("C4", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("D4", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("E4", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("F4", a4Reference: a4Reference, keySignature: keySignature),
            
            // Measure 5-6 - Extended melodic development
            Note.quarter("G4", a4Reference: a4Reference, keySignature: keySignature),
            Note.eighth("F4", a4Reference: a4Reference, keySignature: keySignature),
            Note.eighth("E4", a4Reference: a4Reference, keySignature: keySignature),
            
            Note.sixteenth("D4", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("E4", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("F4", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("G4", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("A4", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("Bb4", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("C5", a4Reference: a4Reference, keySignature: keySignature),
            Note.sixteenth("D5", a4Reference: a4Reference, keySignature: keySignature),
        ]
        
        // Create timed notes with start times based on cumulative durations
        var currentTime: Double = 0.0
        let timedNotes: [TimedNote] = notes.map { note in
            let timedNote = TimedNote(note: note, startTime: currentTime)
            // Advance current time by this note's duration at 120 BPM
            currentTime += note.noteValue.duration(at: 120.0)
            return timedNote
        }
        
        return SheetMusic(
            title: "Allemande",
            composer: "J.S. Bach - Partita No. 2 in D minor, BWV 1004",
            keySignature: keySignature,
            clef: .treble,
            tempo: 120,
            timeSignature: "4/4",
            timedNotes: timedNotes,
            a4Reference: a4Reference
        )
    }()
}