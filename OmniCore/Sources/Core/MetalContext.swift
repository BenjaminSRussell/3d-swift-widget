import Metal
import QuartzCore

/// MetalContext: The primary interface for Metal 3 GPU operations.
/// Optimized for Apple Silicon and supports Triple Buffering for 120 FPS targets.
public final class MetalContext {
    
    public static let shared = MetalContext()
    
    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue
    public let library: MTLLibrary
    
    /// Triple buffering for 120 FPS targets to prevent pipeline stalls.
    private let semaphore = DispatchSemaphore(value: 3)
    public let maxFramesInFlight = 3
    
    private init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal 3 not supported on this device.")
        }
        self.device = device
        
        guard let queue = device.makeCommandQueue() else {
            fatalError("Failed to create Command Queue.")
        }
        self.commandQueue = queue
        
        // Load default library
        do {
            self.library = try device.makeDefaultLibrary(bundle: .main)
        } catch {
            fatalError("Failed to load default library: \(error)")
        }
        
        print("MetalContext: Initialized \(device.name) with Triple Buffering.")
    }
    
    /// Acquires a command buffer and waits for the CPU/GPU semaphore.
    public func makeCommandBuffer() -> MTLCommandBuffer? {
        semaphore.wait()
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            semaphore.signal()
            return nil
        }
        
        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.semaphore.signal()
        }
        
        return commandBuffer
    }
    
    /// Mesh Shaders support check (Metal 3)
    public var supportsMeshShaders: Bool {
        if #available(iOS 16.0, macOS 13.0, *) {
            return device.supportsFamily(.apple9) || device.supportsFamily(.mac2)
        }
        return false
    }
}
