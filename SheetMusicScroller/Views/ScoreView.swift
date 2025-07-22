import SwiftUI

/// View that renders a musical staff with separated fixed gutter and scrolling notes
struct ScoreView: View {
    let notes: [Note]
    let activeNotes: Set<UUID>
    let scrollOffset: CGFloat
    let staffHeight: CGFloat = 120
    let noteSpacing: CGFloat = 60
    let gutterWidth: CGFloat = 80  // Width of the fixed gutter area
    let squiggleX: CGFloat        // X position of the squiggle for pass/fail detection
    let squiggleColor: Color      // Current squiggle tip color
    
    init(notes: [Note], activeNotes: Set<UUID> = Set(), scrollOffset: CGFloat = 0, squiggleX: CGFloat = 80, squiggleColor: Color = .red) {
        self.notes = notes
        self.activeNotes = activeNotes
        self.scrollOffset = scrollOffset
        self.squiggleX = squiggleX
        self.squiggleColor = squiggleColor
    }
    
    var body: some View {
        ZStack {
            // Staff lines that extend across the full width
            VStack(spacing: staffHeight / 6) {
                ForEach(0..<5, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 1)
                }
            }
            .frame(height: staffHeight)
            
            // Fixed gutter with treble clef and key signature
            HStack {
                fixedGutterView
                Spacer()
            }
            
            // Scrolling notes area
            scrollingNotesView
        }
        .frame(height: staffHeight + 60) // Extra space for notes above/below staff
        .clipped()
    }
    
    private var fixedGutterView: some View {
        HStack(spacing: 10) {
            // Treble clef symbol
            Text("𝄞")
                .font(.system(size: 60))
                .foregroundColor(.black)
            
            // Key signature (D minor - Bb)
            // Position the flat symbol on the center line (B4/Bb4 position)
            ZStack {
                Text("♭")
                    .font(.system(size: 20))
                    .foregroundColor(.black)
                    .position(x: 25, y: staffHeight / 2) // Center line (position 0.0 for B4/Bb4)
            }
            .frame(width: 30, height: staffHeight)
            
            // Visual separator line for the gutter
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: staffHeight + 40)
        }
        .frame(width: gutterWidth)
        .background(Color.white.opacity(0.9))
    }
    
    private var scrollingNotesView: some View {
        // Notes positioned on the staff - they scroll horizontally
        ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
            let xPosition = CGFloat(index) * noteSpacing + gutterWidth + 20 - scrollOffset
            let yPosition = noteYPosition(for: note.position)
            let hasPassedSquiggle = xPosition <= squiggleX
            
            Group {
                NoteView(
                    note: note,
                    isActive: activeNotes.contains(note.id),
                    squiggleColor: hasPassedSquiggle ? squiggleColor : nil,
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
            .opacity(xPosition > -50 ? 1 : 0) // Fade out notes that have scrolled too far left
        }
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
    
    ScoreView(
        notes: sampleNotes, 
        activeNotes: Set([sampleNotes[0].id, sampleNotes[2].id]),
        scrollOffset: 0,
        squiggleX: 80,
        squiggleColor: .red
    )
    .padding()
    .background(Color.white)
}