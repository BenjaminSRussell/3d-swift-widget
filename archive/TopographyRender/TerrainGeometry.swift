import SceneKit
import TopographyCore

public class TerrainGeometryBuilder {
    public static func buildGeometry(from data: TerrainData, scale: Float = 1.0) -> SCNGeometry {
        let width = data.width
        let depth = data.depth
        
        var vertices = [SCNVector3]()
        var indices = [Int32]()
        var normals = [SCNVector3]()
        
        // Generate vertices
        for z in 0..<depth {
            for x in 0..<width {
                let y = data.height(at: x, z: z) * scale
                vertices.append(SCNVector3(Float(x), y, Float(z)))
                normals.append(SCNVector3(0, 1, 0)) // Placeholder normals, should calculate real ones
            }
        }
        
        // Generate indices
        for z in 0..<(depth - 1) {
            for x in 0..<(width - 1) {
                let topLeft = z * width + x
                let topRight = topLeft + 1
                let bottomLeft = (z + 1) * width + x
                let bottomRight = bottomLeft + 1
                
                // First triangle
                indices.append(contentsOf: [Int32(topLeft), Int32(bottomLeft), Int32(topRight)])
                
                // Second triangle
                indices.append(contentsOf: [Int32(topRight), Int32(bottomLeft), Int32(bottomRight)])
            }
        }
        
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let normalSource = SCNGeometrySource(normals: normals)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        
        return SCNGeometry(sources: [vertexSource, normalSource], elements: [element])
    }
}
