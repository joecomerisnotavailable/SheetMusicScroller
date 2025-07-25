# Image-Based Musical Symbol Rendering

This document describes the new image-based approach for rendering clefs and accidentals in the SheetMusicScroller app.

## Overview

The app has been updated to replace Unicode symbol rendering (𝄞, 𝄢, ♯, ♭) with image assets that provide:
- Precise origin-based placement 
- Fixed pixel height scaling
- Consistent visual alignment with staff positioning system
- Better cross-platform compatibility

## Architecture

### Core Components

1. **MusicalSymbolImageManager.swift** - Central utility for managing musical symbol images
2. **Assets.xcassets/Clefs/** - Image assets for all clef types
3. **Assets.xcassets/Accidentals/** - Image assets for all accidental types

### Image Asset Structure

```
Assets.xcassets/
├── Clefs/
│   ├── TrebleClef.imageset/
│   ├── BassClef.imageset/
│   ├── AltoClef.imageset/
│   └── TenorClef.imageset/
└── Accidentals/
    ├── Sharp.imageset/
    ├── Flat.imageset/
    └── Natural.imageset/
```

## Origin-Based Positioning System

### Key Principle
Each image has a defined **origin point (0,0)** that aligns with the musical reference:
- **Treble clef**: Origin at the center of the G4 curl
- **Bass clef**: Origin at the F3 line center
- **Flat accidental**: Origin at the center of the B4 ring/loop
- **Sharp accidental**: Origin at the center intersection

### Implementation Details

The `MusicalSymbolImageManager` handles origin positioning through:

```swift
// Calculate where to position the image so its origin aligns correctly
let imageY = referenceY + (targetHeight / 2) - originOffsetFromBottom
```

Where:
- `referenceY`: Target Y coordinate from `StaffPositionMapper.getYFromNoteAndKey()`
- `targetHeight`: Desired image height in pixels
- `originOffsetFromBottom`: Distance from bottom of image to origin point

## Usage Examples

### Clef Rendering (ScoreView.swift)

```swift
// Replace Unicode clef symbol
let clefHeight = MusicalSymbolImageManager.calculateClefImageHeight(for: clef, staffHeight: staffHeight)
let clefOriginPos = MusicalSymbolImageManager.calculateClefOriginPosition(for: clef, ...)

MusicalSymbolImageManager.clefImageView(
    for: sheetMusic.musicContext.clef,
    targetHeight: clefHeight,
    at: clefOriginPos
)
```

### Accidental Rendering

```swift
// Replace Unicode accidental symbol
MusicalSymbolImageManager.accidentalImageView(
    for: accidental,
    targetHeight: 20,
    at: position
)
```

## Migration Changes

### Removed Code
- `clefSymbol` computed property (Unicode symbols)
- `clefFontSize` complex calculation
- `clefVerticalOffset` complex positioning
- Unicode-based `Text()` views for accidentals

### Added Code
- `MusicalSymbolImageManager` utility class
- Image asset directory structure
- Origin-based positioning calculations
- Image view helpers with proper scaling

## Benefits

1. **Precise Alignment**: Origin-based positioning ensures exact alignment with staff lines
2. **Scalability**: Images scale properly without affecting origin alignment
3. **Consistency**: Uniform approach for all musical symbols
4. **Maintainability**: Centralized image management
5. **Future-Proof**: Easy to add new symbols or replace existing assets

## Testing

The positioning logic has been validated with unit tests confirming:
- Origin calculations are mathematically correct
- Image positioning aligns origins with reference points
- Scaling preserves origin alignment

## Future Enhancements

1. Replace placeholder images with professional musical font symbols
2. Add support for additional accidentals (double sharp, double flat)
3. Implement image caching for performance
4. Add vector-based assets for perfect scaling at any resolution