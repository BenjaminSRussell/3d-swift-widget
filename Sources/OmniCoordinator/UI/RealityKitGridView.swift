#if os(macOS)
import SwiftUI
import RealityKit

public struct RealityKitGridView: NSViewRepresentable {
    
    public init() {}
    
    public func makeNSView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Create anchor
        let anchor = AnchorEntity(world: .zero)
        
        // Create grid mesh
        let gridSize: Float = 20.0
        let gridSpacing: Float = 1.0
        let lines = Int(gridSize / gridSpacing)
        
        // Create X-axis lines (green)
        for i in 0...lines {
            let offset = -gridSize/2 + Float(i) * gridSpacing
            let start = SIMD3<Float>(-gridSize/2, 0, offset)
            let end = SIMD3<Float>(gridSize/2, 0, offset)
            let line = createLine(from: start, to: end, color: .green)
            anchor.addChild(line)
        }
        
        // Create Z-axis lines (green)
        for i in 0...lines {
            let offset = -gridSize/2 + Float(i) * gridSpacing
            let start = SIMD3<Float>(offset, 0, -gridSize/2)
            let end = SIMD3<Float>(offset, 0, gridSize/2)
            let line = createLine(from: start, to: end, color: .green)
            anchor.addChild(line)
        }
        
        // Add coordinate axes (X=red, Y=blue, Z=green)
        let xAxis = createLine(from: .zero, to: SIMD3<Float>(15, 0, 0), color: .red)
        let yAxis = createLine(from: .zero, to: SIMD3<Float>(0, 15, 0), color: .blue)
        let zAxis = createLine(from: .zero, to: SIMD3<Float>(0, 0, 15), color: .green)
        
        anchor.addChild(xAxis)
        anchor.addChild(yAxis)
        anchor.addChild(zAxis)
        
        arView.scene.addAnchor(anchor)
        
        // Background color - red
        arView.environment.background = .color(.red)
        
        return arView
    }
    
    public func updateNSView(_ nsView: ARView, context: Context) {}
    
    private func createLine(from start: SIMD3<Float>, to end: SIMD3<Float>, color: NSColor) -> ModelEntity {
        let length = distance(start, end)
        let midpoint = (start + end) / 2
        
        let mesh = MeshResource.generateBox(size: [length, 0.05, 0.05])
        var material = SimpleMaterial()
        material.color = .init(tint: color)
        
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = midpoint
        
        // Rotate to align with the line direction
        let direction = normalize(end - start)
        let up = SIMD3<Float>(0, 1, 0)
        if abs(dot(direction, up)) < 0.99 {
            let rotation = simd_quatf(from: SIMD3<Float>(1, 0, 0), to: direction)
            entity.orientation = rotation
        }
        
        return entity
    }
}
#endif
