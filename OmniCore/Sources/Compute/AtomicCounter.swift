import Metal

/// Phase 3.7: Shader Atomic Operations
/// Manages global atomic counters used for statistics (e.g. active particle count).
public final class AtomicCounter {
    
    public let buffer: MTLBuffer
    
    public init(device: MTLDevice) {
        // Atomic operations on GPU usually require 4-byte alignment and storageModeShared or Private.
        guard let b = device.makeBuffer(length: 4, options: .storageModeShared) else {
            fatalError("Failed to allocate AtomicCounter buffer")
        }
        self.buffer = b
        self.reset()
    }
    
    public func reset() {
        let ptr = buffer.contents().bindMemory(to: UInt32.self, capacity: 1)
        ptr.pointee = 0
    }
    
    public var value: UInt32 {
        let ptr = buffer.contents().bindMemory(to: UInt32.self, capacity: 1)
        return ptr.pointee
    }
}
