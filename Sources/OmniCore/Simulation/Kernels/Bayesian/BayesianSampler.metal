#include <metal_stdlib>
using namespace metal;

// Hierarchical Bayesian Model: Metropolis-within-Gibbs Sampler
// Outputs: Mean (μ) and Variance (σ²) for each data cluster

struct BayesianState {
    float mean;
    float variance;
    float hyperprior_mean;
    float hyperprior_variance;
};

// Simple random number generator (LCG)
inline float random(thread uint& seed) {
    seed = seed * 1664525u + 1013904223u;
    return float(seed) / float(0xFFFFFFFFu);
}

// Log-likelihood for Gaussian
inline float log_likelihood(float x, float mean, float variance) {
    float diff = x - mean;
    return -0.5 * log(2.0 * M_PI_F * variance) - (diff * diff) / (2.0 * variance);
}

kernel void bayesian_sampler(
    device const float* data [[buffer(0)]],           // Observed data points
    device BayesianState* states [[buffer(1)]],       // Current state (μ, σ²)
    device float2* output_params [[buffer(2)]],       // Output: (mean, variance)
    constant uint& num_iterations [[buffer(3)]],
    uint gid [[thread_position_in_grid]]
) {
    // Each thread handles one data cluster
    BayesianState state = states[gid];
    uint seed = gid + 12345;
    
    float current_mean = state.mean;
    float current_variance = state.variance;
    
    // Metropolis-within-Gibbs iterations
    for (uint iter = 0; iter < num_iterations; iter++) {
        // Step 1: Sample new mean (Gibbs step)
        // Proposal: Gaussian centered at current mean
        float proposal_mean = current_mean + (random(seed) - 0.5) * 0.5;
        
        // Compute acceptance ratio
        float current_ll = log_likelihood(data[gid], current_mean, current_variance);
        float proposal_ll = log_likelihood(data[gid], proposal_mean, current_variance);
        
        // Prior: N(hyperprior_mean, hyperprior_variance)
        float current_prior = log_likelihood(current_mean, state.hyperprior_mean, state.hyperprior_variance);
        float proposal_prior = log_likelihood(proposal_mean, state.hyperprior_mean, state.hyperprior_variance);
        
        float log_ratio = (proposal_ll + proposal_prior) - (current_ll + current_prior);
        
        // Metropolis acceptance
        if (log(random(seed)) < log_ratio) {
            current_mean = proposal_mean;
        }
        
        // Step 2: Sample new variance (Gibbs step)
        float proposal_variance = current_variance * exp((random(seed) - 0.5) * 0.2);
        proposal_variance = max(0.01, proposal_variance); // Ensure positive
        
        current_ll = log_likelihood(data[gid], current_mean, current_variance);
        proposal_ll = log_likelihood(data[gid], current_mean, proposal_variance);
        
        log_ratio = proposal_ll - current_ll;
        
        if (log(random(seed)) < log_ratio) {
            current_variance = proposal_variance;
        }
    }
    
    // Update state
    states[gid].mean = current_mean;
    states[gid].variance = current_variance;
    
    // Output final parameters
    output_params[gid] = float2(current_mean, current_variance);
}

// Parallel reduction to compute cluster statistics
kernel void compute_cluster_stats(
    device const float* data [[buffer(0)]],
    device float2* cluster_stats [[buffer(1)]], // (mean, variance)
    uint gid [[thread_position_in_grid]],
    uint tid [[thread_position_in_threadgroup]],
    uint tg_size [[threads_per_threadgroup]]
) {
    threadgroup float shared_sum[256];
    threadgroup float shared_sq_sum[256];
    
    // Each thread accumulates its portion
    shared_sum[tid] = data[gid];
    shared_sq_sum[tid] = data[gid] * data[gid];
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // Parallel reduction
    for (uint stride = tg_size / 2; stride > 0; stride >>= 1) {
        if (tid < stride) {
            shared_sum[tid] += shared_sum[tid + stride];
            shared_sq_sum[tid] += shared_sq_sum[tid + stride];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    
    // Thread 0 writes result
    if (tid == 0) {
        float mean = shared_sum[0] / float(tg_size);
        float variance = (shared_sq_sum[0] / float(tg_size)) - (mean * mean);
        cluster_stats[0] = float2(mean, max(0.01, variance));
    }
}
