import Foundation

/// Mock data for Bach's Partita No. 2 in D minor, Allemande
class BachAllemandeData {
    
    static let bachAllemande: SheetMusic = {
        // Create a simplified excerpt from Bach's Partita No. 2 Allemande
        // This represents the opening measures with positions relative to treble clef staff
        // Position 0 = middle line (B4), negative = higher, positive = lower
        // First note is D4, which should be just below the staff
        
        let notes: [Note] = [
            // Measure 1 - Starting with D4 (the actual first note of the Allemande)
            Note.sixteenth(pitch: "D4", startTime: 0.0, position: 3.5),   // D4 below staff
            Note.sixteenth(pitch: "F4", startTime: 0.125, position: 2.5), // F4 on bottom line
            Note.sixteenth(pitch: "A4", startTime: 0.25, position: 1.5),  // A4 in first space
            Note.sixteenth(pitch: "D5", startTime: 0.375, position: -1.5), // D5 above center
            
            // Measure 1 continued - descending pattern
            Note.sixteenth(pitch: "C5", startTime: 0.5, position: -1.0),   // C5
            Note.sixteenth(pitch: "Bb4", startTime: 0.625, position: -0.5), // Bb4
            Note.sixteenth(pitch: "A4", startTime: 0.75, position: 1.5),   // A4
            Note.sixteenth(pitch: "G4", startTime: 0.875, position: 2.0),  // G4
            
            // Measure 2 - F4 held with ornamentation
            Note.eighth(pitch: "F4", startTime: 1.0, position: 2.5),
            Note.sixteenth(pitch: "E4", startTime: 1.25, position: 3.0),
            Note.sixteenth(pitch: "F4", startTime: 1.375, position: 2.5),
            Note.sixteenth(pitch: "G4", startTime: 1.5, position: 2.0),
            Note.sixteenth(pitch: "A4", startTime: 1.625, position: 1.5),
            Note.sixteenth(pitch: "Bb4", startTime: 1.75, position: -0.5),
            Note.sixteenth(pitch: "A4", startTime: 1.875, position: 1.5),
            
            // Measure 3 - Continue the melodic line
            Note.quarter(pitch: "G4", startTime: 2.0, position: 2.0),
            Note.sixteenth(pitch: "F4", startTime: 2.5, position: 2.5),
            Note.sixteenth(pitch: "E4", startTime: 2.625, position: 3.0),
            Note.sixteenth(pitch: "D4", startTime: 2.75, position: 3.5),
            Note.sixteenth(pitch: "C4", startTime: 2.875, position: 4.0),  // C4 below staff
            
            // Measure 4 - Bb3 with ornamental figures
            Note.eighth(pitch: "Bb3", startTime: 3.0, position: 4.5),
            Note.sixteenth(pitch: "A3", startTime: 3.25, position: 5.0),
            Note.sixteenth(pitch: "Bb3", startTime: 3.375, position: 4.5),
            Note.sixteenth(pitch: "C4", startTime: 3.5, position: 4.0),
            Note.sixteenth(pitch: "D4", startTime: 3.625, position: 3.5),
            Note.sixteenth(pitch: "E4", startTime: 3.75, position: 3.0),
            Note.sixteenth(pitch: "F4", startTime: 3.875, position: 2.5),
            
            // Measure 5-6 - Extended melodic development
            Note.quarter(pitch: "G4", startTime: 4.0, position: 2.0),
            Note.eighth(pitch: "F4", startTime: 4.5, position: 2.5),
            Note.eighth(pitch: "E4", startTime: 4.75, position: 3.0),
            
            Note.sixteenth(pitch: "D4", startTime: 5.0, position: 3.5),
            Note.sixteenth(pitch: "E4", startTime: 5.125, position: 3.0),
            Note.sixteenth(pitch: "F4", startTime: 5.25, position: 2.5),
            Note.sixteenth(pitch: "G4", startTime: 5.375, position: 2.0),
            Note.sixteenth(pitch: "A4", startTime: 5.5, position: 1.5),
            Note.sixteenth(pitch: "Bb4", startTime: 5.625, position: -0.5),
            Note.sixteenth(pitch: "C5", startTime: 5.75, position: -1.0),
            Note.sixteenth(pitch: "D5", startTime: 5.875, position: -1.5),
        ]
        
        return SheetMusic(
            title: "Allemande",
            composer: "J.S. Bach - Partita No. 2 in D minor, BWV 1004",
            tempo: 120,
            timeSignature: "4/4",
            keySignature: "D minor",
            notes: notes
        )
    }()
}