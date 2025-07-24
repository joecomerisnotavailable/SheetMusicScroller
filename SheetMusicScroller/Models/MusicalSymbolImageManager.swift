import SwiftUI

/// Utility for loading and positioning musical symbol images with origin-based placement
struct MusicalSymbolImageManager {
    
    /// Represents a clef image with its positioning information
    struct ClefImageInfo {
        let imageName: String
        let originOffsetFromBottom: CGFloat  // Distance from bottom of image to origin point
        let referenceNoteName: String        // Note that the origin should align with
    }
    
    /// Represents an accidental image with its positioning information
    struct AccidentalImageInfo {
        let imageName: String
        let originOffsetFromBottom: CGFloat  // Distance from bottom of image to origin point
    }
    
    /// Clef image configurations with origin positioning information
    static let clefImages: [Clef: ClefImageInfo] = [
        .treble: ClefImageInfo(
            imageName: "TrebleClef",
            originOffsetFromBottom: 10,  // Origin at bottom loop (y=90 in 100px image)
            referenceNoteName: "G4"
        ),
        .bass: ClefImageInfo(
            imageName: "BassClef", 
            originOffsetFromBottom: 40,  // Origin at F3 position
            referenceNoteName: "F3"
        ),
        .alto: ClefImageInfo(
            imageName: "AltoClef",
            originOffsetFromBottom: 50,  // Origin at C4 position
            referenceNoteName: "C4"
        ),
        .tenor: ClefImageInfo(
            imageName: "TenorClef",
            originOffsetFromBottom: 40,  // Origin at A3 position
            referenceNoteName: "A3"
        )
    ]
    
    /// Accidental image configurations
    static let accidentalImages: [String: AccidentalImageInfo] = [
        "♯": AccidentalImageInfo(imageName: "Sharp", originOffsetFromBottom: 20), // Origin at center intersection
        "♭": AccidentalImageInfo(imageName: "Flat", originOffsetFromBottom: 5),  // Origin at bottom loop (y=35 in 40px image)
        "♮": AccidentalImageInfo(imageName: "Natural", originOffsetFromBottom: 20) // Origin at center
    ]
    
    /// Creates a properly positioned clef image view
    /// - Parameters:
    ///   - clef: The clef type
    ///   - targetHeight: Desired height in pixels for the image
    ///   - position: The target position where the origin should be placed
    /// - Returns: A SwiftUI Image view positioned correctly
    static func clefImageView(for clef: Clef, targetHeight: CGFloat, at position: CGPoint) -> some View {
        guard let clefInfo = clefImages[clef] else {
            return AnyView(EmptyView())
        }
        
        // Calculate the correct position for the image center
        // If origin is originOffsetFromBottom pixels from the bottom, 
        // and we want origin at position.y, then:
        // - Bottom of image should be at: position.y - originOffsetFromBottom
        // - Center of image should be at: position.y - originOffsetFromBottom + (targetHeight / 2)
        let imageCenterY = position.y - clefInfo.originOffsetFromBottom + (targetHeight / 2)
        
        return AnyView(
            Image(clefInfo.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: targetHeight)
                .position(
                    x: position.x,
                    y: imageCenterY
                )
        )
    }
    
    /// Creates a properly positioned accidental image view for use within a ZStack (uses offset)
    /// - Parameters:
    ///   - symbol: The accidental symbol (♯, ♭, ♮)
    ///   - targetHeight: Desired height in pixels for the image
    ///   - offset: The offset from the parent's center where the origin should be placed
    /// - Returns: A SwiftUI Image view positioned correctly
    static func accidentalImageViewWithOffset(for symbol: String, targetHeight: CGFloat, offset: CGPoint) -> some View {
        guard let accidentalInfo = accidentalImages[symbol] else {
            return AnyView(EmptyView())
        }
        
        // Calculate the correct offset for the image center
        // If origin is originOffsetFromBottom pixels from the bottom, 
        // and we want origin at offset.y, then the image center should be offset by:
        let imageCenterYOffset = offset.y - accidentalInfo.originOffsetFromBottom + (targetHeight / 2)
        
        return AnyView(
            Image(accidentalInfo.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: targetHeight)
                .offset(x: offset.x, y: imageCenterYOffset)
        )
    }
    
    /// Creates a properly positioned accidental image view
    /// - Parameters:
    ///   - symbol: The accidental symbol (♯, ♭, ♮)
    ///   - targetHeight: Desired height in pixels for the image
    ///   - position: The target position where the origin should be placed
    /// - Returns: A SwiftUI Image view positioned correctly
    static func accidentalImageView(for symbol: String, targetHeight: CGFloat, at position: CGPoint) -> some View {
        guard let accidentalInfo = accidentalImages[symbol] else {
            return AnyView(EmptyView())
        }
        
        // Calculate the correct position for the image center
        // If origin is originOffsetFromBottom pixels from the bottom, 
        // and we want origin at position.y, then:
        // - Bottom of image should be at: position.y - originOffsetFromBottom  
        // - Center of image should be at: position.y - originOffsetFromBottom + (targetHeight / 2)
        let imageCenterY = position.y - accidentalInfo.originOffsetFromBottom + (targetHeight / 2)
        
        return AnyView(
            Image(accidentalInfo.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: targetHeight)
                .position(
                    x: position.x,
                    y: imageCenterY
                )
        )
    }
    
    /// Calculate the proper clef image height based on staff height and clef type
    /// - Parameters:
    ///   - clef: The clef type
    ///   - staffHeight: The staff height in pixels
    /// - Returns: The calculated image height
    static func calculateClefImageHeight(for clef: Clef, staffHeight: CGFloat) -> CGFloat {
        switch clef {
        case .treble:
            // Treble clef should span from approximately E5 to below the staff
            let g4Y = StaffPositionMapper.getYFromNoteAndKey("G4", keySignature: "C major", clef: clef, staffHeight: staffHeight)
            let e5Y = StaffPositionMapper.getYFromNoteAndKey("E5", keySignature: "C major", clef: clef, staffHeight: staffHeight)
            let distanceG4ToE5 = g4Y - e5Y
            return distanceG4ToE5 * 2.2
        case .bass:
            return staffHeight * 0.6
        case .alto:
            return staffHeight * 0.5
        case .tenor:
            return staffHeight * 0.5
        }
    }
    
    /// Calculate the target position for a clef's origin based on the reference note
    /// - Parameters:
    ///   - clef: The clef type
    ///   - keySignature: The key signature
    ///   - staffHeight: The staff height
    ///   - xPosition: The x coordinate for positioning
    /// - Returns: The position where the clef origin should be placed
    static func calculateClefOriginPosition(for clef: Clef, keySignature: String, staffHeight: CGFloat, xPosition: CGFloat) -> CGPoint {
        guard let clefInfo = clefImages[clef] else {
            return CGPoint(x: xPosition, y: staffHeight / 2)
        }
        
        let yPosition = StaffPositionMapper.getYFromNoteAndKey(
            clefInfo.referenceNoteName,
            keySignature: keySignature,
            clef: clef,
            staffHeight: staffHeight
        )
        
        return CGPoint(x: xPosition, y: yPosition)
    }
}