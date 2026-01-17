import Foundation
import SwiftUI
import simd
import OmniCore
import OmniCoreTypes

/// Phase 17.2: Modular Theme Serialization
public class ThemeManager {
    public static let shared = ThemeManager()
    
    // JSON Schema
    public struct ThemeSchema: Codable {
        public let name: String
        public let parentId: String? // Points to another theme name
        public let palette: Palette?
        public let atmosphere: Atmosphere?
        
        public struct Palette: Codable {
            public let primary: String? // Hex
            public let secondary: String?
            public let accent: String?
            public let background: String?
        }
        
        public struct Atmosphere: Codable {
            public let signalStrength: Float?
        }
    }
    
    public init() {}
    
    public func loadTheme(from jsonString: String) -> ThemeConfig? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        do {
            let schema = try JSONDecoder().decode(ThemeSchema.self, from: data)
            return convertToConfig(schema)
        } catch {
            print("Theme decode failed: \(error)")
            return nil
        }
    }
    
    public func defaultThemeJson() -> String {
        return """
        {
            "name": "Cyberpunk Glass",
            "palette": {
                "primary": "#FF0055",
                "secondary": "#00FFFF",
                "accent": "#FFFFFF",
                "background": "#00000000"
            },
            "atmosphere": {
                "signalStrength": 1.2
            }
        }
        """
    }
    
    private func convertToConfig(_ schema: ThemeSchema, base: ThemeConfig? = nil) -> ThemeConfig {
        var config = base ?? ThemeConfig()
        
        if let palette = schema.palette {
            if let p = palette.primary { config.primaryColor = hexToSIMD(p) }
            if let s = palette.secondary { config.secondaryColor = hexToSIMD(s) }
            if let a = palette.accent { config.sigmaColor = hexToSIMD(a) }
            if let b = palette.background { config.backgroundColor = hexToSIMD(b) }
        }
        
        if let atmosphere = schema.atmosphere {
            if let ss = atmosphere.signalStrength { config.signalStrength = ss }
        }
        
        return config
    }
    
    // Helper: Hex to SIMD4
    private func hexToSIMD(_ hex: String) -> SIMD4<Float> {
        var cString: String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if (cString.hasPrefix("#")) {
            cString.remove(at: cString.startIndex)
        }
        
        if ((cString.count) != 6 && (cString.count) != 8) {
            return SIMD4<Float>(1, 1, 1, 1)
        }
        
        var rgbValue: UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)
        
        if cString.count == 6 {
            return SIMD4<Float>(
                Float((rgbValue & 0xFF0000) >> 16) / 255.0,
                Float((rgbValue & 0x00FF00) >> 8) / 255.0,
                Float(rgbValue & 0x0000FF) / 255.0,
                1.0
            )
        } else {
            return SIMD4<Float>(
                Float((rgbValue & 0xFF000000) >> 24) / 255.0,
                Float((rgbValue & 0x00FF0000) >> 16) / 255.0,
                Float((rgbValue & 0x0000FF00) >> 8) / 255.0,
                Float(rgbValue & 0x000000FF) / 255.0
            )
        }
    }
}
