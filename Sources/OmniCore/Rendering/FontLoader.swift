import Metal
import Foundation

/// FontLoader: Async MSDF (Multi-Channel Signed Distance Field) atlas generation
/// Expert Panel: Typography Engineer - Enables vector-sharp text at any resolution
public actor FontLoader {
    
    private var atlasCache: [String: MTLTexture] = [:]
    private let device: MTLDevice
    
    public init(device: MTLDevice) {
        self.device = device
    }
    
    /// Loads a font and generates an MSDF atlas
    /// - Parameter url: URL to .ttf font file
    /// - Returns: MSDF texture atlas (typically ~20KB for full character set)
    public func loadFont(url: URL) async throws -> MTLTexture {
        let cacheKey = url.lastPathComponent
        
        // Check cache
        if let cached = atlasCache[cacheKey] {
            return cached
        }
        
        // Generate MSDF atlas
        let atlas = try await generateMSDFAtlas(from: url)
        atlasCache[cacheKey] = atlas
        
        print("FontLoader: Generated MSDF atlas for \(cacheKey) (\(atlas.width)x\(atlas.height))")
        return atlas
    }
    
    /// Hot-swaps a font texture in the renderer without rebuilding
    /// - Parameters:
    ///   - texture: New MSDF texture
    ///   - renderer: Target renderer (must have fontTexture property)
    public func hotSwap(texture: MTLTexture, fontTextureSlot: inout MTLTexture?) {
        fontTextureSlot = texture
        print("FontLoader: Hot-swapped font texture")
    }
    
    // MARK: - Private Implementation
    
    private func generateMSDFAtlas(from url: URL) async throws -> MTLTexture {
        // TODO: Full MSDF generation requires:
        // 1. Parse .ttf file using CoreText or FreeType
        // 2. Rasterize glyphs to multi-channel distance fields
        // 3. Pack into texture atlas
        //
        // For now, create a placeholder texture that demonstrates the architecture
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 512,
            height: 512,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]
        descriptor.storageMode = .shared
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw FontLoaderError.textureCreationFailed
        }
        
        // Generate placeholder MSDF data
        // In production, this would be actual signed distance field data
        var data = [UInt8](repeating: 128, count: 512 * 512 * 4)
        
        // Create a simple test pattern (white square in center)
        for y in 200..<312 {
            for x in 200..<312 {
                let idx = (y * 512 + x) * 4
                data[idx] = 255     // R: distance to edge
                data[idx + 1] = 255 // G: distance to edge
                data[idx + 2] = 255 // B: distance to edge
                data[idx + 3] = 255 // A: alpha
            }
        }
        
        texture.replace(
            region: MTLRegionMake2D(0, 0, 512, 512),
            mipmapLevel: 0,
            withBytes: data,
            bytesPerRow: 512 * 4
        )
        
        return texture
    }
}

// MARK: - Errors

public enum FontLoaderError: Error {
    case textureCreationFailed
    case fontParsingFailed
    case invalidFontFormat
}

// MARK: - MSDF Shader Integration

/*
 Metal Shader Usage:
 
 fragment float4 msdf_text_fragment(
     VertexOut in [[stage_in]],
     texture2d<float> msdfAtlas [[texture(0)]]
 ) {
     constexpr sampler s(filter::linear);
     float3 msd = msdfAtlas.sample(s, in.texCoord).rgb;
     
     // Multi-channel signed distance
     float sd = median(msd.r, msd.g, msd.b);
     
     // Screen-space derivative for anti-aliasing
     float screenPxDistance = sd * pxRange - 0.5;
     float opacity = clamp(screenPxDistance + 0.5, 0.0, 1.0);
     
     return float4(textColor.rgb, textColor.a * opacity);
 }
 
 // Helper function
 float median(float r, float g, float b) {
     return max(min(r, g), min(max(r, g), b));
 }
 */
