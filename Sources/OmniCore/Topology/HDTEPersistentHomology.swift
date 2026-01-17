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

    /// Extracts edges (1-simplices) for the Rips Complex based on an epsilon threshold.
    /// Returns a buffer of int2 pairs representing edges.
    public func buildRipsComplex(distanceMatrix: MTLBuffer, count: Int, epsilon: Float) -> MTLBuffer? {
        guard let commandBuffer = context.makeCommandBuffer(),
              let pipeline = try? shaderLibrary.makeComputePipeline(functionName: "extractEdges") else { return nil }
        
        // Atomic counter for edge count
        let counterBuffer = context.device.makeBuffer(length: MemoryLayout<UInt32>.size, options: .storageModeShared)
        memset(counterBuffer?.contents(), 0, MemoryLayout<UInt32>.size)
        
        // Estimate max edges (worst case N^2/2) -- potentially huge, be careful.
        // For 1024 points -> ~500k edges. For 1M points -> Impossible.
        // We assume 'count' is a small subset (landmarks) e.g. < 4096.
        let maxEdges = min(count * count / 2, 2_000_000) 
        let edgeBuffer = context.device.makeBuffer(length: maxEdges * MemoryLayout<SIMD2<Int32>>.stride, options: .storageModePrivate)
        
        guard let encoder = commandBuffer.makeComputeCommandEncoder(), let edgeBuffer = edgeBuffer else { return nil }
        
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(distanceMatrix, offset: 0, index: 0)
        encoder.setBuffer(edgeBuffer, offset: 0, index: 1)
        encoder.setBuffer(counterBuffer, offset: 0, index: 2)
        
        var consts = (UInt32(count), epsilon)
        encoder.setBytes(&consts, length: MemoryLayout<UInt32>.size + MemoryLayout<Float>.size, index: 3)
        
        let threadsPerThreadgroup = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupsPerGrid = MTLSize(
            width: (count + 15) / 16,
            height: (count + 15) / 16,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
        
        commandBuffer.commit()
        return edgeBuffer
    }

    /// Computes 0-dimensional persistent homology (connected components) using Union-Find.
    /// - Parameter edgeBuffer: Buffer containing int2 edges (indices).
    /// - Parameter distanceMatrix: Matrix containing edge weights.
    /// - Parameter count: Number of points.
    /// - Returns: A list of (birth, death) pairs for 0D features.
    /// Computes 0-dimensional persistent homology (connected components) using Union-Find.
    /// - Returns: A tuple containing the persistence pairs and the component assignment map (one ID per point).
    public func compute0DPersistence(edgeBuffer: MTLBuffer, edgeCount: Int, distanceMatrix: MTLBuffer, pointCount: Int) -> (pairs: [(Float, Float)], componentMap: [Int])? {
        // Read back data (Performance warning: synchronous CPU read)
        // In production, this should be double-buffered or async.
        let edges = edgeBuffer.contents().bindMemory(to: SIMD2<Int32>.self, capacity: edgeCount)
        let weights = distanceMatrix.contents().bindMemory(to: Float.self, capacity: pointCount * pointCount)
        
        // 1. Collect and Sort Edges
        var edgeList: [(u: Int, v: Int, weight: Float)] = []
        edgeList.reserveCapacity(edgeCount)
        
        for i in 0..<edgeCount {
            let u = Int(edges[i].x)
            let v = Int(edges[i].y)
            let w = weights[v * pointCount + u]
            edgeList.append((u, v, w))
        }
        
        // Ascending order for filtration
        edgeList.sort { $0.weight < $1.weight }
        
        // 2. Union-Find
        var parent = Array(0..<pointCount)
        func find(_ i: Int) -> Int {
            if parent[i] == i { return i }
            parent[i] = find(parent[i]) // Path compression
            return parent[i]
        }
        
        func union(_ i: Int, _ j: Int) -> Bool {
            let rootI = find(i)
            let rootJ = find(j)
            if rootI != rootJ {
                parent[rootI] = rootJ
                return true
            }
            return false
        }
        
        // 3. Compute Persistence
        var persistencePairs: [(Float, Float)] = []
        
        for edge in edgeList {
            let rootU = find(edge.u)
            let rootV = find(edge.v)
            
            if rootU != rootV {
                persistencePairs.append((0.0, edge.weight))
                let _ = union(edge.u, edge.v)
            }
        }
        
        let remainingRoots = Set(parent.map { find($0) })
        for _ in remainingRoots {
             persistencePairs.append((0.0, Float.infinity))
        }
        
        // Flatten the disjoint set to get canonical component IDs for every point
        let finalMap = (0..<pointCount).map { find($0) }
        
        return (persistencePairs, finalMap)
    }
}
