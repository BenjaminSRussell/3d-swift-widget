import Metal
import CoreText
import CoreGraphics
import Foundation

/// Phase 16.1: Dynamic Font Atlas Manager
/// Generates Signed Distance Field (SDF) font atlases at runtime.
public class FontAtlasManager {
    public let device: MTLDevice
    
    // Atlas Textures
    public private(set) var atlasTexture: MTLTexture?
    private var jfaPingTexture: MTLTexture?
    private var jfaPongTexture: MTLTexture?
    
    // Kernels
    private let initKernel: ComputeKernel
    private let stepKernel: ComputeKernel
    private let finalizeKernel: ComputeKernel
    
    // Glyph Metadata for GPU
    public struct GlyphDescriptor {
        var uvMin: SIMD2<Float>
        var uvMax: SIMD2<Float>
        var size: SIMD2<Float>
        var bearing: SIMD2<Float>
        var advance: Float
        var padding: Float // Align 16
    }
    
    private var glyphDescriptors: [GlyphDescriptor] = []
    public private(set) var glyphBuffer: MTLBuffer?
    
    // Cache
    private var glyphMap: [CGGlyph: Int] = [:]
    private let atlasSize = 1024
    
    public init(device: MTLDevice) {
        self.device = device
        do {
            self.initKernel = try ComputeKernel(functionName: "jfa_init")
            self.stepKernel = try ComputeKernel(functionName: "jfa_step")
            self.finalizeKernel = try ComputeKernel(functionName: "jfa_finalize")
        } catch {
            fatalError("Failed to initialize JFA kernels: \(error)")
        }
    }
    
    /// Generates an SDF atlas for the specified font.
    /// - Parameters:
    ///   - fontName: Name of the font (e.g., "Helvetica").
    ///   - fontSize: Render size for the high-res bitmap (e.g., 64 for SDF).
    public func buildAtlas(fontName: String, fontSize: CGFloat) {
        let font = CTFontCreateWithName(fontName as CFString, fontSize, nil)
        // Note: CTFontCreateWithName always returns a font object (falling back if needed)
        
        // 1. Setup Context
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(data: nil,
                                      width: atlasSize,
                                      height: atlasSize,
                                      bitsPerComponent: 8,
                                      bytesPerRow: atlasSize,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
        
        // Clear black
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: atlasSize, height: atlasSize))
        
        // 2. Render Glyphs (Simple Grid Packing)
        // In a "God-Tier" engine, use a Rectangle Bin Packer (Skyline or MaxRects).
        // For this task, we assume a standard ASCII set fitting in 1024x1024.
        
        let characters = "!\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
        var currentPoint = CGPoint(x: 10, y: 10)
        let padding: CGFloat = 10.0
        let maxHeight: CGFloat = fontSize * 1.5
        
        // Reset descriptors
        glyphDescriptors.removeAll()
        glyphMap.removeAll()
        
        context.setFillColor(gray: 1, alpha: 1) // White Text
        context.setShouldAntialias(false) // We want crisp shapes for SDF calc if possible, or AA for soft range.
        
        var index = 0
        
