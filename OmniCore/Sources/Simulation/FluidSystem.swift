import Metal
import OmniCoreTypes

/// Phase 9.1: Fluid System
/// Manages height and flux buffers for topography-aware fluid simulation.
public final class FluidSystem {
    
    public let gridRes: SIMD2<Int>
    public let heightBuffer: MTLBuffer
    public let fluxBuffer: MTLBuffer // Left, Right, Up, Down flux per cell
    
    public init(device: MTLDevice, width: Int, height: Int) {
        self.gridRes = SIMD2(width, height)
        let totalCells = width * height
        
        // Height buffer: one float per cell
        guard let hBuf = GlobalHeap.shared.allocateBuffer(length: totalCells * MemoryLayout<Float>.stride, options: .storageModePrivate),
              let fBuf = GlobalHeap.shared.allocateBuffer(length: totalCells * MemoryLayout<SIMD4<Float>>.stride, options: .storageModePrivate) else {
            fatalError("Failed to allocate FluidSystem buffers")
        }
        
        self.heightBuffer = hBuf
        self.fluxBuffer = fBuf
        
        self.heightBuffer.label = "Fluid Heights"
        self.fluxBuffer.label = "Fluid Flux"
    }
}
