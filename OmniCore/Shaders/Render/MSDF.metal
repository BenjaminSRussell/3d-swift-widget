#include <metal_stdlib>
#include "../../Include/OmniShaderTypes.h"

using namespace metal;

// Phase 14.1: MSDF Shader Library
// Renders crisp vector-like text from a multi-channel signed distance field atlas.

float median(float r, float g, float b) {
    return max(min(r, g), min(max(r, g), b));
}

// Samples an MSDF texture and returns the distance to the edge.
float sample_msdf_dist(texture2d<float> msdf_atlas, sampler s, float2 uv) {
    float3 sample = msdf_atlas.sample(s, uv).rgb;
    return median(sample.r, sample.g, sample.b) - 0.5;
}

// Fragment shader function for MSDF text rendering
float4 render_msdf_text(float dist, float3 color, float opacity, float pxRange, float thickness) {
    // pxRange is the range in pixels of the distance field (e.g., 2.0 or 4.0)
    // thickness allows adjusting the weight of the font (0.0 is standard)
    
    // Screen-space derivatives for anti-aliasing
    float dx = dfdx(dist);
    float dy = dfdy(dist);
    float edgeWidth = length(float2(dx, dy));
    
    // Smoothstep for anti-aliasing
    float alpha = smoothstep(-edgeWidth, edgeWidth, dist + thickness);
    
    return float4(color, alpha * opacity);
}

struct UIVertexIn {
    float2 position [[attribute(0)]];
    float2 uv [[attribute(1)]];
};

struct UIVertexOut {
    float4 position [[position]];
    float2 uv;
};

// UI Vertex Shader
vertex UIVertexOut ui_vertex(UIVertexIn in [[stage_in]]) {
    UIVertexOut out;
    out.position = float4(in.position * 2.0 - 1.0, 0.0, 1.0); // Map 0-1 to ND-1-1
    out.uv = in.uv;
    return out;
}

// UI Fragment Shader (Using MSDF)
fragment float4 ui_fragment(UIVertexOut in [[stage_in]],
                            texture2d<float> msdf_atlas [[texture(0)]],
                            sampler s [[sampler(0)]]) {
    
    float dist = sample_msdf_dist(msdf_atlas, s, in.uv);
    return render_msdf_text(dist, float3(1.0), 1.0, 2.0, 0.0);
}
