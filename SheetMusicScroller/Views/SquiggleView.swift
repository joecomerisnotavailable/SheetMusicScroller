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

/// Animated squiggle cursor that tracks detected pitch. X is fixed to align with the left vertical bar.
struct SquiggleView: View {
    let fixedX: CGFloat
    let y: CGFloat
    let color: Color
    let drawingConfig: SquiggleDrawingConfig
    
    init(fixedX: CGFloat, y: CGFloat, color: Color, drawingConfig: SquiggleDrawingConfig = SquiggleDrawingConfig()) {
        self.fixedX = fixedX
        self.y = y
        self.color = color
        self.drawingConfig = drawingConfig
    }
    
    var body: some View {
        // Tip-only or minimal squiggle segment centered at fixedX
        Circle()
            .fill(color)
            .frame(width: drawingConfig.tipSize, height: drawingConfig.tipSize)
            .position(x: fixedX, y: y)
            .animation(.easeOut(duration: 0.05), value: y)
    }
}

#Preview {
    VStack(spacing: 20) {
        // Default squiggle tip
        HStack(spacing: 30) {
            SquiggleView(fixedX: 80, y: 75, color: .red)
            Text("Fixed Red Tip")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        // Blue tip variant
        HStack(spacing: 30) {
            SquiggleView(fixedX: 80, y: 100, color: .blue,
                        drawingConfig: SquiggleDrawingConfig(lineWidth: 1.5, tipSize: 3.5, useRoundLineCaps: true))
            Text("Fixed Blue Tip")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        // Green tip variant
        HStack(spacing: 30) {
            SquiggleView(fixedX: 80, y: 50, color: .green,
                        drawingConfig: SquiggleDrawingConfig(lineWidth: 3.5, tipSize: 6.0, useRoundLineCaps: true))
            Text("Fixed Green Tip")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}