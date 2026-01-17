import XCTest
import Metal
@testable import OmniCore

final class ComputeTests: XCTestCase {
    
    func testComputePipelineCreation() {
        guard MTLCreateSystemDefaultDevice() != nil else { return }
        
        // This should not throw if the metallib is found and the kernel exists
        XCTAssertNoThrow(try ComputeKernel(functionName: "test_compute"))
    }
    
    func testComputeDispatch() {
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        
        do {
            let kernel = try ComputeKernel(functionName: "test_compute")
            let buffer = device.makeBuffer(length: 64 * MemoryLayout<Float>.stride, options: .storageModeShared)!
            
            let cmdBuffer = GPUContext.shared.commandQueue.makeCommandBuffer()!
            let encoder = cmdBuffer.makeComputeCommandEncoder()!
            
            encoder.setBuffer(buffer, offset: 0, index: 0)
            kernel.dispatch(encoder: encoder, gridSize: MTLSize(width: 64, height: 1, depth: 1))
            
            encoder.endEncoding()
            cmdBuffer.commit()
            cmdBuffer.waitUntilCompleted()
            
            // Verify results
            let ptr = buffer.contents().bindMemory(to: Float.self, capacity: 64)
            XCTAssertNotEqual(ptr[0], 0.0) // Should have written a random hash
            
        } catch {
            XCTFail("Compute Failure: \(error)")
        }
    }
}
