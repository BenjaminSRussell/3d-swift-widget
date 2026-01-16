import Metal
import OmniCoreTypes

/// Phase 15.3: Post-Processing Controller
/// Orchestrates Bloom passes and the final lens effect composition.
public final class PostProcessor {
    
    private let thresholdKernel: ComputeKernel
    private let blurKernel: ComputeKernel
    private let finalPassKernel: ComputeKernel
    
    public init() throws {
        self.thresholdKernel = try ComputeKernel(functionName: "bloom_threshold")
        self.blurKernel = try ComputeKernel(functionName: "bloom_blur")
        self.finalPassKernel = try ComputeKernel(functionName: "apply_post_process")
    }
    
    public func process(commandBuffer: MTLCommandBuffer, 
                        sceneTexture: MTLTexture, 
                        bloomPing: MTLTexture, 
                        bloomPong: MTLTexture,
                        outputTexture: MTLTexture,
                        frameUniforms: MTLBuffer) {
        
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        let width = sceneTexture.width
        let height = sceneTexture.height
        let gridSize = MTLSize(width: width, height: height, depth: 1)
        
        // 1. Threshold
        encoder.setTexture(sceneTexture, index: 0)
        encoder.setTexture(bloomPing, index: 1)
        thresholdKernel.dispatch(encoder: encoder, gridSize: gridSize)
        
        // 2. Gaussian Blur (Vertical then Horizontal)
        var horizontal = false
        encoder.setTexture(bloomPing, index: 0)
        encoder.setTexture(bloomPong, index: 1)
        encoder.setBytes(&horizontal, length: 1, index: 0)
        blurKernel.dispatch(encoder: encoder, gridSize: gridSize)
        
        horizontal = true
        encoder.setTexture(bloomPong, index: 0)
        encoder.setTexture(bloomPing, index: 1)
        encoder.setBytes(&horizontal, length: 1, index: 0)
        blurKernel.dispatch(encoder: encoder, gridSize: gridSize)
        
        // 3. Final Compose
        encoder.setTexture(sceneTexture, index: 0)
        encoder.setTexture(bloomPing, index: 1)
        encoder.setTexture(outputTexture, index: 2)
        encoder.setBuffer(frameUniforms, offset: 0, index: 0)
        finalPassKernel.dispatch(encoder: encoder, gridSize: gridSize)
        
        encoder.endEncoding()
    }
}
