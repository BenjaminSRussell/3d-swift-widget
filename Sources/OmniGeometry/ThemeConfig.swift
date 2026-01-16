import simd

public struct ThemeConfig {
    public var primaryColor: simd_float4
    public var secondaryColor: simd_float4
    public var sigmaColor: simd_float4
    public var backgroundColor: simd_float4
    public var signalStrength: Float
    
    public init(
        primary: simd_float4 = simd_float4(0, 0.8, 1, 1),
        secondary: simd_float4 = simd_float4(1, 0, 0.5, 1),
        sigma: simd_float4 = simd_float4(0.2, 0.2, 0.2, 0.5),
        bg: simd_float4 = simd_float4(0, 0, 0, 1),
        strength: Float = 1.0
    ) {
        self.primaryColor = primary
        self.secondaryColor = secondary
        self.sigmaColor = sigma
        self.backgroundColor = bg
        self.signalStrength = strength
    }
}
