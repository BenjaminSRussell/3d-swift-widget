import Foundation

/// **The Zero-Copy Sub-System**
///
/// A centralized coordinator that ensures the CPU is writing Frame 3 while the GPU
/// renders Frame 1, eliminating all "micro-stutters" during data updates.
public protocol TripleBufferManager {
    associatedtype DataBuffer

    /// Returns the buffer currently available for writing by the CPU.
    var writeBuffer: DataBuffer { get }

    /// Returns the buffer currently being read by the GPU.
    var readBuffer: DataBuffer { get }

    /// Swaps the buffers to proceed to the next frame.
    /// Should be called after the CPU has finished writing to the writeBuffer.
    func swap()
}
