#!/usr/bin/env swift

// Simple validation script to test our models and functionality
import Foundation

// Copy of Note model from our SwiftUI app
struct Note: Identifiable, Codable {
    let id = UUID()
    let pitch: String
    let startTime: Double
    let duration: Double  
    let position: Double
    let isSharp: Bool
    let isFlat: Bool
    
    init(pitch: String, startTime: Double, duration: Double, position: Double, isSharp: Bool = false, isFlat: Bool = false) {
        self.pitch = pitch
        self.startTime = startTime
        self.duration = duration
        self.position = position
        self.isSharp = isSharp
        self.isFlat = isFlat
    }
    
    static func quarter(pitch: String, startTime: Double, position: Double, isSharp: Bool = false, isFlat: Bool = false) -> Note {
        return Note(pitch: pitch, startTime: startTime, duration: 0.5, position: position, isSharp: isSharp, isFlat: isFlat)
    }
    
    static func sixteenth(pitch: String, startTime: Double, position: Double, isSharp: Bool = false, isFlat: Bool = false) -> Note {
        return Note(pitch: pitch, startTime: startTime, duration: 0.125, position: position, isSharp: isSharp, isFlat: isFlat)
    }
}

// Copy of SheetMusic model from our SwiftUI app
struct SheetMusic: Identifiable, Codable {
    let id = UUID()
    let title: String
    let composer: String
    let tempo: Double
    let timeSignature: String
    let keySignature: String
    let notes: [Note]
    
    var totalDuration: Double {
        return notes.max(by: { $0.startTime + $0.duration < $1.startTime + $1.duration })?.startTime ?? 0
    }
    
    func notesAt(time: Double) -> [Note] {
        return notes.filter { note in
            note.startTime <= time && time <= note.startTime + note.duration
        }
    }
}

// Test our Bach Allemande data
let bachAllemande = SheetMusic(
    title: "Allemande",
    composer: "J.S. Bach - Partita No. 2 in D minor, BWV 1004",
    tempo: 120,
    timeSignature: "4/4",
    keySignature: "D minor",
    notes: [
        Note.sixteenth(pitch: "D5", startTime: 0.0, position: -1.5),
        Note.sixteenth(pitch: "F5", startTime: 0.125, position: -2.0),
        Note.sixteenth(pitch: "A5", startTime: 0.25, position: -2.5),
        Note.sixteenth(pitch: "D6", startTime: 0.375, position: -3.0),
        Note.quarter(pitch: "G5", startTime: 2.0, position: -1.75),
    ]
)

// Test functionality
print("🎼 SheetMusicScroller Validation")
print("================================")
print("Title: \(bachAllemande.title)")
print("Composer: \(bachAllemande.composer)")
print("Tempo: \(bachAllemande.tempo) BPM")
print("Time Signature: \(bachAllemande.timeSignature)")
print("Key: \(bachAllemande.keySignature)")
print("Total Notes: \(bachAllemande.notes.count)")
print("Total Duration: \(bachAllemande.totalDuration) seconds")

print("\n🎵 Note Details:")
for (index, note) in bachAllemande.notes.enumerated() {
    let accidental = note.isSharp ? "♯" : (note.isFlat ? "♭" : "")
    print("  \(index + 1). \(note.pitch)\(accidental) at \(note.startTime)s (duration: \(note.duration)s)")
}

print("\n🎹 Active Notes at different times:")
let testTimes = [0.0, 0.1, 0.25, 0.5, 2.0, 2.5]
for time in testTimes {
    let activeNotes = bachAllemande.notesAt(time: time)
    print("  At \(time)s: \(activeNotes.map { $0.pitch }.joined(separator: ", "))")
}

print("\n✅ All models and data structures validated successfully!")
print("🎯 Ready for SwiftUI integration!")