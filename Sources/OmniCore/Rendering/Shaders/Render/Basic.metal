#include <metal_stdlib>
#include "../Include/OmniShaderTypes.h"

using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
    float2 uv       [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 normal;
    float2 uv;
};

// Simple pass-through vertex shader to validate alignment
vertex VertexOut basic_vertex(VertexIn in [[stage_in]],
                              constant FrameUniforms &uniforms [[buffer(0)]],
                              constant ModelUniforms &model    [[buffer(1)]]) {
    VertexOut out;
    
    float4 pos4 = float4(in.position, 1.0);
    out.position = uniforms.viewProjectionMatrix * model.modelMatrix * pos4;
    out.normal = (model.normalMatrix * float4(in.normal, 0.0)).xyz;
    out.uv = in.uv;
    
    return out;
}

fragment float4 basic_fragment(VertexOut in [[stage_in]]) {
    // Debug output: visualize normals
    float3 n = normalize(in.normal);
    return float4(n * 0.5 + 0.5, 1.0);
}
