import Foundation
import SwiftData

/// 一天里的一行记录：一个 tag chip + 后面跟着写的字。
struct JournalLine: Codable, Identifiable, Hashable {
    var id: UUID
    var tag: String
    var text: String

    init(id: UUID = UUID(), tag: String, text: String = "") {
        self.id = id
        self.tag = tag
        self.text = text
    }
}

/// 一天的日志：由若干行（tag + 文字）组成。每天最多一条，按 day 去重。
@Model
final class JournalEntry {
    var id: UUID
    /// 归一化到当天 0 点，作为一天的唯一键。
    var day: Date
    /// 各行 tag 的并集，逗号分隔——给首页卡片/导出/筛选用，随 lines 自动同步。
    var tags: String
    /// 旧版自由文字（保留，用于历史迁移与导出）。
    var notes: String
    /// 结构化行内容，编码后的 [JournalLine]。可选，方便平滑迁移。
    var linesData: Data?
    var createdAt: Date
    var updatedAt: Date

    init(day: Date, tags: String = "", notes: String = "") {
        self.id = UUID()
        self.day = Calendar.current.startOfDay(for: day)
        self.tags = tags
        self.notes = notes
        self.linesData = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// 每天的行。读时解码，写时编码，并同步 tags 与更新时间。
    var lines: [JournalLine] {
        get {
            guard let linesData,
                  let decoded = try? JSONDecoder().decode([JournalLine].self, from: linesData)
            else { return [] }
            return decoded
        }
        set {
            linesData = try? JSONEncoder().encode(newValue)
            var seen: [String] = []
            for line in newValue {
                let t = line.tag.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty, !seen.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                    seen.append(t)
                }
            }
            tags = seen.joined(separator: ", ")
            updatedAt = Date()
        }
    }

    var tagList: [String] {
        tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// 追加一行（新 tag chip，正文留空等用户写）。
    func appendLine(tag: String) {
        let clean = tag.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return }
        var current = lines
        current.append(JournalLine(tag: clean))
        lines = current
    }

    var isEmpty: Bool {
        let noLines = lines.allSatisfy {
            $0.tag.trimmingCharacters(in: .whitespaces).isEmpty
                && $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return noLines && notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 一行文字预览（回顾折叠时用）。
    var summaryLine: String {
        let parts = lines.map { line -> String in
            let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? line.tag : "\(line.tag)：\(text)"
        }
        let joined = parts.joined(separator: " · ")
        return joined.isEmpty ? notes : joined
    }
}

/// 可点击的日志标签目录。预置 4 个，用户可自由增删。
@Model
final class JournalTag {
    var id: UUID
    var name: String
    /// 排序用，越小越靠前。
    var sortOrder: Int
    var createdAt: Date

    init(name: String, sortOrder: Int) {
        self.id = UUID()
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }

    static let defaults = ["复盘", "看博客", "复习", "实际做项目"]
}
