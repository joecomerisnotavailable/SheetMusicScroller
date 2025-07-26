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
    let noteColors: [UUID: Color] // Persistent colors for notes that have passed
    
    init(sheetMusic: SheetMusic, activeNotes: Set<UUID> = Set(), scrollOffset: CGFloat = 0, squiggleX: CGFloat = 80, squiggleColor: Color = .red, noteColors: [UUID: Color] = [:]) {
        self.sheetMusic = sheetMusic
        self.activeNotes = activeNotes
        self.scrollOffset = scrollOffset
        self.squiggleX = squiggleX
        self.squiggleColor = squiggleColor
        self.noteColors = noteColors
    }
    
    var body: some View {
        ZStack {
            // Staff lines using the unified getYFromNoteAndKey positioning system
            GeometryReader { geometry in
                let staffLines = StaffLine.createStaffLines(for: sheetMusic.musicContext.clef)
                ForEach(Array(staffLines.enumerated()), id: \.offset) { index, staffLine in
                    let yPos = StaffPositionMapper.getYFromNoteAndKey(staffLine.noteName, keySignature: sheetMusic.musicContext.keySignature, clef: sheetMusic.musicContext.clef, staffHeight: staffHeight)
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: geometry.size.width, height: 1)
                        .position(x: geometry.size.width / 2, y: yPos)
                }
            }
            
            // Fixed gutter with clef and key signature
            HStack {
                fixedGutterView
                Spacer()
            }
            
            // Scrolling notes area
            scrollingNotesView
        }
        .frame(height: staffHeight + 80) // Extra space for notes above/below staff and ledger lines
        .clipped()
    }
    
    private var fixedGutterView: some View {
        HStack(spacing: 10) {
            // Clef image with origin-based positioning
            ZStack {
                let clefHeight = MusicalSymbolImageManager.calculateClefImageHeight(for: sheetMusic.musicContext.clef, staffHeight: staffHeight)
                let clefOriginPos = MusicalSymbolImageManager.calculateClefOriginPosition(
                    for: sheetMusic.musicContext.clef,
                    keySignature: sheetMusic.musicContext.keySignature,
                    staffHeight: staffHeight,
                    xPosition: 20  // Center within the 40pt frame
                )
                
                MusicalSymbolImageManager.clefImageView(
                    for: sheetMusic.musicContext.clef,
                    targetHeight: clefHeight,
                    at: clefOriginPos
                )
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

    
    private var keySignatureView: some View {
        ZStack {
            // Key signature accidentals using image assets
            let accidentals = KeySignatureAccidental.createDMinorAccidentals(for: sheetMusic.musicContext.clef)
            ForEach(Array(accidentals.enumerated()), id: \.offset) { index, accidental in
                let yPos = StaffPositionMapper.getYFromNoteAndKey(accidental.noteName, keySignature: sheetMusic.musicContext.keySignature, clef: sheetMusic.musicContext.clef, staffHeight: staffHeight)
                let position = CGPoint(x: 15, y: yPos)
                
                MusicalSymbolImageManager.accidentalImageView(
                    for: accidental.symbol,
                    targetHeight: 20,
                    at: position
                )
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
            
            // Determine note color: use persistent color if available, current squiggle color if just passed, or default
            let noteDisplayColor: Color? = {
                if let persistentColor = noteColors[timedNote.id] {
                    return persistentColor  // Use stored color for notes that have passed
                } else if hasPassedSquiggle {
                    return squiggleColor    // Use current squiggle color for newly passed notes
                } else {
                    return nil  // No special color for notes that haven't reached squiggle
                }
            }()
            
            Group {
                NoteView(
                    timedNote: timedNote,
                    musicContext: sheetMusic.musicContext,
                    isActive: activeNotes.contains(timedNote.id),
                    squiggleColor: noteDisplayColor,
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
        squiggleColor: .red,
        noteColors: [:]
    )
    .padding()
    .background(Color.white)
}