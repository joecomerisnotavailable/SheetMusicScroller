import Foundation
import CoreGraphics

/// Represents a musical note with pitch and timing information
struct Note: Identifiable, Codable {
    let id = UUID()
    let pitch: String        // e.g., "C4", "F#5", "Bb3"
    let startTime: Double    // Time in seconds when note starts
    let duration: Double     // Duration in seconds
    let position: CGFloat    // Y position on the staff (0 = middle of staff)
    let isSharp: Bool        // Whether the note is sharp/flat
    let isFlat: Bool         // Whether the note is flat
    
    init(pitch: String, startTime: Double, duration: Double, position: CGFloat, isSharp: Bool = false, isFlat: Bool = false) {
        self.pitch = pitch
        self.startTime = startTime
        self.duration = duration
        self.position = position
        self.isSharp = isSharp
        self.isFlat = isFlat
    }
}

// Extension for easier note creation
extension Note {
    static func quarter(pitch: String, startTime: Double, position: CGFloat, isSharp: Bool = false, isFlat: Bool = false) -> Note {
        return Note(pitch: pitch, startTime: startTime, duration: 0.5, position: position, isSharp: isSharp, isFlat: isFlat)
    }
    
    static func eighth(pitch: String, startTime: Double, position: CGFloat, isSharp: Bool = false, isFlat: Bool = false) -> Note {
        return Note(pitch: pitch, startTime: startTime, duration: 0.25, position: position, isSharp: isSharp, isFlat: isFlat)
    }
    
    static func sixteenth(pitch: String, startTime: Double, position: CGFloat, isSharp: Bool = false, isFlat: Bool = false) -> Note {
        return Note(pitch: pitch, startTime: startTime, duration: 0.125, position: position, isSharp: isSharp, isFlat: isFlat)
    }
}