import Metal
import OmniCore
import simd

/// Phase 3.9: GPU-Driven State Management
/// Holds persistent simulation state to minimize CPU-GPU bandwidth.
public class SimulationState {
    
    public struct PhysicsConstants {
        var time: Float
        var deltaTime: Float
        var gravity: SIMD3<Float>
        var damping: Float
    }
    
    public let buffer: MTLBuffer
    
    public init() {
        // Allocate just enough for the struct.
        // Storage mode managed (shared) is fine for small frequent updates,
        // or we could use the RingBuffer pattern. 
        // For simplicity in Phase 3, we use a dedicated buffer in Shared memory for CPU write / GPU read.
        let device = GPUContext.shared.device
        guard device === GPUContext.shared.device,
              let buf = device.makeBuffer(length: MemoryLayout<PhysicsConstants>.stride, options: .storageModeShared) else {
            fatalError("Failed to allocate SimulationState buffer")
        }
        self.buffer = buf
        self.buffer.label = "Simulation Globals"
    }
    
    public func update(time: Float, deltaTime: Float) {
        let ptr = buffer.contents().bindMemory(to: PhysicsConstants.self, capacity: 1)
        ptr.pointee.time = time
        ptr.pointee.deltaTime = deltaTime
        ptr.pointee.gravity = SIMD3<Float>(0, -9.81, 0)
        ptr.pointee.damping = 0.98
    }
}