        for char in characters {
            let utf16 = Array(char.utf16)
            var glyphs = [CGGlyph](repeating: 0, count: utf16.count)
            guard CTFontGetGlyphsForCharacters(font, utf16, &glyphs, utf16.count) else { continue }
            let glyph = glyphs[0]
            
            // Get Metrics
            var advance = CGSize.zero
            CTFontGetAdvancesForGlyphs(font, .horizontal, &glyphs, &advance, 1)
            
            let bounds = CTFontGetBoundingRectsForGlyphs(font, .horizontal, &glyphs, nil, 1)
            
            // Check boundaries
            if currentPoint.x + bounds.width + padding > CGFloat(atlasSize) {
                currentPoint.x = 10
                currentPoint.y += maxHeight + padding
            }
            
            // Draw
            // CoreText draws at baseline.
            var position = CGPoint(x: currentPoint.x - bounds.origin.x, y: currentPoint.y - bounds.origin.y)
            CTFontDrawGlyphs(font, &glyphs, &position, 1, context)
            
            // Generate Descriptor
            let uvMin = SIMD2<Float>(Float(currentPoint.x) / Float(atlasSize), Float(currentPoint.y) / Float(atlasSize))
            let uvMax = SIMD2<Float>(Float(currentPoint.x + bounds.width) / Float(atlasSize), Float(currentPoint.y + bounds.height) / Float(atlasSize))
            
            let desc = GlyphDescriptor(
                uvMin: uvMin,
                uvMax: uvMax,
                size: SIMD2<Float>(Float(bounds.width), Float(bounds.height)),
                bearing: SIMD2<Float>(Float(bounds.origin.x), Float(bounds.origin.y)),
                advance: Float(advance.width),
                padding: 0
            )
            
            glyphDescriptors.append(desc)
            glyphMap[glyph] = index
            index += 1
            
            currentPoint.x += bounds.width + padding * 2 // Extra padding for SDF bleed
        }
        
        // 3. Convert Scanline Bitmap to SDF
        guard let data = context.data else { return }
        
        // 4. Transform to SDF via GPU
        let texDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: atlasSize, height: atlasSize, mipmapped: false)
        texDesc.usage = [.shaderRead, .shaderWrite]
        guard let tex = device.makeTexture(descriptor: texDesc) else { return }
        tex.replace(region: MTLRegionMake2D(0, 0, atlasSize, atlasSize), mipmapLevel: 0, withBytes: data, bytesPerRow: atlasSize)
        
        generateSDF(source: tex)
        
        // 5. Upload Descriptors
        if !glyphDescriptors.isEmpty {
            let bufferSize = glyphDescriptors.count * MemoryLayout<GlyphDescriptor>.stride
            glyphBuffer = device.makeBuffer(bytes: glyphDescriptors, length: bufferSize, options: .storageModeShared)
        }
    }
    
    private func generateSDF(source: MTLTexture) {
        ensureTextures(width: source.width, height: source.height)
        guard let ping = jfaPingTexture, let pong = jfaPongTexture else { return }
        
        guard let commandBuffer = MetalContext.shared.commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        // Pass 1: Init
        encoder.setTexture(source, index: 0)
        encoder.setTexture(ping, index: 1)
        initKernel.dispatch(encoder: encoder, gridSize: MTLSize(width: source.width, height: source.height, depth: 1))
        
        // Pass 2: Jump Flood Steps
        var currentStep = 512
        var currentPing = true
        
        while currentStep >= 1 {
            var step = Int32(currentStep)
            encoder.setTexture(currentPing ? ping : pong, index: 0)
            encoder.setTexture(currentPing ? pong : ping, index: 1)
            encoder.setBytes(&step, length: 4, index: 0)
            stepKernel.dispatch(encoder: encoder, gridSize: MTLSize(width: source.width, height: source.height, depth: 1))
            
            currentStep /= 2
            currentPing.toggle()
        }
        
        // Pass 3: Finalize
        let finalAtlasDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: source.width, height: source.height, mipmapped: false)
        finalAtlasDesc.usage = [.shaderRead, .shaderWrite]
        self.atlasTexture = device.makeTexture(descriptor: finalAtlasDesc)
        
        encoder.setTexture(currentPing ? ping : pong, index: 0)
        encoder.setTexture(atlasTexture, index: 1)
        finalizeKernel.dispatch(encoder: encoder, gridSize: MTLSize(width: source.width, height: source.height, depth: 1))
        
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    private func ensureTextures(width: Int, height: Int) {
        if jfaPingTexture?.width != width || jfaPingTexture?.height != height {
            let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg32Float, width: width, height: height, mipmapped: false)
            desc.usage = [.shaderRead, .shaderWrite]
            jfaPingTexture = device.makeTexture(descriptor: desc)
            jfaPongTexture = device.makeTexture(descriptor: desc)
        }
    }
}
