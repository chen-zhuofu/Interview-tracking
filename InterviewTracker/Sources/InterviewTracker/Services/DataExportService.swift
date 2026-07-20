import Foundation
import SwiftData

@MainActor
enum DataExportService {
    struct Manifest: Codable {
        let formatVersion: Int
        let exportedAt: Date
        let appVersion: String
        let counts: [String: Int]
        let excluded: [String]
        let missingAttachments: [String]
    }

    struct Snapshot: Codable {
        let companies: [CompanyRecord]
        let applications: [ApplicationRecord]
        let interviews: [InterviewRecord]
        let timelineEvents: [TimelineEventRecord]
        let stageNodes: [StageNodeRecord]
        let mediaAttachments: [MediaAttachmentRecord]
        let readingItems: [ReadingItemRecord]
        let careerDocuments: [CareerDocumentRecord]
        let journalEntries: [JournalEntryRecord]
        let journalTags: [JournalTagRecord]
        let interviewInsights: [InterviewInsightRecord]
        let activitySessions: [ActivitySessionRecord]
        let todoItems: [TodoItemRecord]
    }

    struct CompanyRecord: Codable {
        let id: UUID
        let name: String
        let website: String?
        let contactPerson: String?
        let contactEmail: String?
        let notes: String?
        let opinion: String?
        let companyDescription: String?
        /// 老备份没有这个键，可选解码为 nil。
        let codeRepoPath: String?
        let createdAt: Date
    }

    struct ApplicationRecord: Codable {
        let id: UUID
        let companyID: UUID?
        let position: String
        let jobDescriptionURL: String?
        let jobDescriptionText: String?
        let appliedDate: Date?
        let lastUpdated: Date
        let notes: String?
        let desireLevel: Int?
        let feedback: String?
        let reviewNotes: String?
        let codeSnippets: String?
        let interviewDocs: String?
        let legacyStatus: String
        let legacyChannel: String?
    }

    struct InterviewRecord: Codable {
        let id: UUID
        let applicationID: UUID?
        let interviewType: String
        let interviewDate: Date?
        let interviewer: String?
        let result: String?
        let notes: String?
        let createdAt: Date
        let googleEventId: String?
        let displayTitle: String?
    }

    struct TimelineEventRecord: Codable {
        let id: UUID
        let companyID: UUID?
        let applicationID: UUID?
        let title: String
        let detail: String?
        let eventType: String
        let eventDate: Date
        let createdAt: Date
    }

    struct StageNodeRecord: Codable {
        let id: UUID
        let applicationID: UUID?
        let title: String
        let bucket: String
        let date: Date
        let hasTime: Bool
        let isInterview: Bool
        let note: String?
        let links: String?
        let createdAt: Date
    }

    struct MediaAttachmentRecord: Codable {
        let id: UUID
        let stageNodeID: UUID?
        let companyID: UUID?
        let fileName: String
        let createdAt: Date
        let sectionKey: String?
    }

    struct ReadingItemRecord: Codable {
        let id: UUID
        let title: String
        let urlString: String
        let kind: String
        let tags: String
        let note: String?
        let readingNotes: String?
        let notesUpdatedAt: Date?
        let fileName: String?
        let isRead: Bool
        let createdAt: Date
    }

    struct CareerDocumentRecord: Codable {
        let id: UUID
        let title: String
        let kind: String
        let fileName: String
        let originalFileName: String
        let fileSize: Int64
        let note: String?
        let targetCompany: String?
        let createdAt: Date
        let updatedAt: Date
    }

    struct JournalLineRecord: Codable {
        let tag: String
        let text: String
    }

    struct JournalEntryRecord: Codable {
        let id: UUID
        let day: Date
        let tags: String
        let notes: String
        let lines: [JournalLineRecord]
        let createdAt: Date
        let updatedAt: Date
    }

    struct JournalTagRecord: Codable {
        let id: UUID
        let name: String
        let sortOrder: Int
        let createdAt: Date
    }

    struct InterviewInsightRecord: Codable {
        let id: UUID
        let title: String
        let companyName: String?
        let body: String
        let createdAt: Date
        let updatedAt: Date
    }

    struct ActivitySessionRecord: Codable {
        let id: UUID
        let category: String
        let status: String?
        /// 精力状态（ActivityMood rawValue）。老备份没有这个键，可选解码为 nil。
        let mood: String?
        let note: String
        let startAt: Date
        let endAt: Date?
        let createdAt: Date
        let updatedAt: Date
    }

