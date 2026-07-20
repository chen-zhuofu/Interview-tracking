import Foundation

/// One durable user-feedback / preference memory line.
struct UserFeedbackMemoryEntry: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var createdAt: Date
    /// preference | correction | feedback
    var kind: String
    var text: String
    var companyHint: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        kind: String,
        text: String,
        companyHint: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kind = kind
        self.text = text
        self.companyHint = companyHint
    }
}

/// Append-only user feedback memory:
/// `~/Library/Application Support/InterviewTracker/user_feedback_memory.jsonl`
enum UserFeedbackMemoryStore {
    private static let fileName = "user_feedback_memory.jsonl"
    private static let lock = NSLock()

    static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("InterviewTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }

    @discardableResult
    static func append(
        kind: String,
        text: String,
        companyHint: String? = nil
    ) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return append(
            UserFeedbackMemoryEntry(
                kind: kind,
                text: trimmed,
                companyHint: companyHint
            )
        )
    }

    @discardableResult
    static func append(_ entry: UserFeedbackMemoryEntry) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]

        do {
            var data = try encoder.encode(entry)
            data.append(contentsOf: "\n".utf8)

            let url = fileURL
            if FileManager.default.fileExists(atPath: url.path) {
                let handle = try FileHandle(forWritingTo: url)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } else {
                try data.write(to: url, options: .atomic)
                try? FileManager.default.setAttributes(
                    [.posixPermissions: 0o600],
                    ofItemAtPath: url.path
                )
            }
            return true
        } catch {
            print("UserFeedbackMemoryStore append failed: \(error.localizedDescription)")
            return false
        }
    }

    /// 用户明确说「记住 / feedback / memory」时，客户端直接落盘，不依赖模型调 tool。
    @discardableResult
    static func captureExplicit(from raw: String) -> Bool {
        guard let entry = parseExplicitCapture(from: raw) else { return false }
        return appendIfNew(kind: entry.kind, text: entry.text)
    }

    /// 解析用户消息里要记的内容；解析不出返回 nil。
    static func parseExplicitCapture(from raw: String) -> UserFeedbackMemoryEntry? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let lower = text.lowercased()
        let hasRemember =
            text.contains("记住")
            || lower.contains("记到 memory")
            || lower.contains("记到memory")
            || lower.contains("写入 memory")
            || lower.contains("写入memory")
            || lower.contains("记进 memory")
            || lower.contains("记进memory")
        guard hasRemember else { return nil }

        var kind = "preference"
        if lower.contains("feedback") || text.contains("反馈") {
            kind = "feedback"
        } else if text.contains("纠正") || text.contains("不要再") || text.contains("别再用") {
            kind = "correction"
        }

        var body = text
        if body.hasPrefix("记住：") || body.hasPrefix("记住:") {
            body = String(body.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            let suffixes = [
                "，记住 feedback", "，记住feedback", "，记住 memory", "，记住memory",
                "，记到 memory", "，记到memory", "，写入 memory", "，记进 memory",
                "记住 feedback", "记住feedback", "记住 memory", "记住memory",
                "，记住", "。记住", " 记住", "记住"
            ]
            for suffix in suffixes.sorted(by: { $0.count > $1.count }) {
                if let range = body.range(of: suffix, options: [.caseInsensitive, .backwards]) {
                    let tail = body[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                    guard tail.isEmpty else { continue }
                    body = String(body[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
        }

        guard body.count >= 3 else { return nil }
        return UserFeedbackMemoryEntry(kind: kind, text: body)
    }

    @discardableResult
    static func appendIfNew(kind: String, text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if loadRecent(limit: 30).contains(where: { $0.text == trimmed && $0.kind == kind }) {
            return false
        }
        return append(kind: kind, text: trimmed)
    }

    /// Newest-last order (file order). Returns the trailing `limit` entries.
    static func loadRecent(limit: Int = 40) -> [UserFeedbackMemoryEntry] {
        lock.lock()
        defer { lock.unlock() }

        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              !data.isEmpty
        else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var entries: [UserFeedbackMemoryEntry] = []
        let text = String(data: data, encoding: .utf8) ?? ""
        for line in text.split(whereSeparator: \.isNewline) {
            let raw = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty, let lineData = raw.data(using: .utf8) else { continue }
            if let entry = try? decoder.decode(UserFeedbackMemoryEntry.self, from: lineData) {
                entries.append(entry)
            }
        }

        if entries.count <= limit { return entries }
        return Array(entries.suffix(limit))
    }

    /// Compact block for the agent system prompt.
    static func promptBlock(limit: Int = 40) -> String {
        let entries = loadRecent(limit: limit)
        guard !entries.isEmpty else { return "" }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        var lines: [String] = ["用户反馈记忆（跨会话落盘，请遵守用户纠正与偏好）："]
        for entry in entries {
            let when = formatter.string(from: entry.createdAt)
            let company = entry.companyHint.map { " @\($0)" } ?? ""
            lines.append("- [\(when)] (\(entry.kind)\(company)) \(entry.text)")
        }
        return lines.joined(separator: "\n")
    }
}
