import Foundation
import SwiftData

/// Restores a backup produced by `DataExportService`. Everything that can be
/// exported can be imported back, including attachment files. Two modes:
/// - merge: upsert by id (same id updated, new ones added, nothing deleted).
/// - replace: wipe everything first, then insert the backup.
@MainActor
enum DataImportService {
    enum Mode {
        case merge
        case replace
    }

    struct Summary {
        var counts: [String: Int] = [:]
        var copiedAttachments = 0
        var missingAttachments = 0
    }

    enum ImportError: LocalizedError {
        case dataFileNotFound

        var errorDescription: String? {
            switch self {
            case .dataFileNotFound:
                return "找不到 data.json，请选择导出时生成的备份文件夹。"
            }
        }
    }

    /// Lenient decode so older backups (without newer sections) still import.
    private struct ImportSnapshot: Decodable {
        var companies: [DataExportService.CompanyRecord]
        var applications: [DataExportService.ApplicationRecord]
        var interviews: [DataExportService.InterviewRecord]
        var timelineEvents: [DataExportService.TimelineEventRecord]
        var stageNodes: [DataExportService.StageNodeRecord]
        var mediaAttachments: [DataExportService.MediaAttachmentRecord]
        var readingItems: [DataExportService.ReadingItemRecord]
        var careerDocuments: [DataExportService.CareerDocumentRecord]
        var journalEntries: [DataExportService.JournalEntryRecord]
        var journalTags: [DataExportService.JournalTagRecord]
        var interviewInsights: [DataExportService.InterviewInsightRecord]
        var activitySessions: [DataExportService.ActivitySessionRecord]
        var todoItems: [DataExportService.TodoItemRecord]

        enum CodingKeys: String, CodingKey {
            case companies, applications, interviews, timelineEvents, stageNodes
            case mediaAttachments, readingItems, careerDocuments
            case journalEntries, journalTags, interviewInsights, activitySessions
            case todoItems
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            func list<T: Decodable>(_ key: CodingKeys) -> [T] {
                (try? c.decodeIfPresent([T].self, forKey: key)) ?? []
            }
            companies = list(.companies)
            applications = list(.applications)
            interviews = list(.interviews)
            timelineEvents = list(.timelineEvents)
            stageNodes = list(.stageNodes)
            mediaAttachments = list(.mediaAttachments)
            readingItems = list(.readingItems)
            careerDocuments = list(.careerDocuments)
            journalEntries = list(.journalEntries)
            journalTags = list(.journalTags)
            interviewInsights = list(.interviewInsights)
            activitySessions = list(.activitySessions)
            todoItems = list(.todoItems)
        }
    }

