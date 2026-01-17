import SwiftUI
import OmniDesignSystem

/// Phase 10.2: Ghost Data (Edge Case Handling)
/// Renders a skeletal wireframe when the data stream is empty or loading.
/// Preserves layout stability and aesthetics.

public struct GhostDataView: View {
    @State private var shimmerPhase: CGFloat = 0.0
    
    public init() {}
    
    public var body: some View {
        Canvas { context, size in
            // Draw a grid of lines that "breathe"
            let lines = 10
            let step = size.width / CGFloat(lines)
            
            for i in 0...lines {
                let x = CGFloat(i) * step
                let path = Path { p in
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                }
                
                // Opacity pulses
                let opacity = 0.1 + 0.05 * sin(shimmerPhase + Double(i))
                
                context.stroke(path, with: .color(ThemeManager.shared.currentTheme.gridLine.opacity(opacity)), lineWidth: 1)
            }
            
            // Horizontal lines
             for i in 0...lines {
                let y = CGFloat(i) * (size.height / CGFloat(lines))
                let path = Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                }
                let opacity = 0.1 + 0.05 * cos(shimmerPhase + Double(i))
                context.stroke(path, with: .color(ThemeManager.shared.currentTheme.gridLine.opacity(opacity)), lineWidth: 1)
            }
            
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                shimmerPhase = .pi * 2
            }
        }
    }
}
