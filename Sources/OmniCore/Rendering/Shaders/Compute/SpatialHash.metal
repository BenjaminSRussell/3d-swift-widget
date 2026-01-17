#include <metal_stdlib>
using namespace metal;

// Spatial Hash for O(1) neighbor search
// Using a simple grid approach

constant uint HASH_TABLE_SIZE = 1000003; // Prime number
constant float CELL_SIZE = 2.0;

// Hash function: (x * p1 ^ y * p2 ^ z * p3) % size
uint hash3D(int3 p) {
    int3 p1 = int3(73856093, 19349663, 83492791);
    int n = p.x * p1.x ^ p.y * p1.y ^ p.z * p1.z;
    return uint(n) % HASH_TABLE_SIZE;
}

// Kernel to populate the spatial grid
kernel void buildSpatialHash(
    device float3 *positions [[buffer(0)]],
    device uint *cellIDs [[buffer(1)]],      // Keys
    device uint *particleIDs [[buffer(2)]],  // Values
    constant uint &count [[buffer(3)]],
    uint id [[thread_position_in_grid]]) {
    
    if (id >= count) return;
    
    float3 pos = positions[id];
    
    // Discretize position
    int3 cell = int3(floor(pos / CELL_SIZE));
    
    // Hash
    uint cellID = hash3D(cell);
    
    // Store pair
    cellIDs[id] = cellID;
    particleIDs[id] = id;
}

// NOTE: Sorting of particleGridIndices by cellID must happen next (using bitonic sort)
// Then we find start/end indices for each cell.
