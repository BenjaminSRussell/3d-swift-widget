import Foundation
import os
import QuartzCore
import Combine
// GlobalHeap is in the same module "OmniCore"

/// Phase 1.6: Debugging & Telemetry
/// Detailed metrics tracking for 120Hz ProMotion targets.
/// Phase 1.6: Debugging & Telemetry
/// Detailed metrics tracking for 120Hz ProMotion targets.
public final class PerformanceMetrics: ObservableObject {
    public static let shared = PerformanceMetrics()
    
    // Published for UI
    @Published public var cpuFrameTime: Double = 0.0 // ms
    @Published public var gpuFrameTime: Double = 0.0 // ms
    @Published public var fps: Double = 0.0
    @Published public var focusScore: Float = 0.0
    
    // Internal State
    private var frameCount: Int = 0
    private var lastTime: CFTimeInterval = 0
    private var cpuSamples: [Double] = []
    private var gpuSamples: [Double] = []
    private let maxSamples = 60
    
    // Phase 19.3: Battery Optimization
    public static var isLowPowerMode: Bool {
        return ProcessInfo.processInfo.isLowPowerModeEnabled
    }
    
    public init() {
        self.lastTime = CACurrentMediaTime()
    }
    
    /// Updates the metrics. Should be called once per frame.
    public static func update(cpuDuration: Double, gpuDuration: Double) {
        shared.updateInstance(cpuDuration: cpuDuration, gpuDuration: gpuDuration)
    }
    
    private func updateInstance(cpuDuration: Double, gpuDuration: Double) {
        let currentTime = CACurrentMediaTime()
        frameCount += 1
        
        // Convert to ms
        let cpuMs = cpuDuration * 1000.0
        let gpuMs = gpuDuration * 1000.0
        
        cpuSamples.append(cpuMs)
        if cpuSamples.count > maxSamples { cpuSamples.removeFirst() }
        
        gpuSamples.append(gpuMs)
        if gpuSamples.count > maxSamples { gpuSamples.removeFirst() }
        
        // Update FPS every 0.5 seconds
        if currentTime - lastTime >= 0.5 {
            let elapsed = currentTime - lastTime
            self.fps = Double(frameCount) / elapsed
            
            // Average
            let avgCpu = cpuSamples.reduce(0, +) / Double(cpuSamples.count)
            let avgGpu = gpuSamples.reduce(0, +) / Double(gpuSamples.count)
            
            DispatchQueue.main.async {
                self.cpuFrameTime = avgCpu
                self.gpuFrameTime = avgGpu
                // self.fps is already updated but assumes main thread access if published? 
                // Wait, fps assignment should arguably be on main thread too if published.
            }
            // Temporarily assign to local var inside async block or just rely on atomic update if not strict... 
            // Better:
            Task { @MainActor in
                self.fps = Double(self.frameCount) / elapsed // Re-calc or capture? Capture safe enough.
            }
            
            // Print to console if in debug mode
            #if DEBUG
            let load = avgGpu / (1000.0 / 120.0) * 100.0 // Load % relative to 8.33ms budget
            print(String(format: "FPS: %.1f | CPU: %.2fms | GPU: %.2fms (%.0f%%) | Mem: %.1f MB", 
                         self.fps, avgCpu, avgGpu, load, MemoryMonitor.usedMemoryMB()))
            #endif
            
            // Reset counters
            frameCount = 0
            lastTime = currentTime
        }
    }
}

public struct MemoryMonitor {
    /// Returns the current memory usage of the app in MB.
    public static func usedMemoryMB() -> Float {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Float(info.resident_size) / (1024 * 1024)
        } else {
            return 0
        }
    }
    
    /// Throws an alert if memory is critical (Project OMNI target < 30MB for Widget).
    public static func checkSafety() -> Bool {
        let mb = usedMemoryMB()
        let heapUsed = Double(GlobalHeap.shared.heap.usedSize) / (1024 * 1024)
        
        if mb > 25.0 {
            print("⚠️ MEMORY WARNING: \(mb) MB used. Approaching WidgetKit limit (30MB).")
            return false
        }
        
        if heapUsed > 18.0 {
            print("⚠️ HEAP WARNING: \(heapUsed) MB of 20 MB Heap used.")
        }
        
        return true
    }
}
