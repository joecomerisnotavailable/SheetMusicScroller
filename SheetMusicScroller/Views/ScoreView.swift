import SwiftUI

/// View that renders a musical staff with notes
struct ScoreView: View {
    let notes: [Note]
    let activeNotes: Set<UUID>
    let scrollOffset: CGFloat
    let staffHeight: CGFloat = 120
    let noteSpacing: CGFloat = 60
    
    init(notes: [Note], activeNotes: Set<UUID> = Set(), scrollOffset: CGFloat = 0) {
        self.notes = notes
        self.activeNotes = activeNotes
        self.scrollOffset = scrollOffset
    }
    
    var body: some View {
        ZStack {
            // Staff lines (5 horizontal lines)
            VStack(spacing: staffHeight / 6) {
                ForEach(0..<5, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 1)
                }
            }
            .frame(height: staffHeight)
            
            // Treble clef symbol (approximation)
            HStack {
                Text("𝄞")
                    .font(.system(size: 60))
                    .foregroundColor(.black)
                    .padding(.trailing, 20)
                
                Spacer()
            }
            
            // Notes positioned on the staff
            ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                let xPosition = CGFloat(index) * noteSpacing + 80 - scrollOffset
                let yPosition = noteYPosition(for: note.position)
                
                NoteView(
                    note: note,
                    isActive: activeNotes.contains(note.id),
                    scale: 1.0
                )
                .position(x: xPosition, y: yPosition)
                
                // Ledger lines for notes above or below the staff
                if needsLedgerLines(for: note.position) {
                    ForEach(ledgerLinePositions(for: note.position), id: \.self) { lineY in
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: 20, height: 1)
                            .position(x: xPosition, y: lineY)
                    }
                }
            }
        }
        .frame(height: staffHeight + 60) // Extra space for notes above/below staff
        .clipped()
    }
    
    // Convert note position to Y coordinate on staff
    private func noteYPosition(for position: CGFloat) -> CGFloat {
        let staffCenter = staffHeight / 2
        let lineSpacing = staffHeight / 6
        return staffCenter + (position * lineSpacing)
    }
    
    // Determine if a note needs ledger lines
    private func needsLedgerLines(for position: CGFloat) -> Bool {
        return position < -2.5 || position > 2.5
    }
    
    // Calculate positions for ledger lines
    private func ledgerLinePositions(for position: CGFloat) -> [CGFloat] {
        var positions: [CGFloat] = []
        let lineSpacing = staffHeight / 6
        let staffCenter = staffHeight / 2
        
        if position < -2.5 {
            // Lines above the staff
            let startLine = Int(floor(position / 0.5)) * -1
            for i in stride(from: startLine, through: 5, by: 1) {
                if i % 2 == 1 { // Only on line positions
                    positions.append(staffCenter - CGFloat(i) * lineSpacing / 2)
                }
            }
        } else if position > 2.5 {
            // Lines below the staff
            let startLine = Int(ceil(position / 0.5))
            for i in stride(from: startLine, through: 6, by: 1) {
                if i % 2 == 1 { // Only on line positions
                    positions.append(staffCenter + CGFloat(i) * lineSpacing / 2)
                }
            }
        }
        
        return positions
    }
}

#Preview {
    let sampleNotes = [
        Note.quarter(pitch: "C4", startTime: 0, position: 2.0),
        Note.eighth(pitch: "E4", startTime: 0.5, position: 1.0),
        Note.sixteenth(pitch: "G4", startTime: 0.75, position: 0.5),
        Note.quarter(pitch: "C5", startTime: 1.0, position: -1.0),
        Note.eighth(pitch: "E5", startTime: 1.5, position: -1.5),
    ]
    
    ScoreView(notes: sampleNotes, activeNotes: Set([sampleNotes[0].id, sampleNotes[2].id]))
        .padding()
        .background(Color.white)
}