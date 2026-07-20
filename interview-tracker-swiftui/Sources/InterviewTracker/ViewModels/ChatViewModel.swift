import Foundation
import SwiftData
import SwiftUI
import AppKit

/// 处理上传图片用的多模态模型。用 Gemini 3.1 Flash-Lite 识别图片内容。
enum ChatVisionConfig {
    static let imageModel = "gemini-3.1-flash-lite"
}

/// 语音输入模型，还没定用哪个，先留空占位。
enum ChatVoiceConfig {
    static let modelName: String? = nil
}

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

struct PendingAgentApproval: Identifiable, Equatable {
    let id = UUID()
    let writes: [AgentToolbox.PendingWrite]
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var draft: String = ""
    @Published var isExpanded: Bool = false
    @Published var isSending: Bool = false
    @Published var errorText: String?
    @Published var showSettings: Bool = false
    @Published var pendingApproval: PendingAgentApproval?
    /// 当前附带待发送的图片，交给 Gemini 识别。
    @Published var attachedImage: NSImage?

    private var attachedImageData: Data?
    private var attachedImageMime: String = "image/png"
    private var collectingWrites: [AgentToolbox.PendingWrite] = []

    var hasAttachment: Bool { attachedImage != nil }

    func attachImage(from url: URL) {
        guard let data = try? Data(contentsOf: url), let image = NSImage(data: data) else { return }
        setAttachment(image: image, data: data, mime: Self.mimeType(for: url))
    }

    /// 从剪贴板等来源直接拿到 NSImage（复制粘贴图片）。
    func attachImage(_ image: NSImage) {
        setAttachment(image: image, data: Self.pngData(from: image), mime: "image/png")
    }

    private func setAttachment(image: NSImage, data: Data?, mime: String) {
        guard let data else { return }
        attachedImage = image
        attachedImageData = data
        attachedImageMime = mime
        isExpanded = true
    }

    func clearAttachment() {
        attachedImage = nil
        attachedImageData = nil
        attachedImageMime = "image/png"
    }

