#include <metal_stdlib>
#include "../../Include/OmniShaderTypes.h"

using namespace metal;

// Phase 15.2: Final Post-Processing Pass

// Generic pseudo-random function for film grain
float noise(float2 uv, float time) {
    return fract(sin(dot(uv.xy, float2(12.9898, 78.233)) + time) * 43758.5453);
}

kernel void apply_post_process(texture2d<float, access::read> scene [[texture(0)]],
                               texture2d<float, access::read> bloom [[texture(1)]],
                               texture2d<float, access::write> output [[texture(2)]],
                               constant FrameUniforms &frame [[buffer(0)]],
                               uint2 id [[thread_position_in_grid]]) {
    
    if (id.x >= output.get_width() || id.y >= output.get_height()) return;
    
    float2 uv = float2(id) / float2(output.get_width(), output.get_height());
    float2 centerDist = uv - 0.5;
    
    // 1. Chromatic Aberration
    float aberration = 0.005;
    float4 color;
    color.r = scene.read(uint2(id + uint2(centerDist * aberration * 100.0))).r;
    color.g = scene.read(id).g;
    color.b = scene.read(uint2(id - uint2(centerDist * aberration * 100.0))).b;
    color.a = 1.0;
    
    // 2. Add Bloom
    float4 bloomColor = bloom.read(id);
    color.rgb += bloomColor.rgb * 0.5; // Bloom intensity
    
    // 3. Filmic Grain
    float grain = noise(uv, frame.time) * 0.02;
    color.rgb += grain;
    
    // 4. Tonemapping (Reinhard)
    color.rgb = color.rgb / (color.rgb + float3(1.0));
    
    // 5. Gamma Correction
    color.rgb = pow(color.rgb, float3(1.0/2.2));
    
    output.write(color, id);
}
