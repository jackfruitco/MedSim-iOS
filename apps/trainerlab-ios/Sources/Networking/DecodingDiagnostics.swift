import Foundation

/// Formats a `DecodingError` into a diagnostic string containing the error case,
/// the coding path to the failing field, and the error's debug description.
/// Falls back to `String(reflecting:)` for non-`DecodingError` inputs.
func formatDecodingError(_ error: Error) -> String {
    guard let decodingError = error as? DecodingError else {
        return String(reflecting: error)
    }
    switch decodingError {
    case let .typeMismatch(type, context):
        return "typeMismatch(\(type)) at \(codingPathString(context.codingPath)): \(context.debugDescription)"
    case let .valueNotFound(type, context):
        return "valueNotFound(\(type)) at \(codingPathString(context.codingPath)): \(context.debugDescription)"
    case let .keyNotFound(key, context):
        return "keyNotFound(\"\(key.stringValue)\") at \(codingPathString(context.codingPath)): \(context.debugDescription)"
    case let .dataCorrupted(context):
        return "dataCorrupted at \(codingPathString(context.codingPath)): \(context.debugDescription)"
    @unknown default:
        return String(reflecting: decodingError)
    }
}

/// Returns a bounded UTF-8 string preview of raw response data, suitable for logging.
/// Caps at `maxBytes` (default 4096) and appends a truncation notice when the data
/// exceeds the cap. Returns a byte-count summary for non-UTF-8 data.
func bodyPreview(_ data: Data, maxBytes: Int = 4096) -> String {
    let slice = data.prefix(maxBytes)
    if let text = String(data: slice, encoding: .utf8) {
        let suffix = data.count > maxBytes
            ? "… [\(data.count) bytes total, showing first \(maxBytes)]"
            : ""
        return text + suffix
    }
    return "[non-UTF-8 body: \(data.count) bytes]"
}

private func codingPathString(_ path: [CodingKey]) -> String {
    path.isEmpty ? "<root>" : path.map(\.stringValue).joined(separator: ".")
}
