import Foundation
import SwiftData

/// 一段活动的时间记录：几点开始、几点结束、做的什么。
/// 用户在聊天里告诉 agent「9点开始干活」「12点去做饭」「收工了」，由 agent 记录，
/// 用来评估每天都做了什么、各花了多长时间。
@Model
final class ActivitySession {
    var id: UUID
    /// 活动名，如「工作」「做饭」「散步」「睡觉」「看博客」。
    var category: String
    /// 用户给这段活动打的完成情况，如「已完成」「进行中」「暂停」「未完成」。可空。
    var status: String
    /// 用户当下的精力状态（ActivityMood 的 rawValue）。可选：nil 表示没记。
    /// 特意用可选类型，保证 SwiftData 加这个字段时走「轻量迁移」，不会推倒重建整表、丢历史数据。
    var mood: String?
    /// 可选细节，如「写日志功能」。
    var note: String
    var startAt: Date
    /// nil 表示还在进行中（没结束）。
    var endAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        category: String,
        startAt: Date,
        endAt: Date? = nil,
        note: String = "",
        status: String = "",
        mood: String? = nil
    ) {
        self.id = UUID()
        self.category = category
        self.status = status
        self.mood = mood
        self.startAt = startAt
        self.endAt = endAt
        self.note = note
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// 常用完成情况，界面里当快捷选项。
    static let statusPresets = ["进行中", "已完成", "未完成", "暂停"]

    /// 归属的自然日（按开始时间的 0 点）。
    var day: Date { Calendar.current.startOfDay(for: startAt) }

    var isOngoing: Bool { endAt == nil }

    /// 时长（秒）。进行中的按「现在」算。
    var durationSeconds: TimeInterval {
        let end = endAt ?? Date()
        return max(0, end.timeIntervalSince(startAt))
    }
}

/// 用户当下的精力状态：疲劳 → 精力旺盛，界面里用 emoji 表示。
enum ActivityMood: String, CaseIterable, Identifiable {
    case tired          // 疲劳
    case slightlyTired  // 略累
    case normal         // 正常
    case motivated      // 想做事
    case energetic      // 精力旺盛

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .tired: return "😫"
        case .slightlyTired: return "😪"
        case .normal: return "🙂"
        case .motivated: return "😃"
        case .energetic: return "🔥"
        }
    }

    var label: String {
        switch self {
        case .tired: return "疲劳"
        case .slightlyTired: return "略累"
        case .normal: return "正常"
        case .motivated: return "想做事"
        case .energetic: return "精力旺盛"
        }
    }

    /// 从存储的 rawValue 还原，取不到返回 nil。
    static func from(_ raw: String?) -> ActivityMood? {
        guard let raw, !raw.isEmpty else { return nil }
        return ActivityMood(rawValue: raw)
    }
}

/// 把秒数变成「X小时Y分」这样的中文时长。工具和界面共用。
enum ActivityDuration {
    static func label(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 && minutes > 0 { return "\(hours)小时\(minutes)分" }
        if hours > 0 { return "\(hours)小时" }
        if minutes > 0 { return "\(minutes)分钟" }
        return "不到1分钟"
    }
}
