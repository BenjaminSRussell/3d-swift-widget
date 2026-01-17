# Omni-Optimization Architecture

The **Omni-Optimization** high-performance library is designed to shift the focus from writing "features" to building robust "systems." It provides centralized mechanisms for memory management, compute scheduling, and visual fidelity that any component in the project can leverage.

## Structure

### 📁 Memory (The Zero-Copy Sub-System)
Located at `Sources/OmniCore/Optimization/Memory`

- **ArenaAllocator**: Reduces allocation overhead by pre-allocating large memory chunks and handing out slices.
- **TripleBufferManager**: Coordinates CPU/GPU frame synchronization to eliminate micro-stutters.
- **UnifiedMemoryStream**: Maps data directly from the Neural Engine to the GPU on Apple Silicon, bypassing the CPU.

### 📁 Compute (The Logic Sub-System)
Located at `Sources/OmniCore/Optimization/Compute`

- **TileBasedCulling**: Divides the screen into tiles and instructs the GPU to skip empty ones.
- **AsyncComputeScheduler**: Manages background threads for heavy mathematical operations (like topography generation) to keep the UI responsive.
- **GPUOccupancyManager**: Monitors GPU load and dynamically adjusts resolution to maintain frame rates.

### 📁 Visuals (The Detail Sub-System)
Located at `Sources/OmniCore/Optimization/Visuals`

- **TemporalAntiAliasing (TAA)**: Blends frames to smooth edges.
- **RayMarchingAccelerator**: Optimizes ray marching with distance fields.
- **VariableRateShading**: Optimizes rendering performance by varying resolution based on content importance.

## Usage

Import the `OmniCore` module to access these optimization tools.

```swift
import OmniCore
// Usage examples will be added as implementations are finalized.
```
