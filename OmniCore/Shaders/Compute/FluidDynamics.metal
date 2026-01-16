#include <metal_stdlib>
#include "../../Include/OmniShaderTypes.h"

using namespace metal;

// Phase 9.2: Virtual Pipe Fluid Dynamics
// Updates flux based on height differences between adjacent cells.

struct FluidParams {
    uint2 gridRes;
    float cellSize;
    float dt;
    float gravity;
};

kernel void update_fluid_flux(device float *heights [[buffer(0)]],
                              device float4 *flux [[buffer(1)]],
                              constant FluidParams &params [[buffer(2)]],
                              uint2 id [[thread_position_in_grid]]) {
    
    if (id.x >= params.gridRes.x || id.y >= params.gridRes.y) return;
    
    uint idx = id.y * params.gridRes.x + id.x;
    float h = heights[idx];
    
    float4 f = flux[idx];
    
    // Neighbor indices
    uint left  = (id.x > 0) ? idx - 1 : idx;
    uint right = (id.x < params.gridRes.x - 1) ? idx + 1 : idx;
    uint down  = (id.y > 0) ? idx - params.gridRes.x : idx;
    uint up    = (id.y < params.gridRes.y - 1) ? idx + params.gridRes.x : idx;
    
    // Calculate flux changes based on pressure (height) difference
    float4 neighborHeights = float4(heights[left], heights[right], heights[down], heights[up]);
    float4 diff = h - neighborHeights;
    
    float K = params.dt * params.gravity / params.cellSize;
    f = max(0.0f, f + K * diff);
    
    // Boundary conditions
    if (id.x == 0) f.x = 0;
    if (id.x == params.gridRes.x - 1) f.y = 0;
    if (id.y == 0) f.z = 0;
    if (id.y == params.gridRes.y - 1) f.w = 0;
    
    flux[idx] = f;
}

kernel void update_fluid_height(device float *heights [[buffer(0)]],
                                device const float4 *flux [[buffer(1)]],
                                constant FluidParams &params [[buffer(2)]],
                                uint2 id [[thread_position_in_grid]]) {
    
    if (id.x >= params.gridRes.x || id.y >= params.gridRes.y) return;
    
    uint idx = id.y * params.gridRes.x + id.x;
    
    // Net flow = Inflow - Outflow
    float outflow = flux[idx].x + flux[idx].y + flux[idx].z + flux[idx].w;
    
    uint left  = (id.x > 0) ? idx - 1 : idx;
    uint right = (id.x < params.gridRes.x - 1) ? idx + 1 : idx;
    uint down  = (id.y > 0) ? idx - params.gridRes.x : idx;
    uint up    = (id.y < params.gridRes.y - 1) ? idx + params.gridRes.x : idx;
    
    float inflow = flux[left].y + flux[right].x + flux[down].w + flux[up].z;
    
    float h = heights[idx] + (inflow - outflow) * params.dt / (params.cellSize * params.cellSize);
    heights[idx] = max(0.0f, h);
}
