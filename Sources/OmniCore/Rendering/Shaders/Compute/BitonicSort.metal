#include <metal_stdlib>
using namespace metal;

// Phase 4.3: Bitonic Sort
// Massively parallel sort for particle cell indices.

kernel void bitonic_sort(device uint *keys [[buffer(0)]],
                         device uint *values [[buffer(1)]],
                         constant uint &p [[buffer(2)]],
                         constant uint &q [[buffer(3)]],
                         uint id [[thread_position_in_grid]]) {
    
    uint i = id;
    uint dist = 1 << (p - q);
    bool direction = ((i >> p) & 1) == 0;
    
    uint j = i ^ dist;
    
    if (j > i) {
        uint key_i = keys[i];
        uint key_j = keys[j];
        
        bool swap = false;
        if (direction) {
            if (key_i > key_j) swap = true;
        } else {
            if (key_i < key_j) swap = true;
        }
        
        if (swap) {
            keys[i] = key_j;
            keys[j] = key_i;
            
            uint val_i = values[i];
            uint val_j = values[j];
            values[i] = val_j;
            values[j] = val_i;
        }
    }
}
