#ifndef OmniTheme_h
#define OmniTheme_h

#include <simd/simd.h>

// Masterpiece Theme Structure
// "Expert Perspective 1 & 9": Shared memory layout for zero-copy theme updates.
// Ensure 16-byte alignment for Metal buffers.

struct GlobalThemeUniforms {
    // Colors (Premultiplied RGBA)
    vector_float4 primaryColor;     // Main Data Color (Cyan/Teal)
    vector_float4 secondaryColor;   // Accent/Highlight (Orange/Purple)
    vector_float4 backgroundColor;  // Deep Void / Fog Color
    vector_float4 gridColor;        // Axis Lines
    
    // Typography & Metrics
    float baseFontSize;        // Standard Scale
    float strokeWidth;         // For Wireframes
    float density;             // Fog/Data Density multiplier
    float time;                // Global Clock
    
    // Glassmorphism Parameters
    float glassRefraction;     // Index of Refraction (1.0 - 2.0)
    float glassBlurSigs;       // Sigma for Gaussian Blur
    float chromaticAberration; // Pixel offset magnitude
    float vignetteStrength;    // Edge darkening
    
    // Interaction
    vector_float2 mousePosition; // Normalized 0-1
    float hoverIntensity;        // 0.0 to 1.0 (Glow strength)
    float activeWidgetID;        // ID of focused widget
    
    // Memory Padding to 256 bytes (Metal Best Practice)
    float _pad[36]; 
};

#endif /* OmniTheme_h */
