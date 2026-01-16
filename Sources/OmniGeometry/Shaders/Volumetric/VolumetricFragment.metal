#include <metal_stdlib>
using namespace metal;

struct FragmentIn {
    float4 position [[position]];
    float3 worldPos;
    float3 normal;
};

// Signed Distance Field for terrain
float terrainSDF(float3 p, texture2d<float, access::sample> heightmap, sampler s) {
    float2 uv = (p.xz / 100.0) + 0.5; // Map world to UV
    float height = heightmap.sample(s, uv).r * 10.0;
    return p.y - height; // Distance to surface
}

// Volumetric fog density based on variance
float fogDensity(float3 p, texture2d<float, access::sample> variance, sampler s) {
    float2 uv = (p.xz / 100.0) + 0.5;
    float sigma = variance.sample(s, uv).g; // Variance in green channel
    
    // Fog is thicker where uncertainty is high
    return sigma * exp(-abs(p.y) * 0.1);
}

fragment float4 volumetric_fragment(
    FragmentIn in [[stage_in]],
    texture2d<float, access::sample> heightmap [[texture(0)]],
    texture2d<float, access::sample> variance [[texture(1)]],
    constant float4x4& viewMatrix [[buffer(0)]],
    constant float3& cameraPos [[buffer(1)]]
) {
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    
    // Ray setup
    float3 rayOrigin = cameraPos;
    float3 rayDir = normalize(in.worldPos - cameraPos);
    
    // Raymarch through volume
    float3 color = float3(0.0);
    float alpha = 0.0;
    
    const int steps = 64;
    const float stepSize = 0.5;
    
    for (int i = 0; i < steps; i++) {
        float t = float(i) * stepSize;
        float3 p = rayOrigin + rayDir * t;
        
        // Sample SDF
        float dist = terrainSDF(p, heightmap, s);
        
        // If we're near the surface, accumulate fog
        if (abs(dist) < 2.0) {
            float density = fogDensity(p, variance, s);
            
            // Accumulate color (blue-white gradient based on height)
            float heightFactor = (p.y + 5.0) / 10.0;
            float3 fogColor = mix(float3(0.2, 0.4, 0.8), float3(1.0, 1.0, 1.0), heightFactor);
            
            // Beer-Lambert law for absorption
            float absorption = exp(-density * stepSize);
            color += fogColor * density * (1.0 - alpha) * stepSize;
            alpha += (1.0 - alpha) * (1.0 - absorption);
            
            if (alpha > 0.99) break; // Early exit
        }
        
        // Stop if we hit the surface
        if (dist < 0.01) {
            // Surface hit - add solid color
            float3 surfaceColor = float3(0.3, 0.6, 0.3);
            color += surfaceColor * (1.0 - alpha);
            alpha = 1.0;
            break;
        }
    }
    
    return float4(color, alpha);
}

// TBDR Imageblock optimization: Read-modify-write in tile memory
fragment float4 volumetric_blend(
    FragmentIn in [[stage_in]],
    float4 currentColor [[color(0)]], // Read current framebuffer (TBDR feature)
    texture2d<float, access::sample> variance [[texture(0)]]
) {
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    
    // Sample uncertainty
    float2 uv = in.position.xy / float2(800, 600); // Screen space
    float sigma = variance.sample(s, uv).g;
    
    // Blend fog layer
    float3 fogColor = float3(0.5, 0.7, 1.0);
    float fogAlpha = sigma * 0.3;
    
    // Programmable blending in tile memory (no DRAM write until tile complete)
    float3 blended = mix(currentColor.rgb, fogColor, fogAlpha);
    
    return float4(blended, 1.0);
}
