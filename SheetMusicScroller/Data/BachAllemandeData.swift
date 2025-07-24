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
        
        // Create timed notes with start times
        let timedNotes: [TimedNote] = [
            // Measure 1 - First 8 notes as specified: D4, D4, E4, F4, G4, A4, Bb4, C#4
            TimedNote(note: notes[0], startTime: 0.0),     // D4
            TimedNote(note: notes[1], startTime: 0.125),   // D4
            TimedNote(note: notes[2], startTime: 0.25),    // E4
            TimedNote(note: notes[3], startTime: 0.375),   // F4
            TimedNote(note: notes[4], startTime: 0.5),     // G4
            TimedNote(note: notes[5], startTime: 0.625),   // A4
            TimedNote(note: notes[6], startTime: 0.75),    // Bb4
            TimedNote(note: notes[7], startTime: 0.875),   // C#4
            
            // Measure 2 - F4 held with ornamentation
            TimedNote(note: notes[8], startTime: 1.0),     // F4 eighth
            TimedNote(note: notes[9], startTime: 1.25),    // E4
            TimedNote(note: notes[10], startTime: 1.375),  // F4
            TimedNote(note: notes[11], startTime: 1.5),    // G4
            TimedNote(note: notes[12], startTime: 1.625),  // A4
            TimedNote(note: notes[13], startTime: 1.75),   // Bb4
            TimedNote(note: notes[14], startTime: 1.875),  // A4
            
            // Measure 3 - Continue the melodic line
            TimedNote(note: notes[15], startTime: 2.0),    // G4 quarter
            TimedNote(note: notes[16], startTime: 2.5),    // F4
            TimedNote(note: notes[17], startTime: 2.625),  // E4
            TimedNote(note: notes[18], startTime: 2.75),   // D4
            TimedNote(note: notes[19], startTime: 2.875),  // C4
            
            // Measure 4 - Bb3 with ornamental figures
            TimedNote(note: notes[20], startTime: 3.0),    // Bb3 eighth
            TimedNote(note: notes[21], startTime: 3.25),   // A3
            TimedNote(note: notes[22], startTime: 3.375),  // Bb3
            TimedNote(note: notes[23], startTime: 3.5),    // C4
            TimedNote(note: notes[24], startTime: 3.625),  // D4
            TimedNote(note: notes[25], startTime: 3.75),   // E4
            TimedNote(note: notes[26], startTime: 3.875),  // F4
            
            // Measure 5-6 - Extended melodic development
            TimedNote(note: notes[27], startTime: 4.0),    // G4 quarter
            TimedNote(note: notes[28], startTime: 4.5),    // F4 eighth
            TimedNote(note: notes[29], startTime: 4.75),   // E4 eighth
            
            TimedNote(note: notes[30], startTime: 5.0),    // D4
            TimedNote(note: notes[31], startTime: 5.125),  // E4
            TimedNote(note: notes[32], startTime: 5.25),   // F4
            TimedNote(note: notes[33], startTime: 5.375),  // G4
            TimedNote(note: notes[34], startTime: 5.5),    // A4
            TimedNote(note: notes[35], startTime: 5.625),  // Bb4
            TimedNote(note: notes[36], startTime: 5.75),   // C5
            TimedNote(note: notes[37], startTime: 5.875),  // D5
        ]
        
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