import Foundation

/// Parses a UUID string from NSItemProvider / drag-drop payloads.
public enum DropPayloadParser {
    public static func uuidString(from item: Any?) -> String? {
        if let string = item as? String {
            return string
        }
        if let nsString = item as? NSString {
            return nsString as String
        }
        if let data = item as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    public static func uuid(from item: Any?) -> UUID? {
        guard let string = uuidString(from: item)?.trimmingCharacters(in: .whitespacesAndNewlines)
        else { return nil }
        return UUID(uuidString: string)
    }
}
