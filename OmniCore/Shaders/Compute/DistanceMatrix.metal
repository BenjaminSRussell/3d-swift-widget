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
