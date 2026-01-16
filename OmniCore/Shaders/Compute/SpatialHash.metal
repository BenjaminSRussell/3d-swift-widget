#include <metal_stdlib>
#include "../Shared/OmniMath.metal"

using namespace metal;

struct GridParams {
    float3 gridMin;
    float  cellSize;
    uint3  gridRes;
};

// Phase 4.2: Spatial Hashing Kernel
// Maps each particle to a cell index.
kernel void hash_particles(device const float3 *positions [[buffer(0)]],
                           device uint *particleCellIndices [[buffer(1)]],
                           device uint *particleIndices [[buffer(2)]],
                           constant GridParams &params [[buffer(3)]],
                           uint id [[thread_position_in_grid]]) {
    
    float3 p = positions[id];
    
    // Calculate 3D grid coordinate
    float3 relP = (p - params.gridMin) / params.cellSize;
    int3 gridPos = int3(floor(relP));
    
    // Clamp to grid boundaries
    gridPos = clamp(gridPos, int3(0), int3(params.gridRes) - 1);
    
    // 1D Hash index (Morton order or simple linear scan)
    uint hashIndex = (uint)gridPos.z * params.gridRes.x * params.gridRes.y + 
                     (uint)gridPos.y * params.gridRes.x + 
                     (uint)gridPos.x;
    
    particleCellIndices[id] = hashIndex;
    particleIndices[id] = id; // Store original index for sorting
}

// Phase 4.4: Find Cell Starts
// After sorting particles by cell index, identify where each cell begins in the sorted buffer.
kernel void clear_cell_starts(device uint *cellStarts [[buffer(0)]],
                              uint id [[thread_position_in_grid]]) {
    cellStarts[id] = 0xFFFFFFFF; // Mark empty
}

kernel void find_cell_starts(device const uint *sortedCellIndices [[buffer(0)]],
                             device uint *cellStarts [[buffer(1)]],
                             uint id [[thread_position_in_grid]]) {
    uint cellIndex = sortedCellIndices[id];
    
    // Check if this is the first particle in a new cell
    if (id == 0 || cellIndex != sortedCellIndices[id - 1]) {
        cellStarts[cellIndex] = id;
    }
}
