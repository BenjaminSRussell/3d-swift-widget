import Metal
import simd

/// HDTEPersistentHomology: Calculates persistent homology on the GPU.
public final class HDTEPersistentHomology {
    
    private let context: MetalContext
    private let shaderLibrary: ShaderLibrary
    
    public init(context: MetalContext, shaderLibrary: ShaderLibrary) {
        self.context = context
        self.shaderLibrary = shaderLibrary
    }
    
    /// Computes a distance matrix for a set of points on the GPU.
    public func computeDistanceMatrix(pointsBuffer: MTLBuffer, count: Int) -> MTLBuffer? {
        guard let commandBuffer = context.makeCommandBuffer(),
              let pipeline = try? shaderLibrary.makeComputePipeline(functionName: "computeDistanceMatrix") else { return nil }
        
        // Output distance matrix: count * count floats
        let matrixSize = count * count * MemoryLayout<Float>.size
        let distanceMatrix = context.device.makeBuffer(length: matrixSize, options: .storageModePrivate)
        
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(pointsBuffer, offset: 0, index: 0)
        encoder.setBuffer(distanceMatrix, offset: 0, index: 1)
        
        var pointCount = UInt32(count)
        encoder.setBytes(&pointCount, length: MemoryLayout<UInt32>.size, index: 2)
        
        // Dispatch 2D grid
        let threadsPerThreadgroup = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupsPerGrid = MTLSize(
            width: (count + 15) / 16,
            height: (count + 15) / 16,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
        
        commandBuffer.commit()
        return distanceMatrix
    }
}
