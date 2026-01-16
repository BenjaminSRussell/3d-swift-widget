import Metal

/// Phase 4.3: GPU Sort Tool
/// Orchestrates the multi-pass Bitonic Sort dispatch.
public final class SortTool {
    
    private let kernel: ComputeKernel
    
    public init() throws {
        self.kernel = try ComputeKernel(functionName: "bitonic_sort")
    }
    
    /// Sorts the keys and values buffers in place.
    /// Note: count must be a power of 2 for Bitonic Sort.
    public func sort(encoder: MTLComputeCommandEncoder, keys: MTLBuffer, values: MTLBuffer, count: Int) {
        let numStages = Int(log2(Double(count)))
        
        for p in 0..<numStages {
            for q in 0...p {
                var pVal = UInt32(p)
                var qVal = UInt32(q)
                
                encoder.setBuffer(keys, offset: 0, index: 0)
                encoder.setBuffer(values, offset: 0, index: 1)
                encoder.setBytes(&pVal, length: 4, index: 2)
                encoder.setBytes(&qVal, length: 4, index: 3)
                
                let gridSize = MTLSize(width: count, height: 1, depth: 1)
                kernel.dispatch(encoder: encoder, gridSize: gridSize)
            }
        }
    }
}
