#pragma once

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NS_INTEGER NSInteger
typedef metal::int32_t NSInteger;
#else
#import <Foundation/Foundation.h>
#endif

#include <simd/simd.h>

// Enforce 16-byte alignment for all shared structures to match Metal std140/std430
#define ALIGNED_16 __attribute__((aligned(16)))

// MARK: - Common Types

typedef vector_float2 float2;
typedef vector_float3 float3;
typedef vector_float4 float4;
typedef matrix_float4x4 float4x4;

// MARK: - Shader Uniforms

struct FrameUniforms {
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float4x4 viewProjectionMatrix;
    float4x4 inverseViewProjectionMatrix;
    
    float3 cameraPosition;
    float  time; // Total time since start
    
    float2 resolution; // Screen resolution in pixels
    float  deltaTime;  // Time since last frame
    uint   frameCount; // Total frames rendered
} ALIGNED_16;

struct ModelUniforms {
    float4x4 modelMatrix;
    float4x4 normalMatrix; // Inverse transpose of model matrix
} ALIGNED_16;

// MARK: - Particle System

struct Particle {
    float3 position;
    float  mass;
    
    float3 velocity;
    float  radius;
    
    float4 color; // RGBA
} ALIGNED_16;
