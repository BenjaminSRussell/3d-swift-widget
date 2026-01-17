#include <metal_stdlib>
using namespace metal;

/// Phase 2.1: Material Resolver (Adaptive Micro-Materials)
/// Samples the background luminance and modifies the refractive index (IoR) and blur strength.
/// This creates a "Milled Crystal" look rather than flat glass.

struct MaterialUniforms {
    float baseIoR;          // Base Index of Refraction (e.g., 1.52 for Glass)
    float blurStrength;     // Max blur radius
    float saturationBoost;  // How much to boost background colors
    float2 resolution;      // Screen resolution
};

// Helper: Calculate luminance
float luminance(float3 color) {
    return dot(color, float3(0.2126, 0.7152, 0.0722));
}

// Fragment Shader for the "Glass" Container
[[fragment]]
float4 material_resolver_main(
    float4 position [[position]],
    texture2d<float> backgroundTexture [[texture(0)]],
    constant MaterialUniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float2 uv = position.xy / uniforms.resolution;
    
    // 1. Adaptive Refraction
    // Shift UVs based on normal (simplified here as edge distortion)
    // In a real 3D shader, we'd use surface normals.
    // Here we simulate "thick edges" by distorting near the border.
    float2 center = float2(0.5, 0.5);
    float dist = distance(uv, center);
    float edgeFactor = smoothstep(0.4, 0.5, dist); // 0 at center, 1 at edge
    
    float ior = mix(uniforms.baseIoR, uniforms.baseIoR + 0.1, edgeFactor);
    float2 refractedUV = uv + (uv - center) * (ior - 1.0) * 0.02; // Fake refraction
    
    // 2. Adaptive Blur Sampling
    // Sample background with LOD bias to simulate blur
    // Higher edge factor -> Thicker glass -> More blur
    float blurLevel = uniforms.blurStrength * (1.0 + edgeFactor);
    
    float4 bgSample = backgroundTexture.sample(s, refractedUV, level(blurLevel));
    
    // 3. Luminance Adjustment
    // If background is dark, increase transparency to look "icy".
    // If background is bright, increase opacity/reflection.
    float lum = luminance(bgSample.rgb);

    
    // 4. Saturation Boost (Prismatic Effect)
    float3 gray = float3(lum);
    float3 saturated = mix(gray, bgSample.rgb, 1.0 + uniforms.saturationBoost);
    
    // 5. Specular Highlight (The "Milled Edge")
    // Simple analytical rim light
    float rim = smoothstep(0.48, 0.5, dist);
    float3 rimColor = float3(1.0) * rim * 0.8;
    
    float3 finalColor = saturated + rimColor;
    
    return float4(finalColor, 1.0); // Compositing handled by pipeline blending
}
