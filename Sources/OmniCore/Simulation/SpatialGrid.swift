import Metal
import OmniCore
import simd

/// Phase 4.2: Spatial Hashing Grid
/// Manages the data structures for $O(N)$ particle lookups.
public final class SpatialGrid {
    
    public struct Params {
        var gridMin: SIMD3<Float>
        var cellSize: Float
        var gridRes: SIMD3<UInt32>
    }
    
    public let maxParticles: Int
    public let totalCells: Int
    public let cellIndexBuffer: MTLBuffer
    public let particleIndexBuffer: MTLBuffer
    public let cellStartBuffer: MTLBuffer
    
    private let hashKernel: ComputeKernel
    private let clearKernel: ComputeKernel
    private let findStartsKernel: ComputeKernel
    
    public init(device: MTLDevice, maxParticles: Int, gridRes: SIMD3<UInt32>) throws {
        self.maxParticles = maxParticles
        self.totalCells = Int(gridRes.x * gridRes.y * gridRes.z)
        
        self.hashKernel = try ComputeKernel(functionName: "hash_particles")
        self.clearKernel = try ComputeKernel(functionName: "clear_cell_starts")
        self.findStartsKernel = try ComputeKernel(functionName: "find_cell_starts")
        
        guard let cellIndices = GlobalHeap.shared.allocateBuffer(length: maxParticles * MemoryLayout<UInt32>.stride),
              let particleIndices = GlobalHeap.shared.allocateBuffer(length: maxParticles * MemoryLayout<UInt32>.stride),
              let cellStarts = GlobalHeap.shared.allocateBuffer(length: totalCells * MemoryLayout<UInt32>.stride) else {
            fatalError("Failed to allocate SpatialGrid buffers")
        }
        
        self.cellIndexBuffer = cellIndices
        self.particleIndexBuffer = particleIndices
        self.cellStartBuffer = cellStarts
        
        self.cellIndexBuffer.label = "Spatial Cell Indices"
        self.particleIndexBuffer.label = "Spatial Particle Indices"
        self.cellStartBuffer.label = "Spatial Cell Starts"
    }
    
    /// Phase 4.4: Discovers start indices of each cell in the sorted buffer.
    public func build(encoder: MTLComputeCommandEncoder, sortedCellIndices: MTLBuffer) {
        // 1. Clear Starts
        clearKernel.dispatch(encoder: encoder, gridSize: MTLSize(width: totalCells, height: 1, depth: 1))
        
        // 2. Find Starts
        encoder.setBuffer(sortedCellIndices, offset: 0, index: 0)
        encoder.setBuffer(cellStartBuffer, offset: 0, index: 1)
        findStartsKernel.dispatch(encoder: encoder, gridSize: MTLSize(width: maxParticles, height: 1, depth: 1))
    }
}
