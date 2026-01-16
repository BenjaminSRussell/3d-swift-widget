import Metal

/// BufferPool: Efficiently manages and reuses large MTLBuffers to reduce allocation overhead.
public final class BufferPool {
    
    private let device: MTLDevice
    private var pool: [Int: [MTLBuffer]] = [:]
    private let lock = NSLock()
    
    public init(device: MTLDevice) {
        self.device = device
    }
    
    /// Acquires a buffer of the requested size, either from the pool or by creating a new one.
    public func acquireBuffer(size: Int, options: MTLResourceOptions = .storageModeShared) -> MTLBuffer? {
        lock.lock()
        defer { lock.unlock() }
        
        if var buffers = pool[size], !buffers.isEmpty {
            let buffer = buffers.removeLast()
            pool[size] = buffers
            return buffer
        }
        
        return device.makeBuffer(length: size, options: options)
    }
    
    /// Returns a buffer to the pool for later reuse.
    public func releaseBuffer(_ buffer: MTLBuffer) {
        lock.lock()
        defer { lock.unlock() }
        
        let size = buffer.length
        var buffers = pool[size] ?? []
        buffers.append(buffer)
        pool[size] = buffers
    }
}
