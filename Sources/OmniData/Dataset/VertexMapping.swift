import Foundation

/// Describes how dataset columns become per-vertex attributes.
///
/// Each emitted vertex is a `SIMD4<Float>`: `xyz` = position, `w` = scalar value
/// (fed through a transfer function for colour). Positions are normalised into
/// `[-1, 1]` and the value into `[0, 1]` unless `normalize` is false.
public struct VertexMapping: Equatable, Sendable {
    public var x: String
    public var y: String
    public var z: String?
    public var value: String?
    public var normalize: Bool

    public init(x: String, y: String, z: String? = nil, value: String? = nil, normalize: Bool = true) {
        self.x = x; self.y = y; self.z = z; self.value = value; self.normalize = normalize
    }

    /// Rows where any mapped column is NaN are dropped.
    public func vertices(from dataset: some Dataset) throws -> [SIMD4<Float>] {
        func col(_ name: String) throws -> [Float] {
            guard let c = dataset.column(named: name) else { throw DatasetError.missingColumn(name) }
            guard let f = c.floats else { throw DatasetError.nonNumericColumn(name) }
            return f
        }
        let xs = try col(x), ys = try col(y)
        let zs = try z.map(col) ?? Array(repeating: 0, count: dataset.rowCount)
        let vs = try value.map(col) ?? Array(repeating: 1, count: dataset.rowCount)

        func scaler(_ v: [Float], to lo: Float, _ hi: Float) -> (Float) -> Float {
            guard normalize else { return { $0 } }
            let finite = v.filter { $0.isFinite }
            guard let mn = finite.min(), let mx = finite.max(), mx > mn else { return { _ in (lo + hi) / 2 } }
            return { lo + ($0 - mn) / (mx - mn) * (hi - lo) }
        }
        let sx = scaler(xs, to: -1, 1), sy = scaler(ys, to: -1, 1)
        let sz = z == nil ? { _ in 0 } : scaler(zs, to: -1, 1)
        let sv = value == nil ? { _ in 1 } : scaler(vs, to: 0, 1)

        var out: [SIMD4<Float>] = []
        out.reserveCapacity(dataset.rowCount)
        for i in 0..<dataset.rowCount {
            let r = (xs[i], ys[i], zs[i], vs[i])
            guard r.0.isFinite, r.1.isFinite, r.2.isFinite, r.3.isFinite else { continue }
            out.append(SIMD4(sx(r.0), sy(r.1), sz(r.2), sv(r.3)))
        }
        return out
    }
}
