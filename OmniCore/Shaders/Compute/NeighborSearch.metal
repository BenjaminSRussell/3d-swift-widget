#include <metal_stdlib>
#include "../Shared/OmniMath.metal"

using namespace metal;

struct GridParams {
    float3 gridMin;
    float  cellSize;
    uint3  gridRes;
};

// Phase 4.5: Neighbor Search
// Demonstrates how to query the spatial grid for nearby particles.
kernel void neighbor_search(device const float3 *positions [[buffer(0)]],
                            device const uint *sortedParticleIndices [[buffer(1)]],
                            device const uint *cellStarts [[buffer(2)]],
                            constant GridParams &params [[buffer(3)]],
                            device float *interactionResult [[buffer(4)]],
                            uint id [[thread_position_in_grid]]) {
    
    float3 p = positions[id];
    float3 relP = (p - params.gridMin) / params.cellSize;
    int3 gridPos = int3(floor(relP));
    
    float searchRadius = params.cellSize;
    float interactionCount = 0;
    
    // Search 3x3x3 neighborhood
    for (int z = -1; z <= 1; z++) {
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                int3 neighborCellPos = gridPos + int3(x, y, z);
                
                // Boundary check
                if (any(neighborCellPos < 0) || any(neighborCellPos >= int3(params.gridRes))) continue;
                
                uint cellIndex = (uint)neighborCellPos.z * params.gridRes.x * params.gridRes.y + 
                                 (uint)neighborCellPos.y * params.gridRes.x + 
                                 (uint)neighborCellPos.x;
                
                uint startIdx = cellStarts[cellIndex];
                if (startIdx == 0xFFFFFFFF) continue;
                
                // Iterate particles in this cell
                // We don't have a "CellEnd" but we can check consecutive cells or use a specific end buffer.
                // For simplicity, we assume we can scan forward until the cell index changes.
                // In a production engine, a 'cellStartsAndCounts' or 'cellEnd' buffer is safer.
                for (uint i = startIdx; i < 1024 * 1024; i++) { // Max guard
                    // Check if we exited the cell (actual logic needs the sortedCellIndices to be robust)
                    // But for this Protocol Phase, we demonstrate the search flow.
                    interactionCount += 1.0; 
                    break; // Just counting cells for the demo
                }
            }
        }
    }
    
    interactionResult[id] = interactionCount;
}
