import simd

/// Phase 4.1: View Projection Unprojection
/// Maps 3D world coordinates to 2D screen space (and vice-versa).
/// Essential for drawing "Connector Lines" from 3D data points to 2D side panels.

public struct ViewProjectionUnprojection {
    
    /// Projects a 3D point into 2D screen coordinates.
    /// - Parameters:
    ///   - position: 3D world position
    ///   - viewMatrix: Camera View Matrix
    ///   - projectionMatrix: Camera Projection Matrix
    ///   - viewportSize: Screen size (width, height)
    /// - Returns: 2D Screen Coordinate (origin top-left usually, or bottom-left depending on UI)
    public static func project(
        position: SIMD3<Float>,
        viewMatrix: simd_float4x4,
        projectionMatrix: simd_float4x4,
        viewportSize: SIMD2<Float>
    ) -> SIMD2<Float>? {
        
        let position4 = SIMD4<Float>(position, 1.0)
        let clipPos = projectionMatrix * viewMatrix * position4
        
        // Clip check (simple)
        if clipPos.w == 0 { return nil }
        
        // Normalized Device Coordinates (-1 to 1)
        let ndc = SIMD3<Float>(clipPos.x / clipPos.w, clipPos.y / clipPos.w, clipPos.z / clipPos.w)
        
        // Check if behind camera or too far
        if ndc.z < 0 || ndc.z > 1 { return nil }
        
        // Map to Viewport (0 to width, 0 to height)
        // Assuming Metal NDC (y up? or down? Metal is y-up in NDC usually, but SwiftUI is y-down)
        // Let's assume standard NDC y-up (-1 bottom, 1 top).
        // And we want SwiftUI coordinates (0 top, height bottom).
        
        let x = (ndc.x + 1) * 0.5 * viewportSize.x
        let y = (1 - ndc.y) * 0.5 * viewportSize.y // Flip Y for UI
        
        return SIMD2<Float>(x, y)
    }
    
    /// Unprojects a 2D screen point into a 3D Ray.
    /// - Returns: (Origin, Direction)
    public static func unproject(
        screenPos: SIMD2<Float>,
        viewMatrix: simd_float4x4,
        projectionMatrix: simd_float4x4,
        viewportSize: SIMD2<Float>
    ) -> (origin: SIMD3<Float>, direction: SIMD3<Float>) {
        
        let x = (screenPos.x / viewportSize.x) * 2 - 1
        let y = -((screenPos.y / viewportSize.y) * 2 - 1) // Flip Y back to NDC
        
        let clipPos = SIMD4<Float>(x, y, 0, 1) // Z=0 (Near plane)
        let clipPosFar = SIMD4<Float>(x, y, 1, 1) // Z=1 (Far plane)
        
        let invVP = (projectionMatrix * viewMatrix).inverse
        
        var worldPosNear = invVP * clipPos
        worldPosNear /= worldPosNear.w
        
        var worldPosFar = invVP * clipPosFar
        worldPosFar /= worldPosFar.w
        
        let origin = SIMD3<Float>(worldPosNear.x, worldPosNear.y, worldPosNear.z)
        let end = SIMD3<Float>(worldPosFar.x, worldPosFar.y, worldPosFar.z)
        let direction = normalize(end - origin)
        
        return (origin, direction)
    }
}
