#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position;
    float3 color;
};

struct VertexOut {
    float4 position [[position]];
    float3 color;
};

vertex VertexOut simple_terrain_vertex(
    uint vid [[vertex_id]],
    constant float4x4& mvp [[buffer(0)]]
) {
    // Generate a simple 3D grid terrain
    const int gridSize = 32;
    int x = vid % gridSize;
    int z = vid / gridSize;
    
    float fx = (float(x) / float(gridSize - 1) - 0.5) * 20.0;
    float fz = (float(z) / float(gridSize - 1) - 0.5) * 20.0;
    
    // Simple wave function for height
    float height = sin(fx * 0.5) * cos(fz * 0.5) * 3.0;
    
    float3 worldPos = float3(fx, height, fz);
    
    VertexOut out;
    out.position = mvp * float4(worldPos, 1.0);
    
    // Color based on height
    float t = (height + 3.0) / 6.0;
    out.color = mix(float3(0.2, 0.3, 0.8), float3(0.8, 0.9, 0.3), t);
    
    return out;
}

fragment float4 simple_terrain_fragment(VertexOut in [[stage_in]]) {
    return float4(in.color, 1.0);
}
