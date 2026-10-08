import SceneKit
import TopographyCore

public class TopographyScene {
    public let scene: SCNScene
    private var terrainNode: SCNNode?
    
    public init() {
        self.scene = SCNScene()
        setupLights()
        setupCamera()
    }
    
    private func setupLights() {
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = NSColor(white: 0.3, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)
        
        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light?.type = .directional
        directionalLight.position = SCNVector3(10, 20, 10)
        // Pointing down
        directionalLight.eulerAngles = SCNVector3(-Float.pi / 3, 0, 0)
        scene.rootNode.addChildNode(directionalLight)
    }
    
    private func setupCamera() {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(10, 15, 20)
        cameraNode.look(at: SCNVector3(5, 0, 5))
        scene.rootNode.addChildNode(cameraNode)
    }
    
    public func updateTerrain(with data: TerrainData) {
        terrainNode?.removeFromParentNode()
        
        let geometry = TerrainGeometryBuilder.buildGeometry(from: data, scale: 2.0)
        
        // Add basic material
        let material = SCNMaterial()
        material.diffuse.contents = NSColor.systemBlue
        material.specular.contents = NSColor.white
        geometry.materials = [material]
        
        terrainNode = SCNNode(geometry: geometry)
        terrainNode?.position = SCNVector3(-Float(data.width)/2.0, 0, -Float(data.depth)/2.0)
        scene.rootNode.addChildNode(terrainNode!)
    }
}
