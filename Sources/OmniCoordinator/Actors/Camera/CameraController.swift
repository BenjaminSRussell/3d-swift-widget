import Foundation
import simd

public actor CameraController {
    // Orbit state
    public var distance: Float = 50.0
    public var azimuth: Float = 0.0 // Horizontal rotation
    public var elevation: Float = .pi / 4 // Vertical angle
    public var fov: Float = .pi / 3
    
    public init() {}
    
    public func rotate(deltaAzimuth: Float, deltaElevation: Float) {
        azimuth += deltaAzimuth
        elevation = max(-Float.pi / 2 + 0.1, min(Float.pi / 2 - 0.1, elevation + deltaElevation))
    }
    
    public func zoom(delta: Float) {
        distance = max(5.0, min(200.0, distance + delta))
    }
    
    public func reset() {
        distance = 50.0
        azimuth = 0.0
        elevation = .pi / 4
    }
    
    public func viewProjectionMatrix(aspect: Float) -> simd_float4x4 {
        // View matrix (camera position)
        let eye = simd_float3(
            distance * cos(elevation) * cos(azimuth),
            distance * sin(elevation),
            distance * cos(elevation) * sin(azimuth)
        )
        let center = simd_float3(0, 0, 0)
        let up = simd_float3(0, 1, 0)
        
        let viewMatrix = createLookAt(eye: eye, center: center, up: up)
        
        // Projection matrix
        let projMatrix = createPerspective(fov: fov, aspect: aspect, near: 0.1, far: 1000.0)
        
        return projMatrix * viewMatrix
    }
    
    private func createLookAt(eye: simd_float3, center: simd_float3, up: simd_float3) -> simd_float4x4 {
        let z = normalize(eye - center)
        let x = normalize(cross(up, z))
        let y = cross(z, x)
        
        return simd_float4x4(
            simd_float4(x.x, y.x, z.x, 0),
            simd_float4(x.y, y.y, z.y, 0),
            simd_float4(x.z, y.z, z.z, 0),
            simd_float4(-dot(x, eye), -dot(y, eye), -dot(z, eye), 1)
        )
    }
    
    private func createPerspective(fov: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
        let yScale = 1 / tan(fov / 2)
        let xScale = yScale / aspect
        let zRange = far - near
        let zScale = -(far + near) / zRange
        let wzScale = -2 * far * near / zRange
        
        return simd_float4x4(
            simd_float4(xScale, 0, 0, 0),
            simd_float4(0, yScale, 0, 0),
            simd_float4(0, 0, zScale, -1),
            simd_float4(0, 0, wzScale, 0)
        )
    }
}
