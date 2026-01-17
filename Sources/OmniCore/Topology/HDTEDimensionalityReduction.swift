import Metal

/// HDTEDimensionalityReduction: Manages t-SNE and UMAP on the GPU.
public final class HDTEDimensionalityReduction {
    
    private let context: MetalContext
    private let shaderLibrary: ShaderLibrary
    
    public init(context: MetalContext, shaderLibrary: ShaderLibrary) {
        self.context = context
        self.shaderLibrary = shaderLibrary
    }
    
    /// Runs one iteration of t-SNE optimization on the GPU.
    public func stepTSNE(embeddingBuffer: MTLBuffer, 
                         velocityBuffer: MTLBuffer, 
                         attractionBuffer: MTLBuffer, 
                         count: Int) {
        
        guard let commandBuffer = context.makeCommandBuffer(),
              let pipeline = try? shaderLibrary.makeComputePipeline(functionName: "tsneOptimization") else { return }
        
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(embeddingBuffer, offset: 0, index: 0)
        encoder.setBuffer(velocityBuffer, offset: 0, index: 1)
        encoder.setBuffer(attractionBuffer, offset: 0, index: 2)
        // Repulsion buffer (3) implicitly handled or future expansion
        
        var countU32 = UInt32(count)
        encoder.setBytes(&countU32, length: MemoryLayout<UInt32>.size, index: 4)
        
        // Dispatch
        let threadsPerThreadgroup = MTLSize(width: 32, height: 1, depth: 1)
        let threadgroupsPerGrid = MTLSize(
            width: (count + 31) / 32,
            height: 1,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
        
        commandBuffer.commit()
    }
}
