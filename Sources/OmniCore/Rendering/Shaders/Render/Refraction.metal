#include <metal_stdlib>
#include "../Include/OmniShaderTypes.h"

using namespace metal;

// Phase 12.1: Refraction & Dispersion Library

// Snell's Law implementation
float3 refract_vector(float3 I, float3 N, float eta) {
    float k = 1.0 - eta * eta * (1.0 - dot(N, I) * dot(N, I));
    if (k < 0.0)
        return float3(0.0); // Total internal reflection
    else
        return eta * I - (eta * dot(N, I) + sqrt(k)) * N;
}

// Chromatic Dispersion: Calculates 3 refracted vectors with slightly different IORs
struct DispersionResult {
    float3 R;
    float3 G;
    float3 B;
};

DispersionResult calculate_dispersion(float3 I, float3 N, float baseIOR, float dispersion) {
    DispersionResult res;
    
    // Convert IOR to eta (incident IOR / refracted IOR)
    // Assume incident is air (1.0)
    float etaR = 1.0 / (baseIOR - dispersion);
    float etaG = 1.0 / baseIOR;
    float etaB = 1.0 / (baseIOR + dispersion);
    
    res.R = refract_vector(I, N, etaR);
    res.G = refract_vector(I, N, etaG);
    res.B = refract_vector(I, N, etaB);
    
    return res;
}
