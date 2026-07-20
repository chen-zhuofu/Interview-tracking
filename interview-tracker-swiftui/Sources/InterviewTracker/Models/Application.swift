import Foundation
import SwiftData

@Model
final class Application {
    var id: UUID
    var position: String
    var jobDescriptionURL: String?
    /// 岗位 JD 正文
    var jobDescriptionText: String?
    var appliedDate: Date?
    var lastUpdated: Date
    var notes: String?
    /// 想去程度 1–5
    var desireLevel: Int?
    /// 收到的反馈
    var feedback: String?
    /// 自己的复盘
    var reviewNotes: String?
    /// 手撕代码 / 算法题
    var codeSnippets: String?
    /// 面试题文档
    var interviewDocs: String?

    /// Legacy enum status (referral / hr_call / …) — only read by LegacyMigrator.
    @Attribute(originalName: "status") var legacyStatus: String
    /// Legacy entry channel — only read by LegacyMigrator.
    @Attribute(originalName: "channel") var legacyChannel: String?

    var company: Company?

    @Relationship(deleteRule: .cascade, inverse: \Interview.application)
    var interviews: [Interview]?

    @Relationship(deleteRule: .cascade, inverse: \StageNode.application)
    var stageNodes: [StageNode]?

    init(
        position: String,
        company: Company? = nil,
        jobDescriptionURL: String? = nil,
        jobDescriptionText: String? = nil,
        appliedDate: Date? = nil,
        notes: String? = nil,
        desireLevel: Int? = nil,
        feedback: String? = nil,
        reviewNotes: String? = nil,
        codeSnippets: String? = nil,
        interviewDocs: String? = nil
    ) {
        self.id = UUID()
        self.position = position
        self.company = company
        self.jobDescriptionURL = jobDescriptionURL
        self.jobDescriptionText = jobDescriptionText
        self.legacyStatus = ""
        self.legacyChannel = nil
        self.appliedDate = appliedDate
        self.lastUpdated = Date()
        self.notes = notes
        self.desireLevel = desireLevel
        self.feedback = feedback
        self.reviewNotes = reviewNotes
        self.codeSnippets = codeSnippets
        self.interviewDocs = interviewDocs
    }

    /// Stage nodes newest-last (date, then creation order).
    var orderedStageNodes: [StageNode] {
        (stageNodes ?? []).sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            return $0.createdAt < $1.createdAt
        }
    }

    /// Current stage = the latest node on the timeline.
    var currentStageNode: StageNode? {
        orderedStageNodes.last
    }

    var currentStageTitle: String {
        currentStageNode?.title ?? "未开始"
    }

    var opportunityBucket: OpportunityBucket {
        guard let node = currentStageNode else { return .notStarted }
        return OpportunityBucket(rawValue: node.bucket) ?? .notStarted
    }

    /// Next upcoming timed node, or the latest past one if none upcoming.
    var nextOrLatestTimedDate: Date? {
        let dates = (stageNodes ?? []).filter(\.hasTime).map(\.date)
        guard !dates.isEmpty else { return nil }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        if let upcoming = dates.filter({ $0 >= startOfToday }).min() {
            return upcoming
        }
        return dates.max()
    }

    /// Date shown on opportunity cards: interview time if booked, else first node date, else last update.
    var displayActivityDate: Date {
        nextOrLatestTimedDate
            ?? orderedStageNodes.first?.date
            ?? appliedDate
            ?? lastUpdated
    }

    /// True when the card date is a timed interview (show clock time).
    var displayActivityIsInterview: Bool {
        nextOrLatestTimedDate != nil
    }

    /// 面试结果按时间线推导：一旦进入下一轮（后面出现任何非拒绝节点），
    /// 就认为这一轮面试通过了；后面只有「拒绝」= 未通过；还没有后续 = 等结果。
    func interviewOutcome(for node: StageNode) -> InterviewOutcome? {
        guard node.isInterview else { return nil }
        let ordered = orderedStageNodes
        guard let index = ordered.firstIndex(where: { $0.id == node.id }) else { return nil }
        let later = ordered[(index + 1)...]
        if later.isEmpty { return .pending }
        if later.contains(where: { !isRejectionNode($0) }) { return .passed }
        return .failed
    }

    private func isRejectionNode(_ node: StageNode) -> Bool {
        node.bucket == OpportunityBucket.closed.rawValue
            && !node.title.localizedCaseInsensitiveContains("offer")
    }
}

/// Result of one interview round, derived from what comes after it on the timeline.
enum InterviewOutcome {
    case passed
    case failed
    case pending

    var label: String {
        switch self {
        case .passed: return "已通过"
        case .failed: return "未通过"
        case .pending: return "等结果"
        }
    }
}
