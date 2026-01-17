import Metal
import OmniCore
import simd

/// Mirror of TuckerFactors in TuckerKernel.metal
public struct TuckerFactors {
    public var core = [Float](repeating: 1.0, count: 27)
    public var factorX = [Float](repeating: 0.1, count: 10)
    public var factorY = [Float](repeating: 0.1, count: 10)
    public var factorZ = [Float](repeating: 0.1, count: 10)
}

/// Phase 23.1: The Stochastic Data Channel
/// Orchestrates dimension reduction (10D -> 3D) for reactive topography.
public final class StochasticDataChannel {
    private let device: MTLDevice
    private let pipeline: MTLComputePipelineState
    
    // Buffers
    public private(set) var inputBuffer: MTLBuffer
    public private(set) var positionBuffer: MTLBuffer
    public private(set) var intensityBuffer: MTLBuffer
    public private(set) var factorBuffer: MTLBuffer
    
    private let numPoints: Int
    
    public init(device: MTLDevice, numPoints: Int) throws {
        self.device = device
        self.numPoints = numPoints
        
        let library: MTLLibrary?
        if let defaultLib = try? device.makeDefaultLibrary() {
            library = defaultLib
        } else {
            // Fallback to OmniShaders.metallib if default fails
            let bundle = Bundle(for: StochasticDataChannel.self)
            if let url = bundle.url(forResource: "OmniShaders", withExtension: "metallib") {
                library = try? device.makeLibrary(URL: url)
            } else {
                library = nil
            }
        }
        
        if let lib = library, let function = lib.makeFunction(name: "tucker_decompose") {
            self.pipeline = try device.makeComputePipelineState(function: function)
        } else {
            print("⚠️ StochasticDataChannel: tucker_decompose kernel not found. Simulator will be disabled.")
            // Use a dummy pipeline or handle nil. For now, we throw to avoid invalid state.
            throw NSError(domain: "OmniCore", code: 404, userInfo: [NSLocalizedDescriptionKey: "tucker_decompose kernel not found"])
        }
        
        // Allocate Buffers
        self.inputBuffer = device.makeBuffer(length: numPoints * 10 * MemoryLayout<Float>.stride, options: .storageModeShared)!
        self.positionBuffer = device.makeBuffer(length: numPoints * MemoryLayout<SIMD3<Float>>.stride, options: .storageModePrivate)!
        self.intensityBuffer = device.makeBuffer(length: numPoints * MemoryLayout<Float>.stride, options: .storageModePrivate)!
        
        var factors = TuckerFactors()
        self.factorBuffer = device.makeBuffer(length: 27 * 4 + 10 * 3 * 4, options: .storageModeShared)!
        updateFactorsBuffer(factors)
    }
    
    private func updateFactorsBuffer(_ factors: TuckerFactors) {
        let ptr = factorBuffer.contents()
        // Simple copy loop or manual pointer arithmetic to match C layout
        var offset = 0
        func copy(_ array: [Float]) {
            let size = array.count * 4
            array.withUnsafeBytes { ptr.advanced(by: offset).copyMemory(from: $0.baseAddress!, byteCount: size) }
            offset += size
        }
        copy(factors.core)
        copy(factors.factorX)
        copy(factors.factorY)
        copy(factors.factorZ)
    }
    
    /// Populates input with new data and dispatches decomposition
    public func update(with signalData: [Float], commandBuffer: MTLCommandBuffer) {
        guard signalData.count == numPoints * 10 else { return }
        
        // 1. Upload new data
        let ptr = inputBuffer.contents().assumingMemoryBound(to: Float.self)
        ptr.update(from: signalData, count: signalData.count)
        
        // 2. Dispatch Kernel
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(positionBuffer, offset: 0, index: 1)
        encoder.setBuffer(intensityBuffer, offset: 0, index: 2)
        encoder.setBuffer(factorBuffer, offset: 0, index: 3)
        
        let threadgroupSize = pipeline.maxTotalThreadsPerThreadgroup
        let numThreadgroups = (numPoints + threadgroupSize - 1) / threadgroupSize
        encoder.dispatchThreadgroups(MTLSize(width: numThreadgroups, height: 1, depth: 1), 
                                     threadsPerThreadgroup: MTLSize(width: threadgroupSize, height: 1, depth: 1))
        encoder.endEncoding()
    }
}
