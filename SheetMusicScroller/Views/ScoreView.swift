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
            // Staff lines using the new positioning system
            let staffLines = StaffLine.createStaffLines(for: sheetMusic.musicContext.clef)
            ForEach(Array(staffLines.enumerated()), id: \.offset) { index, staffLine in
                Rectangle()
                    .fill(Color.black)
                    .frame(width: UIScreen.main.bounds.width, height: 1)
                    .position(x: UIScreen.main.bounds.width / 2, y: StaffPositionMapper.getYFromNoteAndKey(staffLine.noteName, keySignature: sheetMusic.musicContext.keySignature, clef: sheetMusic.musicContext.clef, staffHeight: staffHeight))
            }
            
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
            // Clef symbol with proper positioning and sizing
            ZStack {
                Text(clefSymbol)
                    .font(.system(size: clefFontSize))
                    .foregroundColor(.black)
                    .offset(x: 0, y: clefVerticalOffset)
            }
            .frame(width: 40, height: staffHeight)
            
            // Key signature display using positioning system
            keySignatureView
            
            // Visual separator line for the gutter
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: staffHeight + 40)
        }
        .frame(width: gutterWidth)
        .background(Color.white.opacity(0.9))
    }
    
    private var clefFontSize: CGFloat {
        // Treble clef should be much larger relative to staff - about 75% of staff height
        let staffHeight: CGFloat = 120
        switch sheetMusic.musicContext.clef {
        case .treble: return staffHeight * 0.8  // Larger treble clef
        case .bass: return staffHeight * 0.6
        case .alto: return staffHeight * 0.5
        case .tenor: return staffHeight * 0.5
        }
    }
    
    private var clefVerticalOffset: CGFloat {
        switch sheetMusic.musicContext.clef {
        case .treble: 
            // Treble clef: large curl should be centered on G4 line
            // Use getYFromNoteAndKey to get G4 position
            let g4YPosition = StaffPositionMapper.getYFromNoteAndKey("G4", keySignature: sheetMusic.musicContext.keySignature, clef: sheetMusic.musicContext.clef, staffHeight: staffHeight)
            let staffCenter = staffHeight / 2
            return g4YPosition - staffCenter - 10  // Adjust by -10 to center the curl properly
        case .bass: return 0
        case .alto: return 0
        case .tenor: return 0
        }
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
        ZStack {
            // Key signature accidentals using positioning system
            let accidentals = KeySignatureAccidental.createDMinorAccidentals(for: sheetMusic.musicContext.clef)
            ForEach(Array(accidentals.enumerated()), id: \.offset) { index, accidental in
                Text(accidental.symbol)
                    .font(.system(size: 20))
                    .foregroundColor(.black)
                    .position(x: 15, y: StaffPositionMapper.getYFromNoteAndKey(accidental.noteName, keySignature: sheetMusic.musicContext.keySignature, clef: sheetMusic.musicContext.clef, staffHeight: staffHeight))
            }
        }
        .frame(width: 30, height: staffHeight)
    }
    
    private var scrollingNotesView: some View {
        // Notes positioned on the staff - they scroll horizontally
        ForEach(Array(sheetMusic.timedNotes.enumerated()), id: \.element.id) { index, timedNote in
            let xPosition = CGFloat(index) * noteSpacing + gutterWidth + 20 - scrollOffset
            let yPosition = StaffPositionMapper.getYFromNoteAndKey(timedNote.note.noteName, keySignature: sheetMusic.musicContext.keySignature, clef: sheetMusic.musicContext.clef, staffHeight: staffHeight)
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
                
                // Ledger lines for notes above or below the staff using unified mapping system
                let staffPosition = timedNote.staffPosition(in: sheetMusic.musicContext)
                let ledgerLines = StaffPositionMapper.getLedgerLinesCount(for: staffPosition)
                if ledgerLines > 0 {
                    let ledgerPositions = StaffPositionMapper.getLedgerLinePositions(for: staffPosition)
                    ForEach(Array(ledgerPositions.enumerated()), id: \.offset) { _, linePosition in
                        // Create a temporary note name for this ledger line position to get consistent Y positioning
                        let ledgerMidi = StaffPositionMapper.staffPositionToMidiNote(linePosition, clef: sheetMusic.musicContext.clef)
                        let ledgerNoteName = StaffPositionMapper.midiNoteToNoteName(ledgerMidi)
                        let ledgerY = StaffPositionMapper.getYFromNoteAndKey(ledgerNoteName, keySignature: sheetMusic.musicContext.keySignature, clef: sheetMusic.musicContext.clef, staffHeight: staffHeight)
                        
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: 20, height: 1)
                            .position(x: xPosition, y: ledgerY)
                    }
                }
            }
            .opacity(xPosition > -50 ? 1 : 0) // Fade out notes that have scrolled too far left
        }
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