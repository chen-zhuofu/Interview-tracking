import Foundation
import SwiftData

@Model
final class Company {
    var id: UUID
    var name: String
    var website: String?
    var contactPerson: String?
    var contactEmail: String?
    var notes: String?
    /// 用户对公司的整体看法
    var opinion: String?
    /// 公司介绍（聊天归纳或手动粘贴）
    var companyDescription: String?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Application.company)
    var applications: [Application]?

    @Relationship(deleteRule: .cascade, inverse: \TimelineEvent.company)
    var timelineEvents: [TimelineEvent]?

    @Relationship(deleteRule: .cascade, inverse: \MediaAttachment.company)
    var attachments: [MediaAttachment]?

    init(
        name: String,
        website: String? = nil,
        contactPerson: String? = nil,
        contactEmail: String? = nil,
        notes: String? = nil,
        opinion: String? = nil,
        companyDescription: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.website = website
        self.contactPerson = contactPerson
        self.contactEmail = contactEmail
        self.notes = notes
        self.opinion = opinion
        self.companyDescription = companyDescription
        self.createdAt = Date()
    }
}
