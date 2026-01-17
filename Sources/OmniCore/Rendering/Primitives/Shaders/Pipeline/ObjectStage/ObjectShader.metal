#include <metal_stdlib>
using namespace metal;

struct Payload {
    uint meshletID;
    float isolation_metric;
};

struct MeshletData {
    float3 center;
    float3 eigenvalues; // lambda_1, lambda_2, lambda_3
};

// Object Shader: Decides LOD and Visibility
[[object]]
void terrain_object(
    object_data Payload& payload [[payload]],
    mesh_grid_properties properties,
    uint tid [[thread_position_in_threadgroup]],
    uint meshletID [[thread_position_in_grid]],
    device const float3* stochasticPositions [[buffer(2)]],
    device const float* stochasticIntensities [[buffer(3)]]
) {
    // Read stochastic data

    float intensity = stochasticIntensities[meshletID];
    
    // Simplified Chaos/Metric for stochastic engine
    float chaos = (intensity > 0.8) ? 1.0 : 0.0;
    
    // Cluster Culling: Discard if intensity is near zero (quiescent)
    if (intensity < 0.001) {
        if (tid == 0) {
            properties.set_threadgroups_per_grid(uint3(0, 0, 0));
        }
        return;
    }
    
    // Pass to Mesh Shader
    if (tid == 0) {
        payload.meshletID = meshletID;
        payload.isolation_metric = chaos;
        
        // Dispatch Mesh Shader threadgroup
        properties.set_threadgroups_per_grid(uint3(1, 1, 1));
    }
}

