import Metal
import OmniCoreTypes

/// Phase 7.4: Physics Engine Controller
/// Orchestrates Verlet integration, constraints, and collisions.
public final class PhysicsEngine {
    
    private let verletKernel: ComputeKernel
    private let constraintKernel: ComputeKernel
    private let distanceKernel: ComputeKernel
    
    public init() throws {
        self.verletKernel = try ComputeKernel(functionName: "integrate_verlet")
        self.constraintKernel = try ComputeKernel(functionName: "apply_constraints")
        self.distanceKernel = try ComputeKernel(functionName: "apply_distance_constraints")
        
        // Fluid kernels
        self.interactionKernel = try ComputeKernel(functionName: "apply_ripple")
        self.fluxKernel = try ComputeKernel(functionName: "update_fluid_flux")
        self.heightKernel = try ComputeKernel(functionName: "update_fluid_height")
    }
    
    private let interactionKernel: ComputeKernel
    private let fluxKernel: ComputeKernel
    private let heightKernel: ComputeKernel
    
    /// Executes a single simulation frame.
    /// - Parameters:
    ///   - system: The particle system to update.
    ///   - frameUniforms: Buffer containing deltaTime and frameCount.
    public func step(encoder: MTLComputeCommandEncoder, system: ParticleSystem, frameUniforms: MTLBuffer) {
        
        let gridSize = MTLSize(width: system.maxParticles, height: 1, depth: 1)
        
        // 1. Verlet Integration
        encoder.setBuffer(system.positionBuffer, offset: 0, index: 0)
        encoder.setBuffer(system.previousPositionBuffer, offset: 0, index: 1)
        encoder.setBuffer(system.velocityBuffer, offset: 0, index: 2)
        encoder.setBuffer(frameUniforms, offset: 0, index: 3)
        verletKernel.dispatch(encoder: encoder, gridSize: gridSize)
        
        // 2. Constraints (Bounding Box)
        var boxMin = SIMD3<Float>(-10, 0, -10)
        var boxMax = SIMD3<Float>(10, 20, 10)
        encoder.setBuffer(system.positionBuffer, offset: 0, index: 0)
        encoder.setBuffer(system.previousPositionBuffer, offset: 0, index: 1)
        encoder.setBytes(&boxMin, length: MemoryLayout<SIMD3<Float>>.stride, index: 2)
        encoder.setBytes(&boxMax, length: MemoryLayout<SIMD3<Float>>.stride, index: 3)
        constraintKernel.dispatch(encoder: encoder, gridSize: gridSize)
    }
    
    /// Executes the simulation with multiple constraint solver iterations for stability.
    public func stepCloth(encoder: MTLComputeCommandEncoder, cloth: ClothSystem, frameUniforms: MTLBuffer, iterations: Int = 10) {
        let pSystem = cloth.particleSystem
        let particleGrid = MTLSize(width: pSystem.maxParticles, height: 1, depth: 1)
        let constraintGrid = MTLSize(width: cloth.constraintCount, height: 1, depth: 1)
        
        // 1. Verlet Integration (Once per frame)
        encoder.setBuffer(pSystem.positionBuffer, offset: 0, index: 0)
        encoder.setBuffer(pSystem.previousPositionBuffer, offset: 0, index: 1)
        encoder.setBuffer(pSystem.velocityBuffer, offset: 0, index: 2)
        encoder.setBuffer(frameUniforms, offset: 0, index: 3)
        verletKernel.dispatch(encoder: encoder, gridSize: particleGrid)
        
        // 2. Iterative Constraints
        for _ in 0..<iterations {
            // Distance Constraints
            encoder.setBuffer(pSystem.positionBuffer, offset: 0, index: 0)
            encoder.setBuffer(cloth.constraints, offset: 0, index: 1)
            distanceKernel.dispatch(encoder: encoder, gridSize: constraintGrid)
            
            // Boundary Constraints
            var boxMin = SIMD3<Float>(-10, 0, -10)
            var boxMax = SIMD3<Float>(10, 20, 10)
            encoder.setBuffer(pSystem.positionBuffer, offset: 0, index: 0)
            encoder.setBuffer(pSystem.previousPositionBuffer, offset: 0, index: 1)
            encoder.setBytes(&boxMin, length: MemoryLayout<SIMD3<Float>>.stride, index: 2)
            encoder.setBytes(&boxMax, length: MemoryLayout<SIMD3<Float>>.stride, index: 3)
            constraintKernel.dispatch(encoder: encoder, gridSize: particleGrid)
        }
    }
    
    /// Executes the fluid simulation frame including interaction.
    public func stepFluid(encoder: MTLComputeCommandEncoder, fluid: FluidSystem, interactions: InteractionSystem) {
        let gridSize = MTLSize(width: fluid.gridRes.x, height: fluid.gridRes.y, depth: 1)
        
        // 1. Apply User Interactions (Ripples)
        if interactions.touchCount > 0 {
            encoder.setBuffer(fluid.heightBuffer, offset: 0, index: 0)
            encoder.setBuffer(interactions.touchBuffer, offset: 0, index: 1)
            var count = UInt32(interactions.touchCount)
            encoder.setBytes(&count, length: 4, index: 2)
            var res = SIMD2<UInt32>(UInt32(fluid.gridRes.x), UInt32(fluid.gridRes.y))
            encoder.setBytes(&res, length: 8, index: 3)
            interactionKernel.dispatch(encoder: encoder, gridSize: gridSize)
        }
        
        struct FluidParams {
            var gridRes: SIMD2<UInt32>
            var cellSize: Float
            var dt: Float
            var gravity: Float
        }
        
        var params = FluidParams(
            gridRes: SIMD2<UInt32>(UInt32(fluid.gridRes.x), UInt32(fluid.gridRes.y)),
            cellSize: 0.1, // Fixed for demo, should match world scale
            dt: 0.016,     // Fixed timestep
            gravity: 9.8
        )
        
        // 2. Update Flux
        encoder.setBuffer(fluid.heightBuffer, offset: 0, index: 0)
        encoder.setBuffer(fluid.fluxBuffer, offset: 0, index: 1)
        encoder.setBytes(&params, length: MemoryLayout<FluidParams>.stride, index: 2)
        fluxKernel.dispatch(encoder: encoder, gridSize: gridSize)
        
        // 3. Update Height
        encoder.setBuffer(fluid.heightBuffer, offset: 0, index: 0)
        encoder.setBuffer(fluid.fluxBuffer, offset: 0, index: 1)
        encoder.setBytes(&params, length: MemoryLayout<FluidParams>.stride, index: 2)
        heightKernel.dispatch(encoder: encoder, gridSize: gridSize)
    }
}
