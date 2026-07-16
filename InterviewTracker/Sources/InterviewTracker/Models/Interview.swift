import Foundation
import SwiftData

@Model
final class Interview {
    var id: UUID
    var interviewType: String
    var interviewDate: Date?
    var interviewer: String?
    var result: String?
    var notes: String?
    var createdAt: Date
    /// Google Calendar event id when synced; nil if not on calendar.
    var googleEventId: String?
    /// Optional chip label override for the timeline.
    var displayTitle: String?

    var application: Application?

    init(
        interviewType: String,
        application: Application? = nil,
        interviewDate: Date? = nil,
        interviewer: String? = nil,
        result: String? = nil,
        notes: String? = nil,
        googleEventId: String? = nil,
        displayTitle: String? = nil
    ) {
        self.id = UUID()
        self.interviewType = interviewType
        self.application = application
        self.interviewDate = interviewDate
        self.interviewer = interviewer
        self.result = result
        self.notes = notes
        self.createdAt = Date()
        self.googleEventId = googleEventId
        self.displayTitle = displayTitle
    }
}
