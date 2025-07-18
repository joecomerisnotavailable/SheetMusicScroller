import SwiftUI

/// View that renders a cursor squiggle to indicate current playback position
struct SquiggleView: View {
    let height: CGFloat
    let animated: Bool
    
    @State private var animationOffset: CGFloat = 0
    
    init(height: CGFloat = 200, animated: Bool = true) {
        self.height = height
        self.animated = animated
    }
    
    var body: some View {
        Path { path in
            let width: CGFloat = 8
            let segments = 8
            let segmentHeight = height / CGFloat(segments)
            
            // Start at top center
            path.move(to: CGPoint(x: width/2, y: 0))
            
            // Create a wavy line with alternating curves
            for i in 0..<segments {
                let y = CGFloat(i + 1) * segmentHeight
                let controlX = (i % 2 == 0) ? width : 0
                let controlY = y - segmentHeight/2
                let endX = width/2
                
                path.addQuadCurve(
                    to: CGPoint(x: endX, y: y),
                    control: CGPoint(x: controlX, y: controlY)
                )
            }
        }
        .stroke(
            LinearGradient(
                gradient: Gradient(colors: [.red, .orange, .red]),
                startPoint: .top,
                endPoint: .bottom
            ),
            style: StrokeStyle(lineWidth: 3, lineCap: .round)
        )
        .frame(width: 8, height: height)
        .offset(x: animationOffset)
        .onAppear {
            if animated {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    animationOffset = 2
                }
            }
        }
        .shadow(color: .red.opacity(0.5), radius: 2, x: 0, y: 0)
    }
}

#Preview {
    HStack(spacing: 30) {
        SquiggleView(height: 150, animated: false)
        SquiggleView(height: 200, animated: true)
        SquiggleView(height: 100, animated: false)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}