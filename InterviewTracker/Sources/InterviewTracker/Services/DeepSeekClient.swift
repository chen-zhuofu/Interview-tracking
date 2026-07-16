import Foundation

enum DeepSeekClientError: LocalizedError {
    case missingAPIKey
    case httpStatus(Int, String)
    case emptyContent
    case tooManyToolRounds

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "请先在设置中填写 DeepSeek API Key"
        case .httpStatus(let code, let body):
            return "API 错误 (\(code)): \(body)"
        case .emptyContent:
            return "模型暂时没返回内容，请再发一次"
        case .tooManyToolRounds:
            return "这次操作步骤太多，请拆开再说一次"
        }
    }
}

/// One tool invocation inside an agent run (for traces).
struct AgentToolTrace: Codable, Equatable, Sendable {
    let name: String
    let arguments: String
    let result: String
}

struct AgentRunOutcome: Sendable {
    let reply: String
    let toolTraces: [AgentToolTrace]
    /// Human-readable summaries of writes (for the chat transcript).
    let writeSummaries: [String]
    let roundCount: Int
}

actor DeepSeekClient {
    static let shared = DeepSeekClient()

    private let baseURL = URL(string: "https://api.deepseek.com/chat/completions")!
    private let model = "deepseek-v4-pro"
    private let session: URLSession
    private let maxToolRounds = 8

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Tool-calling loop: the model reads/writes data via `executeTool`
    /// until it produces a plain text reply.
    func runAgent(
        userMessage: String,
        history: [(role: String, content: String)],
        systemPrompt: String,
        tools: [[String: Any]],
        apiKey: String,
        executeTool: @MainActor @Sendable (String, String) async -> (output: String, summary: String?)
    ) async throws -> AgentRunOutcome {
        var messages: [[String: Any]] = [["role": "system", "content": systemPrompt]]
        for turn in history.suffix(10) {
            messages.append(["role": turn.role, "content": turn.content])
        }
        messages.append(["role": "user", "content": userMessage])

        var toolTraces: [AgentToolTrace] = []
        var writeSummaries: [String] = []

        for round in 1...maxToolRounds {
            let assistant = try await requestChat(messages: messages, tools: tools, apiKey: apiKey)

            let toolCalls = assistant["tool_calls"] as? [[String: Any]] ?? []
            if toolCalls.isEmpty {
                let content = (assistant["content"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !content.isEmpty else { throw DeepSeekClientError.emptyContent }
                return AgentRunOutcome(
                    reply: content,
                    toolTraces: toolTraces,
                    writeSummaries: writeSummaries,
                    roundCount: round
                )
            }

            messages.append(sanitizedAssistantMessage(assistant))

            for call in toolCalls {
                guard
                    let id = call["id"] as? String,
                    let function = call["function"] as? [String: Any],
                    let name = function["name"] as? String
                else { continue }
                let arguments = (function["arguments"] as? String) ?? "{}"

                let (output, summary) = await executeTool(name, arguments)
                toolTraces.append(AgentToolTrace(name: name, arguments: arguments, result: output))
                if let summary, !summary.isEmpty {
                    writeSummaries.append(summary)
                }
                messages.append([
                    "role": "tool",
                    "tool_call_id": id,
                    "content": output
                ])
            }
        }
        throw DeepSeekClientError.tooManyToolRounds
    }

    /// Free-form text completion (Markdown / code formatting).
    func complete(
        system: String,
        user: String,
        apiKey: String,
        maxTokens: Int = 8192
    ) async throws -> String {
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ],
            "max_tokens": maxTokens,
            "thinking": ["type": "disabled"]
        ]
        let root = try await post(body: body, apiKey: apiKey)
        guard
            let choices = root["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String,
            !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw DeepSeekClientError.emptyContent
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Quick key check for settings.
    func testConnection(apiKey: String) async throws -> String {
        try await complete(
            system: "回复「连接成功」三个字，不要多余内容。",
            user: "ping",
            apiKey: apiKey,
            maxTokens: 16
        )
    }

    // MARK: - HTTP

    private func requestChat(
        messages: [[String: Any]],
        tools: [[String: Any]],
        apiKey: String
    ) async throws -> [String: Any] {
        var body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": 8192,
            "thinking": ["type": "disabled"]
        ]
        if !tools.isEmpty {
            body["tools"] = tools
        }
        let root = try await post(body: body, apiKey: apiKey)
        guard
            let choices = root["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any]
        else {
            throw DeepSeekClientError.emptyContent
        }
        return message
    }

    private func post(body: [String: Any], apiKey: String) async throws -> [String: Any] {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(status) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw DeepSeekClientError.httpStatus(status, text)
        }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DeepSeekClientError.emptyContent
        }
        return root
    }

    /// Strip provider-specific fields before echoing the assistant message back.
    private func sanitizedAssistantMessage(_ message: [String: Any]) -> [String: Any] {
        var result: [String: Any] = ["role": "assistant"]
        result["content"] = message["content"] ?? NSNull()
        if let toolCalls = message["tool_calls"] {
            result["tool_calls"] = toolCalls
        }
        return result
    }
}
