#include <metal_stdlib>
using namespace metal;

// Phase 7.2: Bounding Constraints
// Keeps particles inside a defined box.
kernel void apply_constraints(device float3 *positions [[buffer(0)]],
                              device float3 *prev_positions [[buffer(1)]],
                              constant float3 &boxMin [[buffer(2)]],
                              constant float3 &boxMax [[buffer(3)]],
                              uint id [[thread_position_in_grid]]) {
    
    float3 p = positions[id];
    float friction = 0.9; // Friction on impact
    
    // Simple box constraint
    for(int i = 0; i < 3; i++) {
        if (p[i] < boxMin[i]) {
            p[i] = boxMin[i];
            // Optional: Adjust prev_position to simulate bounce/friction
        } else if (p[i] > boxMax[i]) {
            p[i] = boxMax[i];
        }
    }
    
    positions[id] = p;
}
