#include <metal_stdlib>
#include "../../Include/OmniShaderTypes.h"

using namespace metal;

// Phase 16.2: Interaction Kernels

struct InteractionTouch {
    float2 position; // 0..1
    float intensity;
    float radius;
};

kernel void apply_ripple(device float *heights [[buffer(0)]],
                         device const InteractionTouch *touches [[buffer(1)]],
                         constant uint &touchCount [[buffer(2)]],
                         constant uint2 &gridRes [[buffer(3)]],
                         uint2 id [[thread_position_in_grid]]) {
    
    if (id.x >= gridRes.x || id.y >= gridRes.y) return;
    
    float2 uv = float2(id) / float2(gridRes);
    float totalDelta = 0.0;
    
    for (uint i = 0; i < touchCount; i++) {
        InteractionTouch touch = touches[i];
        if (touch.intensity <= 0.0) continue;
        
        float dist = distance(uv, touch.position);
        if (dist < touch.radius) {
            // Smooth bell curve ripple
            float force = 1.0 - (dist / touch.radius);
            totalDelta += force * touch.intensity;
        }
    }
    
    if (totalDelta > 0.0) {
        uint idx = id.y * gridRes.x + id.x;
        heights[idx] += totalDelta;
    }
}
