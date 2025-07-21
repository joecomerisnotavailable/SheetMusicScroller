import SwiftUI

/// View that renders a historical trail squiggle showing the marker tip's path over time
struct SquiggleView: View {
    let height: CGFloat
    let currentYPosition: CGFloat
    let scrollOffset: CGFloat
    let squiggleX: CGFloat
    let tipColor: Color
    
    @State private var historyPoints: [CGPoint] = []
    @State private var lastScrollOffset: CGFloat = 0
    
    init(height: CGFloat = 200, currentYPosition: CGFloat = 0, scrollOffset: CGFloat = 0, squiggleX: CGFloat = 0, tipColor: Color = .red) {
        self.height = height
        self.currentYPosition = currentYPosition
        self.scrollOffset = scrollOffset
        self.squiggleX = squiggleX
        self.tipColor = tipColor
    }
    
    var body: some View {
        ZStack {
            // Draw the historical trail
            if historyPoints.count > 1 {
                Path { path in
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
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
            }
            
            // Draw the current tip
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [tipColor, tipColor.opacity(0.7)]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 4
                    )
                )
                .frame(width: 8, height: 8)
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
    HStack(spacing: 30) {
        SquiggleView(height: 150, currentYPosition: 75, scrollOffset: 0, squiggleX: 80, tipColor: .red)
        SquiggleView(height: 200, currentYPosition: 100, scrollOffset: 50, squiggleX: 80, tipColor: .blue)
        SquiggleView(height: 100, currentYPosition: 50, scrollOffset: 100, squiggleX: 80, tipColor: .green)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}