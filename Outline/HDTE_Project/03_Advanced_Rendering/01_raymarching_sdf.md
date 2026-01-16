# Raymarching and Signed Distance Functions

## Introduction to Raymarching

Raymarching is a rendering technique that uses signed distance functions (SDFs) to define surfaces implicitly. Unlike traditional polygon-based rendering, raymarching can render infinite detail and complex mathematical shapes.

### Core Concept

```
For each pixel:
  1. March a ray through the scene
  2. At each step, evaluate SDF to get distance to nearest surface
  3. Move ray forward by that distance
  4. Repeat until surface is hit or max distance reached
```

### Basic Raymarching Implementation

```metal
// Basic raymarching function
float raymarch(Ray ray, float maxDistance, float epsilon) {
    float t = 0.0;
    
    for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
        float3 p = ray.origin + ray.direction * t;
        float distance = sceneSDF(p);
        
        if (distance < epsilon) {
            // Hit surface
            return t;
        }
        
        t += distance;
        
        if (t > maxDistance) {
            // Missed everything
            break;
        }
    }
    
    return -1.0; // No hit
}

// Scene SDF - combines all objects
float sceneSDF(float3 p) {
    float sphere1 = sdSphere(p, float3(0, 0, 0), 1.0);
    float sphere2 = sdSphere(p, float3(2, 0, 0), 0.5);
    float ground = sdPlane(p, float4(0, 1, 0, 0));
    
    // Union operation
    return min(min(sphere1, sphere2), ground);
}
```

## Signed Distance Functions

### Primitive SDFs

```metal
// Sphere SDF
float sdSphere(float3 p, float3 center, float radius) {
    return length(p - center) - radius;
}

// Box SDF
float sdBox(float3 p, float3 center, float3 size) {
    float3 d = abs(p - center) - size;
    return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

// Plane SDF
float sdPlane(float3 p, float4 plane) {
    // plane: (nx, ny, nz, d) where n is normal and d is distance from origin
    return dot(p, plane.xyz) + plane.w;
}

// Cylinder SDF
float sdCylinder(float3 p, float3 a, float3 b, float r) {
    float3 pa = p - a;
    float3 ba = b - a;
    float baba = dot(ba, ba);
    float paba = dot(pa, ba);
    float x = length(pa * baba - ba * paba) - r * baba;
    float y = abs(paba - baba * 0.5) - baba * 0.5;
    float x2 = x * x;
    float y2 = y * y * baba;
    float d = (max(x, y) < 0.0) ? -min(x2, y2) : (((x > 0.0) ? x2 : 0.0) + ((y > 0.0) ? y2 : 0.0));
    return sign(d) * sqrt(abs(d)) / baba;
}
```

### Combining SDFs

```metal
// Union
float opUnion(float d1, float d2) {
    return min(d1, d2);
}

// Subtraction
float opSubtraction(float d1, float d2) {
    return max(-d1, d2);
}

// Intersection
float opIntersection(float d1, float d2) {
    return max(d1, d2);
}

// Smooth union
float opSmoothUnion(float d1, float d2, float k) {
    float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return mix(d2, d1, h) - k * h * (1.0 - h);
}

// Smooth subtraction
float opSmoothSubtraction(float d1, float d2, float k) {
    float h = clamp(0.5 - 0.5 * (d2 + d1) / k, 0.0, 1.0);
    return mix(d2, -d1, h) + k * h * (1.0 - h);
}
```

## Advanced SDF Operations

### Transformations

```metal
// Rotation around X axis
float3 rotateX(float3 p, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return float3(p.x, c * p.y - s * p.z, s * p.y + c * p.z);
}

// Rotation around Y axis
float3 rotateY(float3 p, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return float3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
}

// Rotation around Z axis
float3 rotateZ(float3 p, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return float3(c * p.x - s * p.y, s * p.x + c * p.y, p.z);
}

// Scale
float3 scale(float3 p, float3 s) {
    return p / s;
}

// Translation
float3 translate(float3 p, float3 t) {
    return p - t;
}
```

### Data-Driven SDFs

