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
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Application.company)
    var applications: [Application]?

    init(
        name: String,
        website: String? = nil,
        contactPerson: String? = nil,
        contactEmail: String? = nil,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.website = website
        self.contactPerson = contactPerson
        self.contactEmail = contactEmail
        self.notes = notes
        self.createdAt = Date()
    }
}
