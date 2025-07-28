#if canImport(SwiftUI)
import SwiftUI

/// Configuration for squiggle drawing parameters
struct SquiggleDrawingConfig {
    /// Line width for the squiggle path (smaller, more precise for gritty crayon effect)
    var lineWidth: CGFloat = 2.5
    /// Tip size (diameter) - smaller for more precise crayon appearance
    var tipSize: CGFloat = 4.5
    /// Whether to use round line caps for crayon-like effect
    var useRoundLineCaps: Bool = true
}

/// View that renders a historical trail squiggle showing the marker tip's path over time
/// with a crayon-like appearance using thick lines and round caps
struct SquiggleView: View {
    let height: CGFloat
    let currentYPosition: CGFloat
    let scrollOffset: CGFloat
    let squiggleX: CGFloat
    let tipColor: Color
    
    /// Configuration for drawing parameters
    var drawingConfig: SquiggleDrawingConfig = SquiggleDrawingConfig()
    
    @State private var historyPoints: [CGPoint] = []
    @State private var lastScrollOffset: CGFloat = 0
    
    init(height: CGFloat = 200, currentYPosition: CGFloat = 0, scrollOffset: CGFloat = 0, squiggleX: CGFloat = 0, tipColor: Color = .red, drawingConfig: SquiggleDrawingConfig = SquiggleDrawingConfig()) {
        self.height = height
        self.currentYPosition = currentYPosition
        self.scrollOffset = scrollOffset
        self.squiggleX = squiggleX
        self.tipColor = tipColor
        self.drawingConfig = drawingConfig
    }
    
    var body: some View {
        ZStack {
            // Draw the historical trail with crayon-like appearance and gristly texture
            if historyPoints.count > 1 {
                Path { path in
                    // Create gristly, textured lines by adding slight variations
                    createGristlyPath(path: &path, points: historyPoints)
                }
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [tipColor.opacity(0.75), tipColor.opacity(0.9), tipColor]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(
                        lineWidth: drawingConfig.lineWidth,
                        lineCap: drawingConfig.useRoundLineCaps ? .round : .butt,
                        lineJoin: .round
                    )
                )
            }
            
            // Draw the current tip - sized to match the crayon aesthetic
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [tipColor, tipColor.opacity(0.7)]),
                        center: .center,
                        startRadius: 0,
                        endRadius: drawingConfig.tipSize / 2
                    )
                )
                .frame(width: drawingConfig.tipSize, height: drawingConfig.tipSize)
                .position(x: squiggleX, y: currentYPosition)
                .shadow(color: tipColor.opacity(0.7), radius: 3, x: 0, y: 0)
        }
        .onChange(of: scrollOffset) { _, newScrollOffset in
            updateHistoryPoints(newScrollOffset: newScrollOffset)
        }
        .onChange(of: currentYPosition) { _, _ in
            updateHistoryPoints(newScrollOffset: scrollOffset)
        }
        .onAppear {
            // Initialize with current position
            updateHistoryPoints(newScrollOffset: scrollOffset)
        }
    }
    
    private func updateHistoryPoints(newScrollOffset: CGFloat) {
        let scrollDelta = newScrollOffset - lastScrollOffset
        
        // In both modes, move existing points left by the scroll delta to keep everything in sync
        historyPoints = historyPoints.compactMap { point in
            let newX = point.x - scrollDelta
            return newX >= -50 ? CGPoint(x: newX, y: point.y) : nil // Remove points that have scrolled off screen
        }
        
        // Add current position as the tip
        let currentPoint = CGPoint(x: squiggleX, y: currentYPosition)
        
        // Only add a new point if the position has changed meaningfully or time has passed
        let threshold: CGFloat = 2.0 // Consistent threshold
        if historyPoints.isEmpty || 
           abs(historyPoints.last!.y - currentYPosition) > threshold || 
           scrollDelta > 1 {
            historyPoints.append(currentPoint)
        } else {
            // Update the last point to current position
            historyPoints[historyPoints.count - 1] = currentPoint
        }
        
        // Limit history to reasonable length for performance
        let maxHistory = 150 // Good balance for trail length
        if historyPoints.count > maxHistory {
            historyPoints.removeFirst(historyPoints.count - maxHistory)
        }
        
        lastScrollOffset = newScrollOffset
    }
    
    /// Create a gristly, textured path by adding slight random variations to line segments
    /// This gives the squiggle a more organic, crayon-like texture
    private func createGristlyPath(path: inout Path, points: [CGPoint]) {
        guard points.count > 1 else { return }
        
        path.move(to: points[0])
        
        for i in 1..<points.count {
            let currentPoint = points[i]
            let previousPoint = points[i-1]
            
            // Add slight perpendicular variations to create texture
            let dx = currentPoint.x - previousPoint.x
            let dy = currentPoint.y - previousPoint.y
            let length = sqrt(dx*dx + dy*dy)
            
            // Only add texture if segment is long enough
            if length > 3.0 {
                // Create perpendicular vector for texture variation
                let perpX = -dy / length
                let perpY = dx / length
                
                // Add small random variations (deterministic based on position for consistency)
                let seed = Int(previousPoint.x + previousPoint.y * 17) % 1000
                let variation1 = sin(Double(seed) * 0.1) * 0.8
                let variation2 = cos(Double(seed) * 0.13) * 0.6
                
                // Create intermediate points with texture
                let midPoint = CGPoint(
                    x: (previousPoint.x + currentPoint.x) * 0.5 + perpX * variation1,
                    y: (previousPoint.y + currentPoint.y) * 0.5 + perpY * variation1
                )
                
                let quarterPoint = CGPoint(
                    x: previousPoint.x * 0.75 + currentPoint.x * 0.25 + perpX * variation2,
                    y: previousPoint.y * 0.75 + currentPoint.y * 0.25 + perpY * variation2
                )
                
                // Draw textured line through intermediate points
                path.addLine(to: quarterPoint)
                path.addLine(to: midPoint)
                path.addLine(to: currentPoint)
            } else {
                // For short segments, just draw straight line
                path.addLine(to: currentPoint)
            }
        }
    }
    
    /// Get the current tip color for note coloration
    var currentTipColor: Color {
        return tipColor
    }
}

#Preview {
    VStack(spacing: 20) {
        // Default crayon style
        HStack(spacing: 30) {
            SquiggleView(height: 150, currentYPosition: 75, scrollOffset: 0, squiggleX: 80, tipColor: .red)
            Text("Crayon (Default)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        // Thin line variant
        HStack(spacing: 30) {
            SquiggleView(height: 150, currentYPosition: 75, scrollOffset: 0, squiggleX: 80, tipColor: .blue,
                        drawingConfig: SquiggleDrawingConfig(lineWidth: 1.5, tipSize: 3.5, useRoundLineCaps: true))
            Text("Thin Line")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        // Thick crayon style
        HStack(spacing: 30) {
            SquiggleView(height: 150, currentYPosition: 75, scrollOffset: 0, squiggleX: 80, tipColor: .green,
                        drawingConfig: SquiggleDrawingConfig(lineWidth: 3.5, tipSize: 6.0, useRoundLineCaps: true))
            Text("Thick Crayon")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
#else
// Provide a stub for non-SwiftUI platforms
public struct SquiggleView {
    public init() {}
}
#endif