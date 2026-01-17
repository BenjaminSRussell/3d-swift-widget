import Metal
import MetalKit
import MetalPerformanceShaders
import OmniGeometry

import OmniCore 

/// Hyper-Dimensional Topography Engine Pipeline
/// Orchestrates: Tucker Decomposition → Bayesian Sampling → Volumetric Rendering
public class HDTEPipeline {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let memoryManager: MemoryManager
    
    // Phase 4: Render Graph
    private let renderGraph: RenderGraph
    
    // Pipeline states
    private var tuckerPipeline: MTLComputePipelineState!
    private var bayesianPipeline: MTLComputePipelineState!
    private var terrainMeshPipeline: MTLRenderPipelineState! // Terrain Geometry
    private var bridgeMeshPipeline: MTLRenderPipelineState!  // Pedagogical Bridges
    private var volumetricPipeline: MTLRenderPipelineState!  // Fog Overlay
    
    // Shared resources
    private var inputBuffer: MTLBuffer! // 10D data (shared mode for zero-copy)
    private var positionBuffer: MTLBuffer! // 3D positions (aliased on heap)
    private var varianceTexture: MTLTexture! // Uncertainty map (aliased on heap)
    private var factorsBuffer: MTLBuffer?
    
    public init(device: MTLDevice) throws {
        self.device = device
        self.commandQueue = MetalContext.shared.commandQueue // SHARED QUEUE
        self.memoryManager = MemoryManager(device: device)
        self.renderGraph = RenderGraph(device: device)
        
        
        // Initialize factors - Using flat array for deterministic layout
        struct TuckerFactors {
            var core = (0..<27).map { _ in Float(1.0) }
            var factor_x = (0..<10).map { _ in Float(1.0) }
            var factor_y = (0..<10).map { _ in Float(1.0) }
            var factor_z = (0..<10).map { _ in Float(1.0) }
        }
        // Wait, map returns [Float], we need fixed size. 
        // Let's use a simpler flat buffer and direct copy.
        let factorsCount = 27 + 10 + 10 + 10
        var factorsData = [Float](repeating: 1.0, count: factorsCount)
        // Spread data
        factorsData[27 + 0] = -5.0; factorsData[27 + 4] = 5.0
        factorsData[27 + 10 + 1] = 5.0; factorsData[27 + 10 + 6] = -5.0
        factorsData[27 + 20 + 2] = 5.0; factorsData[27 + 20 + 8] = -5.0
        
        factorsBuffer = device.makeBuffer(bytes: &factorsData, length: factorsCount * 4, options: [])
        print("DEBUG: HDTE - Initialized Factors Buffer (\(factorsCount) floats)")
        
        
        try setupPipelines()
        configurePipeline()
    }
    
    func configurePipeline() {
        // 1. Render Topography to HDR Texture
        renderGraph.addPass(label: "Geometry", format: .rgba16Float)
        
        // 2. Render Text (SDF) to same HDR Texture (No depth test against bloom)
        renderGraph.addPass(label: "Typography", input: "Geometry")
        
        // 3. Bloom Pass (Compute Shader)
        // Uses EnhancedPostProcess.metal
        renderGraph.addComputePass(label: "Bloom", shader: "compute_bloom_dual_kawase")
        
        // 4. Tone Mapping & Dithering (Final Output)
        // Converts HDR -> SDR and applies Blue Noise
        renderGraph.addComputePass(label: "ToneMap", shader: "compute_aces_tonemap")
    }
    
    private func setupPipelines() throws {
        if let tuckerFunc = ShaderBundle.shared.makeFunction(name: "tucker_decompose") {
            print("DEBUG: HDTE - Found tucker_decompose")
            tuckerPipeline = try? device.makeComputePipelineState(function: tuckerFunc)
        } else { print("DEBUG: HDTE - Missing tucker_decompose") }
        
        if let bayesianFunc = ShaderBundle.shared.makeFunction(name: "bayesian_sampler") {
            print("DEBUG: HDTE - Found bayesian_sampler")
            bayesianPipeline = try? device.makeComputePipelineState(function: bayesianFunc)
        } else { print("DEBUG: HDTE - Missing bayesian_sampler") }
        
        // Terrain Mesh Pipeline (Mesh + Object)
        let meshDescriptor = MTLMeshRenderPipelineDescriptor()
        meshDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        meshDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        if let meshFunc = ShaderBundle.shared.makeFunction(name: "terrain_mesh"),
           let objectFunc = ShaderBundle.shared.makeFunction(name: "terrain_object"),
           let fragFunc = ShaderBundle.shared.makeFunction(name: "terrain_fragment") {
            print("DEBUG: HDTE - Found Mesh/Object/Frag Shaders")
            meshDescriptor.meshFunction = meshFunc
            meshDescriptor.objectFunction = objectFunc
            meshDescriptor.fragmentFunction = fragFunc
            terrainMeshPipeline = try? device.makeRenderPipelineState(descriptor: meshDescriptor, options: []).0
        } else { print("DEBUG: HDTE - Missing Mesh/Object/Frag Shaders") }
        
        
        // Pedagogical Bridge Pipeline (Mesh only)
        let bridgeDescriptor = MTLMeshRenderPipelineDescriptor()
        bridgeDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        bridgeDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        if let bridgeMeshFunc = ShaderBundle.shared.makeFunction(name: "topological_bridge_mesh"),
           let bridgeFragFunc = ShaderBundle.shared.makeFunction(name: "topological_bridge_fragment") {
            bridgeDescriptor.meshFunction = bridgeMeshFunc
            bridgeDescriptor.fragmentFunction = bridgeFragFunc
            bridgeMeshPipeline = try? device.makeRenderPipelineState(descriptor: bridgeDescriptor, options: []).0
        }
        
        // Volumetric rendering (Fog Overlay)
        let renderDescriptor = MTLRenderPipelineDescriptor()
        renderDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        renderDescriptor.colorAttachments[0].isBlendingEnabled = true
        renderDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        renderDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        renderDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        if let vertFunc = ShaderBundle.shared.makeFunction(name: "terrain_vertex"),
           let fragFunc = ShaderBundle.shared.makeFunction(name: "volumetric_fragment") {
            renderDescriptor.vertexFunction = vertFunc
            renderDescriptor.fragmentFunction = fragFunc
            volumetricPipeline = try? device.makeRenderPipelineState(descriptor: renderDescriptor)
        }
    }
    
