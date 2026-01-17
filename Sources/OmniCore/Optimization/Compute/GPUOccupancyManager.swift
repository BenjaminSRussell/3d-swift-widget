import Foundation

/// **The Compute Sub-System (The Logic Sub-System)**
///
/// A watchdog that monitors how "full" the GPU waves are. If the GPU is 99% full,
/// it automatically lowers the resolution of just the background to keep the data crisp.
public protocol GPUOccupancyManager {
    /// The current GPU load factor (0.0 to 1.0).
    var currentLoad: Double { get }

    /// Suggests a resolution scale factor based on the current load.
    /// - Returns: A scale factor (e.g., 1.0 for native, 0.5 for half resolution).
    func suggestResolutionScale() -> Double

    /// A delegate delegate/callback to notify when thermal state changes or load becomes critical.
    var onCriticalLoad: (() -> Void)? { get set }
}
