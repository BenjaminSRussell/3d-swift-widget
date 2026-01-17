#include <metal_stdlib>
#include "../Include/OmniShaderTypes.h"
#include "../Shared/OmniMath.metal"

using namespace metal;

// Phase 7.1: Verlet Integration
// p' = p + (p - p_prev) + a * dt^2
kernel void integrate_verlet(device float3 *positions [[buffer(0)]],
                             device float3 *prev_positions [[buffer(1)]],
                             device float3 *velocities [[buffer(2)]],
                             constant FrameUniforms &frame [[buffer(3)]],
                             uint id [[thread_position_in_grid]]) {
    
    float3 p = positions[id];
    float3 p_prev = prev_positions[id];
    float dt = frame.deltaTime;
    
    // Physics constants (ideally from SimulationState/GlobalState)
    float3 gravity = float3(0, -9.81, 0);
    float damping = 0.98; // Air resistance / energy loss
    
    // Verlet derivative: velocity is implicit in (p - p_prev)
    float3 v = (p - p_prev) * damping;
    float3 acceleration = gravity;
    
    float3 p_next = p + v + acceleration * (dt * dt);
    
    // Update buffers
    prev_positions[id] = p;
    positions[id] = p_next;
    
    // Explicit velocity for external systems (e.g. rendering motion blur)
    velocities[id] = v / dt;
}
