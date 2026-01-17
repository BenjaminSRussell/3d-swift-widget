import Metal
import OmniCore
import OmniCoreTypes

/// Phase 18.2: Interaction System (Merged)
/// Handles raycasting and mouse interactions.
public class InteractionSystem {
    let device: MTLDevice
    
    // --- Phase 16.1: Fluid Touch Support ---
    public struct TouchPoint {
        var position: SIMD2<Float> // 0..1 range
        var intensity: Float
        var radius: Float
    }
    
    public private(set) var touchBuffer: MTLBuffer?
    private var activeTouches: [TouchPoint] = []
    
    // Domain G: Telemetry & Audio
    public let entropyMonitor = EntropyMonitor()
    public let acousticRenderer = AcousticRenderer()
    
    public init(device: MTLDevice) {
        self.device = device
        
        // Support up to 10 simultaneous touches for Fluid Sim
        let bufferSize = 10 * MemoryLayout<TouchPoint>.stride
        self.touchBuffer = device.makeBuffer(length: bufferSize, options: .storageModeShared)
        self.touchBuffer?.label = "Active Touches Buffer"
    }
    
    public func addTouch(at normalizedPos: SIMD2<Float>, intensity: Float = 1.0, radius: Float = 0.05) {
        if activeTouches.count < 10 {
            activeTouches.append(TouchPoint(position: normalizedPos, intensity: intensity, radius: radius))
            updateBuffer()
            
            // Domain G: Feed Entropy & Audio
            entropyMonitor.update(position: normalizedPos)
            
            // Map 2D touch to 3D audio space (Z depth is simulated by Y height as interaction plane)
            let audioPos = SIMD3<Float>((normalizedPos.x - 0.5) * 10, 0, (normalizedPos.y - 0.5) * 10)
            acousticRenderer.playPulse(at: audioPos, intensity: intensity)
        }
    }
    
    public func clearTouches() {
        activeTouches.removeAll()
        updateBuffer()
    }
    
    public func updateInteractionSpace(complexity: Float) {
        acousticRenderer.updateReverb(complexity: complexity)
    }

    
    private func updateBuffer() {
        guard let buffer = touchBuffer else { return }
        let pointer = buffer.contents().assumingMemoryBound(to: TouchPoint.self)
        for (index, touch) in activeTouches.enumerated() {
            pointer[index] = touch
        }
        // Fill remaining with zero intensity
        if activeTouches.count < 10 {
            for i in activeTouches.count..<10 {
                pointer[i] = TouchPoint(position: .zero, intensity: 0, radius: 0)
            }
        }
    }
    
    public var touchCount: Int {
        return activeTouches.count
    }
    
    // --- Phase 18.2: Raycasting Support ---
    
    /// Unprojects a 2D screen point to a 3D ray.
    public func createRay(screenPoint: SIMD2<Float>, viewSize: SIMD2<Float>, viewMatrix: float4x4, projectionMatrix: float4x4) -> (origin: SIMD3<Float>, direction: SIMD3<Float>) {
        
        // 1. Convert Screen to NDC (-1 to 1)
        let ndcX = (screenPoint.x / viewSize.x) * 2.0 - 1.0
        let ndcY = 1.0 - (screenPoint.y / viewSize.y) * 2.0 // Flip Y
        
        let ndcNear = SIMD4<Float>(ndcX, ndcY, 0.0, 1.0)
        let ndcFar  = SIMD4<Float>(ndcX, ndcY, 1.0, 1.0)
        
        let invVP = (projectionMatrix * viewMatrix).inverse
        
        var worldNear = invVP * ndcNear
        var worldFar  = invVP * ndcFar
        
        worldNear /= worldNear.w
        worldFar /= worldFar.w
        
        let origin = SIMD3<Float>(worldNear.x, worldNear.y, worldNear.z)
        let end    = SIMD3<Float>(worldFar.x, worldFar.y, worldFar.z)
        let dir    = simd_normalize(end - origin)
        
        return (origin, dir)
    }
    
    /// Checks intersection with the infinite terrain plane (y = height(x,z))
    /// Simplified: Intersect with Y=0 plane for now.
    public func intersectPlane(rayOrigin: SIMD3<Float>, rayDir: SIMD3<Float>, planeY: Float = 0) -> SIMD3<Float>? {
        if abs(rayDir.y) < 0.0001 { return nil }
        
        let t = (planeY - rayOrigin.y) / rayDir.y
        if t < 0 { return nil }
        
        return rayOrigin + rayDir * t
    }
}
