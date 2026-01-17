#include <metal_stdlib>
using namespace metal;

// Expert Panel: Rendering Architect - Lens Dirt Injection
// Bloom catches invisible scratches and dust on the "glass" interface

kernel void apply_lens_dirt(
    texture2d<float, access::read> bloomInput [[texture(0)]],
    texture2d<float, access::read> lensDirt [[texture(1)]],
    texture2d<float, access::write> bloomOutput [[texture(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= bloomOutput.get_width() || gid.y >= bloomOutput.get_height()) {
        return;
    }
    
    // Sample bloom
    float3 bloom = bloomInput.read(gid).rgb;
    
    // Sample lens dirt (tiled if necessary)
    uint2 dirtCoord = uint2(
        gid.x % lensDirt.get_width(),
        gid.y % lensDirt.get_height()
    );
    float dirt = lensDirt.read(dirtCoord).r;
    
    // Bloom catches dirt at grazing angles
    // Dirt is more visible where bloom is bright
    float3 enhanced = bloom * (1.0 + dirt * 0.4);
    
    bloomOutput.write(float4(enhanced, 1.0), gid);
}

// Expert Panel: Color Scientist - ACES Filmic Tone Mapping
// Converts Linear sRGB to display-ready colors without clipping

float3 aces_tonemap(float3 x) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return saturate((x * (a * x + b)) / (x * (c * x + d) + e));
}

kernel void aces_tone_map(
    texture2d<float, access::read> input [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }
    
    float4 color = input.read(gid);
    
    // Apply ACES tone mapping to RGB
    color.rgb = aces_tonemap(color.rgb);
    
    output.write(color, gid);
}

// Expert Panel: Color Scientist - Blue Noise Dithering
// Eliminates banding in transparent gradients

kernel void apply_blue_noise_dither(
    texture2d<float, access::read_write> output [[texture(0)]],
    texture2d<float, access::read> blueNoise [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }
    
    float4 color = output.read(gid);
    
    // Sample blue noise (tiled 64x64)
    uint2 noiseCoord = uint2(gid.x % 64, gid.y % 64);
    float noise = blueNoise.read(noiseCoord).r;
    
    // Apply dithering (±0.5/255 range)
    float dither = (noise - 0.5) / 255.0;
    color.rgb += dither;
    
    output.write(color, gid);
}
