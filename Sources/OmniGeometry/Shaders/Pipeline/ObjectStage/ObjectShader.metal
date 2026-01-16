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
    constant MeshletData* meshlets [[buffer(0)]]
) {
    MeshletData data = meshlets[meshletID];
    
    // Eigenvalue Analysis
    float lambda1 = data.eigenvalues.x;
    float lambda2 = data.eigenvalues.y;
    float lambda3 = data.eigenvalues.z;
    
    // Calculate "Chaos" Metric
    float sum_lambda = lambda1 + lambda2 + lambda3;
    float chaos = (sum_lambda > 0) ? (lambda1 / sum_lambda) : 0.0;
    
    // Cluster Culling (Statistical Bounding Box)
    // Simplified: Check if "energy" is too low
    if (sum_lambda < 0.01) {
        // Discard cluster
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
