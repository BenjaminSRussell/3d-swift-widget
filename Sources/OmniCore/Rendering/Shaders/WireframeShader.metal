#include <metal_stdlib>
using namespace metal;

// Shared data structures
struct VertexIn {
    float3 position [[attribute(0)]];
    float4 color [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

struct Uniforms {
    float4x4 mvpMatrix;
    float time; // Phase 4: Time for animation
};

vertex VertexOut wireframe_vertex(
    const device VertexIn* vertices [[buffer(0)]],
    constant Uniforms &uniforms [[buffer(1)]],
    uint vid [[vertex_id]]
) {
    VertexOut out;
    VertexIn v = vertices[vid];
    
    // Phase 4: Dynamic Displacement (Sine Wave)
    float3 pos = v.position;
    float amp = 2.0;
    float freq = 0.5;
    
    // Simple interference pattern
    float y = sin(pos.x * freq + uniforms.time) * cos(pos.z * freq + uniforms.time * 0.5) * amp;
    pos.y += y;
    
    out.position = uniforms.mvpMatrix * float4(pos, 1.0);
    
    // Solid BRIGHT GREEN for grid
    out.color = float4(0.0, 1.0, 0.0, 1.0);
    
    return out;
}

fragment float4 wireframe_fragment(VertexOut in [[stage_in]]) {
    return in.color;
}
