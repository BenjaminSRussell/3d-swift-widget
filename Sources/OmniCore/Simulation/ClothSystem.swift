import Metal
import OmniCore
import OmniCoreTypes
import simd

/// Phase 8.2: Cloth Simulation System
/// Generates a grid of particles and structural/shear/bending constraints.
public final class ClothSystem {
    
    public let particleSystem: ParticleSystem
    public let constraints: MTLBuffer
    public let constraintCount: Int
    
    public init(device: MTLDevice, width: Int, height: Int) {
        let maxParticles = width * height
        self.particleSystem = ParticleSystem(device: device, maxParticles: maxParticles)
        
        var springConstraints: [SpringConstraint] = []
        
        // Helper to get index
        func idx(_ x: Int, _ y: Int) -> UInt32 { UInt32(y * width + x) }
        
        for y in 0..<height {
            for x in 0..<width {
                // Structural Constraints (Right and Down)
                if x < width - 1 {
                    springConstraints.append(SpringConstraint(p1: idx(x, y), p2: idx(x+1, y), restLength: 1.0, stiffness: 1.0))
                }
                if y < height - 1 {
                    springConstraints.append(SpringConstraint(p1: idx(x, y), p2: idx(x, y+1), restLength: 1.0, stiffness: 1.0))
                }
                
                // Shear Constraints (Diagonals)
                if x < width - 1 && y < height - 1 {
                    springConstraints.append(SpringConstraint(p1: idx(x, y), p2: idx(x+1, y+1), restLength: sqrt(2.0), stiffness: 0.5))
                    springConstraints.append(SpringConstraint(p1: idx(x+1, y), p2: idx(x, y+1), restLength: sqrt(2.0), stiffness: 0.5))
                }
            }
        }
        
        self.constraintCount = springConstraints.count
        let bufferSize = constraintCount * MemoryLayout<SpringConstraint>.stride
        
        guard let buf = GlobalHeap.shared.allocateBuffer(length: bufferSize, options: .storageModeShared) else {
            fatalError("Failed to allocate constraint buffer from Global Heap")
        }
        
        let ptr = buf.contents().bindMemory(to: SpringConstraint.self, capacity: constraintCount)
        for i in 0..<constraintCount {
            ptr[i] = springConstraints[i]
        }
        
        self.constraints = buf
        self.constraints.label = "Cloth Constraints"
    }
}
