import Foundation

/// Buckets + light formatting for free-text stage titles.
/// The user's wording is authoritative — we only tidy casing/spacing and
/// guess which bucket a title belongs to (the agent/user can override).
public enum StageClassifier {
    /// Guess the lifecycle bucket from a stage title.
    /// - 已结束: Offer / 拒绝
    /// - 进行中: 预约… / HR Call / HM Chat / Phone Interview / Onsite / 电面 / 终面…
    /// - 未开始: 准备投 / 官网投 / 海投 / 内推 / 猎头联系 / Recruiter联系…
    public static func bucket(forTitle raw: String) -> OpportunityBucket {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return .notStarted }

        let closedMarkers = ["offer", "拒绝", "拒了", "reject", "挂了", "婉拒", "已结束"]
        if closedMarkers.contains(where: { key.contains($0) }) { return .closed }

        let inProgressMarkers = [
            "预约", "约了", "scheduled",
            "hr call", "hr chat", "hr 电话", "hr电话",
            "hm chat", "hiring manager",
            "phone interview", "phone screen", "电面", "技术面", "一面", "二面", "三面", "四面", "五面", "终面",
            "onsite", "vo", "面试", "interview"
        ]
        if inProgressMarkers.contains(where: { key.contains($0) }) { return .inProgress }

        return .notStarted
    }

    /// Guess whether a stage title counts as an interview round.
    /// 规则：面试从 HR Call 起算；猎头 Call / 内推 / 各种「预约X」都不算面试。
    /// 只是默认值 —— 手动建节点时用户必须自己确认，用户的选择优先。
    public static func isInterview(forTitle raw: String) -> Bool {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return false }

        // 预约 = booked but not happened as an interview record yet.
        let notInterviewMarkers = ["预约", "约了", "offer", "拒绝", "拒了", "reject", "挂了", "婉拒"]
        if notInterviewMarkers.contains(where: { key.contains($0) }) { return false }

        let interviewMarkers = [
            "hr call", "hr chat", "hr 电话", "hr电话",
            "hm chat", "hiring manager",
            "phone interview", "phone screen", "电面", "技术面",
            "一面", "二面", "三面", "四面", "五面", "终面",
            "onsite", "vo", "面试", "interview"
        ]
        return interviewMarkers.contains(where: { key.contains($0) })
    }

    /// Light-touch formatting: keep the user's words, fix casing of common
    /// English stage terms and collapse extra whitespace.
    public static func formatTitle(_ raw: String) -> String {
        var text = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard !text.isEmpty else { return text }

        let phrases: [(pattern: String, replacement: String)] = [
            ("hiring manager chat", "Hiring Manager Chat"),
            ("hiring manager", "Hiring Manager"),
            ("phone interview", "Phone Interview"),
            ("phone screen", "Phone Screen"),
            ("hr call", "HR Call"),
            ("hr chat", "HR Chat"),
            ("hm chat", "HM Chat"),
            ("recruiter", "Recruiter"),
            ("onsite", "Onsite"),
            ("offer", "Offer")
        ]
        for (pattern, replacement) in phrases {
            text = text.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: [.caseInsensitive]
            )
        }
        return text
    }
}
