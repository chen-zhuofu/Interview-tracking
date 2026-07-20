import Foundation

/// Stores the Gemini API key under Application Support.
/// Used for image (vision) processing with Gemini 3.1 Flash-Lite.
/// Keychain is avoided: unsigned SPM binaries prompt for the login password on every read.
enum GeminiKeyStore {
    private static let fileName = "gemini_api_key"
    private static var memoryCache: String?

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("InterviewTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }

    static func load() -> String? {
        if let memoryCache, !memoryCache.isEmpty {
            return memoryCache
        }
        guard
            let data = try? Data(contentsOf: fileURL),
            let key = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !key.isEmpty
        else {
            return nil
        }
        memoryCache = key
        return key
    }

    @discardableResult
    static func save(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        memoryCache = trimmed.isEmpty ? nil : trimmed
        if trimmed.isEmpty {
            try? FileManager.default.removeItem(at: fileURL)
            return true
        }
        do {
            try Data(trimmed.utf8).write(to: fileURL, options: .atomic)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: fileURL.path
            )
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    static func delete() -> Bool {
        memoryCache = nil
        try? FileManager.default.removeItem(at: fileURL)
        return true
    }
}
