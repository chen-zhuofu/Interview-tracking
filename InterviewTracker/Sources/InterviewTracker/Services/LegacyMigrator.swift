import Foundation
import SwiftData

/// One-time migration: old enum status / channel / Interview rows / timeline
/// notes → free-text StageNodes. Runs on launch until it succeeds once.
enum LegacyMigrator {
    private static let flagKey = "stageNodeMigration_v2_done"

    private static let legacyStageTitles: [String: String] = [
        "referral": "内推",
        "applied": "海投",
        "headhunter_chat": "猎头联系",
        "recruiter_chat": "Recruiter联系",
        "hr_call": "HR Call",
        "hm_chat": "Hiring Manager Chat",
        "interview_scheduled": "预约面试",
        "tech_phone_1": "Phone Interview 1",
        "tech_phone_2": "Phone Interview 2",
        "onsite": "Onsite",
        "offer": "Offer",
        "rejected": "拒绝",
        // pre-2026 legacy values
        "resume_screening": "海投",
        "first_interview": "Phone Interview 1",
        "second_interview": "Phone Interview 2",
        "third_interview": "Onsite",
        "hr_interview": "Hiring Manager Chat",
        "accepted": "Offer"
    ]

    private static let legacyChannelTitles: [String: String] = [
        "online": "海投",
        "referral": "内推",
        "headhunter": "猎头联系",
        "recruiter": "Recruiter联系"
    ]

    @MainActor
    static func runIfNeeded(in context: ModelContext) {
        if !UserDefaults.standard.bool(forKey: flagKey) {
            do {
                try migrate(in: context)
                try context.save()
                UserDefaults.standard.set(true, forKey: flagKey)
            } catch {
                print("LegacyMigrator failed: \(error.localizedDescription)")
            }
        }
        if !UserDefaults.standard.bool(forKey: seedFlagKey) {
            do {
                try seedConfirmedHistory(in: context)
                try context.save()
                UserDefaults.standard.set(true, forKey: seedFlagKey)
            } catch {
                print("LegacyMigrator seed failed: \(error.localizedDescription)")
            }
        }
        if !UserDefaults.standard.bool(forKey: interviewBackfillKey) {
            do {
                // isInterview was added after the seed ran; classify existing nodes once.
                for node in try context.fetch(FetchDescriptor<StageNode>()) {
                    node.isInterview = StageClassifier.isInterview(forTitle: node.title)
                }
                try context.save()
                UserDefaults.standard.set(true, forKey: interviewBackfillKey)
            } catch {
                print("LegacyMigrator isInterview backfill failed: \(error.localizedDescription)")
            }
        }
        if !UserDefaults.standard.bool(forKey: journalTagSeedKey) {
            do {
                let existing = try context.fetch(FetchDescriptor<JournalTag>())
                if existing.isEmpty {
                    for (index, name) in JournalTag.defaults.enumerated() {
                        context.insert(JournalTag(name: name, sortOrder: index))
                    }
                    try context.save()
                }
                UserDefaults.standard.set(true, forKey: journalTagSeedKey)
            } catch {
                print("LegacyMigrator journal tag seed failed: \(error.localizedDescription)")
            }
        }
        if !UserDefaults.standard.bool(forKey: journalLinesMigrationKey) {
            do {
                for entry in try context.fetch(FetchDescriptor<JournalEntry>()) where entry.linesData == nil {
                    var lines = entry.tagList.map { JournalLine(tag: $0) }
                    let notes = entry.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !notes.isEmpty {
                        if lines.isEmpty {
                            lines = [JournalLine(tag: "备注", text: notes)]
                        } else {
                            lines[lines.count - 1].text = notes
                        }
                    }
                    entry.lines = lines
                }
                try context.save()
                UserDefaults.standard.set(true, forKey: journalLinesMigrationKey)
            } catch {
                print("LegacyMigrator journal lines migration failed: \(error.localizedDescription)")
            }
        }
    }

    private static let interviewBackfillKey = "stageNodeIsInterviewBackfill_v1"
    private static let journalTagSeedKey = "journalTagSeed_v1"
    private static let journalLinesMigrationKey = "journalLinesMigration_v1"

