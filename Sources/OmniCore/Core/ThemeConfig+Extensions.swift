import Foundation
import OmniCoreTypes
import simd

extension ThemeConfig {
    public static var standard: ThemeConfig {
        var t = ThemeConfig()
        t.primaryColor = simd_float4(1, 0, 0.5, 1) // Default Neon Pink
        t.secondaryColor = simd_float4(0, 1, 1, 1) // Cyan
        t.sigmaColor = simd_float4(0.5, 0.5, 0.5, 1)
        t.backgroundColor = simd_float4(0, 0, 0, 0) // Transparent
        t.signalStrength = 1.0
        return t
    }
}
