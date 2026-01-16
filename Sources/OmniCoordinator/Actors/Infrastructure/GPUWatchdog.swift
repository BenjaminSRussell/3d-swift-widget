import Foundation
import Metal

// "The Watchdog"
// Responsible for monitoring GPU health and triggering restarts.
public actor GPUWatchdog {
    private let device: MTLDevice
    private var isHealthy: Bool = true
    private var lastFrameTime: TimeInterval = 0
    private var restartAction: (() async -> Void)?
    
    public init(device: MTLDevice) {
        self.device = device
    }
    
    public func setRestartAction(_ action: @escaping () async -> Void) {
        self.restartAction = action
    }
    
    public func ping() {
        self.lastFrameTime = Date().timeIntervalSince1970
    }
    
    // Call this periodically from a Timer or unrelated Task
    public func checkHealth() async {
        let now = Date().timeIntervalSince1970
        // If no ping for 2 seconds, assume GPU hang
        if (now - lastFrameTime) > 2.0 {
            print("WATCHDOG: GPU Hang Detected! Restarting subsystem...")
            isHealthy = false
            await triggerRestart()
        }
    }
    
    private func triggerRestart() async {
        // Simple recovery strategy
        isHealthy = true
        lastFrameTime = Date().timeIntervalSince1970 // Reset
        await restartAction?()
    }
}
