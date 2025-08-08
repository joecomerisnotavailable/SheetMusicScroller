#if canImport(SwiftUI)
import SwiftUI

/// View that renders a single musical note using the new mapping system
struct NoteView: View {
    let timedNote: TimedNote
    let musicContext: MusicContext
    let isActive: Bool
    let squiggleColor: Color?
    let scale: CGFloat
    
    init(timedNote: TimedNote, musicContext: MusicContext, isActive: Bool = false, squiggleColor: Color? = nil, scale: CGFloat = 1.0) {
        self.timedNote = timedNote
        self.musicContext = musicContext
        self.isActive = isActive
        self.squiggleColor = squiggleColor
        self.scale = scale
    }
    
    var body: some View {
        ZStack {
            // Note head (filled circle)
            Circle()
                .fill(noteColor)
                .frame(width: noteSize, height: noteSize)
            
            // Accidental symbols using image assets (sharp/flat)
            let accidental = timedNote.accidentalDisplay(in: musicContext)
            if !accidental.isEmpty {
                // Position accidental to the left of the note head
                MusicalSymbolImageManager.accidentalImageViewWithOffset(
                    for: accidental,
                    targetHeight: noteSize * 0.8,
                    offset: CGPoint(x: -noteSize * 0.8, y: 0)
                )
            }
            
            // Note stem (for eighth and shorter notes)
            if timedNote.note.noteValue.hasStem {
                Rectangle()
                    .fill(noteColor)
                    .frame(width: 1.5, height: noteSize * 3)
                    .offset(x: noteSize * 0.4, y: stemDirection * noteSize * 1.5)
            }
            
            // Beams for notes with beam count > 0
            let beamCount = timedNote.note.noteValue.beamCount
            if beamCount > 0 {
                ForEach(0..<beamCount, id: \.self) { i in
                    Rectangle()
                        .fill(noteColor)
                        .frame(width: noteSize * 0.6, height: 2)
                        .offset(
                            x: noteSize * 0.7, 
                            y: stemDirection * noteSize * (2.1 + 0.5 * CGFloat(i))
                        )
                }
            }
            
            // Duration bars for longer notes (half notes and whole notes)
            if timedNote.note.noteValue.beats >= 2.0 {
                let durationWidth = CGFloat(timedNote.note.noteValue.beats * 25)
                Rectangle()
                    .fill(noteColor.opacity(0.3))
                    .frame(width: durationWidth, height: 3)
                    .offset(x: durationWidth / 2, y: 0)
            }
        }
        .scaleEffect(scale)
        .animation(.easeInOut(duration: 0.1), value: isActive)
        .animation(.easeInOut(duration: 0.2), value: squiggleColor)
    }
    
    private var noteColor: Color {
        if let squiggleColor = squiggleColor {
            return squiggleColor
        } else if isActive {
            return .red
        } else {
            return .black
        }
    }
    
    private var noteSize: CGFloat {
        return 12.0 * scale
    }
    
    private var stemDirection: CGFloat {
        // Stems go up for notes below middle staff line, down for notes above
        let position = timedNote.staffPosition(in: musicContext)
        return position > 0 ? -1 : 1
    }
}

#Preview {
    let context = MusicContext(keySignature: "C major", clef: .treble, tempo: 120)
    
    VStack(spacing: 20) {
        NoteView(
            timedNote: TimedNote(note: Note.quarter("C4"), startTime: 0),
            musicContext: context
        )
        NoteView(
            timedNote: TimedNote(note: Note.eighth("F#4"), startTime: 0),
            musicContext: context
        )
        NoteView(
            timedNote: TimedNote(note: Note.sixteenth("Bb4"), startTime: 0),
            musicContext: context
        )
        NoteView(
            timedNote: TimedNote(note: Note.quarter("G4"), startTime: 0),
            musicContext: context,
            isActive: true
        )
        NoteView(
            timedNote: TimedNote(note: Note.eighth("D4"), startTime: 0),
            musicContext: context,
            squiggleColor: .orange
        )
    }
    .padding()
}
#else
// Provide a stub for non-SwiftUI platforms
public struct NoteView {
    public init() {}
}
#endif