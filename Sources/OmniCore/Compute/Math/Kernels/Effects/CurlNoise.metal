#include <metal_stdlib>
using namespace metal;

// Expert Panel: Graphics Artist - Curl Noise for fluid particle flow
// Replaces jittery movement with smooth, turbulent flow

// 3D Perlin noise
float hash3D(float3 p) {
    p = fract(p * float3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.x + p.y) * p.z);
}

float noise3D(float3 p) {
    float3 i = floor(p);
    float3 f = fract(p);
    
    // Cubic interpolation
    float3 u = f * f * (3.0 - 2.0 * f);
    
    // Sample 8 corners of cube
    float n000 = hash3D(i + float3(0, 0, 0));
    float n100 = hash3D(i + float3(1, 0, 0));
    float n010 = hash3D(i + float3(0, 1, 0));
    float n110 = hash3D(i + float3(1, 1, 0));
    float n001 = hash3D(i + float3(0, 0, 1));
    float n101 = hash3D(i + float3(1, 0, 1));
    float n011 = hash3D(i + float3(0, 1, 1));
    float n111 = hash3D(i + float3(1, 1, 1));
    
    // Trilinear interpolation
    return mix(
        mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
        mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y),
        u.z
    );
}

// Curl of a 3D potential field
// Curl = ∇ × F, where F is a vector potential
float3 curl_noise(float3 p, float epsilon) {
    // Sample potential field at offset positions
    float dx = epsilon;
    
    // ∂Fz/∂y - ∂Fy/∂z
    float curl_x = (noise3D(p + float3(0, dx, 0)) - noise3D(p - float3(0, dx, 0))) -
                   (noise3D(p + float3(0, 0, dx)) - noise3D(p - float3(0, 0, dx)));
    
    // ∂Fx/∂z - ∂Fz/∂x
    float curl_y = (noise3D(p + float3(0, 0, dx)) - noise3D(p - float3(0, 0, dx))) -
                   (noise3D(p + float3(dx, 0, 0)) - noise3D(p - float3(dx, 0, 0)));
    
    // ∂Fy/∂x - ∂Fx/∂y
    float curl_z = (noise3D(p + float3(dx, 0, 0)) - noise3D(p - float3(dx, 0, 0))) -
                   (noise3D(p + float3(0, dx, 0)) - noise3D(p - float3(0, dx, 0)));
    
    return float3(curl_x, curl_y, curl_z) / (2.0 * dx);
}

// Turbulent curl noise with multiple octaves
float3 turbulent_curl(float3 p, int octaves, float lacunarity, float gain) {
    float3 result = float3(0);
    float amplitude = 1.0;
    float frequency = 1.0;
    
    for (int i = 0; i < octaves; i++) {
        result += curl_noise(p * frequency, 0.01) * amplitude;
        frequency *= lacunarity;
        amplitude *= gain;
    }
    
    return result;
}

// Particle update kernel using curl noise
struct CurlParticle {
    float3 position;
    float3 velocity;
    float3 color;
    float life;
};

kernel void update_particles_curl(
    device CurlParticle* particles [[buffer(0)]],
    constant float& deltaTime [[buffer(1)]],
    constant float& noiseScale [[buffer(2)]],
    constant float& flowStrength [[buffer(3)]],
    constant float& time [[buffer(4)]],
    uint id [[thread_position_in_grid]]
) {
    CurlParticle p = particles[id];
    
    if (p.life <= 0.0) {
        return;
    }
    
    // Sample curl noise at particle position
    float3 noisePos = p.position * noiseScale + float3(time * 0.1);
    float3 curl = turbulent_curl(noisePos, 3, 2.0, 0.5);
    
    // Apply curl force to velocity
    p.velocity += curl * flowStrength * deltaTime;
    
    // Apply damping
    p.velocity *= 0.98;
    
    // Update position
    p.position += p.velocity * deltaTime;
    
    // Update life
    p.life -= deltaTime;
    
    // Write back
    particles[id] = p;
}

// Data point flow visualization
kernel void flow_data_points(
    device float3* positions [[buffer(0)]],
    device float3* velocities [[buffer(1)]],
    constant float& deltaTime [[buffer(2)]],
    constant float& flowStrength [[buffer(3)]],
    constant float& time [[buffer(4)]],
    uint id [[thread_position_in_grid]]
) {
    float3 pos = positions[id];
    float3 vel = velocities[id];
    
    // Sample curl noise
    float3 noisePos = pos * 0.5 + float3(time * 0.05);
    float3 curl = curl_noise(noisePos, 0.01);
    
    // Smooth, fluid-like movement
    vel += curl * flowStrength * deltaTime;
    vel *= 0.95;  // Damping
    
    // Update position
    pos += vel * deltaTime;
    
    // Write back
    positions[id] = pos;
    velocities[id] = vel;
}
