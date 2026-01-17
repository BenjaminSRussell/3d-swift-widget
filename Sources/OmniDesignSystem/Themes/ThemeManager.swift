import SwiftUI
import Combine

/// Phase 8.1: Procedural Palettes
/// Generates harmonious color schemes based on HSL color theory.
public final class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()
    
    @Published public var currentTheme: AppTheme = .defaultTheme
    
    private init() {}
    
    /// Generates a new theme based on a single "Seed" color.
    /// Uses Split-Complementary harmony for a "High-Tech" look.
    public func generateTheme(from seedColor: Color) {
        let hsl = seedColor.hsla
        
        // 1. Backgrounds (Dark, desaturated version of seed or comp)
        let bg = HSLA(h: hsl.h, s: 0.2, l: 0.05, a: 1.0)
        
        // 2. Primary Accent (The seed itself, boosted)
        let primary = HSLA(h: hsl.h, s: 0.9, l: 0.6, a: 1.0)
        
        // 3. Secondary (Split Complementary: +150 degrees)
        let secondary = HSLA(h: (hsl.h + 150).truncatingRemainder(dividingBy: 360), s: 0.8, l: 0.5, a: 1.0)
        
        // 4. Text (High contrast, slightly tinted)
        let text = HSLA(h: hsl.h, s: 0.1, l: 0.9, a: 1.0)
        
        self.currentTheme = AppTheme(
            background: bg.color,
            primary: primary.color,
            secondary: secondary.color,
            text: text.color,
            gridLine: primary.withAlpha(0.2).color
        )
    }
}

public struct AppTheme {
    public var background: Color
    public var primary: Color
    public var secondary: Color
    public var text: Color
    public var gridLine: Color
    
    public static let defaultTheme = AppTheme(
        background: Color(red: 0.05, green: 0.05, blue: 0.05),
        primary: Color.blue,
        secondary: Color.purple,
        text: Color.white,
        gridLine: Color.blue.opacity(0.2)
    )
}

// MARK: - HSL Utilities
struct HSLA {
    var h: Double // 0-360
    var s: Double // 0-1
    var l: Double // 0-1
    var a: Double // 0-1
    
    var color: Color {
        Color(hue: h/360, saturation: s, brightness: l, opacity: a)
    }
    
    func withAlpha(_ newAlpha: Double) -> HSLA {
        var copy = self
        copy.a = newAlpha
        return copy
    }
}

extension Color {
    var hsla: HSLA {
        // Simple extraction placeholder.
        // In real app, convert UIColor/NSColor to HSB/HSL.
        // Assuming SwiftUI Color can be converted via UIColor (iOS) or NSColor (Mac).
        #if os(macOS)
        let nsColor = NSColor(self)
        return HSLA(h: Double(nsColor.hueComponent) * 360, s: Double(nsColor.saturationComponent), l: Double(nsColor.brightnessComponent), a: Double(nsColor.alphaComponent))
        #else
        let uiColor = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return HSLA(h: Double(h) * 360, s: Double(s), l: Double(b), a: Double(a))
        #endif
    }
}