    @MainActor
    private static func migrate(in context: ModelContext) throws {
        let applications = try context.fetch(FetchDescriptor<Application>())
        let cal = Calendar.current

        for app in applications {
            guard (app.stageNodes ?? []).isEmpty else { continue }

            var nodes: [StageNode] = []

            func addNode(title: String, bucket: OpportunityBucket, date: Date, hasTime: Bool, note: String? = nil) {
                // One node per (title, day).
                if nodes.contains(where: {
                    $0.title == title && cal.isDate($0.date, inSameDayAs: date)
                }) { return }
                let node = StageNode(
                    title: title,
                    bucket: bucket.rawValue,
                    date: date,
                    hasTime: hasTime,
                    isInterview: StageClassifier.isInterview(forTitle: title),
                    note: note,
                    application: app
                )
                context.insert(node)
                nodes.append(node)
            }

            let fallbackDate = app.appliedDate ?? app.lastUpdated

            // 1) Entry channels → not-started nodes on the applied date.
            let channels = (app.legacyChannel ?? "")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            for channel in channels {
                if let title = legacyChannelTitles[channel] {
                    addNode(title: title, bucket: .notStarted, date: fallbackDate, hasTime: false)
                }
            }

            // 2) Interviews → in-progress timed nodes.
            for interview in (app.interviews ?? []) {
                guard let date = interview.interviewDate else { continue }
                let custom = interview.displayTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
                let title = (custom?.isEmpty == false) ? custom! : "面试"
                addNode(
                    title: StageClassifier.formatTitle(title),
                    bucket: .inProgress,
                    date: date,
                    hasTime: !isMidnight(date),
                    note: interview.notes
                )
            }

            // 3) Old timeline notes for this company → nodes (bucket guessed).
            for event in (app.company?.timelineEvents ?? []) {
                let title = StageClassifier.formatTitle(event.title)
                guard !title.isEmpty else { continue }
                addNode(
                    title: title,
                    bucket: StageClassifier.bucket(forTitle: title),
                    date: event.eventDate,
                    hasTime: false,
                    note: event.detail
                )
            }

            // 4) Current status → only add a node when no existing node of the
            //    same bucket already represents that phase (avoids duplicates
            //    like "Recruiter Reach Out" note + "Recruiter联系" status).
            let status = app.legacyStatus.trimmingCharacters(in: .whitespaces)
            if let title = legacyStageTitles[status] {
                let bucket = StageClassifier.bucket(forTitle: title)
                let latestNodeDate = nodes.map(\.date).max() ?? fallbackDate
                let sameBucketExists = nodes.contains { $0.bucket == bucket.rawValue }
                if !sameBucketExists {
                    addNode(title: title, bucket: bucket, date: latestNodeDate, hasTime: false)
                }
            }

            app.legacyChannel = nil
        }

        // Old rows are fully represented by stage nodes now.
        for interview in try context.fetch(FetchDescriptor<Interview>()) {
            context.delete(interview)
        }
        for event in try context.fetch(FetchDescriptor<TimelineEvent>()) {
            context.delete(event)
        }
    }

    private static func isMidnight(_ date: Date) -> Bool {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) == 0 && (comps.minute ?? 0) == 0
    }

    // MARK: - One-time seed of the stage history the user confirmed (2026-07-15).
    // The old data model only stored a single current status per company, so the
    // intermediate stages below never existed in the database and cannot be
    // recovered by migration. Confirmed with the user before applying.

    private static let seedFlagKey = "stageNodeSeed_v1_done"

    private struct SeedNode {
        let title: String
        let month: Int
        let day: Int
        var hour: Int? = nil
        var minute: Int = 0
        var note: String? = nil
    }

    private static let confirmedHistory: [String: [SeedNode]] = [
        "Anthropic": [
            SeedNode(title: "猎头推Leslie", month: 7, day: 14)
        ],
        "Basis AI": [
            SeedNode(title: "猎头推Harrison", month: 7, day: 3),
            SeedNode(title: "HR Call", month: 7, day: 14),
            SeedNode(title: "预约Phone Interview 1", month: 7, day: 15)
        ],
        "DeepSeek": [
            SeedNode(title: "猎头推", month: 7, day: 14)
        ],
        "Dexmate": [
            SeedNode(title: "猎头推Leslie", month: 7, day: 14),
            SeedNode(title: "预约HR Call", month: 7, day: 15)
        ],
        "Google DeepMind": [
            SeedNode(title: "内推", month: 7, day: 13)
        ],
        "Luminai": [
            SeedNode(title: "猎头推Harrison", month: 7, day: 3),
            SeedNode(title: "HM Chat", month: 7, day: 17, hour: 10, note: "Hiring Manager 面试")
        ],
        "Moonshot（月之暗面）": [
            SeedNode(title: "内推", month: 7, day: 3)
        ],
        "NVIDIA": [
            SeedNode(title: "Recruiter联系", month: 7, day: 8),
            SeedNode(title: "预约HR Call", month: 7, day: 13),
            SeedNode(title: "HR Call", month: 7, day: 16, hour: 10)
        ],
        "OpenAI": [
            SeedNode(title: "内推", month: 7, day: 15)
        ],
        "Sierra AI": [
            SeedNode(title: "HR Call", month: 7, day: 10, hour: 14),
            SeedNode(title: "HR Call 2", month: 7, day: 17, hour: 10, note: "Recruiter Chat")
        ]
    ]

    @MainActor
    private static func seedConfirmedHistory(in context: ModelContext) throws {
        let applications = try context.fetch(FetchDescriptor<Application>())
        let cal = Calendar.current

        for app in applications {
            guard let name = app.company?.name,
                  let seeds = confirmedHistory[name] else { continue }

            for node in (app.stageNodes ?? []) {
                for attachment in (node.attachments ?? []) {
                    AttachmentStore.delete(fileName: attachment.fileName)
                    context.delete(attachment)
                }
                context.delete(node)
            }

            for seed in seeds {
                var comps = DateComponents()
                comps.year = 2026
                comps.month = seed.month
                comps.day = seed.day
                comps.hour = seed.hour ?? 12
                comps.minute = seed.minute
                guard let date = cal.date(from: comps) else { continue }
                let node = StageNode(
                    title: seed.title,
                    bucket: StageClassifier.bucket(forTitle: seed.title).rawValue,
                    date: date,
                    hasTime: seed.hour != nil,
                    isInterview: StageClassifier.isInterview(forTitle: seed.title),
                    note: seed.note,
                    application: app
                )
                context.insert(node)
            }
        }
    }
}
