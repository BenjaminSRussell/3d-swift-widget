import Foundation
import os
import Foundation
import os
import QuartzCore
// GlobalHeap is in same module "OmniCore"

/// Phase 1.6: Debugging & Telemetry
/// Detailed metrics tracking for 120Hz ProMotion targets.
public struct PerformanceMetrics {
    public static var frameCount: UInt64 = 0
    public static var lastTime: CFTimeInterval = 0
    public static var fps: Double = 0
    public static var cpuTime: Double = 0
    public static var gpuTime: Double = 0
    
    /// Updates the FPS counter. Should be called once per frame.
    public static func update() {
        let currentTime = CACurrentMediaTime()
        frameCount += 1
        
        // Update FPS every 0.5 seconds
        if currentTime - lastTime >= 0.5 {
            fps = Double(frameCount) / (currentTime - lastTime)
            frameCount = 0
            lastTime = currentTime
            
            // Print to console if in debug mode (or could be hooked to the UI HUD)
            #if DEBUG
            print(String(format: "FPS: %.1f | Mem: %.1f MB", fps, MemoryMonitor.usedMemoryMB()))
            #endif
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