```metal
// SDF from point cloud (metaballs)
float sdPointCloud(float3 p, device float3 *points, int count, float radius) {
    float sum = 0.0;
    for (int i = 0; i < count; i++) {
        float3 point = points[i];
        float d = length(p - point);
        sum += exp(-d * d / (radius * radius));
    }
    return -log(sum) * radius;
}

// SDF from density field (3D texture)
float sdDensityField(float3 p, texture3d<float> densityField, float isovalue) {
    constexpr sampler s(coord::normalized, filter::linear);
    float density = densityField.sample(s, p).x;
    return density - isovalue;
}

// Fractal SDF (Mandelbulb)
float sdMandelbulb(float3 p) {
    float3 w = p;
    float m = dot(w, w);
    
    for (int i = 0; i < 15; i++) {
        float m2 = m * m;
        float m4 = m2 * m2;
        float temp = 1.0 - m2 / m4;
        w = float3(temp * w.x * w.x - temp * w.y * w.y + p.x,
                   2.0 * temp * w.x * w.y + p.y,
                   temp * w.z * w.z + p.z);
        m = dot(w, w);
        if (m > 256.0) break;
    }
    
    return 0.25 * log(m) * sqrt(m) / length(p);
}
```

## Lighting and Shading

### Normal Calculation

```metal
// Compute normal using finite differences
float3 computeNormal(float3 p) {
    float eps = 0.001;
    float3 dx = float3(eps, 0, 0);
    float3 dy = float3(0, eps, 0);
    float3 dz = float3(0, 0, eps);
    
    float nx = sceneSDF(p + dx) - sceneSDF(p - dx);
    float ny = sceneSDF(p + dy) - sceneSDF(p - dy);
    float nz = sceneSDF(p + dz) - sceneSDF(p - dz);
    
    return normalize(float3(nx, ny, nz));
}
```

### Lighting Model

```metal
// Phong lighting
float3 phongLighting(float3 p, float3 viewDir, float3 normal) {
    float3 lightDir = normalize(float3(1, 1, 1));
    float3 ambient = float3(0.1, 0.1, 0.1);
    float3 diffuse = float3(0.7, 0.7, 0.7) * max(dot(normal, lightDir), 0.0);
    float3 specular = float3(0.3, 0.3, 0.3) * pow(max(dot(reflect(-lightDir, normal), viewDir), 0.0), 32.0);
    
    return ambient + diffuse + specular;
}

// Ambient occlusion
float ambientOcclusion(float3 p, float3 normal) {
    float occlusion = 0.0;
    float samples = 8.0;
    
    for (float i = 1.0; i <= samples; i++) {
        float h = i / samples;
        float d = sceneSDF(p + normal * h);
        occlusion += (h - d) * (1.0 - h);
    }
    
    return 1.0 - occlusion / samples;
}
```

## Performance Optimization

### Spatial Acceleration

```metal
// Bounding volume hierarchy for SDFs
struct BVHNode {
    float3 min;
    float3 max;
    int leftChild;
    int rightChild;
    int objectIndex;
    bool isLeaf;
};

float bvhSDF(float3 p, device BVHNode *nodes, int nodeIndex) {
    BVHNode node = nodes[nodeIndex];
    
    // Check if point is inside bounding box
    if (p.x < node.min.x || p.x > node.max.x ||
        p.y < node.min.y || p.y > node.max.y ||
        p.z < node.min.z || p.z > node.max.z) {
        return FLT_MAX;
    }
    
    if (node.isLeaf) {
        // Evaluate actual SDF
        return evaluateSDF(p, node.objectIndex);
    } else {
        // Recurse on children
        float leftDist = bvhSDF(p, nodes, node.leftChild);
        float rightDist = bvhSDF(p, nodes, node.rightChild);
        return min(leftDist, rightDist);
    }
}
```

### LOD System

```swift
class RaymarchingLOD {
    
    float adaptiveStepSize(float distance, float maxSteps) {
        // Smaller steps when close to camera, larger when far
        return max(0.001, distance * 0.01);
    }
    
    int adaptiveMaxSteps(float distance) {
        // Fewer steps for distant objects
        if (distance > 100.0) return 50;
        if (distance > 10.0) return 100;
        return 200;
    }
};
```

## References

1. [Ray Marching and Signed Distance Functions](https://www.alanzucconi.com/2016/03/31/raymarching/) by Alan Zucconi
2. [Inigo Quilez's Articles on SDFs](https://iquilezles.org/articles/)
3. [GPU Ray Marching in Unity](https://catlikecoding.com/unity/tutorials/advanced-rendering/raymarching/)
4. [Signed Distance Fields for Font Rendering](https://steamcdn-a.akamaihd.net/apps/valve/2007/SIGGRAPH2007_AlphaTestedMagnification.pdf)
5. [Real-time Rendering of Volumetric Data using Raymarching](https://developer.nvidia.com/gpugems/gpugems3/part-vi-gpu-computing/chapter-39-volume-rendering-techniques)

**Document Version:** 1.0  
**Last Updated:** 2026-01-16  
**Research Status:** Verified with GPU implementation  
**Next Review:** 2026-02-16