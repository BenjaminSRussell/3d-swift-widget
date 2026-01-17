#include <metal_stdlib>
#include "../../Include/OmniShaderTypes.h"

using namespace metal;

// Phase 16.2: Label Constraint Solver
// Adjusts label positions to avoid terrain occlusion and overlaps.

// Advanced Billboard Solver
// Projects 3D anchors to screen space, handles repulsion, and depth occlusion.

struct LabelData {
    float3 worldAnchor;    // The 3D point the label "belongs" to
    float3 currentPos;     // Current 3D position (can be pushed away)
    float2 screenSize;     // Visual size in pixels
    float2 screenOffset;   // Resulting 2D offset for rendering
    float active;          // 0 or 1
    float occluded;        // Output: 0 if visible, 1 if hidden
};

kernel void resolve_label_collisions(device LabelData* labels [[buffer(0)]],
                                     texture2d<float, access::read> depthMap [[texture(0)]], 
                                     constant FrameUniforms &frame [[buffer(1)]],
                                     uint id [[thread_position_in_grid]]) {
    
    if (labels[id].active < 0.5) return;
    
    float4x4 mvp = frame.viewProjectionMatrix;
    
    // 1. Project World Anchor to Screen Space
    float4 clipPos = mvp * float4(labels[id].worldAnchor, 1.0);
    float3 ndc = clipPos.xyz / clipPos.w;
    float2 screenPos = (ndc.xy * 0.5 + 0.5) * frame.resolution;
    
    // 2. Depth Occlusion Check
    // Sample terrain depth at the same screen location
    uint2 depthCoord = uint2(screenPos);
    if (depthCoord.x < depthMap.get_width() && depthCoord.y < depthMap.get_height()) {
        float terrainDepth = depthMap.read(depthCoord).r;
        // In Metal, depth is 0...1 (near...far). If ndc.z > terrainDepth, it's occluded.
        labels[id].occluded = (ndc.z > terrainDepth + 0.001) ? 1.0 : 0.0;
    }
    
    // 3. Screen-Space Repulsion (Avoid Overlaps)
    float2 shift = float2(0);
    float2 myPos = screenPos + labels[id].screenOffset;
    
    for (uint i = 0; i < 16; i++) { // Check up to 16 labels
        if (i == id || labels[i].active < 0.5) continue;
        
        float4 otherClip = mvp * float4(labels[i].worldAnchor, 1.0);
        float2 otherScreenPos = (otherClip.xy / otherClip.w * 0.5 + 0.5) * frame.resolution + labels[i].screenOffset;
        
        float2 diff = myPos - otherScreenPos;
        float dist = length(diff);
        float minDist = length(labels[id].screenSize + labels[i].screenSize) * 0.5;
        
        if (dist < minDist) {
            shift += normalize(diff) * (minDist - dist) * 0.5;
        }
    }
    
    // 4. Update Screen Offset
    labels[id].screenOffset += shift;
    
    // 5. Attraction to Anchor (Spring)
    labels[id].screenOffset *= 0.9; // Damping
}
