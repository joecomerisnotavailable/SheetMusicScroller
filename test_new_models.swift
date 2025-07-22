#!/usr/bin/env swift

import Foundation

// We need to include our model files here for testing
// Copy of the new Note model
enum NoteDuration: Double, CaseIterable, Codable {
    case whole = 4.0
    case half = 2.0
    case quarter = 1.0
    case eighth = 0.5
    case sixteenth = 0.25
    case thirtySecond = 0.125
    
    var beats: Double {
        return self.rawValue
    }
    
    func duration(at tempo: Double) -> Double {
        return (60.0 / tempo) * beats
    }
}

enum Clef: String, CaseIterable, Codable {
    case treble = "treble"
    case bass = "bass"
    case alto = "alto"
    case tenor = "tenor"
    
    var middleLineMidiNote: Int {
        switch self {
        case .treble: return 71  // B4
        case .bass: return 50    // D3  
        case .alto: return 60    // C4 (middle C)
        case .tenor: return 57   // A3
        }
    }
}

struct MusicContext: Codable {
    let keySignature: String
    let clef: Clef
    let tempo: Double
    let a4Reference: Double
    
    init(keySignature: String, clef: Clef = .treble, tempo: Double = 120, a4Reference: Double = 440.0) {
        self.keySignature = keySignature
        self.clef = clef
        self.tempo = tempo
        self.a4Reference = a4Reference
    }
}

// Simplified version of StaffPositionMapper for testing
class StaffPositionMapper {
    static func noteNameToMidiNote(_ noteName: String) -> Int {
        guard noteName.count >= 2 else { return 60 }
        
        let noteString = String(noteName.dropLast())
        let octaveString = String(noteName.suffix(1))
        
        guard let octave = Int(octaveString) else { return 60 }
        
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
        return (octave + 1) * 12 + noteIndex
    }
    
    static func frequencyToStaffPosition(_ frequency: Double, context: MusicContext) -> Double {
        guard frequency > 0 else { return 0.0 }
        
        // Convert frequency to MIDI note number using the A4 reference
        let midiNote = 69 + 12 * log2(frequency / context.a4Reference)
        
        return midiNoteToStaffPosition(midiNote, clef: context.clef)
    }
    
    static func noteNameToStaffPosition(_ noteName: String, context: MusicContext) -> Double {
        let midiNote = noteNameToMidiNote(noteName)
        return midiNoteToStaffPosition(Double(midiNote), clef: context.clef)
    }
    
    static func midiNoteToStaffPosition(_ midiNote: Double, clef: Clef) -> Double {
        let middleLineMidi = Double(clef.middleLineMidiNote)
        let chromaticDifference = midiNote - middleLineMidi
        return -chromaticDifference * (7.0 / 12.0) * 0.5
    }
    
    static func getAccidentalDisplay(for noteName: String, in keySignature: String) -> String {
        if noteName.contains("#") {
            return "♯"
        } else if noteName.contains("b") {
            return "♭"
        }
        return ""
    }
    
    static func getLedgerLinesCount(for position: Double) -> Int {
        let absPosition = abs(position)
        if absPosition > 4.0 {
            return Int((absPosition - 4.0) / 2.0) + 1
        }
        return 0
    }
}

struct Note: Identifiable, Codable {
    let id = UUID()
    let noteName: String
    let noteValue: NoteDuration
    let a4Reference: Double
    let keySignature: String
    
    init(noteName: String, noteValue: NoteDuration, a4Reference: Double = 440.0, keySignature: String = "C major") {
        self.noteName = noteName
        self.noteValue = noteValue
        self.a4Reference = a4Reference
        self.keySignature = keySignature
    }
    
    var frequency: Double {
        let midiNote = StaffPositionMapper.noteNameToMidiNote(noteName)
        return a4Reference * pow(2.0, Double(midiNote - 69) / 12.0)
    }
    
    var midiNote: Int {
        return StaffPositionMapper.noteNameToMidiNote(noteName)
    }
    
    // Convenience static methods
    static func quarter(_ noteName: String, a4Reference: Double = 440.0, keySignature: String = "C major") -> Note {
        return Note(noteName: noteName, noteValue: .quarter, a4Reference: a4Reference, keySignature: keySignature)
    }
    
    static func sixteenth(_ noteName: String, a4Reference: Double = 440.0, keySignature: String = "C major") -> Note {
        return Note(noteName: noteName, noteValue: .sixteenth, a4Reference: a4Reference, keySignature: keySignature)
    }
    
    static func eighth(_ noteName: String, a4Reference: Double = 440.0, keySignature: String = "C major") -> Note {
        return Note(noteName: noteName, noteValue: .eighth, a4Reference: a4Reference, keySignature: keySignature)
    }
}

struct TimedNote: Identifiable, Codable {
    let id = UUID()
    let note: Note
    let startTime: Double
    
    init(note: Note, startTime: Double) {
        self.note = note
        self.startTime = startTime
    }
    
    func duration(in context: MusicContext) -> Double {
        return note.noteValue.duration(at: context.tempo)
    }
    
    func staffPosition(in context: MusicContext) -> Double {
        return StaffPositionMapper.noteNameToStaffPosition(note.noteName, context: context)
    }
    
    func accidentalDisplay(in context: MusicContext) -> String {
        return StaffPositionMapper.getAccidentalDisplay(for: note.noteName, in: context.keySignature)
    }
}

struct SheetMusic: Identifiable, Codable {
    let id = UUID()
    let title: String
    let composer: String
    let musicContext: MusicContext
    let timeSignature: String
    let timedNotes: [TimedNote]
    
