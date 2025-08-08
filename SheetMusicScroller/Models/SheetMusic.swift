import Foundation

/// Represents a note with timing information for playback
struct TimedNote: Identifiable, Codable {
    let id = UUID()
    let note: Note           // The immutable note data
    let startTime: Double    // Start time in beats (quarter note = 1.0 beat)
    
    init(note: Note, startTime: Double) {
        self.note = note
        self.startTime = startTime
    }
    
    /// Calculate duration in seconds based on note value and tempo
    func duration(in context: MusicContext) -> Double {
        return note.noteValue.duration(at: context.tempo)
    }
    
    /// Calculate the staff position for this note in the given context
    func staffPosition(in context: MusicContext) -> Double {
        return StaffPositionMapper.noteNameToStaffPosition(note.noteName, context: context)
    }
    
    /// Get accidental display for this note in the given context
    func accidentalDisplay(in context: MusicContext) -> String {
        return StaffPositionMapper.getAccidentalDisplay(for: note.noteName, in: context.keySignature)
    }
}

// MARK: - Timing helpers
extension TimedNote {
    /// Calculate the end time of this note
    func endTime(in context: MusicContext) -> Double {
        return startTime + duration(in: context)
    }
    
    /// Half-open interval [start, end), with a small tolerance to avoid edge jitter
    func contains(time: Double, in context: MusicContext, tolerance: Double = 1e-6) -> Bool {
        let s = startTime - tolerance
        let e = endTime(in: context) + tolerance
        return s <= time && time < e
    }
}

/// Represents a piece of sheet music with musical context and timed notes
struct SheetMusic: Identifiable, Codable {
    let id = UUID()
    let title: String
    let composer: String
    let musicContext: MusicContext  // Musical context (key, clef, tempo, A4 reference)
    let timeSignature: String       // e.g., "4/4", "3/4"
    let timedNotes: [TimedNote]     // Notes with timing information
    
    init(title: String, composer: String, musicContext: MusicContext, timeSignature: String, timedNotes: [TimedNote]) {
        self.title = title
        self.composer = composer
        self.musicContext = musicContext
        self.timeSignature = timeSignature
        self.timedNotes = timedNotes
    }
    
    /// Convenience initializer with individual parameters
    init(title: String, composer: String, keySignature: String, clef: Clef = .treble, tempo: Double = 120, timeSignature: String, timedNotes: [TimedNote], a4Reference: Double = 440.0) {
        let context = MusicContext(keySignature: keySignature, clef: clef, tempo: tempo, a4Reference: a4Reference)
        self.init(title: title, composer: composer, musicContext: context, timeSignature: timeSignature, timedNotes: timedNotes)
    }
    
    /// Total duration of the piece in seconds
    var totalDuration: Double {
        guard let lastNote = timedNotes.max(by: { 
            ($0.startTime + $0.duration(in: musicContext)) < ($1.startTime + $1.duration(in: musicContext))
        }) else { return 0 }
        
        return lastNote.startTime + lastNote.duration(in: musicContext)
    }
    
    /// Get notes that should be active at a given time
    func notesAt(time: Double) -> [TimedNote] {
        return timedNotes.filter { $0.contains(time: time, in: musicContext) }
    }
    
    /// Get all notes that start before or at a given time
    func notesUpTo(time: Double) -> [TimedNote] {
        return timedNotes.filter { timedNote in
            timedNote.startTime <= time
        }
    }
    
    /// Get staff positions for all notes in this music
    var noteStaffPositions: [(TimedNote, Double)] {
        return timedNotes.map { timedNote in
            (timedNote, timedNote.staffPosition(in: musicContext))
        }
    }
}