import Foundation

/// One agent run — persisted as a JSONL line under Application Support.
struct AgentTraceRecord: Codable, Equatable, Sendable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date
    /// chat | timeline_node | local_timeline_delete | format | settings_test
    var kind: String
    var userMessage: String
    var history: [[String: String]]?
    var existingSummary: String?
    var rawModelContent: String?
    /// Tool invocations inside the agent run (name / arguments / result).
    var toolCalls: [AgentToolTrace]?
    var applySummaries: [String]?
    var assistantMessage: String?
    var error: String?
    var attemptCount: Int?

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        endedAt: Date = Date(),
        kind: String,
        userMessage: String,
        history: [[String: String]]? = nil,
        existingSummary: String? = nil,
        rawModelContent: String? = nil,
        toolCalls: [AgentToolTrace]? = nil,
        applySummaries: [String]? = nil,
        assistantMessage: String? = nil,
        error: String? = nil,
        attemptCount: Int? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.kind = kind
        self.userMessage = userMessage
        self.history = history
        self.existingSummary = existingSummary
        self.rawModelContent = rawModelContent
        self.toolCalls = toolCalls
        self.applySummaries = applySummaries
        self.assistantMessage = assistantMessage
        self.error = error
        self.attemptCount = attemptCount
    }
}

/// Append-only agent traces: `~/Library/Application Support/InterviewTracker/agent_traces.jsonl`
enum AgentTraceStore {
    private static let fileName = "agent_traces.jsonl"
    private static let lock = NSLock()

    static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("InterviewTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }

    @discardableResult
    static func append(_ record: AgentTraceRecord) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]

        do {
            var data = try encoder.encode(record)
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
            print("AgentTraceStore append failed: \(error.localizedDescription)")
            return false
        }
    }
}
