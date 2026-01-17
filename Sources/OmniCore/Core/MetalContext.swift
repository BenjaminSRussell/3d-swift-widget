import Metal
import QuartzCore

/// MetalContext: The primary interface for Metal 3 GPU operations.
/// Optimized for Apple Silicon and supports Triple Buffering for 120 FPS targets.
public final class MetalContext {
    
    public static let shared = MetalContext()
    
    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue
    public let library: MTLLibrary?
    
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
            print("MetalContext Warning: Failed to load default library: \(error). Shader-dependent features may fail.")
            self.library = nil
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
    
    // MARK: - Indirect Command Buffer Support (Expert Panel: Rendering Architect)
    
    /// Indirect Command Buffers for GPU-driven rendering (eliminates CPU blocking)
    private var indirectCommandBuffers: [MTLIndirectCommandBuffer] = []
    private var currentFrameIndex: Int = 0
    private let icbLock = NSLock()
    
    /// Initializes Indirect Command Buffers for streaming math equations
    /// - Parameter maxCommands: Maximum number of draw commands per frame
    public func setupIndirectCommandBuffers(maxCommands: Int = 1_000_000) {
        guard #available(iOS 13.0, macOS 10.15, *) else {
            print("MetalContext Warning: ICB requires iOS 13+ / macOS 10.15+")
            return
        }
        
        let descriptor = MTLIndirectCommandBufferDescriptor()
        descriptor.commandTypes = [.draw, .drawIndexed]
        descriptor.inheritBuffers = false
        descriptor.inheritPipelineState = false
        descriptor.maxVertexBufferBindCount = 25
        descriptor.maxFragmentBufferBindCount = 25
        
        indirectCommandBuffers = (0..<maxFramesInFlight).compactMap { _ in
            device.makeIndirectCommandBuffer(descriptor: descriptor, maxCommandCount: maxCommands, options: [])
        }
        
        print("MetalContext: Initialized \(indirectCommandBuffers.count) ICBs with \(maxCommands) commands each")
    }
    
    /// Creates a streaming command buffer without CPU blocking (for endless math)
    /// - Returns: Command buffer with current frame's ICB, or nil if ICB not initialized
    public func makeStreamingCommandBuffer() -> (MTLCommandBuffer, MTLIndirectCommandBuffer)? {
        guard !indirectCommandBuffers.isEmpty else {
            print("MetalContext Warning: ICB not initialized. Call setupIndirectCommandBuffers() first.")
            return nil
        }
        
        icbLock.lock()
        let frameIndex = currentFrameIndex % maxFramesInFlight
        currentFrameIndex += 1
        icbLock.unlock()
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return nil
        }
        
        let icb = indirectCommandBuffers[frameIndex]
        
        // No semaphore.wait() - this is the key improvement!
        // GPU generates its own draw calls from the ICB
        
        return (commandBuffer, icb)
    }
}

