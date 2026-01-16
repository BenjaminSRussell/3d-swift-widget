import Metal
import Foundation

public class StochasticPipeline {
    public let nutsSamplerState: MTLComputePipelineState
    
    public init(device: MTLDevice) throws {
        guard let library = try? device.makeDefaultLibrary(bundle: Bundle.module) else {
            throw NSError(domain: "OmniStochastic", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load bundle"])
        }
        
        guard let kernel = library.makeFunction(name: "nuts_sampler") else {
            throw NSError(domain: "OmniStochastic", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing nuts_sampler kernel"])
        }
        
        self.nutsSamplerState = try device.makeComputePipelineState(function: kernel)
    }
}
