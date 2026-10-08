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
            // Sentinel so we can tell the kernel actually wrote every element.
            let input = buffer.contents().bindMemory(to: Float.self, capacity: 64)
            for i in 0..<64 { input[i] = -1 }
            
            let cmdBuffer = GPUContext.shared.commandQueue.makeCommandBuffer()!
            let encoder = cmdBuffer.makeComputeCommandEncoder()!
            
            encoder.setBuffer(buffer, offset: 0, index: 0)
            kernel.dispatch(encoder: encoder, gridSize: MTLSize(width: 64, height: 1, depth: 1))
            
            encoder.endEncoding()
            cmdBuffer.commit()
            cmdBuffer.waitUntilCompleted()
            
            // Verify results
            // rand_hash(uint2(0, 0)) is fract(sin(0) * k) == 0, so check the whole buffer instead
            // of element 0: every value must be overwritten with a hash in [0, 1), and they vary.
            let values = Array(UnsafeBufferPointer(start: buffer.contents().bindMemory(to: Float.self, capacity: 64), count: 64))
            XCTAssertTrue(values.allSatisfy { $0 >= 0 && $0 < 1 }, "kernel should write a hash in [0, 1) to every element")
            XCTAssertGreaterThan(Set(values).count, 32, "hash output should vary across threads")
            
        } catch {
            XCTFail("Compute Failure: \(error)")
        }
    }
}
