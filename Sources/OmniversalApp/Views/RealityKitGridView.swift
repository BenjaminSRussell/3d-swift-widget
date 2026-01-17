import SwiftUI
import RealityKit

struct RealityKitGridView: NSViewRepresentable {
    func makeNSView(context: Context) -> ARView {
        let arView = OrbitalCameraARView(frame: .zero)
        
        // Add default lighting
        let env = try? EnvironmentResource.load(named: "default")
        arView.environment.lighting.resource = env
        
        // Create the scene
        let anchor = AnchorEntity(world: .zero)
        
        // --- 1. GRID IMPLEMENTATION ---
        let gridSize: Float = 50.0
        let gridDivisions: Int = 50
        let spacing = gridSize / Float(gridDivisions)
        
        for i in 0...gridDivisions {
            let offset = -gridSize/2 + Float(i) * spacing
            
            // X-axis lines (Dark Gray)
            let xLine = createLine(
                from: SIMD3<Float>(offset, 0, -gridSize/2),
                to: SIMD3<Float>(offset, 0, gridSize/2),
                color: NSColor(white: 0.3, alpha: 1.0),
                thickness: 0.02
            )
            anchor.addChild(xLine)
            
            // Z-axis lines (Dark Gray)
            let zLine = createLine(
                from: SIMD3<Float>(-gridSize/2, 0, offset),
                to: SIMD3<Float>(gridSize/2, 0, offset),
                color: NSColor(white: 0.3, alpha: 1.0),
                thickness: 0.02
            )
            anchor.addChild(zLine)
        }
        
        // --- 2. COORDINATE AXES (Thicker) ---
        anchor.addChild(createLine(from: .zero, to: [20, 0, 0], color: .red, thickness: 0.05))   // X
        anchor.addChild(createLine(from: .zero, to: [0, 20, 0], color: .green, thickness: 0.05)) // Y
        anchor.addChild(createLine(from: .zero, to: [0, 0, 20], color: .blue, thickness: 0.05))  // Z
        
        // --- 3. TERRAIN ---
        createTerrain(anchor: anchor)
        
        arView.scene.addAnchor(anchor)
        
        // --- 3. CAMERA SETUP ---
        let cameraAnchor = AnchorEntity(world: .zero)
        let camera = PerspectiveCamera()
        // Initial position set by controller
        
        cameraAnchor.addChild(camera)
        arView.scene.addAnchor(cameraAnchor)
        
        // Connect controls
        arView.setCamera(camera, anchor: cameraAnchor)
        
        // Background
        arView.environment.background = .color(.black)
        
        return arView
    }
    
    func updateNSView(_ nsView: ARView, context: Context) {}
    
    private func createLine(from start: SIMD3<Float>, to end: SIMD3<Float>, color: NSColor, thickness: Float) -> ModelEntity {
        let vector = end - start
        let length = simd_length(vector)
        let midpoint = (start + end) / 2
        
        let mesh = MeshResource.generateBox(size: [length, thickness, thickness])
        var material = SimpleMaterial()
        material.color = .init(tint: color)
        
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = midpoint
        
        if length > 0.001 {
            let direction = normalize(vector)
            let defaultDirection = SIMD3<Float>(1, 0, 0)
             if simd_length(direction - defaultDirection) > 0.001 &&
               simd_length(direction + defaultDirection) > 0.001 {
                let rotation = simd_quatf(from: defaultDirection, to: direction)
                entity.orientation = rotation
            }
        }
        return entity
    }

