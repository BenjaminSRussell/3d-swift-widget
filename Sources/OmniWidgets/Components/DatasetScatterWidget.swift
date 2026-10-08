import SwiftUI
import OmniData
import OmniDesignSystem

/// Renders an OmniData `DatasetBuffer` as a slowly rotating 3D point cloud.
/// Each vertex is `xyz` (normalised position) + `w` (normalised value → size/opacity).
/// Draws the CPU copy of the buffer with Canvas so it works in widgets and previews;
/// Metal passes can bind `buffer.buffer` directly.
public struct DatasetScatterWidget: View {
    public let buffer: DatasetBuffer
    public var style: WidgetStyle
    public var rotates: Bool

    public init(buffer: DatasetBuffer, style: WidgetStyle = .glass, rotates: Bool = true) {
        self.buffer = buffer
        self.style = style
        self.rotates = rotates
    }

    /// Point projected into view space: position in points plus the vertex value (0...1) and depth.
    public struct ProjectedPoint: Equatable {
        public var position: CGPoint
        public var value: Float
        public var depth: Float
    }

    /// Orthographic projection after a yaw rotation (radians) about the Y axis plus a fixed
    /// 20° tilt. Output is sorted back-to-front so nearer points are drawn last.
    public static func project(_ vertices: [SIMD4<Float>], in size: CGSize, yaw: Float) -> [ProjectedPoint] {
        let tilt: Float = 20 * .pi / 180
        let (cy, sy, ct, st) = (cos(yaw), sin(yaw), cos(tilt), sin(tilt))
        let half = Float(min(size.width, size.height)) * 0.42
        let cx = Float(size.width) / 2, cyy = Float(size.height) / 2
        return vertices.map { v in
            // Data convention: x/y are the ground plane, z is height → swap into screen Y-up.
            let px = v.x, py = v.z, pz = v.y
            let rx = px * cy + pz * sy
            let rz = -px * sy + pz * cy
            let ry = py * ct - rz * st
            let depth = py * st + rz * ct
            return ProjectedPoint(position: CGPoint(x: CGFloat(cx + rx * half), y: CGFloat(cyy - ry * half)),
                                  value: v.w, depth: depth)
        }
        .sorted { $0.depth > $1.depth }
    }

    public var body: some View {
        ZStack {
            if style == .glass {
                Color.black.opacity(0.2).background(.ultraThinMaterial)
            } else {
                Color.black
            }
            if buffer.vertexCount == 0 {
                GhostDataView()
            } else {
                TimelineView(.animation(paused: !rotates)) { timeline in
                    let yaw = rotates ? Float(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 60) / 60 * 2 * .pi) : 0.6
                    Canvas { context, size in
                        let theme = ThemeManager.shared.currentTheme
                        for p in Self.project(buffer.vertices, in: size, yaw: yaw) {
                            let r = CGFloat(2 + 4 * p.value)
                            let rect = CGRect(x: p.position.x - r, y: p.position.y - r, width: 2 * r, height: 2 * r)
                            let color = style == .holographic ? theme.secondary : theme.primary
                            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.35 + 0.65 * Double(p.value))))
                        }
                    }
                }
            }
            VStack {
                Spacer()
                Text("\(buffer.datasetName) · \(buffer.vertexCount) pts")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(ThemeManager.shared.currentTheme.text.opacity(0.7))
                    .padding(6)
            }
        }
    }
}
