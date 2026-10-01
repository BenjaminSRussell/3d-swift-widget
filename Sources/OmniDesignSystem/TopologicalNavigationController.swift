import Foundation
import simd
import OmniCore

/// TopologicalNavigationController: Manages camera control and manifold-aware interaction.
public final class TopologicalNavigationController {
    
    // Dependencies
    private let topologyEngine: HDTEPersistentHomology
    
    // State
    public var cameraPosition: SIMD3<Float> = SIMD3<Float>(0, 0, 10)
    public var cameraTarget: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    public var parallaxOffset: SIMD2<Float> = .zero
    public var isSnapping: Bool = false
    private var currentPitch: Float = 0.0 // Track vertical rotation angle

    // Configuration
    public var snapThreshold: Float = 0.5
    private let maxPitchAngle: Float = 85.0 * .pi / 180.0 // ±85° in radians
    private let minPitchAngle: Float = -85.0 * .pi / 180.0
    
    public init(topologyEngine: HDTEPersistentHomology) {
        self.topologyEngine = topologyEngine
    }
    
    // MARK: - Interaction Handlers
    
    /// Updates camera position based on a drag gesture, integrating topological snapping.
    public func handleDrag(delta: SIMD2<Float>, inViewportSize size: SIMD2<Float>) {
        // Simple orbital rotation with pitch clamping
        // Updates rotation angles (azimuth via rotationX, elevation via rotationY)

        let sensitivity: Float = 0.01
        let rotationX = delta.x * sensitivity
        let rotationY = delta.y * sensitivity

        // Update camera position based on rotation around target
        // Basic orbital camera math
        let currentOffset = cameraPosition - cameraTarget

        // Rotate around Y axis (horizontal drag / azimuth)
        let rotationMatrixY = float4x4(rotationY: -rotationX) // Drag left = rotate camera right (clockwise)
        let rotatedVec = rotationMatrixY * SIMD4<Float>(currentOffset.x, currentOffset.y, currentOffset.z, 1.0)
        var newOffset = SIMD3<Float>(rotatedVec.x, rotatedVec.y, rotatedVec.z)

        // Apply pitch rotation around X axis (vertical drag / elevation) with clamping
        // Update and clamp the pitch angle
        currentPitch += rotationY
        currentPitch = max(minPitchAngle, min(maxPitchAngle, currentPitch))

        // Create rotation matrix for pitch (rotation around X axis)
        let pitchMatrix = float4x4(rotationX: currentPitch)
        let pitchedVec = pitchMatrix * SIMD4<Float>(newOffset.x, newOffset.y, newOffset.z, 1.0)
        newOffset = SIMD3<Float>(pitchedVec.x, pitchedVec.y, pitchedVec.z)

        cameraPosition = cameraTarget + newOffset
    }
    
    // Helper for rotation matrices
    private func float4x4(rotationY angle: Float) -> simd_float4x4 {
        return simd_float4x4(
            SIMD4<Float>(cos(angle), 0, sin(angle), 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(-sin(angle), 0, cos(angle), 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
    }

    private func float4x4(rotationX angle: Float) -> simd_float4x4 {
        return simd_float4x4(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, cos(angle), -sin(angle), 0),
            SIMD4<Float>(0, sin(angle), cos(angle), 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
    }
    
    /// Attempts to snap the target position to a significant topological feature.
    /// This gives the user a "magnetic" feel when navigating near data structures.
    public func snapToFeature(near point: SIMD3<Float>) -> SIMD3<Float> {
        // 1. Check for nearby 0D persistence features (clusters)
        // Accessing topology engine's critical points (cached or computed)
        
        // Mock Implementation:
        // Let's say we have a list of 'climax' points from the topology engine.
        let criticalPoints: [SIMD3<Float>] = [
            SIMD3<Float>(0, 0, 0),      // Origin
            SIMD3<Float>(10, 5, -5),    // Cluster A
            SIMD3<Float>(-5, -5, 5)     // Cluster B
        ]
        
        var bestMatch: SIMD3<Float>?
        var minDistance: Float = Float.infinity
        
        for feature in criticalPoints {
            let d = distance(point, feature)
            if d < snapThreshold && d < minDistance {
                minDistance = d
                bestMatch = feature
            }
        }
        
        if let match = bestMatch {
            isSnapping = true
            return match
        }
        
        isSnapping = false
        return point
    }
    
    /// Snaps a scalar value (e.g., slider input) to a "climax" or round number.
    /// Used for filtering sliders (e.g., persistence threshold).
    public func snapToClimax(_ value: Float) -> Float {
        // Climax values could be persistence birth/death times that are statistically significant.
        let climaxes: [Float] = [0.1, 0.5, 1.0, 2.5] // Example thresholds
        
        for climax in climaxes {
            if abs(value - climax) < 0.05 {
                return climax
            }
        }
        
        // Fallback to round numbers
        let step: Float = 0.1
        return round(value / step) * step
    }
}
