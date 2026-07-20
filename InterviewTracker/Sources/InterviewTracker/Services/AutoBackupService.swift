import Foundation
import SwiftData

/// 自动备份 + 启动守卫，兜底防止「某张表被静默清空」造成的数据丢失。
///
/// 工作方式：
/// - 每次启动（以及关键写库后）把整库导出成一份带时间戳的 JSON 快照，保留最近若干份。
/// - 启动时先和「最新一份快照」比对各表行数：如果某张表现在是 0、但快照里有数据，
///   判定为异常清空，立刻用 merge 模式从快照还原（merge 只补不删，安全）。
///
/// 复用 DataExportService / DataImportService，不重复造轮子。
@MainActor
enum AutoBackupService {
    /// 最多保留多少份快照。
    static let maxSnapshots = 12

    static var root: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("InterviewTracker/backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 启动时调用：先查异常清空并还原，再存一份新快照。
    static func runStartupGuard(context: ModelContext) {
        restoreIfWiped(context: context)
        snapshot(context: context)
    }

    /// 和最新快照比对：某表现在空了但快照里有 → 从快照 merge 还原。
    private static func restoreIfWiped(context: ModelContext) {
        guard let newest = latestSnapshot(),
              let snapshotCounts = manifestCounts(in: newest) else { return }

        let current = currentCounts(context: context)
        // 只看真实实体（current 的键），避免 manifest 里 attachmentFiles 之类误判。
        let wiped = current
            .filter { key, cur in cur == 0 && (snapshotCounts[key] ?? 0) > 0 }
            .map { $0.key }

        guard !wiped.isEmpty else { return }

        do {
            try DataImportService.importAll(from: newest, mode: .merge, into: context)
            print("AutoBackup: 检测到清空的表 \(wiped)，已从 \(newest.lastPathComponent) 还原。")
        } catch {
            print("AutoBackup: 还原失败 - \(error.localizedDescription)")
        }
    }

    /// 立刻存一份快照。
    @discardableResult
    static func snapshot(context: ModelContext) -> Bool {
        let dest = root.appendingPathComponent("snapshot-" + timestamp(), isDirectory: true)
        do {
            try DataExportService.exportAll(from: context, to: dest)
            prune()
            lastSnapshotAt = Date()
            return true
        } catch {
            print("AutoBackup: 存快照失败 - \(error.localizedDescription)")
            return false
        }
    }

    /// 写库后节流调用：距上次快照不到 minInterval 秒就跳过，避免频繁全量导出。
    private static var lastSnapshotAt: Date?
    static func snapshotThrottled(context: ModelContext, minInterval: TimeInterval = 90) {
        if let last = lastSnapshotAt, Date().timeIntervalSince(last) < minInterval { return }
        snapshot(context: context)
    }

    // MARK: - Helpers

    static func latestSnapshot() -> URL? {
        snapshotDirs().first
    }

    private static func snapshotDirs() -> [URL] {
        let fm = FileManager.default
        let items = (try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        return items
            .filter { $0.lastPathComponent.hasPrefix("snapshot-") }
            .sorted { (modDate($0) ?? .distantPast) > (modDate($1) ?? .distantPast) }
    }

    private static func manifestCounts(in snapshotDir: URL) -> [String: Int]? {
        let url = snapshotDir.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(DataExportService.Manifest.self, from: data))?.counts
    }

    private static func currentCounts(context: ModelContext) -> [String: Int] {
        func count<T: PersistentModel>(_ type: T.Type) -> Int {
            (try? context.fetchCount(FetchDescriptor<T>())) ?? 0
        }
        return [
            "companies": count(Company.self),
            "applications": count(Application.self),
            "interviews": count(Interview.self),
            "timelineEvents": count(TimelineEvent.self),
            "stageNodes": count(StageNode.self),
            "mediaAttachments": count(MediaAttachment.self),
            "readingItems": count(ReadingItem.self),
            "careerDocuments": count(CareerDocument.self),
            "journalEntries": count(JournalEntry.self),
            "journalTags": count(JournalTag.self),
            "interviewInsights": count(InterviewInsight.self),
            "activitySessions": count(ActivitySession.self),
            "todoItems": count(TodoItem.self)
        ]
    }

    private static func prune() {
        let fm = FileManager.default
        for old in snapshotDirs().dropFirst(maxSnapshots) {
            try? fm.removeItem(at: old)
        }
    }

    private static func modDate(_ url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    private static func timestamp() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return f.string(from: Date())
    }
}
