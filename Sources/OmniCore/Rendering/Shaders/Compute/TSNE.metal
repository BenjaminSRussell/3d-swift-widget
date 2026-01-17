#include <metal_stdlib>
using namespace metal;

// Real-time t-SNE Optimization Kernel
// Based on minimizing KL divergence via gradient descent on the embedding.

// Constants
constant float LEARNING_RATE = 200.0;
constant float MOMENTUM = 0.5;

kernel void tsneOptimization(
    device float3 *embedding [[buffer(0)]],        // Current 3D positions (Y)
    device float3 *velocities [[buffer(1)]],       // Momentum/Velocity
    device float *attractionMatrix [[buffer(2)]],  // P matrix (High-dim probs)
    device float *repulsionMatrix [[buffer(3)]],   // Q matrix (Low-dim probs) - optional/implicit
    constant uint &count [[buffer(4)]],
    uint id [[thread_position_in_grid]]) {
    
    if (id >= count) return;
    
    float3 currentPos = embedding[id];
    float3 forces = float3(0.0);
    
    // 1. Attraction Forces (P_ij * Q_ij typically, but simplified for real-time)
    // We iterate over all other points (Naive O(N^2)) -- requires optimization for large N (Barnes-Hut)
    // For < 4096 points, naive is fine on GPU.
    
    for (uint j = 0; j < count; j++) {
        if (id == j) continue;
        
        float3 otherPos = embedding[j];
        float3 diff = currentPos - otherPos;
        float distSq = dot(diff, diff);
        float q_ij = 1.0 / (1.0 + distSq); // Student t-distribution degree 1
        
        // Attraction from P matrix
        float p_ij = attractionMatrix[id * count + j]; // Precomputed P
        
        // Gradient component: 4 * (p_ij - q_ij) * q_ij * (y_i - y_j)
        // Note: Q is usually normalized sum(q), simplified here for demonstration
        
        float stiffness = 4.0 * (p_ij - q_ij) * q_ij;
        forces += stiffness * diff; // Application of force
    }
    
    // 2. Update with Momentum
    float3 currentVel = velocities[id];
    float3 newVel = currentVel * MOMENTUM - (forces * LEARNING_RATE);
    
    velocities[id] = newVel;
    embedding[id] += newVel;
}
