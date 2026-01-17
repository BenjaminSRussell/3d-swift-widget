#include <metal_stdlib>
using namespace metal;

/// Phase 2.3: Volumetric Grid (Ray-Marching)
/// Replaces standard mesh rendering with a signed-distance-field (SDF) raymarcher.
/// Allows for boolean operations and infinite resolution zoom.

struct Ray {
    float3 origin;
    float3 direction;
};

struct VolumetricUniforms {
    float4x4 viewInverse;
    float4x4 projectionInverse;
    float3 cameraPosition;
    float2 resolution;
    float time;
    float densityThreshold; // For "Solid" vs "Gas"
};

// Utility: Hash function for noise
float hash(float2 p) {
    p = 50.0 * fract(p * 0.3183099 + float2(0.71, 0.113));
    return -1.0 + 2.0 * fract(p.x * p.y * (p.x + p.y));
}

// Utility: Value Noise
float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + float2(0.0, 0.0)), hash(i + float2(1.0, 0.0)), u.x),
               mix(hash(i + float2(0.0, 1.0)), hash(i + float2(1.0, 1.0)), u.x), u.y);
}

// Utility: FBM (Fractal Brownian Motion) for Terrain
float fbm(float2 p) {
    float f = 0.0;
    float2x2 m = float2x2(1.6,  1.2, -1.2,  1.6);
    f  = 0.5000 * noise(p); p = m * p;
    f += 0.2500 * noise(p); p = m * p;
    f += 0.1250 * noise(p); p = m * p;
    f += 0.0625 * noise(p); p = m * p;
    return f;
}

// SDF Primitive: Terrain
float sdTerrain(float3 p) {
    // Heightmap function: y = fbm(x, z)
    // SDF approximation: p.y - h
    float h = fbm(p.xz * 0.5) * 2.0; // Scale noise
    return p.y - h;
}

// Map the scene
float map(float3 p, float time) {
    return sdTerrain(p) * 0.5; // Multiplier to reduce artifacts
}

// Ray-Marching Loop
float march(Ray ray, float time) {
    float t = 0.0;
    for (int i = 0; i < 64; i++) {
        float3 p = ray.origin + ray.direction * t;
        float d = map(p, time);
        if (d < 0.001) return t; // Hit
        if (t > 20.0) break;     // Miss
        t += d;
    }
    return -1.0;
}

// Normal calculation
float3 calcNormal(float3 p, float time) {
    float2 e = float2(0.001, 0.0);
    return normalize(float3(
        map(p + e.xyy, time) - map(p - e.xyy, time),
        map(p + e.yxy, time) - map(p - e.yxy, time),
        map(p + e.yyx, time) - map(p - e.yyx, time)
    ));
}

kernel void volumetric_grid_compute(
    texture2d<float, access::write> output [[texture(0)]],
    constant VolumetricUniforms &uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= uint(uniforms.resolution.x) || gid.y >= uint(uniforms.resolution.y)) return;
    
    // Normalize coordinates (-1 to 1)
    float2 uv = (float2(gid) / uniforms.resolution) * 2.0 - 1.0;
    
    // Create Ray from Camera
    // Simple perspective setup (simplified)
    Ray ray;
    ray.origin = uniforms.cameraPosition;
    float4 target = uniforms.projectionInverse * float4(uv, 0, 1);
    float4 dir = uniforms.viewInverse * float4(normalize(target.xyz), 0);
    ray.direction = normalize(dir.xyz);
    
    // March
    float t = march(ray, uniforms.time);
    
    float4 color = float4(0, 0, 0, 0); // Transparent background
    
    if (t > 0.0) {
        float3 p = ray.origin + ray.direction * t;
        float3 n = calcNormal(p, uniforms.time);
        
        // Lighting: Debug Mode
        float3 lightDir = normalize(float3(0.5, 0.8, -0.5));
        float diff = max(dot(n, lightDir), 0.0);
        
        // Height Color Gradient
        float height = p.y; 
        float3 lowColor = float3(0.0, 0.0, 1.0); // Solid Blue
        float3 highColor = float3(1.0, 1.0, 1.0); // Solid White
        float3 baseColor = mix(lowColor, highColor, smoothstep(-1.0, 1.5, height));
        
        color = float4(baseColor * (diff + 0.5), 1.0); // Bright, Opaque
    } else {
         // Ray Miss - Background
         color = float4(0.2, 0.2, 0.2, 1.0); // Solid Dark Grey Background (Not transparent)
    }
    
    output.write(color, gid);
}