    /// 语音输入。模型还没定，先占位提示。
    func startVoiceInput() {
        isExpanded = true
        if let model = ChatVoiceConfig.modelName, !model.isEmpty {
            // TODO: 接上语音识别（model）。
            messages.append(ChatMessage(role: .assistant, text: "正在用 \(model) 听你说…"))
        } else {
            messages.append(ChatMessage(role: .assistant, text: "语音输入还没接模型（模型待定），先占个位～"))
        }
    }

    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "heic": return "image/heic"
        case "bmp": return "image/bmp"
        default: return "image/png"
        }
    }

    private static func pngData(from image: NSImage) -> Data? {
        guard
            let tiff = image.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff)
        else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    func expand() {
        isExpanded = true
    }

    func collapse() {
        guard pendingApproval == nil else { return }
        isExpanded = false
    }

    func send(using context: ModelContext) async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = ""
        if let data = attachedImageData {
            let mime = attachedImageMime
            clearAttachment()
            await sendMessage(text, using: context, imageData: data, imageMime: mime)
        } else {
            await sendMessage(text, using: context)
        }
    }

    /// Run one agent turn: the model calls data tools until it replies in text.
    /// 若带图片，先让 Gemini 把图片转成文字，再交给 DeepSeek agent（走审批流）。
    func sendMessage(
        _ text: String,
        using context: ModelContext,
        imageData: Data? = nil,
        imageMime: String = "image/png"
    ) async {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasImage = imageData != nil
        guard (!text.isEmpty || hasImage), !isSending, pendingApproval == nil else { return }

        guard let apiKey = APIKeyStore.load(), !apiKey.isEmpty else {
            errorText = "请先设置 DeepSeek API Key"
            showSettings = true
            isExpanded = true
            return
        }

        var geminiKey: String?
        if hasImage {
            guard let key = GeminiKeyStore.load(), !key.isEmpty else {
                errorText = "请先在设置里填写 Gemini API Key（识别图片用）"
                showSettings = true
                isExpanded = true
                return
            }
            geminiKey = key
        }

        isExpanded = true
        isSending = true
        errorText = nil
        collectingWrites = []
        let displayText = hasImage ? (text.isEmpty ? "［图片］" : "\(text)　［图片］") : text
        messages.append(ChatMessage(role: .user, text: displayText))
        // 用户明确说「记住 / feedback / memory」时，客户端立刻落盘，不靠模型自觉调 tool。
        let explicitMemorySaved = UserFeedbackMemoryStore.captureExplicit(from: text)

        var agentMessage = text
        if explicitMemorySaved {
            agentMessage = """
            【系统：用户要求记住以下内容，已写入 feedback memory，无需再调 remember_preference】
            \(text)
            """
        }
        if hasImage, let imageData, let geminiKey {
            do {
                let vision = try await GeminiClient.shared.describeImage(
                    imageData,
                    mimeType: imageMime,
                    prompt: text.isEmpty
                        ? "请把这张图片里的所有信息尽量完整地转成文字：公司、职位、时间、地点、联系人、链接、金额等关键信息都保留。"
                        : "结合下面这句话理解这张图片，并把图片里的关键信息完整转成文字：\(text)",
                    apiKey: geminiKey
                )
                agentMessage = """
                用户上传了一张图片。以下是图片识别出来的文字内容（来自 Gemini 3.1 Flash-Lite）：
                \(vision)

                用户附言：\(text.isEmpty ? "（无，请根据图片内容判断该做什么）" : text)
                """
            } catch {
                errorText = error.localizedDescription
                let fail = "识别图片失败：\(error.localizedDescription)"
                messages.append(ChatMessage(role: .assistant, text: fail))
                isSending = false
                return
            }
        }

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
                userMessage: agentMessage,
                history: Array(historyTuples),
                systemPrompt: systemPrompt,
                tools: AgentToolbox.toolSchemas,
                apiKey: apiKey,
                executeTool: { name, arguments in
                    if AgentToolbox.isWriteTool(name) {
                        let write = AgentToolbox.prepareWrite(
                            name: name,
                            argumentsJSON: arguments,
                            in: context
                        )
                        let duplicate = self.collectingWrites.contains {
                            $0.toolName == write.toolName
                                && $0.argumentsJSON == write.argumentsJSON
                        }
                        if !duplicate {
                            self.collectingWrites.append(write)
                        }
                        return (
                            #"{"ok":true,"pending_approval":true,"message":"已加入待审批批次，尚未写入数据库"}"#,
                            nil
                        )
                    }
                    let result = await AgentToolbox.execute(
                        name: name,
                        argumentsJSON: arguments,
                        in: context
                    )
                    return (result.output, result.summary)
                }
            )
            if collectingWrites.isEmpty {
                messages.append(ChatMessage(role: .assistant, text: outcome.reply))
            } else {
                pendingApproval = PendingAgentApproval(writes: collectingWrites)
                // 批准卡只在展开时才显示。如果用户在 agent 思考时收起了窗口，
                // 这里必须强制展开，否则卡片藏起来、输入框又被禁用，就卡死了。
                isExpanded = true
                messages.append(
                    ChatMessage(
                        role: .assistant,
                        text: "下面这些变化还没有执行。请检查后批准或取消。"
                    )
                )
            }
            AgentTraceStore.append(
                AgentTraceRecord(
                    startedAt: startedAt,
                    endedAt: Date(),
                    kind: "chat",
                    userMessage: agentMessage,
                    history: historyForTrace,
                    toolCalls: outcome.toolTraces,
                    applySummaries: collectingWrites.isEmpty ? outcome.writeSummaries : nil,
                    assistantMessage: collectingWrites.isEmpty ? outcome.reply : "等待用户批准",
                    attemptCount: outcome.roundCount
                )
            )
        } catch {
            errorText = error.localizedDescription
            let fail = "处理失败：\(error.localizedDescription)"
            messages.append(ChatMessage(role: .assistant, text: fail))
            // 失败时也把已经调过的工具记录存下来，方便在 traces 里查是哪一步打转。
            var partialTraces: [AgentToolTrace]?
            if case DeepSeekClientError.tooManyToolRounds(let traces) = error {
                partialTraces = traces
            }
            AgentTraceStore.append(
                AgentTraceRecord(
                    startedAt: startedAt,
                    endedAt: Date(),
                    kind: "chat",
                    userMessage: agentMessage,
                    history: historyForTrace,
                    toolCalls: partialTraces,
                    assistantMessage: fail,
                    error: error.localizedDescription
                )
            )
        }

        isSending = false
    }

    func approvePendingWrites(using context: ModelContext) async {
        guard let approval = pendingApproval, !isSending else { return }
        isSending = true
        errorText = nil

        var summaries: [String] = []
        var failures: [String] = []
        for write in approval.writes {
            let result = await AgentToolbox.execute(
                name: write.toolName,
                argumentsJSON: write.argumentsJSON,
                in: context
            )
            if result.output.contains(#""error""#) {
                failures.append("\(write.preview)：\(result.output)")
            } else if let summary = result.summary, !summary.isEmpty {
                summaries.append(summary)
            } else {
                summaries.append(write.preview)
            }
        }

        pendingApproval = nil
        collectingWrites = []
        // 有实际写入就存一份快照（节流），万一之后误清空能还原到这。
        if !summaries.isEmpty {
            AutoBackupService.snapshotThrottled(context: context)
        }
        if failures.isEmpty {
            let detail = summaries.isEmpty ? "" : "\n- " + summaries.joined(separator: "\n- ")
            messages.append(ChatMessage(role: .assistant, text: "已按批准执行。\(detail)"))
        } else {
            let succeeded = summaries.isEmpty ? "" : "\n已完成：\n- " + summaries.joined(separator: "\n- ")
            let failed = "\n未完成：\n- " + failures.joined(separator: "\n- ")
            messages.append(ChatMessage(role: .assistant, text: "执行时有部分操作失败。\(succeeded)\(failed)"))
            errorText = "部分写入失败，请查看聊天记录。"
        }
        AgentTraceStore.append(
            AgentTraceRecord(
                kind: "approved_writes",
                userMessage: "用户批准 \(approval.writes.count) 项写入",
                applySummaries: summaries,
                assistantMessage: failures.isEmpty ? "全部执行成功" : "部分执行失败",
                error: failures.isEmpty ? nil : failures.joined(separator: "\n")
            )
        )
        isSending = false
    }

    func rejectPendingWrites() {
        guard let approval = pendingApproval else { return }
        pendingApproval = nil
        collectingWrites = []
        messages.append(ChatMessage(role: .assistant, text: "已取消，数据库没有发生这些变化。"))
        AgentTraceStore.append(
            AgentTraceRecord(
                kind: "rejected_writes",
                userMessage: "用户取消 \(approval.writes.count) 项写入",
                assistantMessage: "未执行"
            )
        )
    }

    /// UI already applied a local edit; keep it in the chat thread + traces
    /// without an LLM round-trip.
    func recordLocalEdit(userText: String, assistantText: String) {
        isExpanded = true
        messages.append(ChatMessage(role: .user, text: userText))
        messages.append(ChatMessage(role: .assistant, text: assistantText))
        // 时间线草稿只当操作日志记进 AgentTraceStore，不塞进「反馈记忆」。
        AgentTraceStore.append(
            AgentTraceRecord(
                kind: "local_edit",
                userMessage: userText,
                assistantMessage: assistantText
            )
        )
    }
}
