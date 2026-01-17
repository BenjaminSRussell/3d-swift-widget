import Metal
import OmniCore // For GPUContext
import simd

/// Phase 4.2: Transfer Function Texture
/// Generates a Gradient Texture used by shaders to map data values (0-1) to colors.
public final class TransferFunctionGenerator {
    
    public struct ControlPoint {
        public var t: Float // 0.0 to 1.0 (Value)
        public var color: SIMD4<Float> // RGBA
        
        public init(t: Float, color: SIMD4<Float>) {
            self.t = t
            self.color = color
        }
    }
    
    public static func generateTexture(points: [ControlPoint], width: Int = 256) -> MTLTexture? {
        // 1. Sort points
        let sortedPoints = points.sorted { $0.t < $1.t }
        guard !sortedPoints.isEmpty else { return nil }
        
        // 2. Allocate Buffer for CPU generation
        var pixels = [UInt8](repeating: 0, count: width * 4)
        
        // 3. Generate Gradient
        for i in 0..<width {
            let t = Float(i) / Float(width - 1)
            let color = sampleGradient(t: t, points: sortedPoints)
            
            let offset = i * 4
            pixels[offset] = UInt8(clamp(color.x * 255, 0, 255))     // R
            pixels[offset+1] = UInt8(clamp(color.y * 255, 0, 255)) // G
            pixels[offset+2] = UInt8(clamp(color.z * 255, 0, 255)) // B
            pixels[offset+3] = UInt8(clamp(color.w * 255, 0, 255)) // A
        }
        
        // 4. Create Texture
        // 4. Create Texture
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type1D
        descriptor.pixelFormat = .rgba8Unorm
        descriptor.width = width
        descriptor.height = 1
        descriptor.depth = 1
        descriptor.mipmapLevelCount = 1
        descriptor.usage = .shaderRead
        
        guard let device = GPUContext.shared.device as? MTLDevice, // Assuming GPUContext accessible
              let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        
        texture.replace(region: MTLRegionMake1D(0, width), mipmapLevel: 0, withBytes: pixels, bytesPerRow: width * 4)
        
        return texture
    }
    
    private static func sampleGradient(t: Float, points: [ControlPoint]) -> SIMD4<Float> {
        // Handle edges
        if t <= points.first!.t { return points.first!.color }
        if t >= points.last!.t { return points.last!.color }
        
        // Find segment
        for i in 0..<(points.count - 1) {
            let p0 = points[i]
            let p1 = points[i+1]
            if t >= p0.t && t <= p1.t {
                let localT = (t - p0.t) / (p1.t - p0.t)
                return mix(p0.color, p1.color, t: localT)
            }
        }
        return SIMD4<Float>(0,0,0,1)
    }
    
    private static func mix(_ a: SIMD4<Float>, _ b: SIMD4<Float>, t: Float) -> SIMD4<Float> {
        return a * (1 - t) + b * t
    }
    
    private static func clamp(_ v: Float, _ minV: Float, _ maxV: Float) -> Float {
        return min(max(v, minV), maxV)
    }
}
