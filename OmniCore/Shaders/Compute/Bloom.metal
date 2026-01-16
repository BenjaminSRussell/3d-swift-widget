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

// Simple Horizontal/Vertical Gaussian Blur (Ping-pong)
kernel void bloom_blur(texture2d<float, access::read> input [[texture(0)]],
                       texture2d<float, access::write> output [[texture(1)]],
                       constant bool &horizontal [[buffer(0)]],
                       uint2 id [[thread_position_in_grid]]) {
    
    if (id.x >= input.get_width() || id.y >= input.get_height()) return;
    
    float weight[5] = {0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216};
    float4 result = input.read(id) * weight[0];
    
    if (horizontal) {
        for (int i = 1; i < 5; ++i) {
            result += input.read(id + uint2(i, 0)) * weight[i];
            result += input.read(id - uint2(i, 0)) * weight[i];
        }
    } else {
        for (int i = 1; i < 5; ++i) {
            result += input.read(id + uint2(0, i)) * weight[i];
            result += input.read(id - uint2(0, i)) * weight[i];
        }
    }
    
    output.write(result, id);
}
