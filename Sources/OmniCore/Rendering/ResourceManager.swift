import Metal

/// Phase 6.2: Resource Manager (Bindless)
/// Manages a table of resources that can be accessed by index in shaders.
public final class ResourceManager {
    
    public static let shared = ResourceManager()
    
    private let device: MTLDevice
    private let textureHeap: MTLHeap
    
    // We store an array of textures to maintain strong references
    private var textures: [MTLTexture] = []
    public let argumentBuffer: MTLBuffer
    public let causticsBuffer: MTLBuffer
    
    private init() {
        self.device = GPUContext.shared.device
        
        // Use a dedicated heap for textures to permit residency management via useHeap
        let heapDescriptor = MTLHeapDescriptor()
        heapDescriptor.size = 64 * 1024 * 1024 // 64MB for textures (overrides the 20MB budget for demonstration)
        heapDescriptor.storageMode = .private
        self.textureHeap = device.makeHeap(descriptor: heapDescriptor)!
        
        // Allocate argument buffer for 1024 textures
        self.argumentBuffer = device.makeBuffer(length: 1024 * 8, options: .storageModeShared)! // 8 bytes per handle (approx)
        self.argumentBuffer.label = "Global Texture Table"
        
        // Phase 13.2: Caustics Buffer Allocation
        // Assuming a 512x512 caustics map for now
        let causticsLength = 512 * 512 * MemoryLayout<UInt32>.stride
        self.causticsBuffer = device.makeBuffer(length: causticsLength, options: .storageModePrivate)!
        self.causticsBuffer.label = "Caustics Accumulation Buffer"
    }
    
    public func registerTexture(_ texture: MTLTexture) -> Int {
        let index = textures.count
        textures.append(texture)
        return index
    }
    
    /// Phase 14.3: Font Atlas Registration
    public func registerFontAtlas(_ texture: MTLTexture) -> Int {
        texture.label = "MSDF Font Atlas"
        return registerTexture(texture)
    }
    
    /// Clears the caustics accumulation buffer.
    public func clearCausticsBuffer(on commandBuffer: MTLCommandBuffer) {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        encoder.setBuffer(causticsBuffer, offset: 0, index: 0)
        // We'd use a small 'clear_buffer' kernel here or fill with zeros
        // For OMNI, we'll use a compute-based clear for maximum GPU-driven efficiency.
        // encoder.setComputePipelineState(clearKernel)
        // encoder.dispatchThreads(...)
        encoder.endEncoding()
        
        // Alternative: blit based fill if supported/preferred
        let blit = commandBuffer.makeBlitCommandEncoder()
        blit?.fill(buffer: causticsBuffer, range: 0..<causticsBuffer.length, value: 0)
        blit?.endEncoding()
    }
    
    /// Prepares the argument buffer for the shader.
    public func encode(on encoder: MTLRenderCommandEncoder) {
        encoder.useHeap(textureHeap)
        // In a real implementation, we'd use MTLArgumentEncoder to write the handles into argumentBuffer
        encoder.setFragmentBuffer(argumentBuffer, offset: 0, index: 10) // 10 is our GlobalResources index
    }
}