    struct TodoItemRecord: Codable {
        let id: UUID
        let title: String
        let isDone: Bool
        let priority: String
        let category: String
        let sortOrder: Int
        let createdAt: Date
        let updatedAt: Date
        let doneAt: Date?
    }

    static func exportAll(from context: ModelContext, to destination: URL) throws {
        try context.save()

        let companies = try context.fetch(FetchDescriptor<Company>())
        let applications = try context.fetch(FetchDescriptor<Application>())
        let interviews = try context.fetch(FetchDescriptor<Interview>())
        let timelineEvents = try context.fetch(FetchDescriptor<TimelineEvent>())
        let stageNodes = try context.fetch(FetchDescriptor<StageNode>())
        let mediaAttachments = try context.fetch(FetchDescriptor<MediaAttachment>())
        let readingItems = try context.fetch(FetchDescriptor<ReadingItem>())
        let careerDocuments = try context.fetch(FetchDescriptor<CareerDocument>())
        let journalEntries = try context.fetch(FetchDescriptor<JournalEntry>())
        let journalTags = try context.fetch(FetchDescriptor<JournalTag>())
        let interviewInsights = try context.fetch(FetchDescriptor<InterviewInsight>())
        let activitySessions = try context.fetch(FetchDescriptor<ActivitySession>())
        let todoItems = try context.fetch(FetchDescriptor<TodoItem>())

        let snapshot = Snapshot(
            companies: companies.map {
                CompanyRecord(
                    id: $0.id,
                    name: $0.name,
                    website: $0.website,
                    contactPerson: $0.contactPerson,
                    contactEmail: $0.contactEmail,
                    notes: $0.notes,
                    opinion: $0.opinion,
                    companyDescription: $0.companyDescription,
                    codeRepoPath: $0.codeRepoPath,
                    createdAt: $0.createdAt
                )
            },
            applications: applications.map {
                ApplicationRecord(
                    id: $0.id,
                    companyID: $0.company?.id,
                    position: $0.position,
                    jobDescriptionURL: $0.jobDescriptionURL,
                    jobDescriptionText: $0.jobDescriptionText,
                    appliedDate: $0.appliedDate,
                    lastUpdated: $0.lastUpdated,
                    notes: $0.notes,
                    desireLevel: $0.desireLevel,
                    feedback: $0.feedback,
                    reviewNotes: $0.reviewNotes,
                    codeSnippets: $0.codeSnippets,
                    interviewDocs: $0.interviewDocs,
                    legacyStatus: $0.legacyStatus,
                    legacyChannel: $0.legacyChannel
                )
            },
            interviews: interviews.map {
                InterviewRecord(
                    id: $0.id,
                    applicationID: $0.application?.id,
                    interviewType: $0.interviewType,
                    interviewDate: $0.interviewDate,
                    interviewer: $0.interviewer,
                    result: $0.result,
                    notes: $0.notes,
                    createdAt: $0.createdAt,
                    googleEventId: $0.googleEventId,
                    displayTitle: $0.displayTitle
                )
            },
            timelineEvents: timelineEvents.map {
                TimelineEventRecord(
                    id: $0.id,
                    companyID: $0.company?.id,
                    applicationID: $0.application?.id,
                    title: $0.title,
                    detail: $0.detail,
                    eventType: $0.eventType,
                    eventDate: $0.eventDate,
                    createdAt: $0.createdAt
                )
            },
            stageNodes: stageNodes.map {
                StageNodeRecord(
                    id: $0.id,
                    applicationID: $0.application?.id,
                    title: $0.title,
                    bucket: $0.bucket,
                    date: $0.date,
                    hasTime: $0.hasTime,
                    isInterview: $0.isInterview,
                    note: $0.note,
                    links: $0.links,
                    createdAt: $0.createdAt
                )
            },
            mediaAttachments: mediaAttachments.map {
                MediaAttachmentRecord(
                    id: $0.id,
                    stageNodeID: $0.stageNode?.id,
                    companyID: $0.company?.id,
                    fileName: $0.fileName,
                    createdAt: $0.createdAt,
                    sectionKey: $0.sectionKey
                )
            },
            readingItems: readingItems.map {
                ReadingItemRecord(
                    id: $0.id,
                    title: $0.title,
                    urlString: $0.urlString,
                    kind: $0.kind,
                    tags: $0.tags,
                    note: $0.note,
                    readingNotes: $0.readingNotes,
                    notesUpdatedAt: $0.notesUpdatedAt,
                    fileName: $0.fileName,
                    isRead: $0.isRead,
                    createdAt: $0.createdAt
                )
            },
            careerDocuments: careerDocuments.map {
                CareerDocumentRecord(
                    id: $0.id,
                    title: $0.title,
                    kind: $0.kind,
                    fileName: $0.fileName,
                    originalFileName: $0.originalFileName,
                    fileSize: $0.fileSize,
                    note: $0.note,
                    targetCompany: $0.targetCompany,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt
                )
            },
            journalEntries: journalEntries.map {
                JournalEntryRecord(
                    id: $0.id,
                    day: $0.day,
                    tags: $0.tags,
                    notes: $0.notes,
                    lines: $0.lines.map { JournalLineRecord(tag: $0.tag, text: $0.text) },
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt
                )
            },
            journalTags: journalTags.map {
                JournalTagRecord(
                    id: $0.id,
                    name: $0.name,
                    sortOrder: $0.sortOrder,
                    createdAt: $0.createdAt
                )
            },
            interviewInsights: interviewInsights.map {
                InterviewInsightRecord(
                    id: $0.id,
                    title: $0.title,
                    companyName: $0.companyName,
                    body: $0.body,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt
                )
            },
            activitySessions: activitySessions.map {
                ActivitySessionRecord(
                    id: $0.id,
                    category: $0.category,
                    status: $0.status,
                    mood: $0.mood,
                    note: $0.note,
                    startAt: $0.startAt,
                    endAt: $0.endAt,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt
                )
            },
            todoItems: todoItems.map {
                TodoItemRecord(
                    id: $0.id,
                    title: $0.title,
                    isDone: $0.isDone,
                    priority: $0.priority,
                    category: $0.category,
                    sortOrder: $0.sortOrder,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt,
                    doneAt: $0.doneAt
                )
            }
        )

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

        let referencedFiles = Set(
            mediaAttachments.map(\.fileName)
                + readingItems.compactMap(\.fileName)
                + careerDocuments.map(\.fileName)
        )
        let attachmentDestination = destination.appendingPathComponent("attachments", isDirectory: true)
        try fileManager.createDirectory(at: attachmentDestination, withIntermediateDirectories: true)

        var missingAttachments: [String] = []
        let attachmentRoot = AttachmentStore.directory.standardizedFileURL
        for fileName in referencedFiles.sorted() {
            let source = AttachmentStore.url(for: fileName).standardizedFileURL
            guard source.path.hasPrefix(attachmentRoot.path + "/") else {
                missingAttachments.append(fileName)
                continue
            }
            guard fileManager.fileExists(atPath: source.path) else {
                missingAttachments.append(fileName)
                continue
            }
            try fileManager.copyItem(
                at: source,
                to: attachmentDestination.appendingPathComponent(fileName)
            )
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(snapshot).write(
            to: destination.appendingPathComponent("data.json"),
            options: .atomic
        )

        let counts = [
            "companies": companies.count,
            "applications": applications.count,
            "interviews": interviews.count,
            "timelineEvents": timelineEvents.count,
            "stageNodes": stageNodes.count,
            "mediaAttachments": mediaAttachments.count,
            "readingItems": readingItems.count,
            "careerDocuments": careerDocuments.count,
            "journalEntries": journalEntries.count,
            "journalTags": journalTags.count,
            "interviewInsights": interviewInsights.count,
            "activitySessions": activitySessions.count,
            "todoItems": todoItems.count,
            "attachmentFiles": referencedFiles.count - missingAttachments.count
        ]
        let manifest = Manifest(
            formatVersion: 1,
            exportedAt: Date(),
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            counts: counts,
            excluded: [
                "DeepSeek API Key",
                "Google OAuth tokens and client credentials",
                "SwiftData live database files",
                "unreferenced attachment files"
            ],
            missingAttachments: missingAttachments
        )
        try encoder.encode(manifest).write(
            to: destination.appendingPathComponent("manifest.json"),
            options: .atomic
        )

        try copyIfPresent(
            UserFeedbackMemoryStore.fileURL,
            to: destination.appendingPathComponent("memory/user_feedback_memory.jsonl")
        )
        try copyIfPresent(
            AgentTraceStore.fileURL,
            to: destination.appendingPathComponent("diagnostics/agent_traces.jsonl")
        )
    }

    private static func copyIfPresent(_ source: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: source.path) else { return }
        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.copyItem(at: source, to: destination)
    }
}
