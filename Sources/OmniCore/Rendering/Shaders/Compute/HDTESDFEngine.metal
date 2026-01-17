#include <metal_stdlib>
#include "../../Include/OmniShaderTypes.h"

using namespace metal;

// MARK: - Constants
constant int MAX_STEPS = 128;
constant float MAX_DIST = 100.0;
constant float SURF_DIST = 0.001;

// MARK: - SDF Primitives

// Sphere: length(p) - r
float sdSphere(float3 p, float r) {
    return length(p) - r;
}

// Box: length(max(abs(p) - b, 0.0))
float sdBox(float3 p, float3 b) {
    float3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

// Smooth Minimum for metaball effects
float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// MARK: - Scene Map

// Sample the distance to the scene geometry
// For HDTE, this would typically involve sampling a grid or a list of data clusters
float map(float3 p, constant float &time) {
    // Demo scene: A pulsating sphere and a ground plane
    
    // 1. Central "Data Core" Sphere
    float s1 = sdSphere(p - float3(0, 1, 0), 1.0);
    
    // 2. Orbiting "Satellite"
    float3 orbitPos = float3(sin(time), 1.5, cos(time)) * 2.0;
    float s2 = sdSphere(p - orbitPos, 0.5);
    
    // 3. Smooth blend
    return smin(s1, s2, 0.5);
}

// MARK: - Raymarching

// Returns distance to surface
float rayMarch(float3 ro, float3 rd, constant float &time) {
    float dO = 0.0; // Distance Origin
    
    for (int i = 0; i < MAX_STEPS; i++) {
        float3 p = ro + rd * dO;
        float dS = map(p, time);
        dO += dS;
        if (dO > MAX_DIST || dS < SURF_DIST) break;
    }
    
    return dO;
}

// Calculate normal by sampling gradient
float3 GetNormal(float3 p, constant float &time) {
    float d = map(p, time);
    float2 e = float2(0.001, 0);
    
    float3 n = d - float3(
        map(p - e.xyy, time),
        map(p - e.yxy, time),
        map(p - e.yyx, time)
    );
    
    return normalize(n);
}

// MARK: - Kernel

kernel void renderSDF(
    texture2d<float, access::write> output [[texture(0)]],
    constant FrameUniforms &uniforms [[buffer(0)]],
    uint2 id [[thread_position_in_grid]]) {
    
    // Check bounds
    if (id.x >= output.get_width() || id.y >= output.get_height()) return;
    
    // Normalized device coordinates (-1 to 1)
    float2 resolution = float2(output.get_width(), output.get_height());
    float2 uv = (float2(id) - 0.5 * resolution) / resolution.y;
    
    // Camera setup (using uniforms)
    float3 ro = uniforms.cameraPosition;
    
    // Calculate ray direction based on camera view matrix (simplified)
    // Ideally we multiply (uv.x, uv.y, 1.0) by the inverse view matrix
    // For now, simple look-at logic:
    float3 forward = normalize(float3(0,0,0) - ro);
    float3 right = normalize(cross(float3(0,1,0), forward));
    float3 up = cross(forward, right);
    float3 rd = normalize(forward + uv.x * right + uv.y * up);
    
    // Raymarch
    float d = rayMarch(ro, rd, uniforms.time);
    
    // Coloring
    float3 col = float3(0.0);
    
    if (d < MAX_DIST) {
        float3 p = ro + rd * d;
        float3 n = GetNormal(p, uniforms.time);
        
        // Simple lighting
        float3 lightPos = float3(2, 5, 3);
        float3 l = normalize(lightPos - p);
        float dif = clamp(dot(n, l), 0.0, 1.0);
        
        // Glassmorphic translucent base
        col = float3(0.1, 0.4, 0.8) * dif + float3(0.05, 0.1, 0.2);
        
        // Volumetric accumulation (simple fog)
        // float fog = 1.0 / (1.0 + d * d * 0.1);
        // col = mix(float3(0.0), col, fog);
    }
    
    output.write(float4(col, 1.0), id);
}
