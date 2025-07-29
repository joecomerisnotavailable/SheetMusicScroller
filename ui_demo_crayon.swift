import SwiftUI

// Simplified version for demonstration
struct CrayonSquiggleDemo: View {
    @State private var historyPoints: [CGPoint] = []
    let lineWidth: CGFloat = 3.5
    let tipSize: CGFloat = 7.0
    let tipColor: Color = .red
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Crayon-like Squiggle Drawing (No Splines)")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Linear interpolation with thick lines and round caps for crayon effect")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ZStack {
                Rectangle()
                    .fill(Color.white)
                    .border(Color.gray, width: 1)
                    .frame(height: 200)
                
                // Demo squiggle path with crayon-like appearance
                Path { path in
                    let points: [CGPoint] = [
                        CGPoint(x: 50, y: 100),
                        CGPoint(x: 80, y: 80),
                        CGPoint(x: 120, y: 120),
                        CGPoint(x: 160, y: 60),
                        CGPoint(x: 200, y: 140),
                        CGPoint(x: 240, y: 90),
                        CGPoint(x: 280, y: 110)
                    ]
                    
                    path.move(to: points[0])
                    for point in points.dropFirst() {
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
                        lineWidth: lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                
                // Tip
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [tipColor, tipColor.opacity(0.7)]),
                            center: .center,
                            startRadius: 0,
                            endRadius: tipSize / 2
                        )
                    )
                    .frame(width: tipSize, height: tipSize)
                    .position(x: 280, y: 110)
                    .shadow(color: tipColor.opacity(0.7), radius: 3, x: 0, y: 0)
            }
            
            HStack(spacing: 20) {
                VStack {
                    Text("Line Width")
                        .font(.caption)
                    Text("\(lineWidth, specifier: "%.1f") pt")
                        .font(.system(.caption, design: .monospaced))
                }
                
                VStack {
                    Text("Tip Size")
                        .font(.caption)
                    Text("\(tipSize, specifier: "%.1f") pt")
                        .font(.system(.caption, design: .monospaced))
                }
                
                VStack {
                    Text("Line Caps")
                        .font(.caption)
                    Text("Round")
                        .font(.system(.caption, design: .monospaced))
                }
            }
            .padding()
            .background(Color.primary.opacity(0.05))
            .cornerRadius(8)
            
            Text("✅ Spline fitting removed - now uses simple linear interpolation\n🖍️ Crayon-like appearance achieved through thick lines and round caps")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    CrayonSquiggleDemo()
        .frame(width: 400, height: 400)
}