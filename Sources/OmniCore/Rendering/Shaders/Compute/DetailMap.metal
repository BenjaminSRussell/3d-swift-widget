#include <metal_stdlib>
#include "../../Include/OmniShaderTypes.h"

using namespace metal;

// Phase 18.2: Detail Injection
// Blends the high-frequency detail from the ML estimator back into the height map.

kernel void inject_detail(device float *heights [[buffer(0)]],
                          texture2d<float, access::read> detailMap [[texture(0)]],
                          constant uint2 &gridRes [[buffer(1)]],
                          uint2 id [[thread_position_in_grid]]) {
    
    if (id.x >= gridRes.x || id.y >= gridRes.y) return;
    
    // Read Detail
    // The detail map might be lower resolution or upscaled, so we sample carefully.
    // For now, assuming 1:1 mapping for simplicity or using normalized coordinates if texture is different size.
    
    // Map grid index to UV
    float2 uv = float2(id) / float2(gridRes);
    
    // Read from detail texture (which contains "hallucinated" high frequencies)
    // We use a samplerless read if sizes match, otherwise we'd need a sampler.
    // Let's assume the detailMap is resized to gridRes by the ML pass (upsampling).
    uint2 texCoord = uint2(uv * float2(detailMap.get_width(), detailMap.get_height()));
    float detail = detailMap.read(texCoord).r;
    
    // Blend: Add localized detail to the physical height
    // We only add detail where the fluid is "calm" to avoid adding noise to turbulent waves,
    // or conversely add it everywhere for a "rough" liquid look.
    // Let's try adding it as a micro-displacement.
    
    uint idx = id.y * gridRes.x + id.x;
    
    // Modulation intensity (0.1 is subtle)
    float intensity = 0.1;
    heights[idx] += (detail - 0.5) * intensity;
}
