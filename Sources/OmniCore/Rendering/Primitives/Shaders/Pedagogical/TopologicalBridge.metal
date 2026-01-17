#include <metal_stdlib>
using namespace metal;

struct ClusterData {
    float3 position;
    float mean;
    float variance;
    float eigenvalue;
};

struct BridgeVertexOut {
    float4 position [[position]];
    float3 normal;
    float3 color;
    float integrity;
};

inline float computeCorrelation(ClusterData a, ClusterData b) {
    float spatial_dist = distance(a.position, b.position);
    float value_diff = abs(a.mean - b.mean);
    return exp(-spatial_dist * 0.1) * exp(-value_diff * 0.5);
}

inline float3 catmullRomSpline(float3 p0, float3 p1, float3 p2, float3 p3, float t) {
    float t2 = t * t;
    float t3 = t2 * t;
    return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3);
}

inline float fractureNoise(float3 p, float integrity) {
    float n = fract(sin(dot(p, float3(12.9898, 78.233, 45.164))) * 43758.5453);
    return (integrity > 0.7) ? 0.0 : (1.0 - integrity) * n;
}

[[mesh]]
void topological_bridge_mesh(
    uint meshletID [[threadgroup_position_in_grid]],
    uint tid [[thread_index_in_threadgroup]],
    uint lid [[thread_position_in_threadgroup]],
    constant ClusterData* clusters [[buffer(0)]],
    constant float* correlation_matrix [[buffer(1)]],
    constant uint& num_clusters [[buffer(2)]],
    constant float4x4& viewProjection [[buffer(3)]],
    mesh<BridgeVertexOut, void, 128, 64, topology::triangle> output
) {
    uint i = meshletID / num_clusters;
    uint j = meshletID % num_clusters;
    if (i >= j || i >= num_clusters || j >= num_clusters) return;
    
    float correlation = correlation_matrix[i * num_clusters + j];
    if (correlation < 0.7) {
        if (lid == 0) output.set_primitive_count(0);
        return;
    }
    
    float integrity = (correlation - 0.7) / 0.3;
    float thickness = 0.1 + integrity * 0.3;


    const uint totalVertices = 64;
    
    if (lid == 0) output.set_primitive_count(30); // (16-1)*2

    if (lid < totalVertices) {
        float t = float(lid / 4) / 15.0;
        float3 p0 = clusters[i].position;
        float3 p3 = clusters[j].position;
        float3 mid = (p0 + p3) * 0.5 + float3(0, 2, 0);
        float3 p1 = mix(p0, mid, 0.33);
        float3 p2 = mix(mid, p3, 0.67);
        float3 center = catmullRomSpline(p0, p1, p2, p3, t);
        float angle = float(lid % 4) * M_PI_F * 0.5;
        float3 offset = float3(cos(angle), 0, sin(angle)) * thickness;
        float3 worldPos = center + offset + fractureNoise(center, integrity) * float3(0,0.5,0);
        
        BridgeVertexOut v;
        v.position = viewProjection * float4(worldPos, 1.0);
        v.normal = normalize(offset);
        v.color = mix(float3(0.8,0.3,0.2), float3(0.2,0.8,0.3), integrity);
        v.integrity = integrity;
        output.set_vertex(lid, v);
    }

    if (lid < 30) {
        uint base = (lid / 2) * 4;
        if (lid % 2 == 0) {
            output.set_index(lid * 3 + 0, base);
            output.set_index(lid * 3 + 1, base + 1);
            output.set_index(lid * 3 + 2, base + 4);
        } else {
            output.set_index(lid * 3 + 0, base + 1);
            output.set_index(lid * 3 + 1, base + 5);
            output.set_index(lid * 3 + 2, base + 4);
        }
    }
}

fragment float4 topological_bridge_fragment(BridgeVertexOut in [[stage_in]]) {
    float alpha = 0.3 + in.integrity * 0.7;
    float3 color = in.color * (0.3 + 0.7 * max(0.0, dot(in.normal, float3(1,1,1))));
    if (in.integrity < 0.8) alpha *= (0.5 + 0.5 * sin(in.position.x * 10.0));
    return float4(color, alpha);
}
