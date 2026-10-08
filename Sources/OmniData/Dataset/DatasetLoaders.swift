import Foundation

public protocol DatasetLoader {
    func load(data: Data, name: String) throws -> TabularDataset
}

public extension DatasetLoader {
    func load(contentsOf url: URL) throws -> TabularDataset {
        try load(data: Data(contentsOf: url), name: url.deletingPathExtension().lastPathComponent)
    }
}

/// Picks a loader from the file extension (`.csv`, `.tsv`, `.json`).
public enum DatasetLoading {
    public static func load(contentsOf url: URL) throws -> TabularDataset {
        switch url.pathExtension.lowercased() {
        case "csv": return try CSVDatasetLoader().load(contentsOf: url)
        case "tsv": return try CSVDatasetLoader(delimiter: "\t").load(contentsOf: url)
        case "json": return try JSONDatasetLoader().load(contentsOf: url)
        case let ext: throw DatasetError.unsupportedFormat(ext)
        }
    }
}

/// RFC 4180 CSV: first row is the header, fields may be quoted ("a, b"), quotes are
/// escaped by doubling (""), CRLF or LF line endings, blank lines are ignored.
public struct CSVDatasetLoader: DatasetLoader {
    public var delimiter: Character

    public init(delimiter: Character = ",") { self.delimiter = delimiter }

    public func load(data: Data, name: String) throws -> TabularDataset {
        var text = String(decoding: data, as: UTF8.self)
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        var records = try parse(text)
        guard !records.isEmpty else { throw DatasetError.empty }
        let header = records.removeFirst().map { $0.trimmingCharacters(in: .whitespaces) }
        var seen = Set<String>()
        for h in header where !seen.insert(h).inserted { throw DatasetError.duplicateColumn(h) }
        for (i, r) in records.enumerated() where r.count != header.count {
            throw DatasetError.rowWidth(row: i + 2, expected: header.count, found: r.count)
        }
        return try TabularDataset.infer(name: name, header: header, rows: records)
    }

    func parse(_ text: String) throws -> [[String]] {
        var records: [[String]] = []
        var record: [String] = []
        var field = ""
        var inQuotes = false
        var quoteStartRow = 1
        var row = 1
        var chars = text.makeIterator()
        var pending: Character? = nil

        func endRecord() {
            record.append(field)
            field = ""
            if !(record.count == 1 && record[0].isEmpty) { records.append(record) }
            record = []
        }

        while let c = pending ?? chars.next() {
            pending = nil
            if inQuotes {
                if c == "\"" {
                    let next = chars.next()
                    if next == "\"" { field.append("\"") } else { inQuotes = false; pending = next }
                } else {
                    if c == "\n" || c == "\r\n" { row += 1 }
                    field.append(c)
                }
            } else if c == "\"" && field.isEmpty {
                inQuotes = true
                quoteStartRow = row
            } else if c == delimiter {
                record.append(field)
                field = ""
            } else if c == "\n" || c == "\r\n" || c == "\r" {
                endRecord()
                row += 1
            } else {
                field.append(c)
            }
        }
        if inQuotes { throw DatasetError.unterminatedQuote(row: quoteStartRow) }
        if !field.isEmpty || !record.isEmpty { endRecord() }
        return records
    }
}

/// Accepts either an array of flat objects (`[{"x": 1, "label": "a"}, ...]`) or a
/// column layout (`{"columns": ["x", "label"], "rows": [[1, "a"], ...]}`).
/// Column order follows first appearance; missing keys become empty cells.
public struct JSONDatasetLoader: DatasetLoader {
    public init() {}

    public func load(data: Data, name: String) throws -> TabularDataset {
        let root = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        if let objects = root as? [[String: Any]] {
            var header: [String] = []
            var seen = Set<String>()
            // JSONSerialization does not keep key order, so sort keys within each object for determinism.
            for obj in objects { for k in obj.keys.sorted() where seen.insert(k).inserted { header.append(k) } }
            guard !header.isEmpty else { throw DatasetError.empty }
            let rows = objects.map { obj in header.map { Self.cell(obj[$0]) } }
            return try TabularDataset.infer(name: name, header: header, rows: rows)
        }
        if let table = root as? [String: Any] {
            guard let header = table["columns"] as? [String], let rows = table["rows"] as? [[Any]] else {
                throw DatasetError.unsupportedJSON("expected {\"columns\": [...], \"rows\": [[...]]}")
            }
            guard !header.isEmpty else { throw DatasetError.empty }
            for (i, r) in rows.enumerated() where r.count != header.count {
                throw DatasetError.rowWidth(row: i + 1, expected: header.count, found: r.count)
            }
            return try TabularDataset.infer(name: name, header: header, rows: rows.map { $0.map(Self.cell) })
        }
        throw DatasetError.unsupportedJSON("top level must be an array of objects or a columns/rows table")
    }

    static func cell(_ value: Any?) -> String {
        switch value {
        case nil, is NSNull: return ""
        case let s as String: return s
        case let n as NSNumber:
            // JSON booleans arrive as NSNumber with objCType "c" (on Darwin and Linux).
            // Keep them as text so they don't pass for 0/1. JSON never produces Int8 numbers.
            if String(cString: n.objCType) == "c" { return n.boolValue ? "true" : "false" }
            return n.stringValue
        default: return "\(value!)"
        }
    }
}
