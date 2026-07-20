import Foundation

/// Opportunity lifecycle buckets for dashboard.
public enum OpportunityBucket: String, CaseIterable, Sendable {
    case notStarted = "not_started"
    case inProgress = "in_progress"
    case closed = "closed"

    public var label: String {
        let useChinese = (UserDefaults.standard.string(forKey: "appLanguage") ?? "en") == "zh"
        switch self {
        case .notStarted: return useChinese ? "未开始" : "Not started"
        case .inProgress: return useChinese ? "进行中" : "In progress"
        case .closed: return useChinese ? "已结束" : "Closed"
        }
    }

    /// Accept raw values and EN/ZH labels (agent may send either).
    public static func parse(_ raw: String?) -> OpportunityBucket? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if let bucket = OpportunityBucket(rawValue: raw) { return bucket }
        switch raw.lowercased() {
        case "未开始", "not started", "not_started": return .notStarted
        case "开始", "进行中", "面试中", "in progress", "in_progress": return .inProgress
        case "已结束", "结束", "closed": return .closed
        default: return nil
        }
    }
}
