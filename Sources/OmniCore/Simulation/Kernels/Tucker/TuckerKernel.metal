#include <metal_stdlib>
using namespace metal;

// Tucker Decomposition: Reduce 10D data to 3D spatial coordinates
// Input: 10D feature vector per data point
// Output: 3D position (x,y,z) + 1D color intensity

struct TuckerFactors {
    // Core tensor: 3x3x3 (simplified for demo, real would be larger)
    float core[27]; // 3*3*3
    
    // Factor matrices: map 10 features → 3 latent dimensions
    float factor_x[10]; // Feature weights for X axis
    float factor_y[10]; // Feature weights for Y axis
    float factor_z[10]; // Feature weights for Z axis
};

kernel void tucker_decompose(
    device const float* input_vectors [[buffer(0)]], // 10D vectors (N x 10)
    device float3* output_positions [[buffer(1)]],   // 3D positions (N x 3)
    device float* output_intensity [[buffer(2)]],    // Color intensity (N x 1)
    constant TuckerFactors& factors [[buffer(3)]],
    uint gid [[thread_position_in_grid]]
) {
    // Read 10D input
    device const float* input = &input_vectors[gid * 10];
    
    // Project onto latent dimensions
    float x = 0.0, y = 0.0, z = 0.0;
    for (int i = 0; i < 10; i++) {
        x += input[i] * factors.factor_x[i];
        y += input[i] * factors.factor_y[i];
        z += input[i] * factors.factor_z[i];
    }
    
    // Apply core tensor transformation (simplified)
    // In full Tucker: result = core ×₁ factor_x ×₂ factor_y ×₃ factor_z
    // Here we use a weighted sum approximation
    float core_weight = factors.core[0]; // Simplified
    
    output_positions[gid] = float3(x, y, z) * core_weight;
    
    // Intensity: magnitude of the 10D vector
    float magnitude = 0.0;
    for (int i = 0; i < 10; i++) {
        magnitude += input[i] * input[i];
    }
    output_intensity[gid] = sqrt(magnitude);
}

// Update Tucker factors using gradient descent (simplified)
kernel void update_tucker_factors(
    device TuckerFactors& factors [[buffer(0)]],
    device const float* gradients [[buffer(1)]],
    constant float& learning_rate [[buffer(2)]],
    uint gid [[thread_position_in_grid]]
) {
    // Update factor matrices
    if (gid < 10) {
        factors.factor_x[gid] -= learning_rate * gradients[gid];
        factors.factor_y[gid] -= learning_rate * gradients[gid + 10];
        factors.factor_z[gid] -= learning_rate * gradients[gid + 20];
    }
}
