import Metal
import QuartzCore
import OmniCoreTypes // Phase 19 fix

/// HDTESDFEngine: Manages infinite resolution raymarching using Signed Distance Functions.
public final class HDTESDFEngine {
    
    private let context: MetalContext
    private let shaderLibrary: ShaderLibrary
    
    // Texture to render into
    public var outputTexture: MTLTexture?
    
    public init(context: MetalContext, shaderLibrary: ShaderLibrary) {
        self.context = context
        self.shaderLibrary = shaderLibrary
    }
    
    /// Resize output texture to match view
    public func resize(width: Int, height: Int) {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: width, height: height, mipmapped: false)
        descriptor.usage = [.shaderWrite, .shaderRead]
        outputTexture = context.device.makeTexture(descriptor: descriptor)
    }
    
    /// Renders the SDF scene into the output texture
    public func render(time: Float, cameraPosition: SIMD3<Float>) {
        guard let commandBuffer = context.makeCommandBuffer(),
              let outputTexture = outputTexture,
              let pipeline = try? shaderLibrary.makeComputePipeline(functionName: "renderSDF") else { return }
        
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(outputTexture, index: 0)
        
        // Simple uniforms via setBytes for now (or use shared buffer)
        var uniforms = FrameUniforms()
        uniforms.time = time
        uniforms.cameraPosition = cameraPosition
        encoder.setBytes(&uniforms, length: MemoryLayout<FrameUniforms>.stride, index: 0)
        
        // Dispatch
        let w = pipeline.threadExecutionWidth
        let h = pipeline.maxTotalThreadsPerThreadgroup / w
        let threadsPerThreadgroup = MTLSize(width: w, height: h, depth: 1)
        
        let threadgroupsPerGrid = MTLSize(
            width: (outputTexture.width + w - 1) / w,
            height: (outputTexture.height + h - 1) / h,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
        
        commandBuffer.commit()
    }
}
