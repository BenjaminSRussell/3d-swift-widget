import XCTest
import Metal
@testable import OmniCore

final class HDTEPerformanceTests: XCTestCase {
    
    var context: MetalContext!
    
    override func setUp() {
        super.setUp()
        // Ensure we have a Metal device (might fail on some CI, but this is for local perf testing)
        context = MetalContext.shared 
        // We will skip if device not available
        if context == nil {
            try? XCTSkipIf(true, "Metal Context not available")
        }
    }
    
    func testParticleSimulationPerformance() throws {
        // Measure time to dispatch 100 iterations of particle updates
        let particleCount = 1_000_000 // Target 1M
        // Note: Performance test requires GPU. If Context fails, we skip.
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        
        // Use the high-level orchestrator we just restored
        let system = try HDTEParticleSystem(count: particleCount)
        
        // Wait for pipeline creation
        let expectation = self.expectation(description: "Simulation Complete")
        
        let measureOptions = XCTMeasureOptions()
        measureOptions.iterationCount = 5
        
        measure(metrics: [XCTClockMetric()], options: measureOptions) {
            let start = CACurrentMediaTime()
            
            // Run 60 frames of simulation
            for _ in 0..<60 {
                system.update(deltaTime: 0.016)
            }
            
            // Wait for GPU to finish (Blocking for test measurement purposes)
            // Real application would not block, but we need to measure "Throughput"
            if let commandBuffer = context.makeCommandBuffer() {
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
            }
            
            let end = CACurrentMediaTime()
            let duration = end - start
            
            // 60 frames in < 0.5s = >120FPS capability
            // But we actually just want to measure the raw compute time
            // XCTest will report the average time.
        }
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testMemoryBandwidth() {
        // Measure 1GB Buffer Copy
        let size = 100 * 1024 * 1024 // 100MB for quick test
        guard let source = context.device.makeBuffer(length: size, options: .storageModeShared),
              let dest = context.device.makeBuffer(length: size, options: .storageModePrivate) else {
            XCTFail("Failed to allocate buffers")
            return
        }
        
        measure(metrics: [XCTClockMetric()]) {
            guard let commandBuffer = context.makeCommandBuffer(),
                  let encoder = commandBuffer.makeBlitCommandEncoder() else { return }
            
            encoder.copy(from: source, sourceOffset: 0, to: dest, destinationOffset: 0, size: size)
            encoder.endEncoding()
            
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
    }
}
