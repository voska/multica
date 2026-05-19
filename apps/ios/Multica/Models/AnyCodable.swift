import Foundation

/// Used by Generated.swift for `unknown`/`any` payload fields (e.g.
/// AutopilotRun.result, AutopilotRun.trigger_payload). Decodes to its
/// JSON representation; never re-encoded.
struct AnyCodable: Codable, Hashable, Sendable {
    let raw: Data

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) { raw = Data(s.utf8); return }
        if let n = try? container.decode(Double.self) { raw = Data(String(n).utf8); return }
        if let b = try? container.decode(Bool.self) { raw = Data(String(b).utf8); return }
        if container.decodeNil() { raw = Data(); return }
        // Fall back to encoding the underlying JSON via JSONSerialization
        if let dict = try? container.decode([String: AnyCodable].self) {
            raw = (try? JSONEncoder().encode(dict)) ?? Data()
            return
        }
        if let arr = try? container.decode([AnyCodable].self) {
            raw = (try? JSONEncoder().encode(arr)) ?? Data()
            return
        }
        raw = Data()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }
}
