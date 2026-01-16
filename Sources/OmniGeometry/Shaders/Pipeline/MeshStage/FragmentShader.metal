#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float3 normal;
    float3 color;
};

fragment float4 terrain_fragment(VertexOut in [[stage_in]]) {
    // Basic lighting
    float3 lightDir = normalize(float3(1.0, 1.0, 1.0));
    float diffuse = max(dot(in.normal, lightDir), 0.1);
    
    return float4(in.color * diffuse, 1.0);
}
