import Foundation

/// Phase 1.8: Threading Model
/// Enforces strict thread affinity for UI vs Physics/Encoding.
public struct Threading {
    
    public static let physicsQueue = DispatchQueue(label: "com.omni.physics", qos: .userInteractive)
    public static let renderQueue = DispatchQueue(label: "com.omni.render", qos: .userInteractive)
    
    /// Asserts that the code is running on the main thread.
    /// Critical for UI updates.
    public static func assertMainThread() {
        assert(Thread.isMainThread, "CRITICAL: UI Logic must run on Main Thread.")
    }
    
    /// Asserts that the code is NOT running on the main thread.
    /// Critical for heavy encoding or physics to avoid UI hitches.
    public static func assertBackgroundThread() {
        assert(!Thread.isMainThread, "CRITICAL: Heavy lifting must be offloaded from Main Thread.")
    }
}
