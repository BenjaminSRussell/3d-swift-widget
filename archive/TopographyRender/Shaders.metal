#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 normal;
    float height;
};

struct Uniforms {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
};

vertex VertexOut terrain_vertex(const device float3 *vertices [[buffer(0)]],
                                const device float3 *normals [[buffer(1)]],
                                constant Uniforms &uniforms [[buffer(2)]],
                                uint vid [[vertex_id]]) {
    VertexOut out;
    
    float3 position = vertices[vid];
    float3 normal = normals[vid];
    
    out.worldPosition = (uniforms.modelMatrix * float4(position, 1.0)).xyz;
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * float4(out.worldPosition, 1.0);
    out.normal = (uniforms.modelMatrix * float4(normal, 0.0)).xyz;
    out.height = position.y;
    
    return out;
}

fragment float4 terrain_fragment(VertexOut in [[stage_in]]) {
    // Height-based coloring
    float height = in.height;
    float3 color;
    
    // Colors
    float3 water = float3(0.0, 0.2, 0.8);
    float3 sand = float3(0.76, 0.7, 0.5);
    float3 grass = float3(0.1, 0.6, 0.1);
    float3 rock = float3(0.4, 0.4, 0.4);
    float3 snow = float3(1.0, 1.0, 1.0);
    
    if (height < 0.15) {
        color = water;
    } else if (height < 0.25) {
        color = mix(water, sand, (height - 0.15) / 0.10);
    } else if (height < 0.3) {
        color = sand;
    } else if (height < 0.6) {
        color = mix(grass, rock, (height - 0.3) / 0.3);
    } else if (height < 0.8) {
        color = rock;
    } else {
        color = mix(rock, snow, (height - 0.8) / 0.2);
    }
    
    // Simple lighting
    float3 lightDir = normalize(float3(1.0, 1.0, 0.5));
    float diffuse = max(dot(normalize(in.normal), lightDir), 0.2);
    
    return float4(color * diffuse, 1.0);
}
