import Metal

/// Phase 3.5: Indirect Command Buffers (ICB)
/// Enables GPU-driven rendering by allowing compute shaders to encode draw calls.
public final class IndirectCmd {
    
    public let icb: MTLIndirectCommandBuffer
    public let count: Int
    
    public init(device: MTLDevice, maxDrawCount: Int) {
        let descriptor = MTLIndirectCommandBufferDescriptor()
        descriptor.commandTypes = .draw
        descriptor.inheritBuffers = false
        descriptor.inheritPipelineState = false
        
        // Tier 2 support is required for full GPU-driven pipelines on Apple Silicon
        guard let buffer = device.makeIndirectCommandBuffer(descriptor: descriptor, maxCommandCount: maxDrawCount, options: .storageModePrivate) else {
            fatalError("Failed to create Indirect Command Buffer. Device might not support ICB Tier 2.")
        }
        
        self.icb = buffer
        self.count = maxDrawCount
    }
    
    /// Prepares the ICB for execution by a compute kernel.
    public func encode(on encoder: MTLComputeCommandEncoder, index: Int) {
        encoder.useResource(icb, usage: .write)
    }
}