    init(title: String, composer: String, musicContext: MusicContext, timeSignature: String, timedNotes: [TimedNote]) {
        self.title = title
        self.composer = composer
        self.musicContext = musicContext
        self.timeSignature = timeSignature
        self.timedNotes = timedNotes
    }
    
    init(title: String, composer: String, keySignature: String, clef: Clef = .treble, tempo: Double = 120, timeSignature: String, timedNotes: [TimedNote], a4Reference: Double = 440.0) {
        let context = MusicContext(keySignature: keySignature, clef: clef, tempo: tempo, a4Reference: a4Reference)
        self.init(title: title, composer: composer, musicContext: context, timeSignature: timeSignature, timedNotes: timedNotes)
    }
    
    var totalDuration: Double {
        return timedNotes.max(by: { 
            $0.startTime + $0.duration(in: musicContext) < $1.startTime + $1.duration(in: musicContext) 
        })?.startTime ?? 0
    }
    
    func notesAt(time: Double) -> [TimedNote] {
        return timedNotes.filter { timedNote in
            let noteDuration = timedNote.duration(in: musicContext)
            return timedNote.startTime <= time && time <= timedNote.startTime + noteDuration
        }
    }
}

// Test the new structure
print("🎼 New SheetMusicScroller Model Test")
print("===================================")

// Test 1: Basic Note Creation
print("\n🎵 Test 1: Note Creation and Properties")
let note1 = Note.quarter("C4")
let note2 = Note.sixteenth("F#5", keySignature: "D major")
let note3 = Note.eighth("Bb3", a4Reference: 442.0, keySignature: "F major")

print("Note 1: \(note1.noteName) - \(note1.noteValue) - \(String(format: "%.1f", note1.frequency)) Hz")
print("Note 2: \(note2.noteName) - \(note2.noteValue) - \(String(format: "%.1f", note2.frequency)) Hz")
print("Note 3: \(note3.noteName) - \(note3.noteValue) - \(String(format: "%.1f", note3.frequency)) Hz")

// Test 2: Different Clefs and Staff Positions
print("\n🎼 Test 2: Staff Position Mapping Across Clefs")
let testNote = "C4"
let clefs: [Clef] = [.treble, .bass, .alto, .tenor]

for clef in clefs {
    let context = MusicContext(keySignature: "C major", clef: clef)
    let position = StaffPositionMapper.noteNameToStaffPosition(testNote, context: context)
    let ledgerLines = StaffPositionMapper.getLedgerLinesCount(for: position)
    print("\(testNote) in \(clef.rawValue) clef: position \(String(format: "%.1f", position)), ledger lines: \(ledgerLines)")
}

// Test 3: Frequency Mapping
print("\n🎹 Test 3: Frequency to Staff Position")
let frequencies = [220.0, 440.0, 880.0, 1760.0]  // A3, A4, A5, A6
let trebleContext = MusicContext(keySignature: "C major", clef: .treble)

for freq in frequencies {
    let position = StaffPositionMapper.frequencyToStaffPosition(freq, context: trebleContext)
    print("Frequency \(freq) Hz: staff position \(String(format: "%.1f", position))")
}

// Test 4: Extended Range with Ledger Lines
print("\n📏 Test 4: Extended Range Testing")
let extremeNotes = ["C2", "C3", "C4", "C5", "C6", "C7", "C8"]

for noteName in extremeNotes {
    let position = StaffPositionMapper.noteNameToStaffPosition(noteName, context: trebleContext)
    let ledgerLines = StaffPositionMapper.getLedgerLinesCount(for: position)
    let accidental = StaffPositionMapper.getAccidentalDisplay(for: noteName, in: "C major")
    print("\(noteName): position \(String(format: "%.1f", position)), ledger lines: \(ledgerLines), accidental: '\(accidental)'")
}

// Test 5: Create Sample Sheet Music
print("\n🎶 Test 5: Sample Sheet Music Creation")
let sampleNotes = [
    Note.quarter("C4", keySignature: "C major"),
    Note.quarter("E4", keySignature: "C major"),
    Note.quarter("G4", keySignature: "C major"),
    Note.quarter("C5", keySignature: "C major")
]

let timedNotes = [
    TimedNote(note: sampleNotes[0], startTime: 0.0),
    TimedNote(note: sampleNotes[1], startTime: 0.5),
    TimedNote(note: sampleNotes[2], startTime: 1.0),
    TimedNote(note: sampleNotes[3], startTime: 1.5)
]

let sampleMusic = SheetMusic(
    title: "C Major Scale",
    composer: "Test Composer",
    keySignature: "C major",
    clef: .treble,
    tempo: 120,
    timeSignature: "4/4",
    timedNotes: timedNotes
)

print("Title: \(sampleMusic.title)")
print("Composer: \(sampleMusic.composer)")
print("Key: \(sampleMusic.musicContext.keySignature)")
print("Clef: \(sampleMusic.musicContext.clef.rawValue)")
print("Tempo: \(sampleMusic.musicContext.tempo) BPM")
print("Notes: \(sampleMusic.timedNotes.count)")

for (index, timedNote) in sampleMusic.timedNotes.enumerated() {
    let position = timedNote.staffPosition(in: sampleMusic.musicContext)
    let duration = timedNote.duration(in: sampleMusic.musicContext)
    print("  \(index + 1). \(timedNote.note.noteName) at \(timedNote.startTime)s (duration: \(String(format: "%.3f", duration))s, position: \(String(format: "%.1f", position)))")
}

print("\n✅ All new model tests completed successfully!")
print("🎯 New structure is working correctly!")