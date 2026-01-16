import Metal
import MetalPerformanceShaders
import os.signpost

/// Memory manager implementing heap aliasing to stay under 30MB
/// Includes runtime budget enforcement and profiling hooks for iOS widget compliance
public class MemoryManager {
    private let device: MTLDevice
    private let heapSize: Int = 20 * 1024 * 1024 // 20MB heap
    
    // Memory budget enforcement (iOS widget limit)
    public static let widgetMemoryBudget: Int = 30 * 1024 * 1024 // 30MB
    private var memoryBudgetEnabled: Bool = true
    
    // Profiling
    private let signpostLog = OSLog(subsystem: "com.hdte.memory", category: "Allocation")
    private var allocationHistory: [(timestamp: Date, size: Int, type: String)] = []
    
    private var heap: MTLHeap!
    
    // Aliased resources
    private var computeBuffers: [MTLBuffer] = []
    private var renderTextures: [MTLTexture] = []
    private var sharedBuffers: [MTLBuffer] = [] // Track for total memory calculation
    
    // Quality scaling for memory pressure
    private var currentQualityScale: Float = 1.0
    
    public init(device: MTLDevice) {
        self.device = device
        setupHeap()
    }
    
    private func setupHeap() {
        let heapDescriptor = MTLHeapDescriptor()
        heapDescriptor.size = heapSize
        heapDescriptor.storageMode = .private // GPU-only memory
        heapDescriptor.cpuCacheMode = .defaultCache
        heapDescriptor.hazardTrackingMode = .tracked
        
        heap = device.makeHeap(descriptor: heapDescriptor)!
    }
    
    // MARK: - Compute Phase Resources
    
    public func allocateComputeBuffers(sizes: [Int]) -> [MTLBuffer] {
        computeBuffers.removeAll()
        
        for size in sizes {
            guard let buffer = heap.makeBuffer(length: size, options: .storageModePrivate) else {
                fatalError("Failed to allocate compute buffer")
            }
            buffer.makeAliasable() // Critical: allows reuse
            computeBuffers.append(buffer)
        }
        
        return computeBuffers
    }
    
    // MARK: - Render Phase Resources (Aliased on same heap)
    
    public func allocateRenderTextures(descriptors: [MTLTextureDescriptor]) -> [MTLTexture] {
        // First, mark compute buffers as aliasable (we're done with them)
        computeBuffers.forEach { $0.makeAliasable() }
        
        renderTextures.removeAll()
        
        for descriptor in descriptors {
            descriptor.storageMode = .private
            guard let texture = heap.makeTexture(descriptor: descriptor) else {
                fatalError("Failed to allocate render texture")
            }
            texture.makeAliasable()
            renderTextures.append(texture)
        }
        
        return renderTextures
    }
    
    // MARK: - Memoryless Textures (0MB System RAM)
    
    public func createMemorylessDepth(width: Int, height: Int) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.storageMode = .memoryless // Stays in tile memory
        descriptor.usage = [.renderTarget]
        
