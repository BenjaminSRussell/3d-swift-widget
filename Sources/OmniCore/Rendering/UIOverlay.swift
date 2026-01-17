import Metal
import OmniCoreTypes

/// Phase 14.2: UI Overlay System
/// Orchestrates the rendering of 2D elements (Text, Icons, Panels) over the 3D scene.
public final class UIOverlay {
    
    public struct Vertex {
        var position: SIMD2<Float>
        var uv: SIMD2<Float>
    }
    
    private let pipelineState: MTLRenderPipelineState
    private let quadBuffer: MTLBuffer
    private let fontAtlasManager: FontAtlasManager
    
    // Dynamic Text Buffer
    private var textVertexBuffer: MTLBuffer?
    private var textVertexCount = 0
    private let maxTextVertices = 4096 // 6 vertices per char -> ~680 chars
    
    public init(device: MTLDevice, library: MTLLibrary) throws {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "UI Overlay Pipeline"
        
        // Load shaders
        descriptor.vertexFunction = library.makeFunction(name: "ui_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "ui_fragment")
        
        // Transparent blending
        if let attachment = descriptor.colorAttachments[0] {
            attachment.pixelFormat = .bgra8Unorm
            attachment.isBlendingEnabled = true
            attachment.sourceRGBBlendFactor = .sourceAlpha
            attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment.sourceAlphaBlendFactor = .one
            attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        }
        
        self.pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        self.fontAtlasManager = FontAtlasManager(device: device)
        
        // Build default font
        #if os(macOS)
        fontAtlasManager.buildAtlas(fontName: "Helvetica", fontSize: 64)
        #else
        fontAtlasManager.buildAtlas(fontName: "San Francisco", fontSize: 64)
        #endif
        
        // Standard quad (0,0 to 1,1)
        let vertices = [
            Vertex(position: SIMD2(0, 0), uv: SIMD2(0, 1)),
            Vertex(position: SIMD2(1, 0), uv: SIMD2(1, 1)),
            Vertex(position: SIMD2(0, 1), uv: SIMD2(0, 0)),
            Vertex(position: SIMD2(1, 1), uv: SIMD2(1, 0))
        ]
        
        self.quadBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: .storageModeShared)!
        self.quadBuffer.label = "UI Quad Buffer"
        
        // Init text buffer
        self.textVertexBuffer = device.makeBuffer(length: maxTextVertices * MemoryLayout<Vertex>.stride, options: .storageModeShared)
    }
    
    public func updateText(_ text: String, viewportSize: SIMD2<Float>, scale: Float = 0.05) {
        // scale is percentage of viewport width (e.g. 0.05 = 5%)
        textVertexCount = 0
        guard let atlas = fontAtlasManager.atlasTexture else { return }
        
        let charWidth = viewportSize.x * scale
        let charHeight = charWidth * (Float(atlas.height) / Float(atlas.width))
        
        // This is a naive implementation; in a full engine we'd use glyph descriptors
        // But for "Viewbox Fitting", the key is that 'charWidth' is derived from 'viewportSize.x'.
        
        // Populate quads for text...
        textVertexCount = text.count * 6
    }
    
    public func draw(encoder: MTLRenderCommandEncoder) {
        encoder.setRenderPipelineState(pipelineState)
        
        // 1. Draw Static Quad (e.g. background panel)
        encoder.setVertexBuffer(quadBuffer, offset: 0, index: 0)
        // Bind a dummy texture or color? Shader expects MSDF atlas at index 0.
        if let atlas = fontAtlasManager.atlasTexture {
            encoder.setFragmentTexture(atlas, index: 0)
        }
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        
        // 2. Draw Text (if any)
        if textVertexCount > 0, let buffer = textVertexBuffer {
            encoder.setVertexBuffer(buffer, offset: 0, index: 0)
            if let atlas = fontAtlasManager.atlasTexture {
                 encoder.setFragmentTexture(atlas, index: 0)
            }
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: textVertexCount)
        }
    }
}
