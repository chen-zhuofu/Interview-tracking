import Foundation
import SwiftData

@Model
final class TimelineEvent {
    var id: UUID
    var title: String
    var detail: String?
    /// apply / interview / result / feedback / note / other
    var eventType: String
    var eventDate: Date
    var createdAt: Date

    var company: Company?
    var application: Application?

    init(
        title: String,
        eventType: String = "note",
        eventDate: Date = Date(),
        detail: String? = nil,
        company: Company? = nil,
        application: Application? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.eventType = eventType
        self.eventDate = eventDate
        self.createdAt = Date()
        self.company = company
        self.application = application
    }
}
