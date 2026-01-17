#include <metal_stdlib>
#include "../Include/OmniShaderTypes.h"

using namespace metal;

// Phase 15.2: Final Post-Processing Pass

// Generic pseudo-random function for film grain
float noise(float2 uv, float time) {
    return fract(sin(dot(uv.xy, float2(12.9898, 78.233)) + time) * 43758.5453);
}

// Blue Noise approximation
float interleaved_gradient_noise(float2 uv) {
    float3 magic = float3(0.06711056, 0.00583715, 52.9829189);
    return fract(magic.z * fract(dot(uv, magic.xy)));
}

float3 ACESFilm(float3 x) {
    float a = 2.51f;
    float b = 0.03f;
    float c = 2.43f;
    float d = 0.59f;
    float e = 0.14f;
    return saturate((x*(a*x+b))/(x*(c*x+d)+e));
}

// --- Kernels ---

// Simple Downsample (Box)
kernel void downsample_box(texture2d<float, access::read> source [[texture(0)]],
                           texture2d<float, access::write> dest [[texture(1)]],
                           uint2 id [[thread_position_in_grid]]) {
    if (id.x >= dest.get_width() || id.y >= dest.get_height()) return;
    
    // Read 4 pixels from source corresponding to this 1 pixel in dest
    // Assuming 2x downsample
    uint2 srcId = id * 2;
    float4 c1 = source.read(srcId);
    float4 c2 = source.read(srcId + uint2(1, 0));
    float4 c3 = source.read(srcId + uint2(0, 1));
    float4 c4 = source.read(srcId + uint2(1, 1));
    
    float4 avg = (c1 + c2 + c3 + c4) * 0.25;
    dest.write(avg, id);
}

// Simple Upsample (Tent)
kernel void upsample_tent(texture2d<float, access::sample> source [[texture(0)]],
                          texture2d<float, access::write> dest [[texture(1)]],
                          uint2 id [[thread_position_in_grid]]) {
    if (id.x >= dest.get_width() || id.y >= dest.get_height()) return;
    
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 uv = (float2(id) + 0.5) / float2(dest.get_width(), dest.get_height());
    
    float4 c = source.sample(s, uv);
    dest.write(c, id);
}

struct PPSettings {
    float bloomIntensity;
    float aberration;
    float focusScore; // [0, 1] - High jitter/High entropy
    float taaWeight;   // Accumulation weight for TAA
};

// TAA Resolve: Blends current frame with history using neighborhood clamping
kernel void taa_resolve(texture2d<float, access::sample> current [[texture(0)]],
                        texture2d<float, access::sample> history [[texture(1)]],
                        texture2d<float, access::write> output [[texture(2)]],
                        constant FrameUniforms &frame [[buffer(0)]],
                        constant PPSettings &settings [[buffer(1)]],
                        uint2 id [[thread_position_in_grid]]) {
    if (id.x >= output.get_width() || id.y >= output.get_height()) return;
    
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 uv = (float2(id) + 0.5) / float2(output.get_width(), output.get_height());
    
    float4 currColor = current.read(id);
    
    // Neighborhood Clamping (3x3) to reduce ghosting
    float4 m1 = current.read(id + uint2(-1, -1));
    float4 m2 = current.read(id + uint2(0, -1));
    float4 m3 = current.read(id + uint2(1, -1));
    float4 m4 = current.read(id + uint2(-1, 0));
    float4 m5 = currColor;
    float4 m6 = current.read(id + uint2(1, 0));
    float4 m7 = current.read(id + uint2(-1, 1));
    float4 m8 = current.read(id + uint2(0, 1));
    float4 m9 = current.read(id + uint2(1, 1));
    
    float4 cMin = min(min(min(m1, m2), min(m3, m4)), min(min(m5, m6), min(m7, m8)));
    cMin = min(cMin, m9);
    float4 cMax = max(max(max(m1, m2), max(m3, m4)), max(max(m5, m6), max(m7, m8)));
    cMax = max(cMax, m9);
    
    // Reprojection (Simplified for static scenes, would use motion vectors otherwise)
    float2 prevUV = uv - frame.jitter;
    float4 histColor = history.sample(s, prevUV);
    
    // Clamp history to neighborhood
    histColor = clamp(histColor, cMin, cMax);
    
    float4 resolved = mix(currColor, histColor, settings.taaWeight);
    output.write(resolved, id);
}

kernel void apply_post_process(texture2d<float, access::read> scene [[texture(0)]],
                               texture2d<float, access::sample> bloom [[texture(1)]],
                               texture2d<float, access::sample> glass [[texture(2)]],
                               texture2d<float, access::write> output [[texture(3)]],
                               constant FrameUniforms &frame [[buffer(0)]],
                               constant PPSettings &settings [[buffer(1)]], // Bind Settings to Buffer 1
                               uint2 id [[thread_position_in_grid]]) {
    
    if (id.x >= output.get_width() || id.y >= output.get_height()) return;
    
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 uv = float2(id) / float2(output.get_width(), output.get_height());
    float2 centerDist = uv - 0.5;
    
    // Domain G: Neural Focus Modulation
    // High focus score (jitter) leads to more chromatic aberration and grain "noise"
    float focus = settings.focusScore;
    float jitter = focus * (sin(frame.time * 20.0) * 0.5 + 0.5); // Fast jitter pulse
    
    // 1. Chromatic Aberration (Dynamic based on Focus Score)
    float aberrationStrength = settings.aberration + (focus * 0.02) + (jitter * 0.01);
    float2 abOffset = centerDist * aberrationStrength * dot(centerDist, centerDist) * 10.0;
    
    float4 color;
    uint2 rPos = uint2(float2(id) + abOffset * float2(output.get_width(), output.get_height()));
    uint2 bPos = uint2(float2(id) - abOffset * float2(output.get_width(), output.get_height()));
    
    rPos = clamp(rPos, uint2(0), uint2(scene.get_width()-1, scene.get_height()-1));
    bPos = clamp(bPos, uint2(0), uint2(scene.get_width()-1, scene.get_height()-1));
    
    color.r = scene.read(rPos).r;
    color.g = scene.read(id).g;
    color.b = scene.read(bPos).b;
    color.a = 1.0;
    
    // 2. Add Bloom
    float4 bloomColor = bloom.sample(s, uv);
    color.rgb += bloomColor.rgb * settings.bloomIntensity;
    
    // 3. Filmic Grain (Modulated by Focus)
    float grainBase = 0.02 + (focus * 0.05); // Grainy when unfocused
    float grain = noise(uv, frame.time) * grainBase;
    color.rgb += grain;
    
    // 3.5 Glass Imperfections
    float4 glassSample = glass.sample(s, uv);
    // Scratches are represented in 'r', fingerprints in 'g'
    float imperfections = glassSample.r * 0.05 + glassSample.g * 0.02;
    color.rgb += imperfections * (sin(frame.time * 0.1) * 0.5 + 0.5); // Subtle flicker
    
    // 4. Tone Mapping (ACES)
    color.rgb = ACESFilm(color.rgb);
    
    // 5. Blue Noise Dithering
    float dither = interleaved_gradient_noise(float2(id));
    color.rgb += (dither - 0.5) / 255.0;
    
    // 6. Gamma Correction
    color.rgb = pow(color.rgb, float3(1.0/2.2));
    
    float sceneAlpha = scene.read(id).a;
    if (sceneAlpha < 0.1) {
        output.write(float4(0,0,0,0), id); 
    } else {
        color.a = sceneAlpha;
        output.write(color, id);
    }
}
