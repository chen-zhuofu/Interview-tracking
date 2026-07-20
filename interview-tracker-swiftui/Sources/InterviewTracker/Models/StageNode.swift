import Foundation
import SwiftData

/// One stage change on the timeline. The stage title is the user's own wording
/// (lightly formatted) — there is no fixed stage enum.
@Model
final class StageNode {
    var id: UUID
    /// e.g. "猎头推Leslie", "HR Call", "预约 Phone Interview 1", "Offer"
    var title: String
    /// not_started | in_progress | closed — see OpportunityBucket.
    var bucket: String
    var date: Date
    /// True when `date` carries a real clock time (a scheduled call/interview).
    var hasTime: Bool
    /// 是否算一轮面试。面试从 HR Call 起算；猎头 Call、各种「预约X」不算。
    /// 手动建节点时由用户明确选择；agent 建节点时按规则填。
    var isInterview: Bool = false
    var note: String?
    /// URLs, one per line.
    var links: String?
    var createdAt: Date

    var application: Application?

    @Relationship(deleteRule: .cascade, inverse: \MediaAttachment.stageNode)
    var attachments: [MediaAttachment]?

    init(
        title: String,
        bucket: String,
        date: Date,
        hasTime: Bool = false,
        isInterview: Bool = false,
        note: String? = nil,
        links: String? = nil,
        application: Application? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.bucket = bucket
        self.date = date
        self.hasTime = hasTime
        self.isInterview = isInterview
        self.note = note
        self.links = links
        self.createdAt = Date()
        self.application = application
    }
}

/// Image (or other file) attached to a stage node or a company detail section.
/// The file itself is copied into Application Support/InterviewTracker/attachments.
@Model
final class MediaAttachment {
    var id: UUID
    var fileName: String
    var createdAt: Date
    /// For company-section attachments: which detail box owns it
    /// (companyDescription / jobDescription / feedback / review / interviewDocs).
    var sectionKey: String?

    var stageNode: StageNode?
    var company: Company?

    init(
        fileName: String,
        sectionKey: String? = nil,
        stageNode: StageNode? = nil,
        company: Company? = nil
    ) {
        self.id = UUID()
        self.fileName = fileName
        self.createdAt = Date()
        self.sectionKey = sectionKey
        self.stageNode = stageNode
        self.company = company
    }
}
