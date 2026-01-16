#include <metal_stdlib>
using namespace metal;

// Topological Bridge Generation: Connect correlated data clusters
// Implements "Interfaces that Teach" - visual encoding of statistical relationships

struct ClusterData {
    float3 position;      // 3D location in terrain
    float mean;           // Statistical mean (μ)
    float variance;       // Statistical variance (σ²)
    float eigenvalue;     // Dominant eigenvalue (data "energy")
};

struct BridgeVertex {
    float4 position [[position]];
    float3 normal;
    float3 color;
    float integrity;      // 0.0 = fractured, 1.0 = solid
};

// Compute correlation between two clusters
inline float computeCorrelation(ClusterData a, ClusterData b) {
    // Simplified Pearson correlation based on spatial proximity and value similarity
    float spatial_dist = distance(a.position, b.position);
    float value_diff = abs(a.mean - b.mean);
    
    // Inverse distance weighted by value similarity
    float correlation = exp(-spatial_dist * 0.1) * exp(-value_diff * 0.5);
    
    return correlation;
}

// Generate bridge geometry using Catmull-Rom spline
inline float3 catmullRomSpline(float3 p0, float3 p1, float3 p2, float3 p3, float t) {
    float t2 = t * t;
    float t3 = t2 * t;
    
    return 0.5 * (
        (2.0 * p1) +
        (-p0 + p2) * t +
        (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
        (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
    );
}

// Fracture noise: breaks weak bridges
inline float fractureNoise(float3 p, float integrity) {
    // Perlin-like noise
    float n = fract(sin(dot(p, float3(12.9898, 78.233, 45.164))) * 43758.5453);
    
    // Low integrity = high noise = visible fractures
    return (integrity > 0.7) ? 0.0 : (1.0 - integrity) * n;
}

// Mesh Shader: Generate bridge geometry between correlated clusters
[[mesh]]
void topological_bridge_mesh(
    uint meshletID [[threadgroup_position_in_grid]],
    uint tid [[thread_index_in_threadgroup]],
    uint lid [[thread_position_in_threadgroup]],
    constant ClusterData* clusters [[buffer(0)]],
    constant float* correlation_matrix [[buffer(1)]], // NxN matrix
    constant uint& num_clusters [[buffer(2)]],
    constant float4x4& viewProjection [[buffer(3)]],
    mesh<BridgeVertex, void, 128, 64, topology::triangle> output
) {
    // Each meshlet handles one potential bridge
    uint i = meshletID / num_clusters;
    uint j = meshletID % num_clusters;
    
    if (i >= j) return; // Avoid duplicates and self-connections
    
    ClusterData clusterA = clusters[i];
    ClusterData clusterB = clusters[j];
    
    // Check correlation threshold
    float correlation = correlation_matrix[i * num_clusters + j];
    const float threshold = 0.7;
    
    if (correlation < threshold) {
        // No bridge - cull this meshlet
        if (lid == 0) {
            output.set_primitive_count(0);
        }
        return;
    }
    
    // Bridge parameters
    float integrity = (correlation - threshold) / (1.0 - threshold); // [0, 1]
    float thickness = 0.1 + integrity * 0.3; // Thicker = stronger correlation
    
    // Generate bridge curve (16 segments)
    const uint segments = 16;
    const uint verticesPerSegment = 4; // Quad cross-section
    const uint totalVertices = segments * verticesPerSegment;
    
    if (lid == 0) {
        output.set_primitive_count((segments - 1) * 2); // Triangle strip
    }
    
    if (lid < totalVertices) {
        uint segment = lid / verticesPerSegment;
        uint corner = lid % verticesPerSegment;
        
        float t = float(segment) / float(segments - 1);
        
        // Control points for spline (add slight arc)
        float3 p0 = clusterA.position;
        float3 p3 = clusterB.position;
        float3 mid = (p0 + p3) * 0.5;
        mid.y += 2.0; // Arc upward
        float3 p1 = mix(p0, mid, 0.33);
        float3 p2 = mix(mid, p3, 0.67);
        
        // Spline position
        float3 center = catmullRomSpline(p0, p1, p2, p3, t);
        
        // Fracture effect: displace vertices randomly for weak bridges
        float fracture = fractureNoise(center, integrity);
        
        // Cross-section (square)
        float angle = float(corner) * M_PI_F * 0.5;
        float3 offset = float3(cos(angle), 0, sin(angle)) * thickness;
        offset += fracture * float3(0, 0.5, 0); // Vertical displacement for fractures
        
        float3 worldPos = center + offset;
        
        BridgeVertex vertex;
        vertex.position = viewProjection * float4(worldPos, 1.0);
        vertex.normal = normalize(offset);
        
        // Color encoding: correlation strength
        // Green = strong (high correlation), Yellow = moderate, Red = weak
        float3 strongColor = float3(0.2, 0.8, 0.3);
        float3 weakColor = float3(0.8, 0.3, 0.2);
        vertex.color = mix(weakColor, strongColor, integrity);
        
        vertex.integrity = integrity;
        
        output.set_vertex(lid, vertex);
    }
    
    // Indices for triangle strip
    if (lid < (segments - 1) * 8) {
        uint seg = lid / 8;
        uint idx = lid % 8;
        
        // Two triangles per quad
        uint base = seg * verticesPerSegment;
        if (idx < 4) {
            // First triangle
            uint indices[3] = {base, base + 1, base + verticesPerSegment};
            output.set_index(lid, indices[idx % 3]);
        } else {
            // Second triangle
            uint indices[3] = {base + 1, base + verticesPerSegment + 1, base + verticesPerSegment};
            output.set_index(lid, indices[idx % 3]);
        }
    }
}

// Fragment Shader: Render bridge with transparency based on integrity
fragment float4 topological_bridge_fragment(
    BridgeVertex in [[stage_in]]
) {
    // Fractured bridges are more transparent
    float alpha = 0.3 + in.integrity * 0.7;
    
    // Simple lighting
    float3 lightDir = normalize(float3(1, 1, 1));
    float ndotl = max(0.0, dot(in.normal, lightDir));
    float3 color = in.color * (0.3 + 0.7 * ndotl);
    
    // Pulse effect for weak bridges (visual "instability")
    if (in.integrity < 0.8) {
        float pulse = 0.5 + 0.5 * sin(in.position.x * 10.0);
        alpha *= pulse;
    }
    
    return float4(color, alpha);
}

// Compute Kernel: Calculate correlation matrix from cluster data
kernel void compute_correlation_matrix(
    device const ClusterData* clusters [[buffer(0)]],
    device float* correlation_matrix [[buffer(1)]],
    constant uint& num_clusters [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint i = gid.x;
    uint j = gid.y;
    
    if (i >= num_clusters || j >= num_clusters) return;
    
    if (i == j) {
        correlation_matrix[i * num_clusters + j] = 1.0; // Self-correlation
        return;
    }
    
    // Compute correlation
    float corr = computeCorrelation(clusters[i], clusters[j]);
    correlation_matrix[i * num_clusters + j] = corr;
}
