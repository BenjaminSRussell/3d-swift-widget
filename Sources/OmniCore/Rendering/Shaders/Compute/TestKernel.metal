#include <metal_stdlib>
#include "../Shared/OmniMath.metal"

using namespace metal;

// Phase 3 Verification Kernel
// Just writes a value to a buffer to prove execution.
kernel void test_compute(device float *result [[buffer(0)]],
                         uint id [[thread_position_in_grid]]) {
    // Test OmniMath inclusion
    float r = rand_hash(uint2(id, 0)); 
    result[id] = r;
}
