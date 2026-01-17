import Metal
import simd

/// Phase 2: Grid Mesh Generator
/// creates a simple NxN grid of lines (or triangles) to prove geometry is processing.

public struct Vertex {
    public var position: SIMD3<Float>
    public var color: SIMD4<Float>
}

public final class GridMeshGenerator {
    
    /// Generates a grid of size x size with segments.
    /// Returns (Vertices, Indices)
    public static func generateGrid(device: MTLDevice, size: Float, segments: Int) -> (MTLBuffer?, MTLBuffer?, Int)? {
        
        var vertices: [Vertex] = []
        var indices: [UInt16] = []
        
        let halfSize = size / 2.0
        let step = size / Float(segments)
        
        // Generate Vertices
        for z in 0...segments {
            for x in 0...segments {
                let xPos = -halfSize + Float(x) * step
                let zPos = -halfSize + Float(z) * step
                
                vertices.append(Vertex(
                    position: SIMD3<Float>(xPos, 0, zPos),
                    color: SIMD4<Float>(0.0, 1.0, 1.0, 1.0) // Cyan
                ))
            }
        }
        
        // Generate Indices (Lines)
        // Horizontal Lines
        for z in 0...segments {
            for x in 0..<segments {
                let current = UInt16(z * (segments + 1) + x)
                let next = current + 1
                indices.append(current)
                indices.append(next)
            }
        }
        
        // Vertical Lines
        for x in 0...segments {
            for z in 0..<segments {
                let current = UInt16(z * (segments + 1) + x)
                let next = current + UInt16(segments + 1)
                indices.append(current)
                indices.append(next)
            }
        }
        
        // Create Buffers
        guard let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: .storageModeShared),
              let indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride, options: .storageModeShared) else {
            return nil
        }
        
        return (vertexBuffer, indexBuffer, indices.count)
    }
}
