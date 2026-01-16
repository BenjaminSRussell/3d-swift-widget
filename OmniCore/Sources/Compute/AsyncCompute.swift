import Metal

/// Phase 3.6: Async Compute & Fences
/// Manages dependencies between compute and render passes to allow parallel GPU execution.
public final class AsyncCompute {
    
    public let fence: MTLFence
    
    public init(device: MTLDevice) {
        guard let f = device.makeFence() else {
            fatalError("Failed to create MTLFence")
        }
        self.fence = f
    }
    
    /// Signals that the compute work is done.
    public func updateFence(on encoder: MTLComputeCommandEncoder) {
        encoder.updateFence(fence)
    }
    
    /// Waits for the compute work to be done before starting another pass (e.g. rendering).
    public func waitForFence(on encoder: MTLRenderCommandEncoder, stage: MTLRenderStages = .vertex) {
        encoder.waitForFence(fence, before: stage)
    }
    
    public func waitForFence(on encoder: MTLComputeCommandEncoder) {
        encoder.waitForFence(fence)
    }
}
