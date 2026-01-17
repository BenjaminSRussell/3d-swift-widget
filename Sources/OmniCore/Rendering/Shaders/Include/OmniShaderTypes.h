#pragma once

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name)                                                  \
  enum _name : _type _name;                                                    \
  enum _name : _type
#define NS_INTEGER NSInteger
typedef metal::int32_t NSInteger;
#else
#import <Foundation/Foundation.h>
#endif

#include <simd/simd.h>

// Silence clang warnings about vector types if needed
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation"

// Enforce 16-byte alignment for all shared structures to match Metal
// std140/std430
#define ALIGNED_16 __attribute__((aligned(16)))

// MARK: - Common Types

typedef vector_float2 float2;
typedef vector_float3 float3;
typedef vector_float4 float4;
typedef matrix_float4x4 float4x4;

// MARK: - Particle System

typedef struct ALIGNED_16 {
  float3 position;
  float3 velocity;
  float4 dataAttributes;
  float topologicalSignificance;
  uint clusterID;
  float persistence; // From TDA
} Particle;

// Phase 10.2: PBR Material & Lighting
typedef struct ALIGNED_16 {
  float3 baseColor;
  float roughness;
  float metallic;
  float ambientOcclusion;
  float emissive;

  // Phase 11.2: Thin Film Iridescence
  float filmThickness; // in nanometers (e.g., 200-800)
  float filmIOR;       // Refractive index of the film

  // Phase 12.1: Refraction & Dispersion
  float refractionIndex;  // Base IOR
  float dispersionAmount; // Strength of chromatic aberration
} PBRMaterial;

typedef struct ALIGNED_16 {
  float3 position;
  float3 color;
  float intensity;
  float radius;
} PointLight;

// MARK: - Shader Uniforms

typedef struct ALIGNED_16 {
  float4x4 viewMatrix;
  float4x4 projectionMatrix;
  float4x4 viewProjectionMatrix;
  float4x4 inverseViewProjectionMatrix;
  float4x4 prevViewProjectionMatrix; // For TAA

  float3 cameraPosition;
  float time; // Total time since start

  float2 resolution; // Screen resolution in pixels
  float2 jitter;     // Sub-pixel jitter for TAA
  float deltaTime;   // Time since last frame
  uint frameCount;   // Total frames rendered

  PointLight lights[4];
  uint lightCount;
} FrameUniforms;

typedef struct ALIGNED_16 {
  float4x4 modelMatrix;
  float4x4 normalMatrix;
} ModelUniforms;

// Phase 5.3: Meshlet Descriptors
typedef struct ALIGNED_16 {
  uint vertexOffset;
  uint triangleOffset;
  uint vertexCount;
  uint triangleCount;
  float4 boundingCone;   // xyz: normal, w: angle cut-off
  float4 boundingSphere; // xyz: center, w: radius
} MeshletDescriptor;

// Phase 8.1: Physics Constraints
typedef struct ALIGNED_16 {
  uint p1;
  uint p2;
  float restLength;
  float stiffness;
} SpringConstraint;

// Phase 9.2: Theme Configuration
typedef struct ALIGNED_16 {
  float4 primaryColor;
  float4 secondaryColor;
  float4 sigmaColor;
  float4 backgroundColor;
  float signalStrength;
  float padding[3];
} ThemeConfig;

// Phase 6.1: Bindless Resource Structures
struct MaterialResources {
  uint baseColorTextureIndex;
  uint normalTextureIndex;
  float roughness;
  float metalness;
};

#ifdef __METAL_VERSION__
// Bindless Texture Table (Tier 2 Argument Buffers)
using namespace metal;
struct GlobalResources {
  texture2d<float> textures[1024];
  sampler samplers[16];
};
#endif

#ifdef __METAL_VERSION__
// Phase 4.8: Compressed Particle Layout
// Uses 16-bit floats to reduce memory footprint.
struct HalfParticle {
  half3 position;
  half3 velocity;
};
#endif
