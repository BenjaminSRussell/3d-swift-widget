import Foundation
import Metal

/// GPU-ready vertices for a dataset: one `SIMD4<Float>` (xyz position, w value) per row.
/// `vertices` stays on the CPU for SwiftUI/Canvas widgets; `buffer` is a shared-storage
/// `MTLBuffer` with the same contents for Metal render or compute passes.
public final class DatasetBuffer {
    public let datasetName: String
    public let mapping: VertexMapping
    public let vertices: [SIMD4<Float>]
    public let buffer: MTLBuffer?

    public var vertexCount: Int { vertices.count }
    public static let stride = MemoryLayout<SIMD4<Float>>.stride

    public init(dataset: some Dataset, mapping: VertexMapping, device: MTLDevice? = MTLCreateSystemDefaultDevice()) throws {
        self.datasetName = dataset.name
        self.mapping = mapping
        let verts = try mapping.vertices(from: dataset)
        self.vertices = verts
        if let device, !verts.isEmpty {
            self.buffer = verts.withUnsafeBytes {
                device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)
            }
            self.buffer?.label = "OmniData.\(dataset.name)"
        } else {
            self.buffer = nil
        }
    }

    /// Convenience: load a CSV/TSV/JSON file and map it in one step.
    public convenience init(contentsOf url: URL, mapping: VertexMapping, device: MTLDevice? = MTLCreateSystemDefaultDevice()) throws {
        try self.init(dataset: DatasetLoading.load(contentsOf: url), mapping: mapping, device: device)
    }
}
