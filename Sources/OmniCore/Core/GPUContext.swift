import Metal
import QuartzCore

/// Critical: Manages the connection to the GPU.
/// Adheres to the "singleton" pattern for the device, but allows for careful context management.
public final class GPUContext {
    
    public static let shared = GPUContext()
    
    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue
    
    // Performance: Use a semaphore to prevent the CPU from overrunning the GPU.
    // Double buffered (2) or Triple buffered (3) depending on framerate targets.
    // For 120Hz, Triple buffering is safer to prevent miss-beats, but adds latency.
    // We start with Dual (2) for strict low-latency responsiveness.
    private let semaphore = DispatchSemaphore(value: 2)
    
    // MARK: - Phase 1.9 Error Handling
    public enum GPUError: Error {
        case deviceNotFound
        case commandQueueCreationFailed
        case timeout
        case outOfMemory
    }
    
    public var isValidationEnabled: Bool = false {
        didSet {
            // Note: API Validation usually requires a relaunch or scheme setting, 
            // but we can toggle lightweight checks here.
        }
    }
    
    // MARK: - Phase 2.4 Resource Residency
    /// Encodes the global heap into the command encoder to ensure residency.
    public func useGlobalHeap(on encoder: MTLRenderCommandEncoder) {
        encoder.useHeap(GlobalHeap.shared.heap)
    }
    
    public func useGlobalHeap(on encoder: MTLComputeCommandEncoder) {
        encoder.useHeap(GlobalHeap.shared.heap)
    }

    private init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("CRITICAL FAILURE: Metal is not supported on this device.")
        }
        self.device = device
        
        guard let queue = device.makeCommandQueue() else {
            fatalError("CRITICAL FAILURE: Could not create Metal Command Queue.")
        }
        self.commandQueue = queue
        
        print("OmniEngine: GPU Context Initialized. Device: \(device.name)")
    }
    
    /// Acquires a command buffer and handles the semaphore wait.
    /// Returns nil if the queue is somehow broken.
    public func vendCommandBuffer() -> MTLCommandBuffer? {
        // Wait for the semaphore to signal that a previous frame has completed.
        // Timeout is set to avoid deadlocks, but realistically this should be infinite.
        let waitResult = semaphore.wait(timeout: .distantFuture)
        if waitResult == .timedOut {
            print("WARNING: GPU Semaphore timed out. Pipeline stalled.")
            return nil
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            semaphore.signal() // Release if we fail to create
            return nil
        }
        
        // When the GPU finishes this buffer, signal the semaphore to allow the CPU to proceed.
        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.semaphore.signal()
        }
        
        return commandBuffer
    }
}