    /// Main rendering pipeline: 10D data → 3D volumetric visualization
    public func render(commandBuffer: MTLCommandBuffer, inputData: [Float], outputTexture: MTLTexture, viewMatrix: simd_float4x4) {
        // guard let commandBuffer = commandQueue.makeCommandBuffer() else { return } // REMOVED: Use passed in buffer
        
        
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
        if let tuckerEncoder = commandBuffer.makeComputeCommandEncoder() {
            if let tuckerPSO = tuckerPipeline {
                tuckerEncoder.setComputePipelineState(tuckerPSO)
                tuckerEncoder.setBuffer(inputBuffer, offset: 0, index: 0)
                tuckerEncoder.setBuffer(computeBuffers[0], offset: 0, index: 1) // Positions
                tuckerEncoder.setBuffer(computeBuffers[1], offset: 0, index: 2) // Intensity
                if let f = factorsBuffer {
                    tuckerEncoder.setBuffer(f, offset: 0, index: 3)
                }
                
                let threadgroupSize = MTLSize(width: 64, height: 1, depth: 1)
                let threadgroups = MTLSize(width: (1024 + 63) / 64, height: 1, depth: 1)
                tuckerEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
            }
            tuckerEncoder.endEncoding()
        }
        
        // Pass 2: Bayesian Sampling (Compute μ, σ²)
        if let bayesianEncoder = commandBuffer.makeComputeCommandEncoder() {
            if let bayesianPSO = bayesianPipeline {
                bayesianEncoder.setComputePipelineState(bayesianPSO)
                bayesianEncoder.setBuffer(computeBuffers[1], offset: 0, index: 0) // Data
                
                let threadgroupSize = MTLSize(width: 64, height: 1, depth: 1)
                let threadgroups = MTLSize(width: 16, height: 1, depth: 1) // 16 clusters
                bayesianEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
            }
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
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        renderPassDescriptor.depthAttachment.texture = depthTexture
        renderPassDescriptor.depthAttachment.loadAction = .clear
        renderPassDescriptor.depthAttachment.clearDepth = 1.0
        renderPassDescriptor.depthAttachment.storeAction = .dontCare // Memoryless!
        
        // Pass 3: Geometry Rendering (Terrain + Bridges)
        if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            
            // 3.1: Terrain Mesh Shader
            if let terrainPSO = terrainMeshPipeline {
                renderEncoder.setRenderPipelineState(terrainPSO)
                
                // Bind MVP to buffer(0)
                var mvp = viewMatrix
                renderEncoder.setMeshBytes(&mvp, length: MemoryLayout<simd_float4x4>.stride, index: 0)
                
                // Bind Stochastic Data
                renderEncoder.setObjectBuffer(computeBuffers[0], offset: 0, index: 2) // Positions
                renderEncoder.setObjectBuffer(computeBuffers[1], offset: 0, index: 3) // Intensities
                
                renderEncoder.setMeshBuffer(computeBuffers[0], offset: 0, index: 2) // Positions
                renderEncoder.setMeshBuffer(computeBuffers[1], offset: 0, index: 3) // Intensities
                
                // Dispatch object shader grid (e.g. 32x32 meshlets for high density)
                let grid = MTLSize(width: 32, height: 32, depth: 1)
                let threadsPerThreadgroup = MTLSize(width: 1, height: 1, depth: 1)
                renderEncoder.drawMeshThreadgroups(grid, threadsPerObjectThreadgroup: threadsPerThreadgroup, threadsPerMeshThreadgroup: threadsPerThreadgroup)
            }
            
            renderEncoder.endEncoding()
        }
        
        // commandBuffer.commit() // REMOVED: Coordinator will commit
    }
    
    public func reportMemory() {
        memoryManager.reportMemoryUsage()
    }
}

public enum PipelineError: Error {
    case commandQueueCreationFailed
    case libraryLoadingFailed
    case pipelineStateCreationFailed
}
