import Metal

/// Phase 2.1: MTLHeap Architecture
/// Manages a single large contiguous block of GPU memory (The Heap).
/// Prevents fragmentation and OS-level memory pressure kills by reserving budget upfront.
public final class GlobalHeap {
    public static let shared = GlobalHeap()
    
    public let heap: MTLHeap
    
    // Strict Limit: 20MB (Leaving ~10MB headroom for strict 30MB Widget limit)
    private let heapSize = 20 * 1024 * 1024
    
    private init() {
        let descriptor = MTLHeapDescriptor()
        descriptor.size = heapSize
        descriptor.storageMode = .private // GPU only. No CPU direct access.
        descriptor.hazardTrackingMode = .tracked
        
        
        let device = GPUContext.shared.device
        guard device === GPUContext.shared.device else {
             fatalError("GPU Context not initialized")
        }
        
        guard let createdHeap = device.makeHeap(descriptor: descriptor) else {
            fatalError("CRITICAL FAILURE: Could not allocate Global Heap of size \(heapSize) bytes. System is potentially OOM.")
        }
        
        self.heap = createdHeap
        print("OmniEngine: Global Heap Allocated (\(heapSize / 1024 / 1024) MB)")
    }
    
    /// Allocates a buffer efficiently from the heap.
    /// Note: The heap is .private, so the buffer will be .private (GPU only).
    public func allocateBuffer(length: Int, options: MTLResourceOptions = []) -> MTLBuffer? {
        var opts = options
        opts.insert(.storageModePrivate)
        return heap.makeBuffer(length: length, options: opts)
    }
    
    /// Allocates a texture efficiently from the heap.
    /// Supports aliasing (reusing memory) implicitly if resources are deallocated.
    public func allocateTexture(descriptor: MTLTextureDescriptor) -> MTLTexture? {
        return heap.makeTexture(descriptor: descriptor)
    }
}
