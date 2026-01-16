import Metal
import Foundation

/// HDTEUnifiedMemory: Manages zero-copy buffers for high-bandwidth data visualization.
/// leverages Apple Silicon's Unified Memory Architecture (UMA) via .storageModeShared.
public final class HDTEUnifiedMemory {
    
    private let device: MTLDevice
    
    public init(device: MTLDevice) {
        self.device = device
    }
    
    /// Allocates a zero-copy buffer shared between CPU and GPU.
    /// - Parameter size: Size in bytes.
    /// - Returns: A shared MTLBuffer.
    public func makeSharedBuffer(size: Int, label: String? = nil) -> MTLBuffer? {
        let buffer = device.makeBuffer(length: size, options: [.storageModeShared, .cpuCacheModeWriteCombined])
        buffer?.label = label
        return buffer
    }
    
    /// Maps a data stream directly to a shared buffer for zero-copy updates.
    public func mapSharedData<T>(count: Int, label: String? = nil) -> (MTLBuffer, UnsafeMutablePointer<T>)? {
        let size = MemoryLayout<T>.stride * count
        guard let buffer = makeSharedBuffer(size: size, label: label) else { return nil }
        
        let pointer = buffer.contents().bindMemory(to: T.self, capacity: count)
        return (buffer, pointer)
    }
}
