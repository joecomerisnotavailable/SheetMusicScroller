import SwiftUI

/// View that renders a musical staff with separated fixed gutter and scrolling notes using the new mapping system
struct ScoreView: View {
    let sheetMusic: SheetMusic
    let activeNotes: Set<UUID>
    let scrollOffset: CGFloat
    let staffHeight: CGFloat = 120
    let gutterWidth: CGFloat = 80  // Width of the fixed gutter area
    let squiggleX: CGFloat        // X position of the squiggle for pass/fail detection
    let squiggleColor: Color      // Current squiggle tip color
    let noteColors: [UUID: Color] // Persistent colors for notes that have passed
    let pixelsPerSecond: CGFloat = 100  // Scaling factor for time-to-pixel conversion
    
    init(sheetMusic: SheetMusic, activeNotes: Set<UUID> = Set(), scrollOffset: CGFloat = 0, squiggleX: CGFloat = 80, squiggleColor: Color = .red, noteColors: [UUID: Color] = [:]) {
        self.sheetMusic = sheetMusic
        self.activeNotes = activeNotes
        self.scrollOffset = scrollOffset
        self.squiggleX = squiggleX
        self.squiggleColor = squiggleColor
        self.noteColors = noteColors
    }
    
    /// Parse time signature string (e.g., "4/4", "3/4") into numerator and denominator
    private func parseTimeSignature(_ timeSignature: String) -> (Int, Int) {
        let parts = timeSignature.split(separator: "/")
        if parts.count == 2, let numerator = Int(parts[0]), let denominator = Int(parts[1]) {
            return (numerator, denominator)
        }
        return (4, 4)  // Default to 4/4 if parsing fails
    }
    
    /// Calculate the X position for a note based on its start time and duration
    func calculateNoteXPosition(for timedNote: TimedNote) -> CGFloat {
        return CGFloat(timedNote.startTime) * pixelsPerSecond + gutterWidth + 20 - scrollOffset
    }
    
    var body: some View {
        ZStack {
            // Staff lines using the unified getYFromNoteAndKey positioning system
            GeometryReader { geometry in
                let staffLines = StaffLine.createStaffLines(for: sheetMusic.musicContext.clef)
                ForEach(Array(staffLines.enumerated()), id: \.offset) { index, staffLine in
                    let yPos = StaffPositionMapper.getYFromNoteAndKey(staffLine.noteName, keySignature: sheetMusic.musicContext.keySignature, clef: sheetMusic.musicContext.clef, staffHeight: staffHeight, totalFrameHeight: 220)
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
            
            // The thin fixed vertical bar that the squiggle sits on
            Rectangle()
                .fill(Color.black.opacity(0.7))
                .frame(width: 1, height: staffHeight)
                .position(x: squiggleX, y: 110) // 110 matches mid of 220 frame height
                .accessibilityHidden(true)
            
            // Scrolling notes area
            scrollingNotesView
        }
        .frame(height: 220) // Match the container frame height from SheetMusicScrollerView
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
            
            // Time signature display
            let (numerator, denominator) = parseTimeSignature(sheetMusic.timeSignature)
            TimeSignatureView(numerator: numerator, denominator: denominator, staffHeight: staffHeight)
            
            // Visual separator line for the gutter
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: staffHeight + 40)
        }
        .frame(width: gutterWidth, alignment: .leading)
        .background(Color.white.opacity(0.9))
    }
    
    private var scrollingNotesView: some View {
        ZStack {
            ForEach(sheetMusic.timedNotes) { timedNote in
                let x = calculateNoteXPosition(for: timedNote)
                let isLeftOfBar = x <= squiggleX
                let isActive = activeNotes.contains(timedNote.id)
                let colorOverride: Color? = {
                    if isActive { return squiggleColor }
                    if isLeftOfBar, let c = noteColors[timedNote.id] { return c }
                    return nil
                }()
                
                NoteView(
                    timedNote: timedNote,
                    musicContext: sheetMusic.musicContext,
                    isActive: isActive,
                    squiggleColor: colorOverride
                )
                .position(x: x, y: StaffPositionMapper.getYFromNoteAndKey(
                    timedNote.note.noteName,
                    keySignature: sheetMusic.musicContext.keySignature,
                    clef: sheetMusic.musicContext.clef,
                    staffHeight: staffHeight,
                    totalFrameHeight: 220
                ))
            }
        }
    }
}
