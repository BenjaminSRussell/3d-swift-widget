import Metal

/// Phase 2.2: Ring Buffer
/// Manages triple-buffered uniform data to allow CPU to write ahead of GPU.
/// Prevents stalling.
public class RingBuffer<T> {
    
    private let device: MTLDevice
    private let buffers: [MTLBuffer]
    private let count: Int
    private var index: Int = 0
    
    public init(device: MTLDevice, count: Int = 3, label: String? = nil) {
        self.device = device
        self.count = count
        self.buffers = (0..<count).compactMap { _ in
            let buffer = device.makeBuffer(length: MemoryLayout<T>.stride, options: [.cpuCacheModeWriteCombined])
            buffer?.label = label
            return buffer
        }
        
        if buffers.count != count {
            fatalError("Failed to create RingBuffer chain.")
        }
    }
    
    /// Returns the current buffer for writing.
    /// Call `next()` after you are done writing to advance the ring.
    public var current: MTLBuffer {
        return buffers[index]
    }
    
    /// Advances the ring index.
    public func next() {
        index = (index + 1) % count
    }
    
    /// Writes data to the current buffer and advances.
    public func write(_ value: T) {
        let ptr = current.contents().bindMemory(to: T.self, capacity: 1)
        ptr.pointee = value
        next() // Auto-advance? Often safer to let caller control sync, but for simple uniforms this is fine.
    }
}
