import Foundation

/// Google OAuth client (Desktop type) for Calendar sync.
///
/// Do **not** commit real Client ID / Secret.
/// Put credentials only in:
/// `~/Library/Application Support/InterviewTracker/google_oauth_client.json`
enum GoogleOAuthConfig {
    /// Optional local-dev override. Keep empty in git.
    static let clientId = ""
    /// Optional local-dev override. Keep empty in git.
    static let clientSecret = ""

    private static let fileName = "google_oauth_client.json"

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("InterviewTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }

    private struct FileCreds: Codable {
        var clientId: String
        var clientSecret: String
    }

    static var resolved: (clientId: String, clientSecret: String)? {
        let embeddedId = clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        let embeddedSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        if !embeddedId.isEmpty, !embeddedSecret.isEmpty {
            return (embeddedId, embeddedSecret)
        }

        guard
            let data = try? Data(contentsOf: fileURL),
            let file = try? JSONDecoder().decode(FileCreds.self, from: data)
        else { return nil }

        let id = file.clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = file.clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, !secret.isEmpty else { return nil }
        return (id, secret)
    }

    static var isConfigured: Bool { resolved != nil }

    /// Seeds token store with the app OAuth client before starting login.
    static func seedCredentialStore() {
        guard let resolved else { return }
        GoogleCredentialStore.updateCredentials(
            clientId: resolved.clientId,
            clientSecret: resolved.clientSecret
        )
    }
}