    @discardableResult
    static func importAll(from source: URL, mode: Mode, into context: ModelContext) throws -> Summary {
        let (dataFile, attachmentsDir) = try locate(source)
        let data = try Data(contentsOf: dataFile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(ImportSnapshot.self, from: data)

        if mode == .replace {
            try wipeEverything(in: context)
        }

        var summary = Summary()

        // Build id → object maps from whatever already exists (empty after wipe).
        var companyByID = try indexed(Company.self, in: context, key: \.id)
        var appByID = try indexed(Application.self, in: context, key: \.id)
        var interviewByID = try indexed(Interview.self, in: context, key: \.id)
        var stageNodeByID = try indexed(StageNode.self, in: context, key: \.id)
        var timelineByID = try indexed(TimelineEvent.self, in: context, key: \.id)
        var mediaByID = try indexed(MediaAttachment.self, in: context, key: \.id)
        var readingByID = try indexed(ReadingItem.self, in: context, key: \.id)
        var documentByID = try indexed(CareerDocument.self, in: context, key: \.id)
        var journalByID = try indexed(JournalEntry.self, in: context, key: \.id)
        var journalTagByID = try indexed(JournalTag.self, in: context, key: \.id)
        var insightByID = try indexed(InterviewInsight.self, in: context, key: \.id)
        var activityByID = try indexed(ActivitySession.self, in: context, key: \.id)
        var todoByID = try indexed(TodoItem.self, in: context, key: \.id)

        // Companies
        for rec in snapshot.companies {
            let company = companyByID[rec.id] ?? {
                let new = Company(name: rec.name)
                context.insert(new)
                companyByID[rec.id] = new
                return new
            }()
            company.id = rec.id
            company.name = rec.name
            company.website = rec.website
            company.contactPerson = rec.contactPerson
            company.contactEmail = rec.contactEmail
            company.notes = rec.notes
            company.opinion = rec.opinion
            company.companyDescription = rec.companyDescription
            company.codeRepoPath = rec.codeRepoPath
            company.createdAt = rec.createdAt
        }

        // Applications
        for rec in snapshot.applications {
            let app = appByID[rec.id] ?? {
                let new = Application(position: rec.position)
                context.insert(new)
                appByID[rec.id] = new
                return new
            }()
            app.id = rec.id
            app.position = rec.position
            app.jobDescriptionURL = rec.jobDescriptionURL
            app.jobDescriptionText = rec.jobDescriptionText
            app.appliedDate = rec.appliedDate
            app.lastUpdated = rec.lastUpdated
            app.notes = rec.notes
            app.desireLevel = rec.desireLevel
            app.feedback = rec.feedback
            app.reviewNotes = rec.reviewNotes
            app.codeSnippets = rec.codeSnippets
            app.interviewDocs = rec.interviewDocs
            app.legacyStatus = rec.legacyStatus
            app.legacyChannel = rec.legacyChannel
            app.company = rec.companyID.flatMap { companyByID[$0] }
        }

        // Interviews
        for rec in snapshot.interviews {
            let interview = interviewByID[rec.id] ?? {
                let new = Interview(interviewType: rec.interviewType)
                context.insert(new)
                interviewByID[rec.id] = new
                return new
            }()
            interview.id = rec.id
            interview.interviewType = rec.interviewType
            interview.interviewDate = rec.interviewDate
            interview.interviewer = rec.interviewer
            interview.result = rec.result
            interview.notes = rec.notes
            interview.createdAt = rec.createdAt
            interview.googleEventId = rec.googleEventId
            interview.displayTitle = rec.displayTitle
            interview.application = rec.applicationID.flatMap { appByID[$0] }
        }

        // Stage nodes
        for rec in snapshot.stageNodes {
            let node = stageNodeByID[rec.id] ?? {
                let new = StageNode(title: rec.title, bucket: rec.bucket, date: rec.date)
                context.insert(new)
                stageNodeByID[rec.id] = new
                return new
            }()
            node.id = rec.id
            node.title = rec.title
            node.bucket = rec.bucket
            node.date = rec.date
            node.hasTime = rec.hasTime
            node.isInterview = rec.isInterview
            node.note = rec.note
            node.links = rec.links
            node.createdAt = rec.createdAt
            node.application = rec.applicationID.flatMap { appByID[$0] }
        }

        // Timeline events
        for rec in snapshot.timelineEvents {
            let event = timelineByID[rec.id] ?? {
                let new = TimelineEvent(title: rec.title)
                context.insert(new)
                timelineByID[rec.id] = new
                return new
            }()
            event.id = rec.id
            event.title = rec.title
            event.detail = rec.detail
            event.eventType = rec.eventType
            event.eventDate = rec.eventDate
            event.createdAt = rec.createdAt
            event.company = rec.companyID.flatMap { companyByID[$0] }
            event.application = rec.applicationID.flatMap { appByID[$0] }
        }

        // Media attachments
        for rec in snapshot.mediaAttachments {
            let media = mediaByID[rec.id] ?? {
                let new = MediaAttachment(fileName: rec.fileName)
                context.insert(new)
                mediaByID[rec.id] = new
                return new
            }()
            media.id = rec.id
            media.fileName = rec.fileName
            media.createdAt = rec.createdAt
            media.sectionKey = rec.sectionKey
            media.stageNode = rec.stageNodeID.flatMap { stageNodeByID[$0] }
            media.company = rec.companyID.flatMap { companyByID[$0] }
        }

        // Reading items
        for rec in snapshot.readingItems {
            let item = readingByID[rec.id] ?? {
                let new = ReadingItem(
                    title: rec.title,
                    urlString: rec.urlString,
                    kind: ReadingKind(rawValue: rec.kind) ?? .blog
                )
                context.insert(new)
                readingByID[rec.id] = new
                return new
            }()
            item.id = rec.id
            item.title = rec.title
            item.urlString = rec.urlString
            item.kind = rec.kind
            item.tags = rec.tags
            item.note = rec.note
            item.readingNotes = rec.readingNotes
            item.notesUpdatedAt = rec.notesUpdatedAt
            item.fileName = rec.fileName
            item.isRead = rec.isRead
            item.createdAt = rec.createdAt
        }

        // Career documents
        for rec in snapshot.careerDocuments {
            let doc = documentByID[rec.id] ?? {
                let new = CareerDocument(
                    title: rec.title,
                    kind: DocumentKind(rawValue: rec.kind) ?? .other,
                    fileName: rec.fileName,
                    originalFileName: rec.originalFileName,
                    fileSize: rec.fileSize
                )
                context.insert(new)
                documentByID[rec.id] = new
                return new
            }()
            doc.id = rec.id
            doc.title = rec.title
            doc.kind = rec.kind
            doc.fileName = rec.fileName
            doc.originalFileName = rec.originalFileName
            doc.fileSize = rec.fileSize
            doc.note = rec.note
            doc.targetCompany = rec.targetCompany
            doc.createdAt = rec.createdAt
            doc.updatedAt = rec.updatedAt
        }

        // Journal tags
        for rec in snapshot.journalTags {
            let tag = journalTagByID[rec.id] ?? {
                let new = JournalTag(name: rec.name, sortOrder: rec.sortOrder)
                context.insert(new)
                journalTagByID[rec.id] = new
                return new
            }()
            tag.id = rec.id
            tag.name = rec.name
            tag.sortOrder = rec.sortOrder
            tag.createdAt = rec.createdAt
        }

        // Journal entries
        for rec in snapshot.journalEntries {
            let entry = journalByID[rec.id] ?? {
                let new = JournalEntry(day: rec.day)
                context.insert(new)
                journalByID[rec.id] = new
                return new
            }()
            entry.id = rec.id
            entry.day = Calendar.current.startOfDay(for: rec.day)
            entry.notes = rec.notes
            entry.createdAt = rec.createdAt
            var lines = rec.lines.map { JournalLine(tag: $0.tag, text: $0.text) }
            if lines.isEmpty {
                // Older backup: rebuild lines from the comma-separated tags.
                lines = rec.tags
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .map { JournalLine(tag: $0) }
            }
            entry.lines = lines
            if lines.isEmpty { entry.tags = rec.tags }
            entry.updatedAt = rec.updatedAt
        }

        // Interview insights
        for rec in snapshot.interviewInsights {
            let insight = insightByID[rec.id] ?? {
                let new = InterviewInsight()
                context.insert(new)
                insightByID[rec.id] = new
                return new
            }()
            insight.id = rec.id
            insight.title = rec.title
            insight.companyName = rec.companyName
            insight.body = rec.body
            insight.createdAt = rec.createdAt
            insight.updatedAt = rec.updatedAt
        }

        // Activity sessions
        for rec in snapshot.activitySessions {
            let session = activityByID[rec.id] ?? {
                let new = ActivitySession(category: rec.category, startAt: rec.startAt)
                context.insert(new)
                activityByID[rec.id] = new
                return new
            }()
            session.id = rec.id
            session.category = rec.category
            session.status = rec.status ?? ""
            session.mood = rec.mood
            session.note = rec.note
            session.startAt = rec.startAt
            session.endAt = rec.endAt
            session.createdAt = rec.createdAt
            session.updatedAt = rec.updatedAt
        }

        // Todo items
        for rec in snapshot.todoItems {
            let todo = todoByID[rec.id] ?? {
                let new = TodoItem(title: rec.title)
                context.insert(new)
                todoByID[rec.id] = new
                return new
            }()
            todo.id = rec.id
            todo.title = rec.title
            todo.isDone = rec.isDone
            todo.priority = rec.priority
            todo.category = rec.category
            todo.sortOrder = rec.sortOrder
            todo.createdAt = rec.createdAt
            todo.updatedAt = rec.updatedAt
            todo.doneAt = rec.doneAt
        }

        // Attachment files: copy back the ones referenced, keeping their names.
        let referenced = Set(
            snapshot.mediaAttachments.map(\.fileName)
                + snapshot.readingItems.compactMap(\.fileName)
                + snapshot.careerDocuments.map(\.fileName)
        )
        for fileName in referenced where !fileName.isEmpty {
            let destination = AttachmentStore.url(for: fileName)
            if FileManager.default.fileExists(atPath: destination.path) { continue }
            let candidate = attachmentsDir.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: candidate.path) {
                do {
                    try FileManager.default.copyItem(at: candidate, to: destination)
                    summary.copiedAttachments += 1
                } catch {
                    summary.missingAttachments += 1
                }
            } else {
                summary.missingAttachments += 1
            }
        }

        try context.save()

        summary.counts = [
            "companies": snapshot.companies.count,
            "applications": snapshot.applications.count,
            "interviews": snapshot.interviews.count,
            "timelineEvents": snapshot.timelineEvents.count,
            "stageNodes": snapshot.stageNodes.count,
            "mediaAttachments": snapshot.mediaAttachments.count,
            "readingItems": snapshot.readingItems.count,
            "careerDocuments": snapshot.careerDocuments.count,
            "journalEntries": snapshot.journalEntries.count,
            "journalTags": snapshot.journalTags.count,
            "interviewInsights": snapshot.interviewInsights.count,
            "activitySessions": snapshot.activitySessions.count,
            "todoItems": snapshot.todoItems.count
        ]
        return summary
    }

