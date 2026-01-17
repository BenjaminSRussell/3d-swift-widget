// #pragma once removed
#include <metal_stdlib>
using namespace metal;

// MARK: - Constants
constant float PI = 3.14159265358979323846;
constant float TWO_PI = 6.28318530717958647692;

// MARK: - Random Number Generation
// Gold Noise or PCG Hash for high quality, fast random numbers on GPU.
inline float rand_hash(uint2 p) {
    return fract(sin(dot(float2(p), float2(12.9898, 78.233))) * 43758.5453);
}

// MARK: - Packing
inline uint pack_float_to_unorm16(float2 v) {
    uint2 packed = uint2(saturate(v) * 65535.0);
    return (packed.y << 16) | packed.x;
}

inline float2 unpack_unorm16_to_float(uint p) {
    float2 v;
    v.x = float(p & 0xFFFF);
    v.y = float(p >> 16);
    return v / 65535.0;
}

// MARK: - Safe Atomics
// Metal atomic_fetch_add only supports int/uint.
// For floats, we use a CAS loop (Compare-And-Swap).
inline void atomic_add_float(device atomic_uint* address, float value) {
    uint old_int = atomic_load_explicit(address, memory_order_relaxed);
    while (true) {
        float old_float = as_type<float>(old_int);
        float new_float = old_float + value;
        uint new_int = as_type<uint>(new_float);
        if (atomic_compare_exchange_weak_explicit(address, &old_int, new_int, memory_order_relaxed, memory_order_relaxed)) {
            break;
        }
    }
}
