import Foundation
import SwiftData
import SwiftUI

struct ChatMessage: Identifiable, Equatable {
    enum Role: String {
        case user
        case assistant
        case system
    }

    let id: UUID
    let role: Role
    let text: String
    let timestamp: Date

    init(id: UUID = UUID(), role: Role, text: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var draft: String = ""
    @Published var isExpanded: Bool = false
    @Published var isSending: Bool = false
    @Published var errorText: String?
    @Published var showSettings: Bool = false

    func expand() {
        isExpanded = true
    }

    func collapse() {
        isExpanded = false
    }

    func send(using context: ModelContext) async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = ""
        await sendMessage(text, using: context)
    }

    /// Run one agent turn: the model calls data tools until it replies in text.
    func sendMessage(_ text: String, using context: ModelContext) async {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        guard let apiKey = APIKeyStore.load(), !apiKey.isEmpty else {
            errorText = "请先设置 DeepSeek API Key"
            showSettings = true
            isExpanded = true
            return
        }

        isExpanded = true
        isSending = true
        errorText = nil
        messages.append(ChatMessage(role: .user, text: text))
        UserFeedbackMemoryStore.append(kind: "chat", text: text)

        let historyTuples = messages
            .filter { $0.role == .user || $0.role == .assistant }
            .dropLast()
            .suffix(10)
            .map { (role: $0.role.rawValue, content: $0.text) }
        let historyForTrace = historyTuples.map { ["role": $0.role, "content": $0.content] }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd EEEE"
        let systemPrompt = DeepSeekPrompt.agentSystemPrompt(
            todayISO: formatter.string(from: Date()),
            memoryBlock: UserFeedbackMemoryStore.promptBlock(limit: 40)
        )

        let startedAt = Date()
        do {
            let outcome = try await DeepSeekClient.shared.runAgent(
                userMessage: text,
                history: Array(historyTuples),
                systemPrompt: systemPrompt,
                tools: AgentToolbox.toolSchemas,
                apiKey: apiKey,
                executeTool: { name, arguments in
                    let result = await AgentToolbox.execute(
                        name: name,
                        argumentsJSON: arguments,
                        in: context
                    )
                    return (result.output, result.summary)
                }
            )
            messages.append(ChatMessage(role: .assistant, text: outcome.reply))
            AgentTraceStore.append(
                AgentTraceRecord(
                    startedAt: startedAt,
                    endedAt: Date(),
                    kind: "chat",
                    userMessage: text,
                    history: historyForTrace,
                    toolCalls: outcome.toolTraces,
                    applySummaries: outcome.writeSummaries,
                    assistantMessage: outcome.reply,
                    attemptCount: outcome.roundCount
                )
            )
        } catch {
            errorText = error.localizedDescription
            let fail = "处理失败：\(error.localizedDescription)"
            messages.append(ChatMessage(role: .assistant, text: fail))
            AgentTraceStore.append(
                AgentTraceRecord(
                    startedAt: startedAt,
                    endedAt: Date(),
                    kind: "chat",
                    userMessage: text,
                    history: historyForTrace,
                    assistantMessage: fail,
                    error: error.localizedDescription
                )
            )
        }

        isSending = false
    }

    /// UI already applied a local edit; keep it in the chat thread + traces
    /// without an LLM round-trip.
    func recordLocalEdit(userText: String, assistantText: String) {
        isExpanded = true
        messages.append(ChatMessage(role: .user, text: userText))
        messages.append(ChatMessage(role: .assistant, text: assistantText))
        UserFeedbackMemoryStore.append(kind: "timeline", text: userText)
        AgentTraceStore.append(
            AgentTraceRecord(
                kind: "local_edit",
                userMessage: userText,
                assistantMessage: assistantText
            )
        )
    }
}
