import XCTest
import Metal
@testable import OmniCore
import OmniStochastic

/// GPU performance smoke tests. Skipped when no Metal device is available
/// (e.g. headless CI without a paravirtualized GPU).
final class HDTEPerformanceTests: XCTestCase {

    private func requireDevice() throws -> MTLDevice {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device not available")
        }
        return device
    }

    func testParticleSystemAllocationPerformance() throws {
        let device = try requireDevice()
        let particleCount = 10_000 // stays well inside the 20 MB GlobalHeap

        measure(metrics: [XCTClockMetric()]) {
            let system = ParticleSystem(device: device, maxParticles: particleCount)
            XCTAssertEqual(system.maxParticles, particleCount)
            XCTAssertGreaterThanOrEqual(system.positionBuffer.length,
                                        particleCount * MemoryLayout<SIMD3<Float>>.stride)
        }
    }

    func testMemoryBandwidth() throws {
        let device = try requireDevice()
        let context = MetalContext.shared
        let size = 16 * 1024 * 1024 // 16 MB keeps CI fast
        guard let source = device.makeBuffer(length: size, options: .storageModeShared),
              let dest = device.makeBuffer(length: size, options: .storageModePrivate) else {
            throw XCTSkip("Could not allocate benchmark buffers")
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
