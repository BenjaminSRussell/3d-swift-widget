#include <metal_stdlib>
using namespace metal;

struct ICBMeshCommand {
    uint command; // placeholder, structure depends on encoding. 
    // Metal shading language has dedicated `command_buffer` type for this
};

struct ICBContainer {
    command_buffer icb [[id(0)]];
};

// "Genesis" Kernel: Writes draw commands to the ICB
kernel void update_icb(
    device uint* visible_count [[buffer(0)]],
    constant ICBContainer& container [[buffer(1)]], 
    uint tid [[thread_position_in_grid]]
) {
    command_buffer icb = container.icb;
    // Only thread 0 writes the command in this simplified demo
    // In reality, each thread could write a command for a different object
    if (tid == 0) {
        // Get a handle to the draw command at index 0
        render_command cmd(icb, 0);
        
        // Culling Logic (GPU Autonomy)
        // If *visible_count > 0 ...
        
        // Encode "drawMeshThreadgroups"
        cmd.draw_mesh_threadgroups(
            uint3(1, 1, 1), // threadsPerObjectThreadgroup
            uint3(128, 1, 1), // threadsPerMeshThreadgroup (lid budget)
            uint3(1000, 1, 1) // threadgroupsPerGrid (1000 points)
        );
    }
}
