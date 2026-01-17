#include <metal_stdlib>
using namespace metal;

/// Phase 2.4: SSGI (Screen Space Global Illumination)
/// Approximates global illumination by ray-marching the screen-space depth/color buffers.
/// Confined strictly to the widget's internal canvas.

// Simple Ray-March in Screen Space
// Returns the color accumulated from bouncing rays
kernel void ssgi_compute(
    texture2d<float, access::read> colorTexture [[texture(0)]],
    texture2d<float, access::read> depthTexture [[texture(1)]],
    texture2d<float, access::write> output [[texture(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    
    // 1. Read Base Color & Depth
    float4 baseColor = colorTexture.read(gid);
    float depth = depthTexture.read(gid).r;
    
    if (baseColor.a < 0.1) {
        output.write(baseColor, gid);
        return;
    }
    
    // 2. Simple Ambient Occlusion / GI Approximation
    // Sampling neighbors to detect "glow" bleed
    float3 accumulatedLight = float3(0.0);
    int samples = 0;
    
    // Sample a small radius
    for (int x = -2; x <= 2; x++) {
        for (int y = -2; y <= 2; y++) {
            if (x == 0 && y == 0) continue;
            
            uint2 neighborCoord = uint2(gid.x + x * 4, gid.y + y * 4); // Stride 4 for wider gather
            
            // Boundary check
            if (neighborCoord.x >= colorTexture.get_width() || neighborCoord.y >= colorTexture.get_height()) continue;
            
            float4 neighborColor = colorTexture.read(neighborCoord);
            float neighborDepth = depthTexture.read(neighborCoord).r;
            
            // Depth Threshold to avoid bleeding from far objects
            if (abs(depth - neighborDepth) < 0.05) {
                // If neighbor is bright, it contributes to GI
                float brightness = max(neighborColor.r, max(neighborColor.g, neighborColor.b));
                if (brightness > 0.8) {
                    accumulatedLight += neighborColor.rgb * 0.1; // 10% bounce
                }
            }
            samples++;
        }
    }
    
    // Blend GI
    float3 finalRGB = baseColor.rgb + accumulatedLight;
    output.write(float4(finalRGB, baseColor.a), gid);
}
