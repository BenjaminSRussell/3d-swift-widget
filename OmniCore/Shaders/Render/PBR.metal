#include <metal_stdlib>
#include "../../Include/OmniShaderTypes.h"

using namespace metal;

// Phase 10.1: PBR Functions (Cook-Torrance)

constant float PI = 3.14159265359;

// Normal Distribution Function (Trowbridge-Reitz GGX)
float D_GGX(float NdotH, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float denom = (NdotH * NdotH * (a2 - 1.0) + 1.0);
    return a2 / (PI * denom * denom);
}

// Geometry Function (Smith's Schlick-GGX)
float G_SchlickGGX(float NdotV, float roughness) {
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;
    return NdotV / (NdotV * (1.0 - k) + k);
}

float G_Smith(float NdotV, float NdotL, float roughness) {
    return G_SchlickGGX(NdotV, roughness) * G_SchlickGGX(NdotL, roughness);
}

// Fresnel Equation (Schlick's approximation)
float3 F_Schlick(float cosTheta, float3 F0) {
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

float3 calculate_pbr(float3 N, float3 V, float3 L, float3 albedo, float roughness, float metallic, float3 lightColor) {
    float3 H = normalize(V + L);
    float NdotV = max(dot(N, V), 0.0001);
    float NdotL = max(dot(N, L), 0.0001);
    float NdotH = max(dot(N, H), 0.0);
    float HdotV = max(dot(H, V), 0.0);

    float3 F0 = mix(float3(0.04), albedo, metallic);
    
    float D = D_GGX(NdotH, roughness);
    float G = G_Smith(NdotV, NdotL, roughness);
    float3 F = F_Schlick(HdotV, F0);
    
    float3 numerator = D * G * F;
    float denominator = 4.0 * NdotV * NdotL;
    float3 specular = numerator / denominator;
    
    float3 kS = F;
    float3 kD = (float3(1.0) - kS) * (1.0 - metallic);
    
    return (kD * albedo / PI + specular) * lightColor * NdotL;
}
