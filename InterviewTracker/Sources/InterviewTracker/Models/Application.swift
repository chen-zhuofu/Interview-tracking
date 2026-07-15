import Foundation
import SwiftData

@Model
final class Application {
    var id: UUID
    var position: String
    var jobDescriptionURL: String?
    var status: String
    var appliedDate: Date?
    var lastUpdated: Date
    var notes: String?

    @Relationship(inverse: \Company.applications)
    var company: Company?

    @Relationship(deleteRule: .cascade, inverse: \Interview.application)
    var interviews: [Interview]?

    init(
        position: String,
        company: Company? = nil,
        jobDescriptionURL: String? = nil,
        status: String = "applied",
        appliedDate: Date? = nil,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.position = position
        self.company = company
        self.jobDescriptionURL = jobDescriptionURL
        self.status = status
        self.appliedDate = appliedDate
        self.lastUpdated = Date()
        self.notes = notes
    }
}
