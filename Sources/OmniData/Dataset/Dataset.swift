import Foundation

/// A column of tabular data. Numeric columns are stored as `Float` so they can be
/// uploaded to the GPU without conversion; anything else is kept as text.
public enum DatasetColumn: Equatable, Sendable {
    case numeric([Float])
    case text([String])

    public var count: Int {
        switch self {
        case .numeric(let v): return v.count
        case .text(let v): return v.count
        }
    }

    public var floats: [Float]? {
        if case .numeric(let v) = self { return v }
        return nil
    }
}

/// Anything that can present itself as named, equal-length columns.
public protocol Dataset: Sendable {
    var name: String { get }
    var columnNames: [String] { get }
    var rowCount: Int { get }
    func column(named: String) -> DatasetColumn?
}

public extension Dataset {
    /// Float values for a numeric column, or `nil` if the column is missing or textual.
    func floats(_ name: String) -> [Float]? { column(named: name)?.floats }

    /// Inclusive min/max of a numeric column.
    func range(of name: String) -> ClosedRange<Float>? {
        guard let v = floats(name), let lo = v.min(), let hi = v.max() else { return nil }
        return lo...hi
    }
}

/// In-memory column store produced by the loaders.
public struct TabularDataset: Dataset, Equatable {
    public let name: String
    public let columnNames: [String]
    public let columns: [String: DatasetColumn]
    public let rowCount: Int

    public init(name: String, columnNames: [String], columns: [String: DatasetColumn]) throws {
        let counts = Set(columnNames.compactMap { columns[$0]?.count })
        guard counts.count <= 1, columnNames.allSatisfy({ columns[$0] != nil }) else {
            throw DatasetError.raggedColumns
        }
        self.name = name
        self.columnNames = columnNames
        self.columns = columns
        self.rowCount = counts.first ?? 0
    }

    public func column(named: String) -> DatasetColumn? { columns[named] }

    /// Builds columns from string cells, typing a column as numeric when every
    /// non-empty cell parses as a number. Empty numeric cells become `.nan`.
    static func infer(name: String, header: [String], rows: [[String]]) throws -> TabularDataset {
        var columns: [String: DatasetColumn] = [:]
        for (i, col) in header.enumerated() {
            let cells = rows.map { i < $0.count ? $0[i].trimmingCharacters(in: .whitespaces) : "" }
            let parsed = cells.map { $0.isEmpty ? Float.nan : Float($0) }
            let hasValue = cells.contains { !$0.isEmpty }
            if hasValue, parsed.allSatisfy({ $0 != nil }) {
                columns[col] = .numeric(parsed.map { $0! })
            } else {
                columns[col] = .text(cells)
            }
        }
        return try TabularDataset(name: name, columnNames: header, columns: columns)
    }
}

public enum DatasetError: Error, Equatable, CustomStringConvertible {
    case empty
    case duplicateColumn(String)
    case rowWidth(row: Int, expected: Int, found: Int)
    case unterminatedQuote(row: Int)
    case unsupportedJSON(String)
    case raggedColumns
    case missingColumn(String)
    case nonNumericColumn(String)
    case unsupportedFormat(String)

    public var description: String {
        switch self {
        case .empty: return "Dataset has no header row"
        case .duplicateColumn(let c): return "Duplicate column '\(c)'"
        case .rowWidth(let r, let e, let f): return "Row \(r) has \(f) fields, expected \(e)"
        case .unterminatedQuote(let r): return "Unterminated quoted field starting on row \(r)"
        case .unsupportedJSON(let why): return "Unsupported JSON layout: \(why)"
        case .raggedColumns: return "Columns have different lengths"
        case .missingColumn(let c): return "Column '\(c)' not found"
        case .nonNumericColumn(let c): return "Column '\(c)' is not numeric"
        case .unsupportedFormat(let ext): return "No loader for '.\(ext)' files"
        }
    }
}
