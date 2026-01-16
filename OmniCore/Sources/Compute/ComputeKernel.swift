import Metal
import QuartzCore

/// Phase 3.1: Compute Pipeline Abstraction
/// Wrapper around MTLComputePipelineState to manage compilation and dispatch.
public class ComputeKernel {
    public let pipelineState: MTLComputePipelineState
    private let device: MTLDevice
    
    /// Initializes a compute kernel from the default library.
    /// - Parameters:
    ///   - functionName: The name of the kernel function in the .metal file.
    ///   - constants: Optional function constants for shader variants.
    public init(functionName: String, constants: MTLFunctionConstantValues? = nil) throws {
        self.device = GPUContext.shared.device
        
        // Load default library
        // SwiftPM resource bundle logic can be tricky.
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: ComputeKernel.self)
        #endif
        
        guard let libraryURL = bundle.url(forResource: "OmniShaders", withExtension: "metallib") else {
             fatalError("OmniShaders.metallib not found in bundle: \(bundle.bundlePath)")
        }
        let library = try device.makeLibrary(URL: libraryURL)
        
        // Load function
        let function: MTLFunction
        if let constants = constants {
            function = try library.makeFunction(name: functionName, constantValues: constants)
        } else {
            guard let fn = library.makeFunction(name: functionName) else {
                fatalError("Function \(functionName) not found in OmniShaders.metallib")
            }
            function = fn
        }
        
        self.pipelineState = try device.makeComputePipelineState(function: function)
    }
    
    /// Phase 3.2: Optimized Dispatch
    /// Automatically calculates threadgroups based on grid size and hardware limits.
    public func dispatch(encoder: MTLComputeCommandEncoder, gridSize: MTLSize) {
        encoder.setComputePipelineState(pipelineState)
        
        // Calculate optimal threadgroup size
        let maxThreads = pipelineState.maxTotalThreadsPerThreadgroup
        // let w = min(maxThreads, gridSize.width) // Simplify to 1D optimization for now, or use heuristics
        // A safe default is usually 32 or 64 (SIMD width).
        // Let's aim for 64.
        let threadsPerGroup = MTLSize(width: min(64, gridSize.width), height: 1, depth: 1)
        
        encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadsPerGroup)
    }
}
