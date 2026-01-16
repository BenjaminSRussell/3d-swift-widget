import Metal
import QuartzCore

/// Phase 3.1: Compute Pipeline Abstraction
/// Wrapper around MTLComputePipelineState to manage compilation and dispatch.
public class ComputeKernel {
    public let pipelineState: MTLComputePipelineState
    private let device: MTLDevice
    
    /// Helper to find the bundle containing the metallib.
    private static var safeBundle: Bundle {
        // Strategy 1: Bundle(for: Class) - Works for Frameworks and Test Targets
        let bundle = Bundle(for: ComputeKernel.self)
        if bundle.url(forResource: "OmniShaders", withExtension: "metallib") != nil {
            return bundle
        }
        
        // Strategy 2: Bundle.main - Works for executables
        if Bundle.main.url(forResource: "OmniShaders", withExtension: "metallib") != nil {
            return Bundle.main
        }
        
        // Strategy 3: Iterate all bundles (Desperate fallback)
        for b in Bundle.allBundles + Bundle.allFrameworks {
            if b.url(forResource: "OmniShaders", withExtension: "metallib") != nil {
                return b
            }
        }
        
        fatalError("Could not find OmniShaders.metallib in any bundle.")
    }

    /// Initializes a compute kernel from the default library.
    /// - Parameters:
    ///   - functionName: The name of the kernel function in the .metal file.
    ///   - constants: Optional function constants for shader variants.
    public init(functionName: String, constants: MTLFunctionConstantValues? = nil) throws {
        self.device = GPUContext.shared.device
        
        // Load default library
        let bundle = Self.safeBundle
        
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
    
    /// Phase 3.2 & 3.3: Optimized Dispatch & Threadgroup Memory
    /// Automatically calculates threadgroups based on grid size and hardware limits.
    /// - Parameters:
    ///   - encoder: The encoder to dispatch on.
    ///   - gridSize: The total number of threads required.
    ///   - threadgroupMemoryLength: Optional local data store (LDS) size in bytes.
    public func dispatch(encoder: MTLComputeCommandEncoder, gridSize: MTLSize, threadgroupMemoryLength: Int = 0) {
        encoder.setComputePipelineState(pipelineState)
        
        if threadgroupMemoryLength > 0 {
            encoder.setThreadgroupMemoryLength(threadgroupMemoryLength, index: 0)
        }
        
        // Phase 3.2: Maximize execution unit utilization by aligning to SIMD width (typically 32 or 64 on Apple Silicon)
        let maxThreads = pipelineState.maxTotalThreadsPerThreadgroup
        let executionWidth = pipelineState.threadExecutionWidth
        
        // Heuristic: Use execution width (32/64) as the primary dimension for 1D/linear workloads
        let width = min(executionWidth, maxThreads)
        let threadsPerGroup = MTLSize(width: width, height: 1, depth: 1)
        
        // Metal 3: Non-uniform threadgroup dispatching allows the grid to not be a multiple of threadgroups
        encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadsPerGroup)
    }
}
