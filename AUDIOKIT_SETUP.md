# AudioKit Integration Instructions

This document provides instructions for adding AudioKit to the SheetMusicScroller Xcode project to enable real-time pitch detection.

## Adding AudioKit via Swift Package Manager in Xcode

1. Open `SheetMusicScroller.xcodeproj` in Xcode
2. Select the project in the navigator (top-level item)
3. Select the "SheetMusicScroller" target
4. Go to the "Package Dependencies" tab
5. Click the "+" button to add a package dependency
6. Add the following packages:

### AudioKit Core
- URL: `https://github.com/AudioKit/AudioKit.git`
- Version: `5.6.0` or later
- Add to target: SheetMusicScroller

### AudioKit Extensions  
- URL: `https://github.com/AudioKit/AudioKitEX.git`
- Version: `5.6.0` or later
- Add to target: SheetMusicScroller

## Info.plist Configuration

The `Info.plist` file has already been created with the necessary microphone usage description:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs access to the microphone for real-time pitch detection to synchronize the sheet music display with your playing.</string>
```

## Code Integration

The following files have been modified to support real-time pitch detection:

- `PitchDetector.swift` - New service for AudioKit pitch tracking
- `SheetMusicScrollerView.swift` - Updated to support pitch mode
- `SquiggleView.swift` - Modified to handle pitch-based positioning
- `Info.plist` - Added microphone permissions

## Features Added

1. **Mode Toggle**: Switch between time-based playback and live pitch detection
2. **Real-time Pitch Display**: Shows current frequency, note name, and amplitude
3. **Live Squiggle Movement**: Squiggle tip follows detected pitch in real-time
4. **Visual Feedback**: Color-coded squiggle based on signal strength
5. **Cross-platform Support**: Works on both macOS and iOS
6. **Future-ready**: Structured for chord detection extension

## Usage

1. Launch the app
2. Toggle to "Live Pitch" mode
3. Tap the microphone button to start listening
4. Grant microphone permission when prompted
5. Play an instrument or sing - the squiggle will move based on detected pitch

## Troubleshooting

- If AudioKit is not available, the app falls back to mock pitch detection for testing
- Ensure microphone permissions are granted in system settings
- Check that the correct AudioKit versions are installed