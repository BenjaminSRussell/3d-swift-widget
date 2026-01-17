import Metal
import OmniCore

/// SpatialHash: GPU-accelerated spatial data structure for O(1) neighbor queries.
public final class SpatialHash {
    
    private let context: MetalContext
    private let shaderLibrary: ShaderLibrary
    
    // Buffers
    private var cellIDBuffer: MTLBuffer?
    private var particleIDBuffer: MTLBuffer?
    private var sortTool: SortTool?
    
    public init(context: MetalContext, shaderLibrary: ShaderLibrary) {
        self.context = context
        self.shaderLibrary = shaderLibrary
        self.sortTool = try? SortTool()
    }
    
    /// Builds the spatial hash for a set of particles.
    /// This involves hashing cell IDs and then sorting the particles by cell ID.
    public func build(positions: MTLBuffer, count: Int) {
        guard let commandBuffer = context.makeCommandBuffer(),
              let buildPipeline = try? shaderLibrary.makeComputePipeline(functionName: "buildSpatialHash"),
              let sortTool = self.sortTool else { return }
        
        // 1. Allocate Buffers
        let u32Stride = MemoryLayout<UInt32>.stride
        if cellIDBuffer == nil || cellIDBuffer!.length < count * u32Stride {
             cellIDBuffer = context.device.makeBuffer(length: count * u32Stride, options: .storageModePrivate)
             particleIDBuffer = context.device.makeBuffer(length: count * u32Stride, options: .storageModePrivate)
        }
        
        guard let cellBuf = cellIDBuffer, let particleBuf = particleIDBuffer else { return }
        
        // 2. Dispatch Build Kernel
        // Note: Kernel needs update to write to separate buffers
        // OR we just keep using interleaving for build and split for sort? 
        // Better to update kernel to write split.
        // Assuming kernel signature: (positions, cellIDs, particleIDs, count)
        
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        encoder.setComputePipelineState(buildPipeline)
        encoder.setBuffer(positions, offset: 0, index: 0)
        encoder.setBuffer(cellBuf, offset: 0, index: 1)
        encoder.setBuffer(particleBuf, offset: 0, index: 2)
        var countU32 = UInt32(count)
        encoder.setBytes(&countU32, length: MemoryLayout<UInt32>.size, index: 3)
        
        let threads = MTLSize(width: 32, height: 1, depth: 1)
        let grids = MTLSize(width: (count + 31) / 32, height: 1, depth: 1)
        encoder.dispatchThreadgroups(grids, threadsPerThreadgroup: threads)
        
        // 3. Sort by Cell ID
        // Note: SortTool implementation assumes it orchestrates its own dispatches in a loop.
        // We can pass the SAME encoder if SortTool allows it, or we endEncoding and let SortTool handle it.
        // Checking SortTool: it takes an encoder. Perfect.
        
        sortTool.sort(encoder: encoder, keys: cellBuf, values: particleBuf, count: count)
        
        encoder.endEncoding()
        commandBuffer.commit()
    }
}
