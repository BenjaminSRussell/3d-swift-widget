#if canImport(Metal)
import XCTest
import SwiftUI
import OmniData
@testable import OmniWidgets

/// Acceptance for #4: the fixture CSV goes through OmniData into a buffer that a widget renders.
final class DatasetWidgetTests: XCTestCase {
    func testFixtureCSVFeedsScatterWidget() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "elevation_sample", withExtension: "csv", subdirectory: "Fixtures"))
        let buffer = try DatasetBuffer(contentsOf: url,
                                       mapping: VertexMapping(x: "lon", y: "lat", z: "elevation_m", value: "temp_c"))
        XCTAssertEqual(buffer.vertexCount, 4)

        let widget = DatasetScatterWidget(buffer: buffer, rotates: false)
        let size = CGSize(width: 200, height: 200)
        let points = DatasetScatterWidget.project(widget.buffer.vertices, in: size, yaw: 0.6)
        XCTAssertEqual(points.count, 4)
        for p in points {
            XCTAssert(CGRect(origin: .zero, size: size).contains(p.position), "\(p.position) off-canvas")
        }
        XCTAssertEqual(points.map(\.depth), points.map(\.depth).sorted(by: >))

        // The factory routes dataset buffers to the scatter widget.
        _ = StandardWidgetFactory.shared.makeWidget(for: .dataset(buffer), style: .flat)
    }
}
#endif
