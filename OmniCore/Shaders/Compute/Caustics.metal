#include <metal_stdlib>
#include "../../Include/OmniShaderTypes.h"

using namespace metal;

// Phase 13.1: Caustics Projection Kernel
// Each thread processes a fluid cell and "shoots" a light ray (photon).
// The ray is refracted by the surface normal and hits the topography floor.

struct CausticsParams {
    uint2 gridRes;
    float cellSize;
    float waterLevel;
    float lightIntensity;
    float3 lightDir;
};

// Helper to accumulate intensity into a texture using atomic fixed-point additions.
// This ensures multiple photons hitting the same pixel are summed correctly.
void accumulate_caustic(device atomic_uint *causticsMap, float2 uv, uint2 res, float intensity) {
    uint2 pixel = uint2(uv * float2(res));
    if (pixel.x >= res.x || pixel.y >= res.y) return;
    
    uint idx = pixel.y * res.x + pixel.x;
    // Scale intensity to fixed-point for atomic addition
    atomic_fetch_add_explicit(&causticsMap[idx], (uint)(intensity * 1000.0f), memory_order_relaxed);
}

kernel void project_caustics(device const float *heights [[buffer(0)]],
                             device atomic_uint *causticsMap [[buffer(1)]],
                             constant CausticsParams &params [[buffer(2)]],
                             uint2 id [[thread_position_in_grid]]) {
    
    if (id.x >= params.gridRes.x || id.y >= params.gridRes.y) return;
    
    // 1. Calculate surface normal at this fluid cell
    uint idx = id.y * params.gridRes.x + id.x;
    float h = heights[idx];
    
    // Finite difference normal
    uint left  = (id.x > 0) ? idx - 1 : idx;
    uint right = (id.x < params.gridRes.x - 1) ? idx + 1 : idx;
    uint down  = (id.y > 0) ? idx - params.gridRes.x : idx;
    uint up    = (id.y < params.gridRes.y - 1) ? idx + params.gridRes.x : idx;
    
    float3 normal = normalize(float3(
        heights[left] - heights[right],
        2.0f * params.cellSize,
        heights[down] - heights[up]
    ));
    
    // 2. Refract light ray based on surface normal
    float3 I = normalize(-params.lightDir);
    float3 R = refract(I, normal, 1.0f / 1.33f); // Air to water
    
    if (length(R) < 0.1f) return; // Total internal reflection or error
    
    // 3. Project ray onto the floor (assume floor is at y = 0 for now)
    // Ray start: (id.x * cellSize, waterLevel + h, id.y * cellSize)
    float3 rayStart = float3(id.x * params.cellSize, params.waterLevel + h, id.y * params.cellSize);
    
    // Intersection with plane y = 0
    float t = -rayStart.y / R.y;
    if (t < 0) return;
    
    float3 floorPos = rayStart + R * t;
    
    // 4. Accumulate intensity
    // map floor position back to UV
    float2 uv = floorPos.xz / (float2(params.gridRes) * params.cellSize);
    accumulate_caustic(causticsMap, uv, params.gridRes, params.lightIntensity);
}
