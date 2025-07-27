import SwiftUI

/// Configuration for squiggle drawing parameters
struct SquiggleDrawingConfig {
    /// Whether to use smooth curves instead of linear interpolation
    var useSmoothCurves: Bool = true
    /// Line width for the squiggle path
    var lineWidth: CGFloat = 2.0
    /// Tip size (diameter)
    var tipSize: CGFloat = 6.0
    /// Smoothing factor for curve interpolation (0.0 = linear, 1.0 = maximum smoothing)
    var smoothingFactor: CGFloat = 0.6
    /// Whether to use round line caps for crayon-like effect
    var useRoundLineCaps: Bool = true
}

/// View that renders a historical trail squiggle showing the marker tip's path over time
/// with improved smooth curve drawing for a more organic, crayon-like appearance
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
            // Draw the historical trail with smooth curves
            if historyPoints.count > 1 {
                Path { path in
                    if drawingConfig.useSmoothCurves && historyPoints.count >= 3 {
                        // Use smooth curve interpolation for organic appearance
                        createSmoothPath(path: &path, points: historyPoints, smoothingFactor: drawingConfig.smoothingFactor)
                    } else {
                        // Fallback to linear interpolation for compatibility
                        path.move(to: historyPoints[0])
                        for point in historyPoints.dropFirst() {
                            path.addLine(to: point)
                        }
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
            
            // Draw the current tip - smaller and matching path width
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
    
    /// Creates a smooth path using Catmull-Rom spline interpolation for organic appearance
    /// This provides a crayon-like drawing effect by smoothly connecting points
    private func createSmoothPath(path: inout Path, points: [CGPoint], smoothingFactor: CGFloat) {
        guard points.count >= 3 else {
            // Not enough points for smooth interpolation, use linear
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            return
        }
        
        path.move(to: points[0])
        
        // For the first segment, use the first point as control point
        let startControl = calculateControlPoint(p0: points[0], p1: points[0], p2: points[1], p3: points.count > 2 ? points[2] : points[1], smoothingFactor: smoothingFactor)
        
        for i in 1..<points.count {
            let p0 = i >= 2 ? points[i-2] : points[0]
            let p1 = points[i-1]
            let p2 = points[i]
            let p3 = i < points.count - 1 ? points[i+1] : points[i]
            
            // Calculate control points for Catmull-Rom spline
            let controlPoint1 = calculateControlPoint(p0: p0, p1: p1, p2: p2, p3: p3, smoothingFactor: smoothingFactor)
            let controlPoint2 = calculateControlPoint(p0: p1, p1: p2, p2: p3, p3: i < points.count - 2 ? points[i+2] : p3, smoothingFactor: smoothingFactor, isSecondControl: true)
            
            // Add cubic curve to create smooth connection
            path.addCurve(to: p2, control1: controlPoint1, control2: controlPoint2)
        }
    }
    
    /// Calculate control point for Catmull-Rom spline interpolation
    private func calculateControlPoint(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, smoothingFactor: CGFloat, isSecondControl: Bool = false) -> CGPoint {
        // Catmull-Rom spline control point calculation
        // smoothingFactor controls the tension (0.0 = linear, 1.0 = maximum smoothness)
        let tension = smoothingFactor * 0.5 // Scale factor for reasonable curve tension
        
        if isSecondControl {
            // Second control point - look backward from p2
            let dx = (p2.x - p0.x) * tension
            let dy = (p2.y - p0.y) * tension
            return CGPoint(x: p2.x - dx, y: p2.y - dy)
        } else {
            // First control point - look forward from p1
            let dx = (p3.x - p1.x) * tension
            let dy = (p3.y - p1.y) * tension
            return CGPoint(x: p1.x + dx, y: p1.y + dy)
        }
    }
    
    /// Get the current tip color for note coloration
    var currentTipColor: Color {
        return tipColor
    }
}

#Preview {
    VStack(spacing: 20) {
        // Original linear style
        HStack(spacing: 30) {
            SquiggleView(height: 150, currentYPosition: 75, scrollOffset: 0, squiggleX: 80, tipColor: .red, 
                        drawingConfig: SquiggleDrawingConfig(useSmoothCurves: false, lineWidth: 2, tipSize: 8))
            Text("Linear")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        // New smooth curves with different configurations
        HStack(spacing: 30) {
            SquiggleView(height: 150, currentYPosition: 75, scrollOffset: 0, squiggleX: 80, tipColor: .blue,
                        drawingConfig: SquiggleDrawingConfig(useSmoothCurves: true, lineWidth: 2.5, tipSize: 6, smoothingFactor: 0.6))
            Text("Smooth")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        // Crayon-like thick style
        HStack(spacing: 30) {
            SquiggleView(height: 150, currentYPosition: 75, scrollOffset: 0, squiggleX: 80, tipColor: .green,
                        drawingConfig: SquiggleDrawingConfig(useSmoothCurves: true, lineWidth: 4, tipSize: 8, smoothingFactor: 0.8))
            Text("Crayon")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}