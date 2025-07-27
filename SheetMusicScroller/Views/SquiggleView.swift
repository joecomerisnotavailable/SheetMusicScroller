import SwiftUI

/// Configuration for squiggle drawing parameters
struct SquiggleDrawingConfig {
    /// Line width for the squiggle path (thicker for crayon-like effect)
    var lineWidth: CGFloat = 3.5
    /// Tip size (diameter)
    var tipSize: CGFloat = 7.0
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
            // Draw the historical trail with crayon-like appearance
            if historyPoints.count > 1 {
                Path { path in
                    // Simple linear interpolation for clean, direct connections
                    path.move(to: historyPoints[0])
                    for point in historyPoints.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [tipColor.opacity(0.3), tipColor.opacity(0.6), tipColor]),
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
                        drawingConfig: SquiggleDrawingConfig(lineWidth: 2.0, tipSize: 5.0, useRoundLineCaps: true))
            Text("Thin Line")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        // Thick crayon style
        HStack(spacing: 30) {
            SquiggleView(height: 150, currentYPosition: 75, scrollOffset: 0, squiggleX: 80, tipColor: .green,
                        drawingConfig: SquiggleDrawingConfig(lineWidth: 5.0, tipSize: 9.0, useRoundLineCaps: true))
            Text("Thick Crayon")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}