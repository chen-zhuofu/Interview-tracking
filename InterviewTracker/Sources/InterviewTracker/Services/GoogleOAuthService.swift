import Foundation
import CryptoKit
import AppKit
import Network

enum GoogleOAuthError: LocalizedError {
    case missingCredentials
    case cancelled
    case noCode
    case tokenExchangeFailed(String)
    case serverFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "尚未配置 Google 登录。请先在 Google Cloud 创建桌面应用 OAuth 客户端。"
        case .cancelled:
            return "已取消 Google 授权"
        case .noCode:
            return "未收到授权码"
        case .tokenExchangeFailed(let message):
            return "换取令牌失败：\(message)"
        case .serverFailed(let message):
            return "本地回调失败：\(message)"
        }
    }
}

enum GoogleOAuthService {
    static let calendarScope = "https://www.googleapis.com/auth/calendar.events https://www.googleapis.com/auth/userinfo.email"

    /// Opens the browser and waits for the OAuth redirect on a local loopback port.
    @MainActor
    static func connect() async throws {
        GoogleOAuthConfig.seedCredentialStore()
        guard let stored = GoogleCredentialStore.load(),
              !stored.clientId.isEmpty,
              !stored.clientSecret.isEmpty
        else { throw GoogleOAuthError.missingCredentials }

        let verifier = makeCodeVerifier()
        let challenge = makeCodeChallenge(verifier)
        let server = try await LoopbackHTTPServer.create()
        let redirectURI = "http://127.0.0.1:\(server.port)"

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: stored.clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: calendarScope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        guard let authURL = components.url else {
            throw GoogleOAuthError.serverFailed("无法构造授权 URL")
        }

        NSWorkspace.shared.open(authURL)

        let code = try await server.waitForAuthorizationCode(timeout: 180)
        let tokens = try await exchangeCode(
            code: code,
            redirectURI: redirectURI,
            verifier: verifier,
            clientId: stored.clientId,
            clientSecret: stored.clientSecret
        )

        var email: String?
        if let access = tokens.accessToken {
            email = try? await fetchEmail(accessToken: access)
        }

        GoogleCredentialStore.updateTokens(
            accessToken: tokens.accessToken ?? "",
            refreshToken: tokens.refreshToken,
            expiry: tokens.expiry,
            accountEmail: email
        )
    }

    static func validAccessToken() async throws -> String {
        guard let stored = GoogleCredentialStore.load() else {
            throw GoogleOAuthError.missingCredentials
        }
        if let access = stored.accessToken, !access.isEmpty,
           let expiry = stored.expiry, expiry > Date().addingTimeInterval(60) {
            return access
        }
        guard let refresh = stored.refreshToken, !refresh.isEmpty else {
            throw GoogleOAuthError.missingCredentials
        }
        let tokens = try await refreshAccessToken(
            refreshToken: refresh,
            clientId: stored.clientId,
            clientSecret: stored.clientSecret
        )
        GoogleCredentialStore.updateTokens(
            accessToken: tokens.accessToken ?? "",
            refreshToken: tokens.refreshToken ?? refresh,
            expiry: tokens.expiry,
            accountEmail: stored.accountEmail
        )
        guard let access = tokens.accessToken, !access.isEmpty else {
            throw GoogleOAuthError.tokenExchangeFailed("未返回 access_token")
        }
        return access
    }

    // MARK: - Token HTTP

    private struct TokenResponse: Decodable {
        let accessToken: String?
        let refreshToken: String?
        let expiresIn: Int?
        let error: String?
        let errorDescription: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
            case error
            case errorDescription = "error_description"
        }

