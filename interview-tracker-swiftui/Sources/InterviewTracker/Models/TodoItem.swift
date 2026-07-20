import Foundation
import SwiftData
import SwiftUI

/// 一条待办：「我要做的事」。可勾选完成、设优先级（P0–P3）、分「生活 / 职业」两类。
@Model
final class TodoItem {
    var id: UUID
    /// 要做的事。
    var title: String
    /// 是否已完成（勾选）。
    var isDone: Bool
    /// 优先级：TodoPriority 的 rawValue（p0/p1/p2/p3）。
    var priority: String
    /// 分类：TodoCategory 的 rawValue（life/career）。
    var category: String
    /// 同优先级里的手动排序，越小越靠前。
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
    /// 勾选完成的时间；未完成为 nil。
    var doneAt: Date?

    init(
        title: String,
        priority: TodoPriority = .p2,
        category: TodoCategory = .career,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.isDone = false
        self.priority = priority.rawValue
        self.category = category.rawValue
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
        self.doneAt = nil
    }

    var priorityValue: TodoPriority { TodoPriority(rawValue: priority) ?? .p2 }
    var categoryValue: TodoCategory { TodoCategory(rawValue: category) ?? .career }
}

/// 优先级：P0 最紧急 → P3 最不急。
enum TodoPriority: String, CaseIterable, Identifiable, Comparable {
    case p0
    case p1
    case p2
    case p3

    var id: String { rawValue }

    var label: String {
        switch self {
        case .p0: return "P0"
        case .p1: return "P1"
        case .p2: return "P2"
        case .p3: return "P3"
        }
    }

    /// 排序权重，越小越靠前（P0 最靠前）。
    var rank: Int {
        switch self {
        case .p0: return 0
        case .p1: return 1
        case .p2: return 2
        case .p3: return 3
        }
    }

    var color: Color {
        switch self {
        case .p0: return AppTheme.rose
        case .p1: return AppTheme.orange
        case .p2: return AppTheme.accent
        case .p3: return AppTheme.softBlue
        }
    }

    static func < (lhs: TodoPriority, rhs: TodoPriority) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// 分类：生活 / 职业。
enum TodoCategory: String, CaseIterable, Identifiable {
    case life
    case career

    var id: String { rawValue }

    var label: String {
        switch self {
        case .life: return "生活"
        case .career: return "职业"
        }
    }

    var icon: String {
        switch self {
        case .life: return "leaf"
        case .career: return "briefcase"
        }
    }

    var color: Color {
        switch self {
        case .life: return AppTheme.green
        case .career: return AppTheme.purple
        }
    }
}
