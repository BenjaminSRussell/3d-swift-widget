#include <metal_stdlib>
using namespace metal;

kernel void computeDistanceMatrix(
    device float3 *points [[buffer(0)]],
    device float *distanceMatrix [[buffer(1)]],
    constant uint &count [[buffer(2)]],
    uint2 id [[thread_position_in_grid]]) {
    
    if (id.x < count && id.y < count) {
        float d = distance(points[id.x], points[id.y]);
        distanceMatrix[id.y * count + id.x] = d;
    }
}

struct Edge {
    int2 indices;
};

struct DistanceParams {
    uint count;
    float epsilon;
};

kernel void extractEdges(
    device float *distanceMatrix [[buffer(0)]],
    device Edge *edges [[buffer(1)]],
    device atomic_uint *edgeCount [[buffer(2)]],
    constant DistanceParams &params [[buffer(3)]],
    uint2 id [[thread_position_in_grid]]) {
    
    // Only process upper triangle to avoid duplicates and self-loops
    if (id.x < params.count && id.y < id.x) {
        float dist = distanceMatrix[id.y * params.count + id.x];
        
        if (dist <= params.epsilon) {
            uint index = atomic_fetch_add_explicit(edgeCount, 1, memory_order_relaxed);
            edges[index].indices = int2(id.x, id.y);
        }
    }
}
