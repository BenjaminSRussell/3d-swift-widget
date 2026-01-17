import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// HDTEGlassmorphicUI: Provides a design system for the translucent, depth-aware interface.
public struct HDTEGlassmorphicUI {
    
    
    /// Calculates adaptive corner radius based on viewport size.
    /// Ensures the radius scales appropriately for different widget sizes.
    public static func cornerRadius(for viewportSize: CGSize) -> CGFloat {
        let minDimension = min(viewportSize.width, viewportSize.height)
        return minDimension * 0.12 // 12% of smallest dimension
    }
    
    /// Default corner radius for standard layouts (fallback)
    public static let defaultCornerRadius: CGFloat = 20.0
    
    public static let panelBorderWidth: CGFloat = 0.5
    public static let panelBorderColor = Color.white.opacity(0.2)
    
    // MARK: - Components
    
    /// A glassmorphic background container with blur and subtle border.
    public struct GlassPanel<Content: View>: View {
        let content: Content
        
        public init(@ViewBuilder content: () -> Content) {
            self.content = content()
        }
        
        public var body: some View {
            ZStack {
                // Blur Effect
                #if os(iOS)
                VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                #elseif os(macOS)
                VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                #endif
                
                // Border
                RoundedRectangle(cornerRadius: HDTEGlassmorphicUI.defaultCornerRadius)
                    .stroke(HDTEGlassmorphicUI.panelBorderColor, lineWidth: HDTEGlassmorphicUI.panelBorderWidth)
                
                // Content
                content
                    .padding()
            }
            .clipShape(RoundedRectangle(cornerRadius: HDTEGlassmorphicUI.defaultCornerRadius))
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
        }
    }
    
    /// A floating data indicator for 3D annotations.
    public struct DataIndicator: View {
        let label: String
        let value: String
        
        public init(label: String, value: String) {
            self.label = label
            self.value = value
        }
        
        public var body: some View {
            HStack(spacing: 8) {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.thinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Platform Agnostic Blur Wrapper

#if os(iOS)
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}
#elseif os(macOS)
import AppKit
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
#endif
