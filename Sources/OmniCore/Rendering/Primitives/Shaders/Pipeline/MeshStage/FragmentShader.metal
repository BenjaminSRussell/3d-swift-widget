#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float3 normal;
    float3 color;
};

// Helper for spectral mapping (Inferno-ish)
float3 heat_map(float t) {
    float3 c0 = float3(0.0, 0.0, 0.0);
    float3 c1 = float3(0.5, 0.0, 0.5); // Purple
    float3 c2 = float3(1.0, 0.5, 0.0); // Orange
    float3 c3 = float3(1.0, 1.0, 0.5); // Yellow
    
    if (t < 0.33) return mix(c0, c1, t * 3.0);
    if (t < 0.66) return mix(c1, c2, (t - 0.33) * 3.0);
    return mix(c2, c3, (t - 0.66) * 3.0);
}

fragment float4 terrain_fragment(VertexOut in [[stage_in]]) {
    // Basic lighting
    float3 lightDir = normalize(float3(1.0, 1.0, 1.0));
    float diffuse = max(dot(in.normal, lightDir), 0.2);
    
    // intensity is passed in color.x for now as a proxy
    float intensity = in.color.x;
    float3 heatColor = heat_map(intensity);
    
    // Mix base color and heatmap
    float3 finalColor = mix(in.color, heatColor, 0.7);
    
    return float4(finalColor * diffuse, 1.0);
}

