import Foundation

/// **The Zero-Copy Sub-System**
///
/// Instead of allocating/deallocating memory constantly (which causes lag), this system
/// grabs a massive chunk of RAM at startup and hands out "slices" to widgets.
public protocol ArenaAllocator {
    /// Allocates a block of memory of the given size.
    /// - Parameter size: The number of bytes to allocate.
    /// - Returns: A pointer to the allocated memory.
    func allocate(size: Int) -> UnsafeMutableRawPointer

    /// Resets the allocator, invalidating all previous allocations.
    /// This is typically called at the end of a frame or a heavy operation.
    func reset()
}
