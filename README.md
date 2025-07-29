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

## Squiggle Drawing and Pitch Detection Improvements

### Enhanced Squiggle Drawing
The app features improved squiggle (pitch trace) rendering with:

- **Smooth Curve Interpolation**: Replaced linear interpolation with Catmull-Rom spline curves for a more organic, crayon-like appearance
- **Configurable Drawing Parameters**: 
  - `useSmoothCurves`: Enable/disable smooth curve rendering
  - `lineWidth`: Adjustable stroke width for the squiggle path
  - `tipSize`: Configurable tip size that matches the path width
  - `smoothingFactor`: Control curve smoothness (0.0 = linear, 1.0 = maximum smoothing)
  - `useRoundLineCaps`: Round line caps for improved visual appearance

### Pitch Detection Stability
Enhanced pitch detection with configurable filtering and smoothing:

- **Median Filtering**: Reduces jitter from spurious outliers with configurable window size (1-15 samples)
- **Frequency Smoothing**: Exponential smoothing for stable frequency readings (0.0-0.95 factor)
- **Runtime Frame Size Adjustment**: Analysis window size configurable from 256-4096 samples
- **Real-time Configuration**: UI sliders for experimentation with different parameters

### Configuration Options

#### Frame Size Effects:
- **Smaller frames (256-512)**: Lower latency, less accuracy, more noise sensitivity
- **Medium frames (1024-2048)**: Balanced latency and accuracy (recommended)
- **Larger frames (2048-4096)**: Higher accuracy, increased latency, better noise rejection

#### Smoothing Trade-offs:
- **Median Filter Window**: Larger windows reduce jitter but increase response delay
- **Frequency Smoothing**: Higher factors provide stability but may lag rapid pitch changes
- **Combined Use**: Both filters can be used together for optimal results

#### Recommended Settings:
- **Real-time Performance**: Frame size 1024, median window 3-5, smoothing 0.5-0.7
- **High Accuracy**: Frame size 2048, median window 5-7, smoothing 0.7-0.8
- **Low Latency**: Frame size 512, median window 1-3, smoothing 0.3-0.5

### UI Controls
The app includes interactive controls for:
- Analysis frame size slider (affects pitch detection accuracy vs latency)
- Median filter window size (reduces jitter from outliers)
- Frequency smoothing factor (exponential smoothing for stability)
- Enable/disable toggles for filtering options
- Clear filter history button to reset smoothing buffers

### Technical Implementation Notes

#### Texture Overlay Approach (Optional Enhancement):
For adding crayon/pencil texture effects, consider these modular approaches:
1. **Custom Shader**: Use Metal shaders to apply texture along the path
2. **Texture Masking**: Composite a texture image with the squiggle using blend modes
3. **Pattern Overlay**: Use Core Graphics patterns or SwiftUI overlays
4. **PencilKit Integration**: For iOS, PencilKit provides natural drawing textures

**Implementation Strategy**: Create a `TextureOverlayConfig` struct with texture image, blend mode, and opacity parameters. Apply using SwiftUI's `.overlay()` modifier with custom texture rendering.

#### Performance Considerations:
- Smooth curve calculations are optimized for real-time rendering
- History point management prevents memory growth
- Filtering operations use efficient algorithms suitable for audio rate processing
- UI updates are throttled to prevent excessive redraws

## License

This is a demonstration project created for educational purposes.
