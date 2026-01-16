import Metal

/// ShaderLibrary: Manages MSL shader loading and compute pipeline states.
public final class ShaderLibrary {
    
    private let device: MTLDevice
    private var computePipelines: [String: MTLComputePipelineState] = [:]
    private var renderPipelines: [String: MTLRenderPipelineState] = [:]
    
    public init(device: MTLDevice) {
        self.device = device
    }
    
    /// Loads a compute kernel from the library and caches the pipeline state.
    public func makeComputePipeline(functionName: String) throws -> MTLComputePipelineState {
        if let existing = computePipelines[functionName] {
            return existing
        }
        
        guard let library = MetalContext.shared.library.makeFunction(name: functionName) else {
            throw ShaderError.functionNotFound(functionName)
        }
        
        let pipeline = try device.makeComputePipelineState(function: library)
        computePipelines[functionName] = pipeline
        return pipeline
    }
    
    public enum ShaderError: Error {
        case functionNotFound(String)
        case compilationFailed(String)
    }
}
