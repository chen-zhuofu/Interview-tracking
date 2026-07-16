import Foundation
import SwiftData

/// 收藏的一篇论文（本地 PDF 或链接）、tech blog 或 YouTube 视频。
@Model
final class ReadingItem {
    var id: UUID
    var title: String
    var urlString: String
    /// paper | blog | video
    var kind: String
    /// 逗号分隔的标签，如 "LLM, RLHF"
    var tags: String
    /// 一句话备注：为什么值得读。
    var note: String?
    /// 阅读笔记正文（Markdown，独立于备注）。
    var readingNotes: String?
    /// 笔记最后一次保存时间。
    var notesUpdatedAt: Date?
    /// 本地 PDF 在 AttachmentStore 里的文件名（论文常用）。
    var fileName: String?
    var isRead: Bool
    var createdAt: Date

    init(
        title: String,
        urlString: String,
        kind: ReadingKind,
        tags: String = "",
        note: String? = nil,
        fileName: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.urlString = urlString
        self.kind = kind.rawValue
        self.tags = tags
        self.note = note
        self.readingNotes = nil
        self.notesUpdatedAt = nil
        self.fileName = fileName
        self.isRead = false
        self.createdAt = Date()
    }

    var readingKind: ReadingKind {
        ReadingKind(rawValue: kind) ?? .blog
    }

    var url: URL? {
        let raw = urlString.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return nil }
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
            return URL(string: raw)
        }
        return URL(string: "https://" + raw)
    }

    /// 来源标识：本地 PDF 或域名（如 arxiv.org）。
    var domain: String {
        if fileName != nil { return "本地 PDF" }
        guard let host = url?.host() else { return "" }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    var hasNotes: Bool {
        !(readingNotes ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var tagList: [String] {
        tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

enum ReadingKind: String, CaseIterable {
    case paper
    case blog
    case video

    var label: String {
        switch self {
        case .paper: return "论文"
        case .blog: return "博客"
        case .video: return "视频"
        }
    }

    var icon: String {
        switch self {
        case .paper: return "doc.text"
        case .blog: return "text.alignleft"
        case .video: return "play.rectangle"
        }
    }
}
