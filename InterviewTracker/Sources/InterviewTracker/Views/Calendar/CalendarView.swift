import SwiftUI
import SwiftData

struct CalendarView: View {
    var isPanel: Bool = false

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var navigation: NavigationStore
    @Query private var stageNodes: [StageNode]

    private enum DateGroup: String, CaseIterable {
        case today = "今天"
        case laterThisWeek = "这周晚些时候"
        case nextWeek = "下周"
        case later = "以后"
        case past = "过去的面试"

        var accent: Color {
            switch self {
            case .today: return AppTheme.accent
            case .laterThisWeek: return AppTheme.softBlue
            case .nextWeek: return AppTheme.orange
            case .later: return AppTheme.purple
            case .past: return AppTheme.muted
            }
        }
    }

    /// 日历条目：面试节点一律显示（没钟点就“时间待定”）；非面试节点只显示约了具体时间的。
    private var calendarNodes: [StageNode] {
        stageNodes.filter { $0.isInterview || $0.hasTime }
    }

    private var groupedNodes: [(group: DateGroup, nodes: [StageNode])] {
        let now = Date()
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: now)

        let thisWeekBounds = WeekBounds.mondayToSunday(containing: now, calendar: cal)
        let thisWeekEnd = thisWeekBounds?.end ?? now

        let nextWeekStartDay = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: thisWeekEnd)) ?? now
        let nextWeekBounds = WeekBounds.mondayToSunday(containing: nextWeekStartDay, calendar: cal)
        let nextWeekEnd = nextWeekBounds?.end ?? now

        var today: [StageNode] = []
        var laterThisWeek: [StageNode] = []
        var nextWeek: [StageNode] = []
        var later: [StageNode] = []
        var past: [StageNode] = []

        for node in calendarNodes {
            let date = node.date
            let dayStart = cal.startOfDay(for: date)
            if dayStart == todayStart {
                today.append(node)
            } else if date < todayStart {
                past.append(node)
            } else if date <= thisWeekEnd {
                laterThisWeek.append(node)
            } else if date <= nextWeekEnd {
                nextWeek.append(node)
            } else {
                later.append(node)
            }
        }

        let ascending: (StageNode, StageNode) -> Bool = { $0.date < $1.date }
        today.sort(by: ascending)
        laterThisWeek.sort(by: ascending)
        nextWeek.sort(by: ascending)
        later.sort(by: ascending)
        past.sort(by: { $0.date > $1.date })

        return [
            (.today, today),
            (.laterThisWeek, laterThisWeek),
            (.nextWeek, nextWeek),
            (.later, later),
            (.past, past)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isPanel {
                panelHeader
            }

            Group {
                if calendarNodes.isEmpty {
                    ContentUnavailableView(
                        "暂无面试安排",
                        systemImage: "calendar.badge.clock",
                        description: Text("在底部聊天框说说时间和公司，会自动出现在这里")
                    )
                    .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: isPanel ? 20 : 28) {
                            if !isPanel {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("日历")
                                        .font(.system(size: 34, weight: .bold, design: .rounded))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text("今天、这周、下周，一眼看清节奏")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }

                            ForEach(groupedNodes, id: \.group) { (group, items) in
                                if !items.isEmpty {
                                    sectionView(group: group, nodes: items)
                                }
                            }
                        }
                        .padding(isPanel ? 16 : 28)
                        .padding(.bottom, isPanel ? 100 : 28)
                    }
                }
            }
        }
        .background(isPanel ? AppTheme.card : AppTheme.background)
    }

    private var panelHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("日历")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("今天、这周、下周")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
            Button {
                navigation.closeCalendar()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.hoverCue)
            .help("关闭")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.stroke)
                .frame(height: 1)
        }
    }

    private func sectionView(group: DateGroup, nodes: [StageNode]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(group.accent)
                    .frame(width: 8, height: 8)
                Text(group.rawValue)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(group == .past ? AppTheme.textSecondary : AppTheme.textPrimary)
                Text("\(nodes.count)")
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(AppTheme.muted)
            }

            VStack(spacing: 10) {
                ForEach(nodes) { node in
                    Button {
                        if let id = node.application?.company?.id {
                            navigation.openCompany(id)
                        }
                    } label: {
                        nodeCard(node)
                    }
                    .buttonStyle(.hoverCue)
                }
            }
        }
    }

    private func nodeCard(_ node: StageNode) -> some View {
        HStack(spacing: 14) {
            Text(node.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.orange, in: Capsule())

            VStack(alignment: .leading, spacing: 3) {
                Text(node.application?.company?.name ?? "未知公司")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(node.application?.position ?? "")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Text(
                node.hasTime
                ? node.date.formatted(.dateTime.month(.twoDigits).day(.twoDigits).hour().minute())
                : node.date.formatted(.dateTime.month(.twoDigits).day(.twoDigits)) + " 时间待定"
            )
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}
