import SwiftUI

/// View that renders a musical staff with separated fixed gutter and scrolling notes using the new mapping system
struct ScoreView: View {
    let sheetMusic: SheetMusic
    let activeNotes: Set<UUID>
    let scrollOffset: CGFloat
    let staffHeight: CGFloat = 120
    let noteSpacing: CGFloat = 60
    let gutterWidth: CGFloat = 80  // Width of the fixed gutter area
    let squiggleX: CGFloat        // X position of the squiggle for pass/fail detection
    let squiggleColor: Color      // Current squiggle tip color
    
    init(sheetMusic: SheetMusic, activeNotes: Set<UUID> = Set(), scrollOffset: CGFloat = 0, squiggleX: CGFloat = 80, squiggleColor: Color = .red) {
        self.sheetMusic = sheetMusic
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
            
            // Fixed gutter with clef and key signature
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
            // Clef symbol
            Text(clefSymbol)
                .font(.system(size: 60))
                .foregroundColor(.black)
            
            // Key signature display (simplified for now)
            keySignatureView
            
            // Visual separator line for the gutter
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: staffHeight + 40)
        }
        .frame(width: gutterWidth)
        .background(Color.white.opacity(0.9))
    }
    
    private var clefSymbol: String {
        switch sheetMusic.musicContext.clef {
        case .treble: return "𝄞"
        case .bass: return "𝄢"
        case .alto: return "𝄡"
        case .tenor: return "𝄡"  // Tenor clef uses same symbol as alto, just positioned differently
        }
    }
    
    private var keySignatureView: some View {
        VStack {
            // Simplified key signature display - just show if it contains sharps or flats
            if sheetMusic.musicContext.keySignature.contains("♯") || sheetMusic.musicContext.keySignature.contains("#") {
                Text("♯")
                    .font(.system(size: 20))
                    .foregroundColor(.black)
                    .offset(y: -staffHeight * 0.1)
            } else if sheetMusic.musicContext.keySignature.contains("♭") || sheetMusic.musicContext.keySignature.contains("b") {
                Text("♭")
                    .font(.system(size: 20))
                    .foregroundColor(.black)
                    .offset(y: -staffHeight * 0.15)
            }
            Spacer()
        }
        .frame(height: staffHeight)
    }
    
    private var scrollingNotesView: some View {
        // Notes positioned on the staff - they scroll horizontally
        ForEach(Array(sheetMusic.timedNotes.enumerated()), id: \.element.id) { index, timedNote in
            let xPosition = CGFloat(index) * noteSpacing + gutterWidth + 20 - scrollOffset
            let staffPosition = timedNote.staffPosition(in: sheetMusic.musicContext)
            let yPosition = noteYPosition(for: staffPosition)
            let hasPassedSquiggle = xPosition <= squiggleX
            
            Group {
                NoteView(
                    timedNote: timedNote,
                    musicContext: sheetMusic.musicContext,
                    isActive: activeNotes.contains(timedNote.id),
                    squiggleColor: hasPassedSquiggle ? squiggleColor : nil,
                    scale: 1.0
                )
                .position(x: xPosition, y: yPosition)
                
                // Ledger lines for notes above or below the staff using new mapping system
                let ledgerLines = StaffPositionMapper.getLedgerLinesCount(for: staffPosition)
                if ledgerLines > 0 {
                    let ledgerPositions = StaffPositionMapper.getLedgerLinePositions(for: staffPosition)
                    ForEach(Array(ledgerPositions.enumerated()), id: \.offset) { _, linePosition in
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: 20, height: 1)
                            .position(x: xPosition, y: noteYPosition(for: linePosition))
                    }
                }
            }
            .opacity(xPosition > -50 ? 1 : 0) // Fade out notes that have scrolled too far left
        }
    }
    
    // Convert note position to Y coordinate on staff
    private func noteYPosition(for position: Double) -> CGFloat {
        let staffCenter = staffHeight / 2
        let lineSpacing = staffHeight / 6
        return staffCenter + (CGFloat(position) * lineSpacing)
    }
}

#Preview {
    // Create sample sheet music using the new system
    let context = MusicContext(keySignature: "D minor", clef: .treble, tempo: 120)
    let sampleNotes = [
        TimedNote(note: Note.quarter("C4"), startTime: 0),
        TimedNote(note: Note.eighth("E4"), startTime: 0.5),
        TimedNote(note: Note.sixteenth("G4"), startTime: 0.75),
        TimedNote(note: Note.quarter("C5"), startTime: 1.0),
        TimedNote(note: Note.eighth("E5"), startTime: 1.5),
    ]
    
    let sampleMusic = SheetMusic(
        title: "Sample",
        composer: "Test",
        musicContext: context,
        timeSignature: "4/4",
        timedNotes: sampleNotes
    )
    
    ScoreView(
        sheetMusic: sampleMusic,
        activeNotes: Set([sampleNotes[0].id, sampleNotes[2].id]),
        scrollOffset: 0,
        squiggleX: 80,
        squiggleColor: .red
    )
    .padding()
    .background(Color.white)
}