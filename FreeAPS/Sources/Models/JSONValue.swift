import Foundation

/// Recursive type-erased JSON representation. Allows storing arbitrary
/// JSON content as structured nested values inside another Codable type.
/// Used by BackupBundle to keep each settings-file's payload inspectable
/// instead of stringified.
indirect enum JSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        // Bool must come before Double — NSNumber bridges treat true/false as 1/0.
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }
        if let value = try? container.decode(Double.self) {
            self = .number(value)
            return
        }
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
            return
        }
        if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
            return
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unsupported JSON value"
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case let .bool(value):
            try container.encode(value)
        case let .number(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        }
    }
}

extension JSONValue {
    /// Parse a raw JSON string into a JSONValue. Returns nil when the input is not valid JSON.
    static func from(rawJSON raw: RawJSON) -> JSONValue? {
        guard let data = raw.data(using: .utf8) else { return nil }
        return try? JSONCoding.decoder.decode(JSONValue.self, from: data)
    }

    /// Serialize a JSONValue back to a raw JSON string, matching iAPS's standard formatting.
    var rawJSON: RawJSON? {
        guard let data = try? JSONCoding.encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
