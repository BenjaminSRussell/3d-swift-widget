import Foundation
import simd
import OmniGeometry

public class TopologicalNavigationController: ObservableObject {
    @Published public var cameraPosition: SIMD3<Float> = SIMD3<Float>(0, 20, 40)
    @Published public var cameraTarget: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    
    // Spherical Coordinates
    private var radius: Float = 45.0
    private var theta: Float = 0.0 // Azimuth
    private var phi: Float = Float.pi / 4 // Polar angle (from Y axis)
    
    public init(topologyEngine: Any) {
        updateCameraPosition()
    }
    
    public func handleDrag(delta: SIMD2<Float>, inViewportSize size: SIMD2<Float>) {
        let sensitivity: Float = 0.005
        
        // Horizontal drag -> Azimuth (Theta)
        theta -= delta.x * sensitivity
        
        // Vertical drag -> Polar (Phi)
        phi -= delta.y * sensitivity
        
        // Clamp Phi to avoid gimbal lock (0.01 to Pi-0.01)
        let epsilon: Float = 0.001
        phi = max(epsilon, min(Float.pi - epsilon, phi))
        
        updateCameraPosition()
    }
    
    public func handleZoom(delta: Float) {
        let zoomSpeed: Float = 2.0
        radius -= delta * zoomSpeed
        radius = max(5.0, min(200.0, radius)) // Clamp radius
        updateCameraPosition()
    }
    
    private func updateCameraPosition() {
        // Spherical to Cartesian
        let x = radius * sin(phi) * sin(theta)
        let y = radius * cos(phi)
        let z = radius * sin(phi) * cos(theta)
        
        self.cameraPosition = cameraTarget + SIMD3<Float>(x, y, z)
        // print("Camera: \(cameraPosition)") // Debug
    }
}
