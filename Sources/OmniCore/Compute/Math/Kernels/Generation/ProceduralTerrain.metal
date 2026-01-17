#include <metal_stdlib>
using namespace metal;

// Expert Panel: Data Scientist - GPU-based terrain generation
// All math runs on compute shaders, not CPU

struct Vertex {
    float3 position;
    float3 normal;
    float2 texCoord;
};

struct Formula {
    float4 coefficients;  // a, b, c, d for formula: z = a*sin(b*x) + c*cos(d*y)
    float amplitude;
    float frequency;
    float octaves;
    float persistence;
};

// Perlin-style noise function
float hash(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    
    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));
    
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// Fractal Brownian Motion
float fbm(float2 p, float octaves, float persistence) {
    float value = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    
    for (int i = 0; i < int(octaves); i++) {
        value += amplitude * noise(p * frequency);
        frequency *= 2.0;
        amplitude *= persistence;
    }
    
    return value;
}

// Evaluate formula at position
float evaluate_formula(constant Formula& formula, float2 pos) {
    float x = pos.x;
    float y = pos.y;
    
    // Base formula: z = a*sin(b*x) + c*cos(d*y)
    float base = formula.coefficients.x * sin(formula.coefficients.y * x) +
                 formula.coefficients.z * cos(formula.coefficients.w * y);
    
    // Add fractal noise
    float noise = fbm(pos * formula.frequency, formula.octaves, formula.persistence);
    
    return (base + noise) * formula.amplitude;
}

// Calculate normal from height field
float3 calculate_normal(constant Formula& formula, float2 pos, float epsilon) {
    float h = evaluate_formula(formula, pos);
    float hx = evaluate_formula(formula, pos + float2(epsilon, 0));
    float hy = evaluate_formula(formula, pos + float2(0, epsilon));
    
    float3 tangentX = float3(epsilon, hx - h, 0);
    float3 tangentY = float3(0, hy - h, epsilon);
    
    return normalize(cross(tangentX, tangentY));
}

// Main terrain generation kernel
kernel void generate_terrain(
    device Vertex* vertices [[buffer(0)]],
    constant Formula& formula [[buffer(1)]],
    constant uint& gridSize [[buffer(2)]],
    constant float& worldSize [[buffer(3)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= gridSize * gridSize) {
        return;
    }
    
    // Calculate grid position
    uint x = id % gridSize;
    uint y = id / gridSize;
    
    // Map to world space
    float fx = (float(x) / float(gridSize - 1)) * worldSize - worldSize * 0.5;
    float fy = (float(y) / float(gridSize - 1)) * worldSize - worldSize * 0.5;
    float2 pos = float2(fx, fy);
    
    // Evaluate height
    float height = evaluate_formula(formula, pos);
    
    // Calculate normal
    float epsilon = worldSize / float(gridSize);
    float3 normal = calculate_normal(formula, pos, epsilon);
    
    // Write vertex
    vertices[id].position = float3(fx, height, fy);
    vertices[id].normal = normal;
    vertices[id].texCoord = float2(float(x) / float(gridSize - 1), float(y) / float(gridSize - 1));
}

// Streaming terrain generation (for octree chunks)
kernel void generate_terrain_chunk(
    device Vertex* vertices [[buffer(0)]],
    constant Formula& formula [[buffer(1)]],
    constant float3& chunkOrigin [[buffer(2)]],
    constant float& chunkSize [[buffer(3)]],
    constant uint& resolution [[buffer(4)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= resolution * resolution) {
        return;
    }
    
    uint x = id % resolution;
    uint y = id / resolution;
    
    // Local position within chunk
    float fx = (float(x) / float(resolution - 1)) * chunkSize;
    float fy = (float(y) / float(resolution - 1)) * chunkSize;
    
    // World position
    float2 worldPos = chunkOrigin.xz + float2(fx, fy);
    
    // Evaluate height
    float height = evaluate_formula(formula, worldPos);
    
    // Calculate normal
    float epsilon = chunkSize / float(resolution);
    float3 normal = calculate_normal(formula, worldPos, epsilon);
    
    // Write vertex
    vertices[id].position = float3(worldPos.x, height, worldPos.y);
    vertices[id].normal = normal;
    vertices[id].texCoord = float2(float(x) / float(resolution - 1), float(y) / float(resolution - 1));
}
