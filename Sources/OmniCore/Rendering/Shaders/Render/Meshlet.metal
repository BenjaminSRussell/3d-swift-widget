#include <metal_stdlib>
#include "../Shared/OmniMath.metal"
#include "../Include/OmniShaderTypes.h"

using namespace metal;

struct Meshlet {
    uint vertexOffset;
    uint triangleOffset;
    uint vertexCount;
    uint triangleCount;
    float4 boundingCone;
    float4 boundingSphere;
};

struct MeshletOutput {
    float4 position [[position]];
    float3 normal;
};

// Phase 5.2: Object Shader
// Culls meshlets before they reach the mesh shader.
[[object]]
void object_cull(constant Meshlet *meshlets [[buffer(0)]],
                 constant FrameUniforms &frame [[buffer(1)]],
                 mesh_grid_properties grid,
                 uint3 thread_position_in_grid [[thread_position_in_grid]]) {
    
    uint id = thread_position_in_grid.x;
    Meshlet m = meshlets[id];
    
    bool visible = true;
    
    // 1. Cone Culling (Backface Culling)
    // Check if the cone of normals faces away from the camera.
    // cone.xyz = axis, cone.w = cutoff (sin of half-angle)
    // We need view vector from camera to meshlet center.
    float3 center = m.boundingSphere.xyz;
    float3 viewDir = normalize(center - frame.cameraPosition);
    
    // If cone data is valid (axis length > 0)
    if (length_squared(m.boundingCone.xyz) > 0.1) {
        // If dot(axis, viewDir) > cutoff, the entire cluster is backfacing
        if (dot(m.boundingCone.xyz, viewDir) > m.boundingCone.w) {
            visible = false;
        }
    }
    
    // 2. Frustum Culling (Sphere)
    // Simple check against view frustum planes could go here, 
    // but for now we rely on the cone check + coarse bounds.
    
    if (visible) {
        grid.set_threadgroups_per_grid(uint3(1, 1, 1));
    }
}

#include "PBR.metal"

// Phase 5.2: Mesh Shader
// Generates primitives (triangles) from meshlet data.
[[mesh]]
void mesh_main(const object_data Meshlet &meshlet [[payload]],
               device const float3 *vertices [[buffer(0)]],
               uint tid [[thread_index_in_threadgroup]],
               uint3 mesh_grid_pos [[threadgroup_position_in_grid]],
               mesh_output<MeshletOutput, uint3, 64, 126> output) {
    
    // Set primitive count
    if (tid == 0) {
        output.set_primitive_count(meshlet.triangleCount);
    }
    
    // Emit vertices
    if (tid < meshlet.vertexCount) {
        float3 p = vertices[meshlet.vertexOffset + tid];
        MeshletOutput v;
        v.position = float4(p, 1.0);
        v.normal = float3(0, 1, 0); // Stub
        output.set_vertex(tid, v);
    }
}

#include "Iridescence.metal"

#include "Refraction.metal"

// Phase 10.4: Fragment Shader Integration
fragment float4 fragment_main(MeshletOutput in [[stage_in]],
                              constant FrameUniforms &frame [[buffer(0)]],
                              constant PBRMaterial &material [[buffer(1)]],
                              constant GlobalResources &resources [[buffer(2)]],
                              texture2d<float> backbuffer [[texture(0)]],
                              sampler s [[sampler(0)]]) {
    
    float3 N = normalize(in.normal);
    float3 V = normalize(frame.cameraPosition - in.position.xyz);
    float3 I = -V; // Incident vector
    float NdotV = max(dot(N, V), 0.0001);
    
    // Phase 11.4: Iridescence
    float3 iridescentTint = calculate_iridescence(NdotV, material.filmThickness, material.filmIOR);
    
    // Phase 12.3: Refraction & Dispersion
    // Sample the backbuffer using screen-space coordinates shifted by refracted vectors
    float2 screenUV = in.position.xy / frame.resolution;
    
    DispersionResult disp = calculate_dispersion(I, N, material.refractionIndex, material.dispersionAmount);
    
    // Simplistic screen-space refraction (distortion only, no true raytracing)
    float distortion = 0.1; // Scale refraction displacement
    float2 uvR = screenUV + disp.R.xy * distortion;
    float2 uvG = screenUV + disp.G.xy * distortion;
    float2 uvB = screenUV + disp.B.xy * distortion;
    
    float3 refractiveColor;
    refractiveColor.r = backbuffer.sample(s, uvR).r;
    refractiveColor.g = backbuffer.sample(s, uvG).g;
    refractiveColor.b = backbuffer.sample(s, uvB).b;
    
    float3 lighting = 0;
    
    for (uint i = 0; i < frame.lightCount; i++) {
        PointLight light = frame.lights[i];
        float3 L = normalize(light.position - in.position.xyz);
        
        float dist = distance(light.position, in.position.xyz);
        float attenuation = 1.0 / (dist * dist);
        float3 lightColor = light.color * light.intensity * attenuation;
        
        float3 pbr = calculate_pbr(N, V, L, material.baseColor, material.roughness, material.metallic, lightColor);
        lighting += pbr * iridescentTint;
    }
    
    // Mix refractive color with opaque base (Fresnel would be better here)
    float dielectricFresnel = 0.04 + (1.0 - 0.04) * pow(1.0 - NdotV, 5.0);
    float3 finalColor = mix(refractiveColor, lighting, dielectricFresnel);
    
    // Ambient & Emissive
    finalColor += material.baseColor * 0.05f * material.ambientOcclusion * iridescentTint;
    
    // Phase 13.3: Caustics Integration
    // Sample the caustics buffer (atomic uints)
    uint2 causticsRes = uint2(512, 512); // Grid resolution for caustics
    float2 causticsUV = in.position.xy / frame.resolution; // Simplified screen-space caustics
    uint2 pixel = uint2(causticsUV * float2(causticsRes));
    
    if (pixel.x < causticsRes.x && pixel.y < causticsRes.y) {
        // device const atomic_uint* cMap = (device const atomic_uint*)resources.textures[0/*caustics_id*/]; // Stub: indexing caustics buffer via bindless
        // In a real implementation we'd pass the buffer directly or via ArgBuffer
        // For now, let's assume we have a caustics map available.
        // uint cRaw = atomic_load_explicit(&cMap[pixel.y * causticsRes.x + pixel.x], memory_order_relaxed);
        // float cIntensity = (float)cRaw / 1000.0f;
        // finalColor *= (1.0 + cIntensity);
    }
    
    // Tonemapping
    finalColor = finalColor / (finalColor + float3(1.0));
    finalColor = pow(finalColor, float3(1.0/2.2));
    
    return float4(finalColor, 1.0);
}
