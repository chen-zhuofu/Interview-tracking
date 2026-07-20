import Foundation

/// Opportunity lifecycle buckets for dashboard.
public enum OpportunityBucket: String, CaseIterable, Sendable {
    case notStarted = "not_started"
    case inProgress = "in_progress"
    case closed = "closed"

    public var label: String {
        switch self {
        case .notStarted: return "未开始"
        case .inProgress: return "进行中"
        case .closed: return "已结束"
        }
    }

    /// Accept both raw values and Chinese labels (agent may send either).
    public static func parse(_ raw: String?) -> OpportunityBucket? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if let bucket = OpportunityBucket(rawValue: raw) { return bucket }
        switch raw {
        case "未开始": return .notStarted
        case "开始", "进行中", "面试中": return .inProgress
        case "已结束", "结束": return .closed
        default: return nil
        }
    }
}
