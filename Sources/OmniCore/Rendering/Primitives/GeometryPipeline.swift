import Metal
import Foundation
import OmniCore

public class GeometryPipeline {
    public let pipelineState: MTLRenderPipelineState
    
    public init(device: MTLDevice, pixelFormat: MTLPixelFormat) throws {
        // Load the default library from the OmniCore ShaderBundle
        // Load from ShaderBundle using robust multi-library lookup
        let bundle = ShaderBundle.shared
        
        guard let objectFunction = bundle.makeFunction(name: "terrain_object"),
              let meshFunction = bundle.makeFunction(name: "terrain_mesh"),
              let fragmentFunction = bundle.makeFunction(name: "terrain_fragment") else {
             // Basic fallback purely for build passing if shaders aren't found/compiled yet
             // In production this is a fatal error
             throw NSError(domain: "OmniGeometry", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing shader functions"])
        }
        
        let descriptor = MTLMeshRenderPipelineDescriptor()
        descriptor.objectFunction = objectFunction
        descriptor.meshFunction = meshFunction
        descriptor.fragmentFunction = fragmentFunction
        
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        descriptor.depthAttachmentPixelFormat = .depth32Float
        
        // Alpha blending for "Stochastic" transparency
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        // Use the overload that returns just the state if options are not needed, or unpack
        let (state, _) = try device.makeRenderPipelineState(descriptor: descriptor, options: [])
        self.pipelineState = state
        
        // Load ICB Update Kernel
        guard let icbFunction = bundle.makeFunction(name: "update_icb") else {
             throw NSError(domain: "OmniGeometry", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing update_icb kernel"])
        }
        self.icbPipelineState = try device.makeComputePipelineState(function: icbFunction)
        self.icbFunction = icbFunction
        
        // Ridge Line Pipeline (Type 14)
        guard let ridgeMesh = bundle.makeFunction(name: "ridgeline_mesh"),
              let ridgeFrag = bundle.makeFunction(name: "ridgeline_fragment") else {
             throw NSError(domain: "OmniGeometry", code: 4, userInfo: [NSLocalizedDescriptionKey: "Missing ridgeline shaders"])
        }
        
        // Clone descriptor for lines
        let ridgeDescriptor = MTLMeshRenderPipelineDescriptor()
        ridgeDescriptor.objectFunction = objectFunction // Reuse object function
        ridgeDescriptor.meshFunction = ridgeMesh
        ridgeDescriptor.fragmentFunction = ridgeFrag
        ridgeDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        ridgeDescriptor.depthAttachmentPixelFormat = .depth32Float
        ridgeDescriptor.colorAttachments[0].isBlendingEnabled = true
        ridgeDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        ridgeDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        let (ridgeState, _) = try device.makeRenderPipelineState(descriptor: ridgeDescriptor, options: [])
        self.ridgeLinePipelineState = ridgeState
    }
    
    public let icbPipelineState: MTLComputePipelineState
    public let icbFunction: MTLFunction
    public let ridgeLinePipelineState: MTLRenderPipelineState
}
