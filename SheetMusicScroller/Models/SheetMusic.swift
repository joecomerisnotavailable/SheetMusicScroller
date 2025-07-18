import Foundation

/// Represents a piece of sheet music with multiple notes
struct SheetMusic: Identifiable, Codable {
    let id = UUID()
    let title: String
    let composer: String
    let tempo: Double        // BPM (beats per minute)
    let timeSignature: String // e.g., "4/4", "3/4"
    let keySignature: String  // e.g., "C major", "D minor"
    let notes: [Note]
    
    init(title: String, composer: String, tempo: Double, timeSignature: String, keySignature: String, notes: [Note]) {
        self.title = title
        self.composer = composer
        self.tempo = tempo
        self.timeSignature = timeSignature
        self.keySignature = keySignature
        self.notes = notes
    }
    
    /// Total duration of the piece in seconds
    var totalDuration: Double {
        return notes.max(by: { $0.startTime + $0.duration < $1.startTime + $1.duration })?.startTime ?? 0
    }
    
    /// Get notes that should be active at a given time
    func notesAt(time: Double) -> [Note] {
        return notes.filter { note in
            note.startTime <= time && time <= note.startTime + note.duration
        }
    }
    
    /// Get all notes that start before or at a given time
    func notesUpTo(time: Double) -> [Note] {
        return notes.filter { note in
            note.startTime <= time
        }
    }
}