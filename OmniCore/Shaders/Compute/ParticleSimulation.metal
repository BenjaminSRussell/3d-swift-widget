#include <metal_stdlib>
#include "../../Include/OmniShaderTypes.h"

using namespace metal;

kernel void updateParticles(
    device Particle *particles [[buffer(0)]],
    constant FrameUniforms &uniforms [[buffer(1)]],
    uint id [[thread_position_in_grid]]) {
    
    Particle p = particles[id];
    
    // Basic Verlet Integration
    p.position += p.velocity * uniforms.deltaTime;
    
    // Boundary check (simple wrap for now)
    if (length(p.position) > 100.0) {
        p.position = -p.position * 0.9;
    }
    
    particles[id] = p;
}