    // MARK: - Helpers

    /// Accepts either the backup folder or the data.json file directly.
    private static func locate(_ source: URL) throws -> (dataFile: URL, attachmentsDir: URL) {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: source.path, isDirectory: &isDir), isDir.boolValue {
            let dataFile = source.appendingPathComponent("data.json")
            guard fm.fileExists(atPath: dataFile.path) else { throw ImportError.dataFileNotFound }
            return (dataFile, source.appendingPathComponent("attachments", isDirectory: true))
        }
        if source.lastPathComponent == "data.json", fm.fileExists(atPath: source.path) {
            let root = source.deletingLastPathComponent()
            return (source, root.appendingPathComponent("attachments", isDirectory: true))
        }
        throw ImportError.dataFileNotFound
    }

    private static func indexed<T: PersistentModel>(
        _ type: T.Type,
        in context: ModelContext,
        key: (T) -> UUID
    ) throws -> [UUID: T] {
        var map: [UUID: T] = [:]
        for object in try context.fetch(FetchDescriptor<T>()) {
            map[key(object)] = object
        }
        return map
    }

    private static func wipeEverything(in context: ModelContext) throws {
        // Deleting companies cascades to applications, interviews, stage nodes,
        // timeline events and their attachments.
        for c in try context.fetch(FetchDescriptor<Company>()) { context.delete(c) }
        // Orphans not covered by a company cascade:
        for a in try context.fetch(FetchDescriptor<Application>()) { context.delete(a) }
        for i in try context.fetch(FetchDescriptor<Interview>()) { context.delete(i) }
        for t in try context.fetch(FetchDescriptor<TimelineEvent>()) { context.delete(t) }
        for s in try context.fetch(FetchDescriptor<StageNode>()) { context.delete(s) }
        for m in try context.fetch(FetchDescriptor<MediaAttachment>()) { context.delete(m) }
        for r in try context.fetch(FetchDescriptor<ReadingItem>()) { context.delete(r) }
        for d in try context.fetch(FetchDescriptor<CareerDocument>()) { context.delete(d) }
        for j in try context.fetch(FetchDescriptor<JournalEntry>()) { context.delete(j) }
        for jt in try context.fetch(FetchDescriptor<JournalTag>()) { context.delete(jt) }
        for ii in try context.fetch(FetchDescriptor<InterviewInsight>()) { context.delete(ii) }
        for act in try context.fetch(FetchDescriptor<ActivitySession>()) { context.delete(act) }
        for todo in try context.fetch(FetchDescriptor<TodoItem>()) { context.delete(todo) }
        try context.save()
    }
}
