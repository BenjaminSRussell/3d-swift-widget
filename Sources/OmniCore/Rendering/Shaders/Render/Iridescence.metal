#include <metal_stdlib>
#include "../Include/OmniShaderTypes.h"
#include "../Shared/OmniMath.metal"

using namespace metal;

// Phase 11.1: Thin Film Interference
// Simulates iridescence by calculating phase shifts between top and bottom reflections.

// Approximate XYZ to RGB conversion matrix
constant float3x3 XYZ_TO_RGB = float3x3(
    float3( 3.2404542, -0.9692660,  0.0556434),
    float3(-1.5371385,  1.8760108, -0.2040259),
    float3(-0.4985314,  0.0415560,  1.0572252)
);

// Fresnel at an interface
float fresnel_dielectric(float cosTheta, float eta) {
    float sinTheta2 = 1.0 - cosTheta * cosTheta;
    float sinThetaT2 = sinTheta2 / (eta * eta);
    if (sinThetaT2 >= 1.0) return 1.0; // TIR
    float cosThetaT = sqrt(1.0 - sinThetaT2);
    
    float rs = (cosTheta - eta * cosThetaT) / (cosTheta + eta * cosThetaT);
    float rp = (eta * cosTheta - cosThetaT) / (eta * cosTheta + cosThetaT);
    return (rs * rs + rp * rp) * 0.5;
}

// Simple interference approximation for a single wavelength
float interference(float d, float eta, float cosTheta, float lambda) {
    // Phase difference: 2 * n * d * cos(theta_t) + phase shift from reflections
    float sinTheta2 = 1.0 - cosTheta * cosTheta;
    float cosThetaT = sqrt(1.0 - sinTheta2 / (eta * eta));
    float opd = 2.0 * eta * d * cosThetaT; // Optical Path Difference
    
    // Constructive interference when opd = m * lambda
    return 0.5 + 0.5 * cos(2.0 * PI * opd / lambda);
}

// Calculate interference tint across the visible spectrum (RGB estimation)
float3 calculate_iridescence(float cosTheta, float d, float eta) {
    if (d <= 0.0) return float3(1.0);
    
    // Wavelengths for R, G, B (nm)
    float3 lambdas = float3(650.0, 530.0, 460.0);
    
    float3 result;
    result.r = interference(d, eta, cosTheta, lambdas.r);
    result.g = interference(d, eta, cosTheta, lambdas.g);
    result.b = interference(d, eta, cosTheta, lambdas.b);
    
    return saturate(result);
}
