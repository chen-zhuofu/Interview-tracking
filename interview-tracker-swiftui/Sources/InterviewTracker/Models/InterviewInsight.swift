import Foundation
import SwiftData

/// 一条面试心得：自由文字为主，可选标题和关联公司。用户手写或让 agent 帮记。
@Model
final class InterviewInsight {
    var id: UUID
    /// 标题（可选），如 "NVIDIA · HR Call 复盘"。
    var title: String
    /// 关联公司名（可选，纯文本，不建关系）。
    var companyName: String?
    /// 心得正文，自由书写。
    var body: String
    var createdAt: Date
    var updatedAt: Date

    init(title: String = "", companyName: String? = nil, body: String = "") {
        self.id = UUID()
        self.title = title
        self.companyName = companyName
        self.body = body
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (companyName ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// 折叠时的一行预览。
    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        let company = (companyName ?? "").trimmingCharacters(in: .whitespaces)
        if !company.isEmpty { return "\(company) 面试心得" }
        let firstLine = body.split(separator: "\n").first.map(String.init) ?? "未命名心得"
        return String(firstLine.prefix(30))
    }
}
