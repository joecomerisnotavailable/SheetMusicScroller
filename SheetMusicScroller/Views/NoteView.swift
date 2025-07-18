import SwiftUI

/// View that renders a single musical note
struct NoteView: View {
    let note: Note
    let isActive: Bool
    let scale: CGFloat
    
    init(note: Note, isActive: Bool = false, scale: CGFloat = 1.0) {
        self.note = note
        self.isActive = isActive
        self.scale = scale
    }
    
    var body: some View {
        ZStack {
            // Note head (filled circle)
            Circle()
                .fill(noteColor)
                .frame(width: noteSize, height: noteSize)
            
            // Accidental symbols (sharp/flat)
            if note.isSharp {
                Text("♯")
                    .font(.system(size: noteSize * 0.8))
                    .foregroundColor(.black)
                    .offset(x: -noteSize * 0.8, y: 0)
            } else if note.isFlat {
                Text("♭")
                    .font(.system(size: noteSize * 0.8))
                    .foregroundColor(.black)
                    .offset(x: -noteSize * 0.8, y: 0)
            }
            
            // Note stem (for eighth and sixteenth notes)
            if note.duration <= 0.25 {
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 1.5, height: noteSize * 3)
                    .offset(x: noteSize * 0.4, y: stemDirection * noteSize * 1.5)
            }
            
            // Beams for sixteenth notes
            if note.duration <= 0.125 {
                Rectangle()
                    .fill(Color.black)
                    .frame(width: noteSize * 0.6, height: 2)
                    .offset(x: noteSize * 0.7, y: stemDirection * noteSize * 2.5)
            }
        }
        .scaleEffect(scale)
        .animation(.easeInOut(duration: 0.1), value: isActive)
    }
    
    private var noteColor: Color {
        if isActive {
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
        return note.position > 0 ? -1 : 1
    }
}

#Preview {
    VStack(spacing: 20) {
        NoteView(note: Note.quarter(pitch: "C4", startTime: 0, position: 0))
        NoteView(note: Note.eighth(pitch: "F#4", startTime: 0, position: -1, isSharp: true))
        NoteView(note: Note.sixteenth(pitch: "Bb4", startTime: 0, position: -0.5, isFlat: true))
        NoteView(note: Note.quarter(pitch: "G4", startTime: 0, position: 0.5), isActive: true)
    }
    .padding()
}