import Metal
import os.log

/// Phase 1.6: Debugging & Telemetry
/// wrapper for MTLCaptureManager to allow programmatic capture of frames when glitches occur.
public final class GPUCapture {
    public static let shared = GPUCapture()
    private let logger = Logger(subsystem: "com.omni.core", category: "GPUCapture")
    
    public enum Trigger {
        case manual
        case error
        case performance
    }
    
    private init() {}
    
    /// Triggers a GPU capture for the next command buffer.
    /// - Parameter scope: The type of capture (usually .frame or .commandBuffer)
    public func triggerCapture(scope: MTLCaptureScope? = nil) {
        let manager = MTLCaptureManager.shared()
        
        guard manager.supportsDestination(.gpuTraceDocument) else {
            logger.warning("GPU Capture not supported on this device/configuration.")
            return
        }
        
        do {
            let captureDescriptor = MTLCaptureDescriptor()
            captureDescriptor.captureObject = scope ?? manager.makeCaptureScope(device: GPUContext.shared.device)
            captureDescriptor.destination = .gpuTraceDocument
            // Save to Documents/tmp
            let date = ISO8601DateFormatter().string(from: Date())
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("OmniCapture_\(date).gputrace")
            captureDescriptor.outputURL = url
            
            try manager.startCapture(with: captureDescriptor)
            logger.info("Started GPU Capture: \(url.path)")
            
            // Note: Capture automatically stops when the scope completes or stop() is called.
            // If checking a single frame, usually the scope bound to a frame boundary handles this.
            
        } catch {
            logger.error("Failed to start GPU capture: \(error.localizedDescription)")
        }
    }
    
    public func stopCapture() {
        if MTLCaptureManager.shared().isCapturing {
            MTLCaptureManager.shared().stopCapture()
            logger.info("Stopped GPU Capture.")
        }
    }
}
