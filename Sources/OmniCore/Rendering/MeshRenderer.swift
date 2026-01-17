import Metal
import Foundation

/// Phase 5.3: Mesh Renderer
/// Orchestrates modern Mesh/Object shader pipelines.
public final class MeshRenderer {
    
    private let pipelineState: MTLRenderPipelineState
    
    public init(device: MTLDevice) throws {
        let descriptor = MTLMeshRenderPipelineDescriptor()
        
        // Load shaders using robust ShaderBundle
        let library = ShaderBundle.shared.metalLibrary

        
        descriptor.objectFunction = library.makeFunction(name: "object_cull")
        descriptor.meshFunction = library.makeFunction(name: "mesh_main")
        descriptor.fragmentFunction = library.makeFunction(name: "fragment_main")
        
        // Phase 3.2: MRT Setup
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[1].pixelFormat = .rgba16Float // Normal
        descriptor.depthAttachmentPixelFormat = .depth32Float
        
        // Phase 3.2: MRT Setup
        // Note: SDK mismatch for Mesh Shaders in this environment. 
        // We configure the fallback descriptor for MRT.
        
        // Fallback for older OS / SDK (Standard Vertex/Fragment)
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = library.makeFunction(name: "vertex_main")
        desc.fragmentFunction = library.makeFunction(name: "fragment_main")
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm
        desc.colorAttachments[1].pixelFormat = .rgba16Float
        desc.depthAttachmentPixelFormat = .depth32Float
        self.pipelineState = try device.makeRenderPipelineState(descriptor: desc, options: [], reflection: nil)
        
        // Phase 3.2: Composite Output
        guard let compFunc = library.makeFunction(name: "composite_main") else {
            throw NSError(domain: "OmniCore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Composite kernel missing"])
        }
        self.compositeState = try device.makeComputePipelineState(function: compFunc)
    }
    
    private let compositeState: MTLComputePipelineState
    
    public func draw(encoder: MTLRenderCommandEncoder, meshletCount: Int) {
        encoder.setRenderPipelineState(pipelineState)
        
        // Bind bindless resources
        ResourceManager.shared.encode(on: encoder)
        
        // Dispatch object shader
        encoder.drawMeshThreadgroups(MTLSize(width: meshletCount, height: 1, depth: 1), 
                                      threadsPerObjectThreadgroup: MTLSize(width: 32, height: 1, depth: 1), 
                                      threadsPerMeshThreadgroup: MTLSize(width: 64, height: 1, depth: 1))
    }
    
    public func composite(encoder: MTLComputeCommandEncoder, 
                          color: MTLTexture, 
                          normal: MTLTexture, 
                          depth: MTLTexture, 
                          sdf: MTLTexture, 
                          output: MTLTexture) {
        encoder.setComputePipelineState(compositeState)
        encoder.setTexture(color, index: 0)
        encoder.setTexture(normal, index: 1)
        encoder.setTexture(depth, index: 2)
        encoder.setTexture(sdf, index: 3)
        encoder.setTexture(output, index: 4)
        
        let w = compositeState.threadExecutionWidth
        let h = compositeState.maxTotalThreadsPerThreadgroup / w
        let threads = MTLSize(width: w, height: h, depth: 1)
        let grid = MTLSize(width: (output.width + w - 1) / w, 
                           height: (output.height + h - 1) / h, 
                           depth: 1)
        
        encoder.dispatchThreadgroups(grid, threadsPerThreadgroup: threads)
    }
}
