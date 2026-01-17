#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float3 color;
};

vertex VertexOut force_visible_vertex(uint vid [[vertex_id]]) {
    // Full screen triangle
    float2 positions[3] = {
        float2(-1, -1),
        float2(3, -1),
        float2(-1, 3)
    };
    
    VertexOut out;
    out.position = float4(positions[vid], 0.0, 1.0);
    out.color = float3(1.0, 0.0, 1.0); // Bright magenta
    return out;
}

fragment float4 force_visible_fragment(VertexOut in [[stage_in]]) {
    return float4(in.color, 1.0);
}
