#include <metal_stdlib>
#include "../../Include/OmniShaderTypes.h"
#include "../../Shared/OmniMath.metal"

using namespace metal;

struct FluidParams {
    uint2 gridRes;
    float cellSize;
    float dt;
    float gravity;
};

// Phase 9.3: Fluid-Particle Interaction
// Particles are pushed by fluid velocity and can add height to the fluid (ripples).
kernel void particle_to_fluid(device float *heights [[buffer(0)]],
                              device const float3 *particlePositions [[buffer(1)]],
                              constant FluidParams &params [[buffer(2)]],
                              uint id [[thread_position_in_grid]]) {
    
    float3 p = particlePositions[id];
    
    // Map particle pos to fluid grid
    float2 gridP = p.xz / params.cellSize;
    int2 cell = int2(floor(gridP));
    
    if (cell.x < 0 || cell.x >= (int)params.gridRes.x || cell.y < 0 || cell.y >= (int)params.gridRes.y) return;
    
    uint idx = cell.y * params.gridRes.x + cell.x;
    
    // Add height based on vertical penetration (simplified)
    if (p.y < 0) {
        atomic_add_float((device atomic_uint*)&heights[idx], -p.y * 0.1f);
    }
}