        var expiry: Date? {
            guard let expiresIn else { return nil }
            return Date().addingTimeInterval(TimeInterval(expiresIn))
        }
    }

    private static func exchangeCode(
        code: String,
        redirectURI: String,
        verifier: String,
        clientId: String,
        clientSecret: String
    ) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "code": code,
            "client_id": clientId,
            "client_secret": clientSecret,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": verifier
        ]
        request.httpBody = formEncode(body).data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: request)
        let tokens = try JSONDecoder().decode(TokenResponse.self, from: data)
        if let error = tokens.error {
            throw GoogleOAuthError.tokenExchangeFailed(tokens.errorDescription ?? error)
        }
        return tokens
    }

    private static func refreshAccessToken(
        refreshToken: String,
        clientId: String,
        clientSecret: String
    ) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        request.httpBody = formEncode(body).data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: request)
        let tokens = try JSONDecoder().decode(TokenResponse.self, from: data)
        if let error = tokens.error {
            throw GoogleOAuthError.tokenExchangeFailed(tokens.errorDescription ?? error)
        }
        return tokens
    }

    private static func fetchEmail(accessToken: String) async throws -> String? {
        var request = URLRequest(url: URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        struct UserInfo: Decodable { let email: String? }
        return try JSONDecoder().decode(UserInfo.self, from: data).email
    }

    private static func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    private static func makeCodeChallenge(_ verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    private static func formEncode(_ fields: [String: String]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return fields
            .map { key, value in
                let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(k)=\(v)"
            }
            .joined(separator: "&")
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Loopback HTTP (captures ?code=)

private final class LoopbackHTTPServer: @unchecked Sendable {
    private(set) var port: UInt16 = 0
    private let listener: NWListener
    private var continuation: CheckedContinuation<String, Error>?
    private var finished = false

    static func create() async throws -> LoopbackHTTPServer {
        let server = try LoopbackHTTPServer()
        try await server.startAndBind()
        return server
    }

    private init() throws {
        listener = try NWListener(using: .tcp, on: .any)
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
    }

    private func startAndBind() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            final class ResumeOnce: @unchecked Sendable {
                private var done = false
                private let lock = NSLock()
                func run(_ body: () -> Void) {
                    lock.lock()
                    defer { lock.unlock() }
                    guard !done else { return }
                    done = true
                    body()
                }
            }
            let once = ResumeOnce()
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    once.run { cont.resume() }
                case .failed(let error):
                    once.run {
                        cont.resume(throwing: GoogleOAuthError.serverFailed(error.localizedDescription))
                    }
                default:
                    break
                }
            }
            listener.start(queue: .global(qos: .userInitiated))
        }
        guard let bound = listener.port?.rawValue, bound > 0 else {
            listener.cancel()
            throw GoogleOAuthError.serverFailed("无法绑定本地端口")
        }
        port = bound
    }

    func waitForAuthorizationCode(timeout: TimeInterval) async throws -> String {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            self.continuation = cont
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak self] in
                self?.fail(GoogleOAuthError.cancelled)
            }
        }
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let self else { return }
            defer { connection.cancel() }
            if let error {
                self.fail(GoogleOAuthError.serverFailed(error.localizedDescription))
                return
            }
            guard let data, let request = String(data: data, encoding: .utf8) else {
                self.fail(GoogleOAuthError.noCode)
                return
            }

            let html: String
            if let code = Self.extractCode(from: request) {
                html = """
                <html><body style="font-family:system-ui;padding:40px">
                <h2>已连接 Google Calendar</h2>
                <p>可以关闭此窗口，回到 Interview Tracker。</p>
                </body></html>
                """
                self.respond(connection: connection, html: html)
                self.succeed(code)
            } else if request.contains("error=") {
                html = """
                <html><body style="font-family:system-ui;padding:40px">
                <h2>授权失败</h2>
                <p>请回到 App 重试。</p>
                </body></html>
                """
                self.respond(connection: connection, html: html)
                self.fail(GoogleOAuthError.cancelled)
            } else {
                self.respond(connection: connection, html: "<html><body>OK</body></html>")
            }
        }
    }

    private func respond(connection: NWConnection, html: String) {
        let body = html.data(using: .utf8) ?? Data()
        let header = """
        HTTP/1.1 200 OK\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(body.count)\r
        Connection: close\r
        \r

        """
        var payload = Data(header.utf8)
        payload.append(body)
        connection.send(content: payload, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static func extractCode(from request: String) -> String? {
        let firstLine = request.split(separator: "\r\n").first.map(String.init) ?? request
        guard let pathPart = firstLine.split(separator: " ").dropFirst().first else { return nil }
        guard let components = URLComponents(string: "http://127.0.0.1\(pathPart)") else { return nil }
        return components.queryItems?.first(where: { $0.name == "code" })?.value
    }

    private func succeed(_ code: String) {
        finish { cont in cont.resume(returning: code) }
    }

    private func fail(_ error: Error) {
        finish { cont in cont.resume(throwing: error) }
    }

    private func finish(_ block: (CheckedContinuation<String, Error>) -> Void) {
        guard !finished, let cont = continuation else { return }
        finished = true
        continuation = nil
        listener.cancel()
        block(cont)
    }
}
