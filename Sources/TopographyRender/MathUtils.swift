import simd

public struct Matrix4x4 {
    public static func identity() -> matrix_float4x4 {
        return matrix_identity_float4x4
    }
    
    public static func perspective(fovy: Float, aspect: Float, near: Float, far: Float) -> matrix_float4x4 {
        let yScale = 1 / tan(fovy * 0.5)
        let xScale = yScale / aspect
        let zRange = far - near
        let zScale = -(far + near) / zRange
        let wzScale = -2 * far * near / zRange
        
        return matrix_float4x4(columns: (
            simd_float4(xScale, 0, 0, 0),
            simd_float4(0, yScale, 0, 0),
            simd_float4(0, 0, zScale, -1),
            simd_float4(0, 0, wzScale, 0)
        ))
    }
    
    public static func lookAt(eye: simd_float3, center: simd_float3, up: simd_float3) -> matrix_float4x4 {
        let z = normalize(eye - center)
        let x = normalize(cross(up, z))
        let y = cross(z, x)
        
        return matrix_float4x4(columns: (
            simd_float4(x.x, y.x, z.x, 0),
            simd_float4(x.y, y.y, z.y, 0),
            simd_float4(x.z, y.z, z.z, 0),
            simd_float4(-dot(x, eye), -dot(y, eye), -dot(z, eye), 1)
        ))
    }
    
    public static func rotation(angle: Float, axis: simd_float3) -> matrix_float4x4 {
        let normalizedAxis = normalize(axis)
        let ct = cos(angle)
        let st = sin(angle)
        let ci = 1 - ct
        let x = normalizedAxis.x, y = normalizedAxis.y, z = normalizedAxis.z
        
        return matrix_float4x4(columns: (
            simd_float4(ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
            simd_float4(x * y * ci - z * st, ct + y * y * ci, z * y * ci + x * st, 0),
            simd_float4(x * z * ci + y * st, y * z * ci - x * st, ct + z * z * ci, 0),
            simd_float4(0, 0, 0, 1)
        ))
    }
    
    public static func translation(_ t: simd_float3) -> matrix_float4x4 {
        var matrix = matrix_identity_float4x4
        matrix.columns.3 = simd_float4(t.x, t.y, t.z, 1)
        return matrix
    }
    
    public static func scale(_ s: Float) -> matrix_float4x4 {
        var matrix = matrix_identity_float4x4
        matrix.columns.0.x = s
        matrix.columns.1.y = s
        matrix.columns.2.z = s
        return matrix
    }
}
