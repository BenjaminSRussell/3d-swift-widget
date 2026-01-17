#include <metal_stdlib>
#include "../../Include/OmniShaderTypes.h"

using namespace metal;

// Phase 15.1: Bloom Kernels

// Extracts pixels with luminance above a certain threshold
kernel void bloom_threshold(texture2d<float, access::read> input [[texture(0)]],
                            texture2d<float, access::write> output [[texture(1)]],
                            uint2 id [[thread_position_in_grid]]) {
    
    if (id.x >= input.get_width() || id.y >= input.get_height()) return;
    
    float4 color = input.read(id);
    float luminance = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    
    float threshold = 0.8;
    float4 result = (luminance > threshold) ? color : float4(0.0, 0.0, 0.0, 1.0);
    output.write(result, id);
}

// Dual Kawase Downsample
kernel void dual_kawase_down(texture2d<float, access::sample> source [[texture(0)]],
                             texture2d<float, access::write> dest [[texture(1)]],
                             uint2 id [[thread_position_in_grid]]) {
    if (id.x >= dest.get_width() || id.y >= dest.get_height()) return;
    
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 uv = (float2(id) + 0.5) / float2(dest.get_width(), dest.get_height());
    float2 halfpixel = 0.5 / float2(source.get_width(), source.get_height());
    
    float4 sum = source.sample(s, uv) * 4.0;
    sum += source.sample(s, uv + halfpixel * float2(-1, -1));
    sum += source.sample(s, uv + halfpixel * float2( 1,  1));
    sum += source.sample(s, uv + halfpixel * float2(-1,  1));
    sum += source.sample(s, uv + halfpixel * float2( 1, -1));
    
    dest.write(sum / 8.0, id);
}

// Dual Kawase Upsample
kernel void dual_kawase_up(texture2d<float, access::sample> source [[texture(0)]],
                           texture2d<float, access::write> dest [[texture(1)]],
                           constant float &offset [[buffer(0)]],
                           uint2 id [[thread_position_in_grid]]) {
    if (id.x >= dest.get_width() || id.y >= dest.get_height()) return;
    
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 uv = (float2(id) + 0.5) / float2(dest.get_width(), dest.get_height());
    float2 halfpixel = 0.5 / float2(source.get_width(), source.get_height());
    
    float4 sum = source.sample(s, uv + float2(-halfpixel.x * 2.0, 0.0) * offset);
    sum += source.sample(s, uv + float2(-halfpixel.x, halfpixel.y) * offset) * 2.0;
    sum += source.sample(s, uv + float2(0.0, halfpixel.y * 2.0) * offset);
    sum += source.sample(s, uv + float2(halfpixel.x, halfpixel.y) * offset) * 2.0;
    sum += source.sample(s, uv + float2(halfpixel.x * 2.0, 0.0) * offset);
    sum += source.sample(s, uv + float2(halfpixel.x, -halfpixel.y) * offset) * 2.0;
    sum += source.sample(s, uv + float2(0.0, -halfpixel.y * 2.0) * offset);
    sum += source.sample(s, uv + float2(-halfpixel.x, -halfpixel.y) * offset) * 2.0;
    
    dest.write(sum / 12.0, id);
}
