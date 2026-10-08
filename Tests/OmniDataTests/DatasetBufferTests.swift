#if canImport(Metal)
import XCTest
import Metal
@testable import OmniData

final class DatasetBufferTests: XCTestCase {
    func testFixtureCSVUploadsToMTLBuffer() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("No Metal device") }
        let url = try XCTUnwrap(Bundle.module.url(forResource: "elevation_sample", withExtension: "csv", subdirectory: "Fixtures"))
        let buf = try DatasetBuffer(contentsOf: url, mapping: VertexMapping(x: "lon", y: "lat", z: "elevation_m"), device: device)
        XCTAssertEqual(buf.vertexCount, 5)
        let mtl = try XCTUnwrap(buf.buffer)
        XCTAssertEqual(mtl.length, 5 * DatasetBuffer.stride)
        let gpu = mtl.contents().bindMemory(to: SIMD4<Float>.self, capacity: 5)
        for i in 0..<5 { XCTAssertEqual(gpu[i], buf.vertices[i]) }
    }

    func testNoDeviceKeepsCPUVertices() throws {
        let ds = try CSVDatasetLoader().load(data: Data("x,y\n0,0\n2,4\n".utf8), name: "t")
        let buf = try DatasetBuffer(dataset: ds, mapping: VertexMapping(x: "x", y: "y"), device: nil)
        XCTAssertNil(buf.buffer)
        XCTAssertEqual(buf.vertices, [SIMD4(-1, -1, 0, 1), SIMD4(1, 1, 0, 1)])
    }
}
#endif
