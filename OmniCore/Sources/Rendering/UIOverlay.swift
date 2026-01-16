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
    
    public init(device: MTLDevice, library: MTLLibrary) throws {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "UI Overlay Pipeline"
        
        // Load shaders (assumes basic UI shaders exist or are part of OMNI library)
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
        
        // Standard quad (0,0 to 1,1)
        let vertices = [
            Vertex(position: SIMD2(0, 0), uv: SIMD2(0, 1)),
            Vertex(position: SIMD2(1, 0), uv: SIMD2(1, 1)),
            Vertex(position: SIMD2(0, 1), uv: SIMD2(0, 0)),
            Vertex(position: SIMD2(1, 1), uv: SIMD2(1, 0))
        ]
        
        self.quadBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: .storageModeShared)!
        self.quadBuffer.label = "UI Quad Buffer"
    }
    
    public func draw(encoder: MTLRenderCommandEncoder) {
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(quadBuffer, offset: 0, index: 0)
        
        // In a real implementation:
        // 1. Bind UI uniform data (position/scale/color)
        // 2. Bind MSDF atlas
        // 3. Draw instances for each glyph or panel
    }
}
