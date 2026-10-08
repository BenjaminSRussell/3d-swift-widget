import XCTest
@testable import OmniData

final class DatasetLoaderTests: XCTestCase {
    private func fixture(_ name: String, _ ext: String) throws -> URL {
        try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures"))
    }

    func testFixtureCSVRowCountAndFloatColumns() throws {
        let ds = try DatasetLoading.load(contentsOf: fixture("elevation_sample", "csv"))
        XCTAssertEqual(ds.name, "elevation_sample")
        XCTAssertEqual(ds.rowCount, 5)
        XCTAssertEqual(ds.columnNames, ["station", "lon", "lat", "elevation_m", "temp_c"])
        XCTAssertEqual(ds.floats("elevation_m"), [512.5, 430.0, 120.25, 95.0, 388.75])
        XCTAssertEqual(ds.floats("lon")?.first ?? 0, -72.10, accuracy: 1e-5)
        XCTAssertEqual(ds.column(named: "station"),
                       .text(["Summit, North", "Ridge", "Valley", "Lake \"Clear\"", "Mesa"]))
        // Empty numeric cell is NaN, column still numeric.
        let temp = try XCTUnwrap(ds.floats("temp_c"))
        XCTAssertEqual(Array(temp.prefix(4)), [8.25, 9.5, 12.75, 13.0])
        XCTAssertTrue(temp[4].isNaN)
        XCTAssertEqual(ds.range(of: "elevation_m"), 95.0...512.5)
    }

    func testFixtureJSONTableMatchesCSV() throws {
        let ds = try DatasetLoading.load(contentsOf: fixture("elevation_sample", "json"))
        XCTAssertEqual(ds.rowCount, 3)
        XCTAssertEqual(ds.floats("elevation_m"), [512.5, 430.0, 120.25])
        XCTAssertEqual(ds.column(named: "station")?.count, 3)
    }

    func testJSONArrayOfObjects() throws {
        let json = #"[{"x": 1, "y": 2.5, "tag": "a", "ok": true}, {"x": 3, "y": -1, "tag": "b", "ok": false}]"#
        let ds = try JSONDatasetLoader().load(data: Data(json.utf8), name: "objs")
        XCTAssertEqual(ds.rowCount, 2)
        XCTAssertEqual(ds.floats("x"), [1, 3])
        XCTAssertEqual(ds.floats("y"), [2.5, -1])
        XCTAssertEqual(ds.column(named: "ok"), .text(["true", "false"]))
    }

    func testCSVHandlesCRLFBlankLinesAndBOM() throws {
        let csv = "\u{FEFF}a,b\r\n1,2\r\n\r\n3,\"multi\nline\"\r\n"
        let ds = try CSVDatasetLoader().load(data: Data(csv.utf8), name: "t")
        XCTAssertEqual(ds.rowCount, 2)
        XCTAssertEqual(ds.floats("a"), [1, 3])
        XCTAssertEqual(ds.column(named: "b"), .text(["2", "multi\nline"]))
    }

    func testCSVErrors() {
        XCTAssertThrowsError(try CSVDatasetLoader().load(data: Data("a,b\n1\n".utf8), name: "t")) {
            XCTAssertEqual($0 as? DatasetError, .rowWidth(row: 2, expected: 2, found: 1))
        }
        XCTAssertThrowsError(try CSVDatasetLoader().load(data: Data("a,a\n1,2\n".utf8), name: "t")) {
            XCTAssertEqual($0 as? DatasetError, .duplicateColumn("a"))
        }
        XCTAssertThrowsError(try CSVDatasetLoader().load(data: Data("a\n\"oops\n".utf8), name: "t")) {
            XCTAssertEqual($0 as? DatasetError, .unterminatedQuote(row: 2))
        }
        XCTAssertThrowsError(try CSVDatasetLoader().load(data: Data(), name: "t")) {
            XCTAssertEqual($0 as? DatasetError, .empty)
        }
        XCTAssertThrowsError(try DatasetLoading.load(contentsOf: URL(fileURLWithPath: "/tmp/x.parquet"))) {
            XCTAssertEqual($0 as? DatasetError, .unsupportedFormat("parquet"))
        }
    }

    func testVertexMappingNormalisesAndDropsNaNRows() throws {
        let ds = try DatasetLoading.load(contentsOf: fixture("elevation_sample", "csv"))
        let verts = try VertexMapping(x: "lon", y: "lat", z: "elevation_m", value: "temp_c").vertices(from: ds)
        XCTAssertEqual(verts.count, 4) // Mesa has no temp_c
        XCTAssertEqual(verts[0].x, -1, accuracy: 1e-5)          // westmost lon
        XCTAssertEqual(verts[0].z, 1, accuracy: 1e-5)           // highest elevation
        XCTAssertEqual(verts[0].w, 0, accuracy: 1e-5)           // coldest
        XCTAssertEqual(verts[3].w, 1, accuracy: 1e-5)           // warmest
        for v in verts { XCTAssert((-1...1).contains(v.x) && (-1...1).contains(v.y) && (0...1).contains(v.w)) }

        let raw = try VertexMapping(x: "lon", y: "lat", normalize: false).vertices(from: ds)
        XCTAssertEqual(raw.count, 5)
        XCTAssertEqual(raw[2], SIMD4<Float>(-72.0, 41.78, 0, 1))

        XCTAssertThrowsError(try VertexMapping(x: "station", y: "lat").vertices(from: ds)) {
            XCTAssertEqual($0 as? DatasetError, .nonNumericColumn("station"))
        }
        XCTAssertThrowsError(try VertexMapping(x: "nope", y: "lat").vertices(from: ds)) {
            XCTAssertEqual($0 as? DatasetError, .missingColumn("nope"))
        }
    }
}
