import Foundation
import SwiftData

/// 求职资料：简历 / presentation slides / cover letter 等文件。
/// 文件本体拷贝进 AttachmentStore，原文件移动或删除都不影响。
@Model
final class CareerDocument {
    var id: UUID
    var title: String
    /// resume | slides | coverLetter | other
    var kind: String
    /// AttachmentStore 里的文件名。
    var fileName: String
    /// 原始文件名（保留扩展名，用于显示和复制出去时的命名）。
    var originalFileName: String
    var fileSize: Int64
    /// 备注：比如“投 OpenAI 用的版本”“英文版 v3”。
    var note: String?
    /// 关联公司（可选，纯文本）。
    var targetCompany: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        title: String,
        kind: DocumentKind,
        fileName: String,
        originalFileName: String,
        fileSize: Int64,
        note: String? = nil,
        targetCompany: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.kind = kind.rawValue
        self.fileName = fileName
        self.originalFileName = originalFileName
        self.fileSize = fileSize
        self.note = note
        self.targetCompany = targetCompany
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var documentKind: DocumentKind {
        DocumentKind(rawValue: kind) ?? .other
    }

    var fileExtension: String {
        (originalFileName as NSString).pathExtension.lowercased()
    }

    var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

enum DocumentKind: String, CaseIterable {
    case resume
    case slides
    case coverLetter
    case other

    var label: String {
        switch self {
        case .resume: return L10n.t("Resume", "简历")
        case .slides: return "Slides"
        case .coverLetter: return "Cover Letter"
        case .other: return L10n.t("Other", "其他")
        }
    }

    var icon: String {
        switch self {
        case .resume: return "person.text.rectangle"
        case .slides: return "rectangle.on.rectangle.angled"
        case .coverLetter: return "envelope.open.badge.clock"
        case .other: return "doc"
        }
    }

    /// 从文件名猜类型（导入时的默认值，用户可改）。
    static func guess(fromFileName name: String) -> DocumentKind {
        let lower = name.lowercased()
        if lower.contains("resume") || lower.contains("cv") || lower.contains("简历") {
            return .resume
        }
        if lower.contains("slide") || lower.contains("deck") || lower.contains("presentation")
            || lower.hasSuffix(".key") || lower.hasSuffix(".ppt") || lower.hasSuffix(".pptx") {
            return .slides
        }
        if lower.contains("cover") || lower.contains("求职信") {
            return .coverLetter
        }
        return .other
    }
}
