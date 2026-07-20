import Foundation

/// OAuth client credentials + tokens under Application Support (same approach as APIKeyStore).
enum GoogleCredentialStore {
    private static let fileName = "google_calendar_oauth.json"
    private static var memoryCache: Stored?

    struct Stored: Codable, Equatable {
        var clientId: String
        var clientSecret: String
        var accessToken: String?
        var refreshToken: String?
        var expiry: Date?
        var accountEmail: String?
    }

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("InterviewTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }

    static func load() -> Stored? {
        if let memoryCache { return memoryCache }
        guard
            let data = try? Data(contentsOf: fileURL),
            let stored = try? JSONDecoder().decode(Stored.self, from: data)
        else { return nil }
        memoryCache = stored
        return stored
    }

    @discardableResult
    static func save(_ stored: Stored) -> Bool {
        memoryCache = stored
        do {
            let data = try JSONEncoder().encode(stored)
            try data.write(to: fileURL, options: .atomic)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: fileURL.path
            )
            return true
        } catch {
            return false
        }
    }

    static func updateCredentials(clientId: String, clientSecret: String) {
        var stored = load() ?? Stored(clientId: "", clientSecret: "")
        stored.clientId = clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        stored.clientSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        save(stored)
    }

    static func updateTokens(
        accessToken: String,
        refreshToken: String?,
        expiry: Date?,
        accountEmail: String?
    ) {
        guard var stored = load() else { return }
        stored.accessToken = accessToken
        if let refreshToken { stored.refreshToken = refreshToken }
        stored.expiry = expiry
        if let accountEmail { stored.accountEmail = accountEmail }
        save(stored)
    }

    static var isConnected: Bool {
        guard let stored = load() else { return false }
        return !(stored.refreshToken ?? "").isEmpty || !(stored.accessToken ?? "").isEmpty
    }

    @discardableResult
    static func disconnect() -> Bool {
        guard var stored = load() else { return true }
        stored.accessToken = nil
        stored.refreshToken = nil
        stored.expiry = nil
        stored.accountEmail = nil
        return save(stored)
    }

    @discardableResult
    static func clearAll() -> Bool {
        memoryCache = nil
        try? FileManager.default.removeItem(at: fileURL)
        return true
    }
}
