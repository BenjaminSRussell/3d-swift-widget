#ifndef ThemeConfig_h
#define ThemeConfig_h

#include <metal_stdlib>
using namespace metal;

struct ThemeConfig {
    float4 primaryColor;
    float4 secondaryColor;
    float4 sigmaColor;
    float4 backgroundColor;
    float signalStrength;
    float padding[3]; // Align to 16 bytes if necessary, though float4 is 16 aligned
};

#endif
