import Foundation

/// Mock data for Bach's Partita No. 2 in D minor, Allemande
class BachAllemandeData {
    
    static let bachAllemande: SheetMusic = {
        // Create a simplified excerpt from Bach's Partita No. 2 Allemande
        // This represents the opening measures with positions relative to treble clef staff
        // Position 0 = middle line (B4), negative = higher, positive = lower
        
        let notes: [Note] = [
            // Measure 1 - Starting with D5, F5, A5 chord pattern
            Note.sixteenth(pitch: "D5", startTime: 0.0, position: -1.5),   // D above staff
            Note.sixteenth(pitch: "F5", startTime: 0.125, position: -2.0), // F above staff  
            Note.sixteenth(pitch: "A5", startTime: 0.25, position: -2.5),  // A above staff
            Note.sixteenth(pitch: "D6", startTime: 0.375, position: -3.0), // High D
            
            // Measure 1 continued - descending pattern
            Note.sixteenth(pitch: "C6", startTime: 0.5, position: -2.75),
            Note.sixteenth(pitch: "Bb5", startTime: 0.625, position: -2.25),
            Note.sixteenth(pitch: "A5", startTime: 0.75, position: -2.5),
            Note.sixteenth(pitch: "G5", startTime: 0.875, position: -1.75),
            
            // Measure 2 - F5 held with ornamentation
            Note.eighth(pitch: "F5", startTime: 1.0, position: -2.0),
            Note.sixteenth(pitch: "E5", startTime: 1.25, position: -1.75),
            Note.sixteenth(pitch: "F5", startTime: 1.375, position: -2.0),
            Note.sixteenth(pitch: "G5", startTime: 1.5, position: -1.75),
            Note.sixteenth(pitch: "A5", startTime: 1.625, position: -2.5),
            Note.sixteenth(pitch: "Bb5", startTime: 1.75, position: -2.25),
            Note.sixteenth(pitch: "A5", startTime: 1.875, position: -2.5),
            
            // Measure 3 - Continue the melodic line
            Note.quarter(pitch: "G5", startTime: 2.0, position: -1.75),
            Note.sixteenth(pitch: "F5", startTime: 2.5, position: -2.0),
            Note.sixteenth(pitch: "E5", startTime: 2.625, position: -1.75),
            Note.sixteenth(pitch: "D5", startTime: 2.75, position: -1.5),
            Note.sixteenth(pitch: "C5", startTime: 2.875, position: -1.25),
            
            // Measure 4 - Bb4 with ornamental figures
            Note.eighth(pitch: "Bb4", startTime: 3.0, position: -0.5),
            Note.sixteenth(pitch: "A4", startTime: 3.25, position: -0.25),
            Note.sixteenth(pitch: "Bb4", startTime: 3.375, position: -0.5),
            Note.sixteenth(pitch: "C5", startTime: 3.5, position: -1.25),
            Note.sixteenth(pitch: "D5", startTime: 3.625, position: -1.5),
            Note.sixteenth(pitch: "E5", startTime: 3.75, position: -1.75),
            Note.sixteenth(pitch: "F5", startTime: 3.875, position: -2.0),
            
            // Measure 5-6 - Extended melodic development
            Note.quarter(pitch: "G5", startTime: 4.0, position: -1.75),
            Note.eighth(pitch: "F5", startTime: 4.5, position: -2.0),
            Note.eighth(pitch: "E5", startTime: 4.75, position: -1.75),
            
            Note.sixteenth(pitch: "D5", startTime: 5.0, position: -1.5),
            Note.sixteenth(pitch: "E5", startTime: 5.125, position: -1.75),
            Note.sixteenth(pitch: "F5", startTime: 5.25, position: -2.0),
            Note.sixteenth(pitch: "G5", startTime: 5.375, position: -1.75),
            Note.sixteenth(pitch: "A5", startTime: 5.5, position: -2.5),
            Note.sixteenth(pitch: "Bb5", startTime: 5.625, position: -2.25),
            Note.sixteenth(pitch: "C6", startTime: 5.75, position: -2.75),
            Note.sixteenth(pitch: "D6", startTime: 5.875, position: -3.0),
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