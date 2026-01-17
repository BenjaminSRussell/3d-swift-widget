import Metal
import Foundation
import OmniCore

public class StochasticPipeline {
    public let nutsSamplerState: MTLComputePipelineState
    
    public init(device: MTLDevice) throws {
        // Use robust ShaderBundle lookup
        guard let kernel = ShaderBundle.shared.makeFunction(name: "nuts_sampler") else {
            throw NSError(domain: "OmniStochastic", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing nuts_sampler kernel"])
        }
        
        self.nutsSamplerState = try device.makeComputePipelineState(function: kernel)
    }
    
    // Dedicated queue for stochastic processes to avoid blocking rendering
    private var commandQueue: MTLCommandQueue?
    
    public func dispatchAsync(device: MTLDevice) {
        if commandQueue == nil {
            commandQueue = device.makeCommandQueue()
        }
        
        guard let commandBuffer = commandQueue?.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        encoder.setComputePipelineState(nutsSamplerState)
        
        // Dummy dispatch for the sampler - replacing single thread dispatch with enough to do work
        let w = nutsSamplerState.threadExecutionWidth
        encoder.dispatchThreadgroups(MTLSize(width: 1, height: 1, depth: 1), 
                                     threadsPerThreadgroup: MTLSize(width: w, height: 1, depth: 1))
        
        encoder.endEncoding()
        commandBuffer.commit()
    }
}
