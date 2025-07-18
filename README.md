# SheetMusicScroller

A minimal SwiftUI multiplatform demo application that displays scrolling sheet music with timer-driven playback.

## Features

🎼 **Complete SwiftUI Implementation**
- Models for musical notes and sheet music
- Custom views for rendering notes, staff, and UI controls
- Timer-driven horizontal scrolling animation
- Multiplatform support (iOS and macOS)

🎵 **Musical Content**
- Bach's Partita No. 2 in D minor, Allemande (opening measures)
- Realistic note positioning and timing
- Support for different note durations (quarter, eighth, sixteenth)
- Accidental symbols (sharps and flats)

🎹 **Interactive UI**
- Play/Pause controls
- Reset functionality
- Time display with progress tracking
- Animated cursor squiggle indicating playback position
- Active note highlighting

## Project Structure

```
SheetMusicScroller/
├── Models/
│   ├── Note.swift              # Musical note representation
│   └── SheetMusic.swift        # Sheet music collection
├── Views/
│   ├── NoteView.swift          # Individual note rendering
│   ├── SquiggleView.swift      # Animated cursor
│   ├── ScoreView.swift         # Musical staff and notes
│   └── SheetMusicScrollerView.swift  # Main interface
├── Data/
│   └── BachAllemandeData.swift # Mock Bach Allemande data
├── SheetMusicScrollerApp.swift # App entry point
└── ContentView.swift           # Main content view
```

## Key Components

### Models
- **Note**: Represents individual musical notes with pitch, timing, and position
- **SheetMusic**: Contains collection of notes with metadata (composer, tempo, etc.)

### Views
- **NoteView**: Renders individual notes with stems, beams, and accidentals
- **SquiggleView**: Animated wavy cursor indicating playback position
- **ScoreView**: Musical staff with positioned notes and ledger lines
- **SheetMusicScrollerView**: Main interface with playback controls

### Data
- **BachAllemandeData**: Mock data representing Bach's Partita No. 2 Allemande opening

## How to Build and Run

### Prerequisites
- Xcode 15.0 or later
- iOS 16.0+ or macOS 13.0+

### Building
1. Open `SheetMusicScroller.xcodeproj` in Xcode
2. Select your target device (iOS Simulator or macOS)
3. Build and run (⌘R)

### Testing Models
You can validate the core models work correctly by running:
```bash
swift validate.swift
```

## Features Implemented

✅ **Core Models**
- Note structure with pitch, timing, and position
- SheetMusic collection with metadata
- Helper methods for different note durations

✅ **UI Components**
- Custom note rendering with stems and accidentals
- Musical staff with 5 lines and treble clef
- Animated cursor with gradient coloring
- Play/pause/reset controls

✅ **Functionality**
- Timer-driven scrolling animation
- Real-time note highlighting
- Time display and progress tracking
- Multiplatform SwiftUI support

✅ **Data**
- Bach Allemande excerpt with realistic timing
- Proper note positioning on staff
- Support for various note durations

## Demo Content

The app includes the opening measures of Bach's Partita No. 2 in D minor, Allemande:
- **Tempo**: 120 BPM
- **Time Signature**: 4/4
- **Key**: D minor
- **Duration**: ~6 seconds of music
- **Notes**: Mix of sixteenth, eighth, and quarter notes

## Architecture

This demo uses a clean SwiftUI architecture:
- **Models**: Pure Swift structs for data representation
- **Views**: SwiftUI views with clear separation of concerns
- **Data**: Static mock data for demonstration
- **Timer**: SwiftUI Timer for driving animations

## Future Enhancements

This minimal demo provides a foundation for:
- Audio playback integration
- Pitch detection and following
- MIDI input/output
- More complex musical notation
- Multi-voice/polyphonic support
- Real-time music analysis

## License

This is a demonstration project created for educational purposes.
