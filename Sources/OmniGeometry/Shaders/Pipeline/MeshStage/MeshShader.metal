#include <metal_stdlib>
using namespace metal;

// Payload passed from Object Shader
struct Payload {
    uint meshletID;
    float isolation_metric; // "Chaos" metric
};

// Simplified vertex output
struct VertexOut {
    float4 position [[position]];
    float3 normal;
    float3 color;
};

// Mesh Shader: Generates geometry dynamically
[[mesh]]
void terrain_mesh(
    object_data Payload& payload [[payload]],
    mesh<VertexOut, void, 128, 128, topology::triangle> output,
    uint tid [[thread_index_in_threadgroup]],
    uint lid [[thread_position_in_threadgroup]],
    constant float4x4 &viewProjection [[buffer(0)]]
) {
    // Determine primitive count based on isolation metric
    uint vertexCount = 64; 
    uint primitiveCount = 32;
    
    // In a real implementation this would come from the payload's covariance analysis
    if (payload.isolation_metric > 0.85) {
        // High chaos -> double resolution (simulating 16x effect)
        vertexCount = 128; 
        primitiveCount = 64; 
    }
    
    if (lid == 0) {
        output.set_primitive_count(primitiveCount);
    }
    
    // Procedural Generation (f(u,v))
    if (lid < vertexCount) {
        float u = float(lid) / float(vertexCount);
        float v = float(payload.meshletID) / 100.0;
        
        // Parametric function
        float x = (u - 0.5) * 10.0;
        float z = (v - 0.5) * 10.0;
        float y = sin(x) * cos(z); // Placeholder for FBM
        
        VertexOut vOut;
        vOut.position = viewProjection * float4(x, y, z, 1.0);
        
        // Analytic Derivatives for Normals
        float3 dfdu = float3(1.0, cos(x)*cos(z), 0);
        float3 dfdv = float3(0, -sin(x)*sin(z), 1.0);
        vOut.normal = normalize(cross(dfdu, dfdv));
        
        // Color based on "Chaos"
        vOut.color = float3(payload.isolation_metric, 1.0 - payload.isolation_metric, 0.0);
        
        output.set_vertex(lid, vOut);
    }
    
    // Topology (Line Strip collapsed to triangles for demo)
    if (lid < primitiveCount) {
        output.set_index(lid * 3 + 0, lid);
        output.set_index(lid * 3 + 1, lid + 1);
        output.set_index(lid * 3 + 2, lid + 2);
    }
}
