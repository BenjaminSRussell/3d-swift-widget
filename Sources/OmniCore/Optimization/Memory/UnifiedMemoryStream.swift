import Foundation
import Metal

/// **The Zero-Copy Sub-System**
///
/// A specialized tool for Apple Silicon that maps data directly from the Neural Engine
/// to the GPU, bypassing the CPU entirely.
public protocol UnifiedMemoryStream {
    /// The Metal buffer that supports unified memory access.
    var metalBuffer: MTLBuffer { get }

    /// Writes data directly to the unified memory buffer.
    /// - Parameter data: The data to write.
    /// - Parameter offset: The offset in bytes from the start of the buffer.
    func write<T>(data: [T], offset: Int)

    /// Synchronizes the resource to ensure visibility to the GPU.
    func synchronize()
}
