#include <metal_stdlib>
using namespace metal;

struct Payload {
    uint meshletID;
    float isolation_metric;
};

struct VertexOut {
    float4 position [[position]];
    float3 color;
    float depth; 
};

// Logarithmic Z-Buffer Helper
float logarithmic_depth(float z, float far) {
    float C = 1.0;
    return log(C * z + 1.0) / log(C * far + 1.0);
}

[[mesh]]
void ridgeline_mesh(
    object_data Payload& payload [[payload]],
    mesh<VertexOut, void, 128, 128, topology::line> output, // Topology: LINE
#include "../../Shared/ThemeConfig.metal"

    uint tid [[thread_index_in_threadgroup]],
    uint lid [[thread_position_in_threadgroup]],
    constant float4x4 &viewProjection [[buffer(0)]],
    constant ThemeConfig &theme [[buffer(1)]],
    texture2d<float, access::sample> spectrogram [[texture(0)]]
) {
    uint vertexCount = 128;
    uint primitiveCount = 127; 
    
    if (lid == 0) {
        output.set_primitive_count(primitiveCount);
    }
    
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    
    // Generate Ridge Lines
    if (lid < vertexCount) {
        float u = float(lid) / float(vertexCount);
        // Offset by payload ID to create separate "ridges" depth-wise
        float v = float(payload.meshletID) / 50.0; 
        
        float x = (u - 0.5) * 50.0;
        float z = (v * 10.0) + 5.0; // Pushed back
        
        // Sample Spectrogram Data driven by NUTS
        // Map world space to UV
        float2 sampleUV = float2(u, float(payload.meshletID % 100) / 100.0);
        float4 data = spectrogram.sample(s, sampleUV);
        float density = data.r;
        float uncertainty = data.g;
        
        // FBM + Data Hybrid
        // Base shape + Data impulse
        float base_shape = sin(x * 0.5 + v * 10) * cos(x * 2.0) * exp(-abs(x)*0.2) * 2.0;
        float data_impulse = density * 10.0 * theme.signalStrength; // Scale by theme signal
        
        float y = base_shape + data_impulse;
        
        VertexOut vOut;
        float4 worldPos = float4(x, y, z, 1.0);
        float4 clipPos = viewProjection * worldPos;
        
        vOut.position = clipPos;
        
        // Color: Modifiable Theme Colors
        float t = (y + 5.0) / 10.0; // Normalized height
        // Mix primary and secondary based on height
        float3 baseColor = mix(theme.primaryColor.rgb, theme.secondaryColor.rgb, t);
        
        // 6-Sigma Confidence Band Visualization
        // If uncertainty is high, mix in the Sigma Color
        vOut.color = mix(baseColor, theme.sigmaColor.rgb, uncertainty);
        vOut.depth = clipPos.z / clipPos.w;
        
        output.set_vertex(lid, vOut);
    }
    
    // Line Topology
    if (lid < primitiveCount) {
        output.set_index(lid * 2 + 0, lid);
        output.set_index(lid * 2 + 1, lid + 1);
    }
}

fragment float4 ridgeline_fragment(VertexOut in [[stage_in]]) {
    // Fade out at distance
    float alpha = 1.0 - smoothstep(0.8, 1.0, in.depth);
    return float4(in.color, alpha);
}
