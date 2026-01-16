#include <metal_stdlib>
#include "../../Include/OmniShaderTypes.h"

using namespace metal;

// Phase 8.1: Distance Constraints
// Adjusts particle positions to maintain a target rest length.
kernel void apply_distance_constraints(device float3 *positions [[buffer(0)]],
                                       device const SpringConstraint *constraints [[buffer(1)]],
                                       uint id [[thread_position_in_grid]]) {
    
    SpringConstraint c = constraints[id];
    
    float3 p1 = positions[c.p1];
    float3 p2 = positions[c.p2];
    
    float3 delta = p2 - p1;
    float currentLength = length(delta);
    
    // Avoid division by zero
    if (currentLength < 1e-6) return;
    
    float diff = (currentLength - c.restLength) / currentLength;
    
    // Shift both particles by half the difference
    // Note: This simple version doesn't account for mass (assume equal mass)
    // and doesn't use atomics (potential race conditions if many constraints share particles).
    // In a high-fidelity engine, we use atomics or specific coloring of constraints.
    float3 shift = delta * 0.5 * diff * c.stiffness;
    
    positions[c.p1] += shift;
    positions[c.p2] -= shift;
}
