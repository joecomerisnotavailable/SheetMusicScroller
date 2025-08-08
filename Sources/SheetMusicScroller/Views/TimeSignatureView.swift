#if canImport(SwiftUI)
import SwiftUI

/// View that renders a time signature with numerator and denominator
struct TimeSignatureView: View {
    let numerator: Int
    let denominator: Int
    let staffHeight: CGFloat
    
    var body: some View {
        VStack(spacing: staffHeight * 0.1) {
            Text("\(numerator)")
                .font(.system(size: staffHeight * 0.45, weight: .regular, design: .serif))
                .foregroundColor(.black)
            Text("\(denominator)")
                .font(.system(size: staffHeight * 0.45, weight: .regular, design: .serif))
                .foregroundColor(.black)
        }
        .frame(width: staffHeight * 0.6, height: staffHeight, alignment: .center)
        .accessibilityLabel("Time signature \(numerator) over \(denominator)")
    }
}

#Preview {
    VStack(spacing: 20) {
        TimeSignatureView(numerator: 4, denominator: 4, staffHeight: 120)
        TimeSignatureView(numerator: 3, denominator: 4, staffHeight: 120)
        TimeSignatureView(numerator: 6, denominator: 8, staffHeight: 120)
        TimeSignatureView(numerator: 2, denominator: 2, staffHeight: 120)
    }
    .padding()
    .background(Color.white)
}
#else
// Provide a stub for non-SwiftUI platforms
public struct TimeSignatureView {
    public init() {}
}
#endif