import Foundation

/// **DEBUG/TEST DATA** - Mock data for testing squiggle trail and note alignment
/// This file contains test data and should be removed after validation is complete
class CMajorScaleTestData {
    
    static let cMajorScaleTest: SheetMusic = {
        // Create an ascending C Major scale starting at C4 (middle C)
        // Position calculations:
        // - Bottom staff line (E4) = position 2.5
        // - Second line from bottom (G4) = position 1.5  
        // - Distance between bottom line and second line = 1.0
        // - So C4 should be at position 3.5 (same distance below bottom line)
        // - But requirement says "same distance below as second-lowest line is above"
        // - Second-lowest line is G4 at position 1.5
        // - Distance from bottom line to G4 = 2.5 - 1.5 = 1.0
        // - So C4 should be at position 2.5 + 1.0 = 3.5 ✓
        
        let notes: [Note] = [
            // Ascending C Major scale starting at C4
            Note.quarter(pitch: "C4", startTime: 0.0, position: 3.5),   // C4 - below staff
            Note.quarter(pitch: "D4", startTime: 0.5, position: 3.0),   // D4 - below staff  
            Note.quarter(pitch: "E4", startTime: 1.0, position: 2.5),   // E4 - bottom line
            Note.quarter(pitch: "F4", startTime: 1.5, position: 2.0),   // F4 - first space
            Note.quarter(pitch: "G4", startTime: 2.0, position: 1.5),   // G4 - second line ⭐ TARGET
            Note.quarter(pitch: "A4", startTime: 2.5, position: 1.0),   // A4 - second space
            Note.quarter(pitch: "B4", startTime: 3.0, position: 0.5),   // B4 - middle line
            Note.quarter(pitch: "C5", startTime: 3.5, position: 0.0),   // C5 - third space
            Note.quarter(pitch: "D5", startTime: 4.0, position: -0.5),  // D5 - fourth line
            Note.quarter(pitch: "E5", startTime: 4.5, position: -1.0),  // E5 - fourth space
            Note.quarter(pitch: "F5", startTime: 5.0, position: -1.5),  // F5 - top line
            Note.quarter(pitch: "G5", startTime: 5.5, position: -2.0),  // G5 - above staff
            Note.quarter(pitch: "A5", startTime: 6.0, position: -2.5),  // A5 - above staff
        ]
        
        return SheetMusic(
            title: "🧪 TEST: C Major Scale (Ascending)",
            composer: "DEBUG DATA - Mock scale for squiggle trail validation",
            tempo: 120,
            timeSignature: "4/4", 
            keySignature: "C major",
            notes: notes
        )
    }()
}