# Error Log - SheetMusicScroller

## Corrected Errors

### 1. Frequency Mapping Inversion (Fixed in commit e7a0430)
**Error**: Higher frequencies appeared lower on screen instead of higher
**Files Modified**: 
- `SheetMusicScroller/PitchDetector.swift` - Line 354: Changed `(midi - c5) * 0.5` to `-(midi - c5) * 0.5`
- `SheetMusicScroller/Views/SheetMusicScrollerView.swift` - Squiggle Y position calculation
**Code Reference**: 
```swift
// BEFORE (incorrect):
let staffPosition = (midi - c5) * 0.5
// AFTER (correct):
let staffPosition = -(midi - c5) * 0.5
```

### 2. Incorrect Reference Note in Frequency Calculation (Fixed in commit e7a0430)
**Error**: Used C4 as reference instead of C5, causing wrong positioning
**Files Modified**: 
- `SheetMusicScroller/PitchDetector.swift` - Line 353: Changed reference from C4 to C5
**Code Reference**:
```swift
// BEFORE (incorrect):
let c4 = 60.0
let staffPosition = -(midi - c4) * 0.5
// AFTER (correct):
let c5 = 72.0
let staffPosition = -(midi - c5) * 0.5
```

### 3. Incorrect Treble Clef Frequency Mappings (Fixed in commit [CURRENT])
**Error**: Frequency-to-staff-position mapping was off by significant amounts for most notes
**Files Modified**:
- `SheetMusicScroller/PitchDetector.swift` - Lines 339-357: Completely rewrote frequency mapping based on actual treble clef note frequencies
**Code Reference**:
```swift
// BEFORE (incorrect scale factor):
let staffPosition = -(midi - c5) * 0.5
// AFTER (correct treble clef mapping):
let a4Midi = 69.0
let a4Position = 0.5
let semitoneSpacing = 0.3  // Each semitone ≈ 0.3 staff position units
let staffPosition = a4Position - (midi - a4Midi) * semitoneSpacing
```

### 4. Incorrect Key Signature Positioning (Fixed in commit [CURRENT])
**Error**: Flat symbol was positioned incorrectly, not on the center line where Bb4 should be
**Files Modified**:
- `SheetMusicScroller/Views/ScoreView.swift` - Lines 54-62: Fixed flat symbol positioning to center line
**Code Reference**:
```swift
// BEFORE (incorrect offset):
.offset(y: -staffHeight * 0.15) // Position on B line
// AFTER (correct center line positioning):
.position(x: 25, y: staffHeight / 2) // Center line (position 0.0 for B4/Bb4)
```

### 5. Oversimplified Frequency-to-Staff Mapping (Fixed in commit [CURRENT])
**Error**: Used linear 0.3 semitone spacing instead of proper musical intervals
**Issue**: In music theory, each staff position (line to space) is either 1 semitone OR 2 semitones (whole tone), never fractional values like 0.3 semitones
**Files Modified**:
- `SheetMusicScroller/PitchDetector.swift` - Lines 339-361: Replace linear mapping with proper treble clef note positions
**Code Reference**:
```swift
// BEFORE (incorrect - linear spacing):
let semitoneSpacing = 0.3  // Each semitone ≈ 0.3 staff position units
let staffPosition = a4Position - (midi - a4Midi) * semitoneSpacing
// AFTER (correct - discrete note positions with interpolation):
let notePositions: [Int: Double] = [
    69: 0.5,   // A4 - second space 
    70: 0.0,   // Bb4 - center line (D Minor)
    74: -1.0,  // D5 - fourth line
    // ... other treble clef positions
]
```

**Do not reproduce these errors:**
- Do not invert frequency-to-screen position mapping (higher frequencies must appear higher on screen)
- Do not use incorrect reference notes in MIDI calculations
- Do not ignore coordinate system conventions (lower Y values = higher on screen)
- Do not use linear semitone spacing (like 0.3) for frequency-to-staff mapping - use discrete note positions
- Do not position key signature symbols arbitrarily - they must align with actual staff note positions
- Do not ignore musical theory: staff positions represent either 1 or 2 semitone intervals, never fractional