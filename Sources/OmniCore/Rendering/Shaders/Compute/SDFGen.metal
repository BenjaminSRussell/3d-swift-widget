#include <metal_stdlib>
using namespace metal;

// Phase 2.1: Jump Flood Algorithm for SDF Generation

struct JFASeed {
    float2 pos; // Coordinate of the nearest seed point
};

kernel void jfa_init(texture2d<float, access::read> input [[texture(0)]],
                     texture2d<float, access::write> output [[texture(1)]],
                     uint2 id [[thread_position_in_grid]]) {
    if (id.x >= input.get_width() || id.y >= input.get_height()) return;
    
    float val = input.read(id).r;
    // We seed pixels that are on the boundary.
    // For simplicity, we seed ALL white pixels for outside distance calculation 
    // and ALL black for inside? No, that's not JFA.
    
    // Standard JFA: Every "seed" pixel starts with its own coordinate.
    // Non-seed pixels start with an "infinity" sentinel.
    
    if (val > 0.5) {
        output.write(float4(float2(id), 0, 0), id);
    } else {
        output.write(float4(-10000.0, -10000.0, 0, 0), id);
    }
}

// JFA Step: Samples neighbors at 'step' distance and keeps the nearest coordinate
kernel void jfa_step(texture2d<float, access::read> input [[texture(0)]],
                     texture2d<float, access::write> output [[texture(1)]],
                     constant int &step [[buffer(0)]],
                     uint2 id [[thread_position_in_grid]]) {
    if (id.x >= output.get_width() || id.y >= output.get_height()) return;
    
    float2 bestCoord = input.read(id).xy;
    float bestDist = length(bestCoord - float2(id));
    
    for (int y = -1; y <= 1; ++y) {
        for (int x = -1; x <= 1; ++x) {
            if (x == 0 && y == 0) continue;
            
            int2 samplePos = int2(id) + int2(x, y) * step;
            if (samplePos.x < 0 || samplePos.y < 0 || 
                samplePos.x >= (int)input.get_width() || 
                samplePos.y >= (int)input.get_height()) continue;
            
            float2 coord = input.read(uint2(samplePos)).xy;
            if (coord.x < -5000.0) continue; // Sentinel
            
            float dist = length(coord - float2(id));
            if (dist < bestDist) {
                bestDist = dist;
                bestCoord = coord;
            }
        }
    }
    
    output.write(float4(bestCoord, 0, 0), id);
}

// Finalize: Calculate actual distance and store in R8 or similar
kernel void jfa_finalize(texture2d<float, access::read> seedTex [[texture(0)]],
                         texture2d<float, access::write> output [[texture(1)]],
                         uint2 id [[thread_position_in_grid]]) {
    if (id.x >= output.get_width() || id.y >= output.get_height()) return;
    
    float2 seed = seedTex.read(id).xy;
    float dist = length(seed - float2(id));
    
    // Normalize distance for R8 texture. 
    // Let's say max range is 64 pixels. 
    float normalizedDist = saturate(dist / 64.0);
    output.write(float4(normalizedDist, normalizedDist, normalizedDist, 1.0), id);
}