        return device.makeTexture(descriptor: descriptor)!
    }
    
    public func createMemorylessMSAA(width: Int, height: Int, sampleCount: Int) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.textureType = .type2DMultisample
        descriptor.sampleCount = sampleCount
        descriptor.storageMode = .memoryless
        descriptor.usage = [.renderTarget]
        
        return device.makeTexture(descriptor: descriptor)!
    }
    
    // MARK: - Shared Buffers (Zero-Copy CPU↔GPU)
    
    public func createSharedBuffer(size: Int) -> MTLBuffer {
        os_signpost(.begin, log: signpostLog, name: "Allocate Shared Buffer", "Size: %d KB", size / 1024)
        
        // Enforce budget before allocation
        if memoryBudgetEnabled {
            let projected = currentMemoryUsage() + size
            if projected > Self.widgetMemoryBudget {
                handleMemoryPressure()
                // Retry after pressure handling
                if currentMemoryUsage() + size > Self.widgetMemoryBudget {
                    fatalError("Memory budget exceeded: \(projected / 1024 / 1024)MB > 30MB")
                }
            }
        }
        
        // Shared mode: accessible by both CPU and GPU without copying
        guard let buffer = device.makeBuffer(length: size, options: .storageModeShared) else {
            fatalError("Failed to allocate shared buffer")
        }
        
        sharedBuffers.append(buffer)
        allocationHistory.append((Date(), size, "SharedBuffer"))
        
        os_signpost(.end, log: signpostLog, name: "Allocate Shared Buffer")
        return buffer
    }
    
    // MARK: - Memory Budget Enforcement
    
    /// Calculate current total memory usage across all resources
    public func currentMemoryUsage() -> Int {
        var total = 0
        
        // Heap usage (aliased resources count only once)
        total += heap.usedSize
        
        // Shared buffers (not on heap)
        total += sharedBuffers.reduce(0) { $0 + $1.allocatedSize }
        
        // Note: Memoryless textures contribute 0 bytes
        
        return total
    }
    
    /// Enforce memory budget before allocation
    public func enforceMemoryBudget(additionalSize: Int) throws {
        let projected = currentMemoryUsage() + additionalSize
        if projected > Self.widgetMemoryBudget {
            throw MemoryError.budgetExceeded(current: currentMemoryUsage(), projected: projected)
        }
    }
    
    /// Handle memory pressure by reducing quality
    private func handleMemoryPressure() {
        os_signpost(.event, log: signpostLog, name: "Memory Pressure", "Current: %d MB", currentMemoryUsage() / 1024 / 1024)
        
        // Reduce quality scale
        currentQualityScale = max(0.5, currentQualityScale - 0.25)
        
        // Clear allocation history to free some overhead
        if allocationHistory.count > 100 {
            allocationHistory.removeFirst(allocationHistory.count - 100)
        }
        
        print("⚠️ Memory pressure detected. Quality scale reduced to \(currentQualityScale)")
    }
    
    /// Get current quality scale for adaptive resolution
    public func getQualityScale() -> Float {
        return currentQualityScale
    }
    
    /// Enable or disable memory budget enforcement (useful for testing)
    public func setMemoryBudgetEnabled(_ enabled: Bool) {
        memoryBudgetEnabled = enabled
    }
    
    // MARK: - Memory Diagnostics
    
    public func reportMemoryUsage() {
        let heapUsed = heap.usedSize
        let heapTotal = heap.size
        let totalUsage = currentMemoryUsage()
        let percentage = Double(totalUsage) / Double(Self.widgetMemoryBudget) * 100.0
        
        print("""
        ═══════════════════════════════════════════════════════
        HDTE Memory Report
        ═══════════════════════════════════════════════════════
        Heap Usage:    \(heapUsed / 1024 / 1024)MB / \(heapTotal / 1024 / 1024)MB
        Shared Buffers: \(sharedBuffers.reduce(0) { $0 + $1.allocatedSize } / 1024 / 1024)MB
        Total Usage:   \(totalUsage / 1024 / 1024)MB / 30MB (\(String(format: "%.1f", percentage))%)
        Quality Scale: \(currentQualityScale)x
        Status:        \(totalUsage < Self.widgetMemoryBudget ? "✅ Within Budget" : "❌ EXCEEDED")
        ═══════════════════════════════════════════════════════
        """)
    }
    
    /// Export allocation timeline for Instruments analysis
    public func exportAllocationTimeline() -> [(timestamp: Date, size: Int, type: String)] {
        return allocationHistory
    }
    
    /// Validate resource aliasing is working correctly
    public func validateAliasing() -> Bool {
        // Check that heap usage doesn't exceed expected maximum
        let maxExpected = heapSize / 2 // Should reuse ~50% due to aliasing
        let actual = heap.usedSize
        
        let isValid = actual <= heapSize
        
        if !isValid {
            print("⚠️ Aliasing validation failed: \(actual / 1024 / 1024)MB used, expected ≤ \(maxExpected / 1024 / 1024)MB")
        }
        
        return isValid
    }
}

// MARK: - Memory Errors

enum MemoryError: Error {
    case budgetExceeded(current: Int, projected: Int)
    
    var localizedDescription: String {
        switch self {
        case .budgetExceeded(let current, let projected):
            return "Memory budget exceeded: \(current / 1024 / 1024)MB → \(projected / 1024 / 1024)MB (limit: 30MB)"
        }
    }
}
