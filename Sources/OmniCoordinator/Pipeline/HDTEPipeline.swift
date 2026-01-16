import Metal
import MetalKit
import MetalPerformanceShaders

/// Hyper-Dimensional Topography Engine Pipeline
/// Orchestrates: Tucker Decomposition → Bayesian Sampling → Volumetric Rendering
public class HDTEPipeline {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let memoryManager: MemoryManager
    
    // Pipeline states
    private var tuckerPipeline: MTLComputePipelineState!
    private var bayesianPipeline: MTLComputePipelineState!
    private var volumetricPipeline: MTLRenderPipelineState!
    
    // Shared resources
    private var inputBuffer: MTLBuffer! // 10D data (shared mode for zero-copy)
    private var positionBuffer: MTLBuffer! // 3D positions (aliased on heap)
    private var varianceTexture: MTLTexture! // Uncertainty map (aliased on heap)
    
    public init(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        self.memoryManager = MemoryManager(device: device)
        
        setupPipelines()
    }
    
    private func setupPipelines() {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Failed to load Metal library")
        }
        
        // Tucker decomposition
        if let tuckerFunc = library.makeFunction(name: "tucker_decompose") {
            tuckerPipeline = try? device.makeComputePipelineState(function: tuckerFunc)
        }
        
        // Bayesian sampler
        if let bayesianFunc = library.makeFunction(name: "bayesian_sampler") {
            bayesianPipeline = try? device.makeComputePipelineState(function: bayesianFunc)
        }
        
        // Volumetric rendering
        let renderDescriptor = MTLRenderPipelineDescriptor()
        renderDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        renderDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        if let vertFunc = library.makeFunction(name: "terrain_vertex"),
           let fragFunc = library.makeFunction(name: "volumetric_fragment") {
            renderDescriptor.vertexFunction = vertFunc
            renderDescriptor.fragmentFunction = fragFunc
            volumetricPipeline = try? device.makeRenderPipelineState(descriptor: renderDescriptor)
        }
    }
    
    /// Main rendering pipeline: 10D data → 3D volumetric visualization
    public func render(inputData: [Float], outputTexture: MTLTexture, viewMatrix: simd_float4x4) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        // === PHASE 1: COMPUTE (Memory Aliasing Active) ===
        
        // Create shared input buffer (zero-copy from CPU)
        inputBuffer = memoryManager.createSharedBuffer(size: inputData.count * MemoryLayout<Float>.stride)
        inputBuffer.contents().copyMemory(from: inputData, byteCount: inputData.count * MemoryLayout<Float>.stride)
        
        // Allocate compute resources on heap
        let computeBuffers = memoryManager.allocateComputeBuffers(sizes: [
            1024 * MemoryLayout<simd_float3>.stride, // Position buffer
            1024 * MemoryLayout<Float>.stride        // Intensity buffer
        ])
        
        // Pass 1: Tucker Decomposition (10D → 3D)
        if let tuckerEncoder = commandBuffer.makeComputeCommandEncoder(),
           let tuckerPSO = tuckerPipeline {
            tuckerEncoder.setComputePipelineState(tuckerPSO)
            tuckerEncoder.setBuffer(inputBuffer, offset: 0, index: 0)
            tuckerEncoder.setBuffer(computeBuffers[0], offset: 0, index: 1) // Positions
            tuckerEncoder.setBuffer(computeBuffers[1], offset: 0, index: 2) // Intensity
            
            let threadgroupSize = MTLSize(width: 64, height: 1, depth: 1)
            let threadgroups = MTLSize(width: (1024 + 63) / 64, height: 1, depth: 1)
            tuckerEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
            tuckerEncoder.endEncoding()
        }
        
        // Pass 2: Bayesian Sampling (Compute μ, σ²)
        if let bayesianEncoder = commandBuffer.makeComputeCommandEncoder(),
           let bayesianPSO = bayesianPipeline {
            bayesianEncoder.setComputePipelineState(bayesianPSO)
            bayesianEncoder.setBuffer(computeBuffers[1], offset: 0, index: 0) // Data
            
            let threadgroupSize = MTLSize(width: 64, height: 1, depth: 1)
            let threadgroups = MTLSize(width: 16, height: 1, depth: 1) // 16 clusters
            bayesianEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
            bayesianEncoder.endEncoding()
        }
        
        // === PHASE 2: RENDER (Memory Re-aliased) ===
        
        // Allocate render resources (reusing heap memory)
        let varianceDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rg32Float,
            width: 256,
            height: 256,
            mipmapped: false
        )
        let renderTextures = memoryManager.allocateRenderTextures(descriptors: [varianceDesc])
        varianceTexture = renderTextures[0]
        
        // Create memoryless depth buffer
        let depthTexture = memoryManager.createMemorylessDepth(
            width: outputTexture.width,
            height: outputTexture.height
        )
        
        // Render pass descriptor
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        renderPassDescriptor.depthAttachment.texture = depthTexture
        renderPassDescriptor.depthAttachment.loadAction = .clear
        renderPassDescriptor.depthAttachment.clearDepth = 1.0
        renderPassDescriptor.depthAttachment.storeAction = .dontCare // Memoryless!
        
        // Pass 3: Volumetric Rendering
        if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
           let volumetricPSO = volumetricPipeline {
            renderEncoder.setRenderPipelineState(volumetricPSO)
            renderEncoder.setFragmentTexture(varianceTexture, index: 1)
            
            // Draw full-screen quad for raymarching
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
        }
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Report memory usage
        memoryManager.reportMemoryUsage()
    }
}
