import Metal
import OmniCore
import OmniCoreTypes
import QuartzCore

/// HDTEParticleSystem: High-level orchestrator for particle simulation.
/// Wraps ParticleSystem (data), PhysicsEngine (logic), and SimulationState (parameters).
public final class HDTEParticleSystem {
    
    private let context: MetalContext
    private let particleSystem: ParticleSystem
    private let physicsEngine: PhysicsEngine
    private let simulationState: SimulationState
    
    // Performance Tracking
    private let metrics = PerformanceMetrics.self
    
    public init(count: Int) throws {
        self.context = MetalContext.shared
        self.particleSystem = ParticleSystem(device: context.device, maxParticles: count)
        self.physicsEngine = try PhysicsEngine()
        self.simulationState = SimulationState()
    }
    
    /// Executes one frame of simulation.
    public func update(deltaTime: Float) {
        // Update CPU state
        let time = Float(CACurrentMediaTime())
        simulationState.update(time: time, deltaTime: deltaTime)
        
        // Dispatch GPU work
        guard let commandBuffer = context.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        let start = CACurrentMediaTime()
        
        physicsEngine.step(encoder: encoder, system: particleSystem, frameUniforms: simulationState.buffer)
        
        encoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted() // Blocking for simplicity in this synchronous wrapper
        
        let duration = CACurrentMediaTime() - start
        
        // Update metrics
        metrics.update(cpuDuration: 0, gpuDuration: duration)
    }
}
