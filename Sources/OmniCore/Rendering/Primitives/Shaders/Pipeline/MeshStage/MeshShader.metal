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
    const object_data Payload& payload [[payload]],
    mesh<VertexOut, void, 128, 128, topology::triangle> output,
    uint tid [[thread_index_in_threadgroup]],
    uint lid [[thread_position_in_threadgroup]],
    constant float4x4 &viewProjection [[buffer(0)]],
    device const float3* stochasticPositions [[buffer(2)]],
    device const float* stochasticIntensities [[buffer(3)]]
) {
    // Get base position from stochastic channel
    float3 basePos = stochasticPositions[payload.meshletID];
    float intensity = stochasticIntensities[payload.meshletID];

    // Determine primitive count based on isolation metric
    uint vertexCount = 64; 
    uint primitiveCount = 32;
    
    if (payload.isolation_metric > 0.85) {
        vertexCount = 128; 
        primitiveCount = 64; 
    }
    
    if (lid == 0) {
        output.set_primitive_count(primitiveCount);
    }
    
    // Procedural Generation (f(u,v)) centered around basePos
    if (lid < vertexCount) {
        float u = float(lid) / float(vertexCount);

        
        // Parametric relative offset
        float dx = (u - 0.5) * 5.0;
        float dz = (float(lid % 8) / 8.0 - 0.5) * 5.0; // Simplified local grid
        
        float3 pos = basePos + float3(dx, sin(dx + basePos.x * 0.1) * intensity * 2.0, dz);
        
        VertexOut vOut;
        vOut.position = viewProjection * float4(pos, 1.0);
        
        // Approximate Normal
        vOut.normal = normalize(float3(0, 1.0, 0));
        
        // Color: Mix chaos and intensity
        // Intensity is used for heatmapping in fragment shader
        vOut.color = float3(intensity, payload.isolation_metric, 1.0 - intensity);
        
        output.set_vertex(lid, vOut);
    }
    
    // Topology
    if (lid < primitiveCount) {
        output.set_index(lid * 3 + 0, lid);
        output.set_index(lid * 3 + 1, (lid + 1) % vertexCount);
        output.set_index(lid * 3 + 2, (lid + 2) % vertexCount);
    }
}