    private func createTerrain(anchor: AnchorEntity) {
        // Simple procedural terrain
        let width: Int = 100
        let depth: Int = 100
        let spacing: Float = 0.5
        let amplitude: Float = 3.0
        let frequency: Float = 0.1
        
        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        var normals: [SIMD3<Float>] = []
        
        // Generate vertices
        for z in 0...depth {
            for x in 0...width {
                let xPos = Float(x) * spacing - Float(width) * spacing / 2
                let zPos = Float(z) * spacing - Float(depth) * spacing / 2
                let yPos = sin(xPos * frequency) * cos(zPos * frequency) * amplitude
                
                positions.append([xPos, yPos, zPos])
                normals.append([0, 1, 0]) // Approximate up
            }
        }
        
        // Generate indices (triangle strip logic -> triangles)
        for z in 0..<depth {
            for x in 0..<width {
                let topLeft = UInt32(z * (width + 1) + x)
                let topRight = topLeft + 1
                let bottomLeft = UInt32((z + 1) * (width + 1) + x)
                let bottomRight = bottomLeft + 1
                
                // Triangle 1
                indices.append(topLeft)
                indices.append(bottomLeft)
                indices.append(topRight)
                
                // Triangle 2
                indices.append(topRight)
                indices.append(bottomLeft)
                indices.append(bottomRight)
            }
        }
        
        // Define Mesh Descriptors
        var meshDesc = MeshDescriptor(name: "Terrain")
        meshDesc.positions = MeshBuffer(positions)
        meshDesc.normals = MeshBuffer(normals)
        meshDesc.primitives = .triangles(indices)
        
        let mesh = try! MeshResource.generate(from: [meshDesc])
        
        // Material - Wireframe-like look using UnlitMaterial with partial transparency
        var material = UnlitMaterial()
        material.color = .init(tint: .cyan.withAlphaComponent(0.3))
        
        let entity = ModelEntity(mesh: mesh, materials: [material])
        anchor.addChild(entity)
        
        // Add point cloud points for "data" feel
        for pos in positions {
             // Only add points selectively to avoid clutter
            if Float.random(in: 0...1) > 0.95 {
                let point = ModelEntity(
                    mesh: MeshResource.generateSphere(radius: 0.05),
                    materials: [UnlitMaterial(color: .white)]
                )
                point.position = pos
                anchor.addChild(point)
            }
        }
    }
}

// MARK: - Orbital Camera Controller
class OrbitalCameraARView: ARView {
    var cameraEntity: Entity?
    var cameraAnchor: AnchorEntity?
    
    // Orbital parameters
    var radius: Float = 25.0
    var theta: Float = 0.5 // Horizontal angle
    var phi: Float = 0.5   // Vertical angle
    var center: SIMD3<Float> = .zero
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupInteraction()
    }
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        setupInteraction()
    }
    
    private func setupInteraction() {
        // We will handle mouse events directly
    }
    
    func setCamera(_ camera: Entity, anchor: AnchorEntity) {
        self.cameraEntity = camera
        self.cameraAnchor = anchor
        updateCameraPosition()
    }
    
    private func updateCameraPosition() {
        guard let camera = cameraEntity else { return }
        
        let x = radius * sin(phi) * cos(theta)
        let y = radius * cos(phi)
        let z = radius * sin(phi) * sin(theta)
        
        camera.position = center + SIMD3<Float>(x, y, z)
        camera.look(at: center, from: camera.position, relativeTo: nil)
    }
    
    override func scrollWheel(with event: NSEvent) {
        // Zoom
        let sensitivity: Float = 0.5
        radius -= Float(event.deltaY) * sensitivity
        radius = max(2.0, min(radius, 100.0))
        updateCameraPosition()
    }
    
    override func mouseDragged(with event: NSEvent) {
        // Orbit
        let sensitivity: Float = 0.01
        theta -= Float(event.deltaX) * sensitivity
        phi -= Float(event.deltaY) * sensitivity
        
        // Clamp vertical angle to avoid flipping
        phi = max(0.1, min(phi, Float.pi - 0.1))
        
        updateCameraPosition()
    }
    
    override func rightMouseDragged(with event: NSEvent) {
        // Pan (Simple implementation)
        let sensitivity: Float = 0.05
        // Calculate right and up vectors relative to camera
        // For now just moving center on X/Z plane strictly
        center.x -= Float(event.deltaX) * sensitivity
        center.z -= Float(event.deltaY) * sensitivity
        updateCameraPosition()
    }
}
