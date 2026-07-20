import Foundation

enum GeminiClientError: LocalizedError {
    case missingAPIKey
    case httpStatus(Int, String)
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "请先在设置中填写 Gemini API Key"
        case .httpStatus(let code, let body):
            return "Gemini 错误 (\(code)): \(body)"
        case .emptyContent:
            return "Gemini 没返回内容，请再试一次"
        }
    }
}

/// Thin client for Google's Gemini generateContent REST API.
/// Used to turn an uploaded image into text (Gemini 3.1 Flash-Lite).
actor GeminiClient {
    static let shared = GeminiClient()

    private let session: URLSession
    private let host = "https://generativelanguage.googleapis.com/v1beta/models"

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Send an image (+ optional prompt) and get back the model's text answer.
    func describeImage(
        _ imageData: Data,
        mimeType: String,
        prompt: String,
        apiKey: String,
        model: String = ChatVisionConfig.imageModel
    ) async throws -> String {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw GeminiClientError.missingAPIKey }

        let body: [String: Any] = [
            "contents": [[
                "role": "user",
                "parts": [
                    ["text": prompt],
                    ["inline_data": ["mime_type": mimeType, "data": imageData.base64EncodedString()]]
                ]
            ]]
        ]
        let root = try await post(model: model, body: body, apiKey: trimmedKey)

        guard
            let candidates = root["candidates"] as? [[String: Any]],
            let content = candidates.first?["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]]
        else {
            throw GeminiClientError.emptyContent
        }
        let text = parts.compactMap { $0["text"] as? String }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw GeminiClientError.emptyContent }
        return text
    }

    /// Quick key check for settings.
    func testConnection(apiKey: String, model: String = ChatVisionConfig.imageModel) async throws -> String {
        let body: [String: Any] = [
            "contents": [[
                "role": "user",
                "parts": [["text": "回复「连接成功」四个字，不要多余内容。"]]
            ]]
        ]
        let root = try await post(model: model, body: body, apiKey: apiKey)
        guard
            let candidates = root["candidates"] as? [[String: Any]],
            let content = candidates.first?["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]]
        else {
            throw GeminiClientError.emptyContent
        }
        let text = parts.compactMap { $0["text"] as? String }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "连接成功" : text
    }

    // MARK: - HTTP

    private func post(model: String, body: [String: Any], apiKey: String) async throws -> [String: Any] {
        guard let url = URL(string: "\(host)/\(model):generateContent") else {
            throw GeminiClientError.httpStatus(-1, "bad url")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(status) else {
            throw GeminiClientError.httpStatus(status, String(data: data, encoding: .utf8) ?? "")
        }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GeminiClientError.emptyContent
        }
        return root
    }
}
