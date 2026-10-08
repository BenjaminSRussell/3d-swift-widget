#if canImport(Metal)
import XCTest
import Metal
import OmniData
@testable import OmniWidgets

/// #7: simulated device loss either recovers (new generation, ready) or ends in the fallback
/// state that drives the banner. #3: the demo renderer draws a non-blank frame.
@MainActor
final class DeviceLossTests: XCTestCase {
    private func fixtureBuffer(device: MTLDevice?) throws -> DatasetBuffer {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "elevation_sample", withExtension: "csv", subdirectory: "Fixtures"))
        return try DatasetBuffer(contentsOf: url, mapping: VertexMapping(x: "lon", y: "lat", z: "elevation_m", value: "elevation_m"), device: device)
    }

    func testSimulatedResetRecoversWithNewGeneration() async throws {
        guard MTLCreateSystemDefaultDevice() != nil else { throw XCTSkip("No Metal device") }
        let monitor = GPUHealthMonitor(retryDelay: .milliseconds(1), observeSystemDevices: false)
        XCTAssertTrue(monitor.state.isReady)
        XCTAssertEqual(monitor.generation, 0)
        monitor.simulateDeviceLoss()
        XCTAssertNil(monitor.device)
        await monitor.waitForRecovery()
        XCTAssertTrue(monitor.state.isReady)
        XCTAssertEqual(monitor.generation, 1)
        XCTAssertNotNil(monitor.device)
        XCTAssertTrue(monitor.events.contains { $0.hasPrefix("Recovered on") })
    }

    func testPermanentLossFallsBackAndShowsBannerThenRetryRecovers() async throws {
        guard MTLCreateSystemDefaultDevice() != nil else { throw XCTSkip("No Metal device") }
        let monitor = GPUHealthMonitor(maxRecoveryAttempts: 2, retryDelay: .milliseconds(1), observeSystemDevices: false)
        let scene = ResilientDatasetScene(buffer: try fixtureBuffer(device: nil), monitor: monitor)
        XCTAssertNil(scene.bannerText)

        monitor.simulateDeviceLoss(permanently: true)
        await monitor.waitForRecovery()
        XCTAssertEqual(monitor.state, .fallback(reason: "Simulated permanent device loss"))
        XCTAssertEqual(scene.bannerText?.hasPrefix("GPU unavailable"), true)

        monitor.retry()
        await monitor.waitForRecovery()
        XCTAssertTrue(monitor.state.isReady)
        XCTAssertNil(scene.bannerText)
    }

    func testNoDeviceStartsInFallback() async {
        let monitor = GPUHealthMonitor(deviceProvider: { nil }, maxRecoveryAttempts: 1,
                                       retryDelay: .milliseconds(1), observeSystemDevices: false)
        XCTAssertEqual(monitor.state, .fallback(reason: "No Metal device available"))
        monitor.reportFailure("command buffer error: test")
        await monitor.waitForRecovery()
        XCTAssertEqual(monitor.state, .fallback(reason: "command buffer error: test"))
    }

    func testFlakyProviderRecoversOnLaterAttempt() async throws {
        guard let real = MTLCreateSystemDefaultDevice() else { throw XCTSkip("No Metal device") }
        var calls = 0
        let monitor = GPUHealthMonitor(deviceProvider: {
            calls += 1
            return calls == 1 || calls >= 4 ? real : nil // initial OK, then two failed attempts
        }, maxRecoveryAttempts: 3, retryDelay: .milliseconds(1), observeSystemDevices: false)
        monitor.reportFailure("GPU timeout: test")
        await monitor.waitForRecovery()
        XCTAssertTrue(monitor.state.isReady)
        XCTAssertTrue(monitor.events.contains("Recovered on \(real.name) (attempt 3)"))
    }

    func testDemoRendererDrawsNonBlankFrameAndRebuildsAfterRecovery() async throws {
        let monitor = GPUHealthMonitor(retryDelay: .milliseconds(1), observeSystemDevices: false)
        guard let device = monitor.device else { throw XCTSkip("No Metal device") }
        let buffer = try fixtureBuffer(device: device)
        func litPixels(_ dev: MTLDevice) throws -> Int {
            let px = try DatasetPointRenderer(device: dev, buffer: buffer).renderOffscreen(width: 128, height: 128, time: 1)
            return stride(from: 0, to: px.count, by: 4).filter { px[$0] > 8 || px[$0 + 1] > 8 || px[$0 + 2] > 8 }.count
        }
        XCTAssertGreaterThan(try litPixels(device), 20, "Demo scene rendered a blank frame")

        monitor.simulateDeviceLoss()
        await monitor.waitForRecovery()
        let recovered = try XCTUnwrap(monitor.device)
        XCTAssertGreaterThan(try litPixels(recovered), 20, "No frame after recovery")
    }
}
#endif
