#include <metal_stdlib>
using namespace metal;

struct Particle {
    float3 position;
    float3 momentum;
};

// Log Probability Gradient (Dual Number Automatic Differentiation placeholder)
inline float3 gradient_log_prob(float3 pos) {
    // Placeholder Gaussian: -0.5 * (x^2 + y^2 + z^2)
    // Derivative: -x, -y, -z
    return -pos; 
}

// Leapfrog Integrator (Symplectic)
inline Particle leapfrog_step(Particle p, float epsilon) {
    Particle next = p;
    float3 half_v = p.momentum + 0.5 * epsilon * gradient_log_prob(p.position);
    next.position = p.position + epsilon * half_v;
    next.momentum = half_v + 0.5 * epsilon * gradient_log_prob(next.position);
    return next;
}

// Hamiltonian Monte Carlo Kernel
kernel void nuts_sampler(
    device Particle* particles [[buffer(0)]],
    device float3* samples [[buffer(1)]],     // Output samples
    device atomic_uint* divergence_count [[buffer(2)]],
    texture2d<float, access::write> spectrogram [[texture(0)]],
    uint tid [[thread_position_in_grid]]
) {
    Particle p = particles[tid];
    
    // Resample momentum (Gibbs step)
    // Needs random source, using simple hash for demo
    uint seed = tid + 12345;
    // ... random generation skipped for brevity ...
    
    // Perform NUTS steps (simplified to static HMC for this snippet)
    // "Manifold" Compute Shader
    float epsilon = 0.01;
    Particle start_p = p;
    
    // 10 Leapfrog steps
    for (int i=0; i<10; i++) {
        p = leapfrog_step(p, epsilon);
    }
    
    // Hamiltonian Check
    float H_start = 0.5 * dot(start_p.momentum, start_p.momentum) + 0.5 * dot(start_p.position, start_p.position);
    float H_end = 0.5 * dot(p.momentum, p.momentum) + 0.5 * dot(p.position, p.position);
    
    float delta_H = abs(H_end - H_start);
    
    // Divergence Detection
    if (delta_H > 1000.0) {
        atomic_fetch_add_explicit(divergence_count, 1, memory_order_relaxed);
    }
    
    // Metropolis Correction (Simplified acceptance)
    particles[tid] = p; // Accept
    samples[tid] = p.position;
    
    // Write to Spectrogram (Density Mapping)
    // Map position range [-5, 5] (approx) to [0, 1] UV space
    // In a real implementation this would use atomics or scatter writes for true density
    float2 uv = (p.position.xz / 10.0) + 0.5;
    if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
        uint2 coords = uint2(uv * float2(spectrogram.get_width(), spectrogram.get_height()));
        
        // R: Density (1.0), G: Uncertainty (delta_H normalized), B: 0, A: 1
        float uncertainty = clamp(delta_H / 100.0, 0.0, 1.0); 
        spectrogram.write(float4(1.0, uncertainty, 0.0, 1.0), coords); 
    }
}
