import SwiftUI
import SwiftData

struct CalendarView: View {
    @Query private var interviews: [Interview]

    // MARK: - Grouped data

    private enum DateGroup: String, CaseIterable {
        case today = "今天"
        case tomorrow = "明天"
        case thisWeek = "本周"
        case later = "之后"
        case history = "历史记录"

        var priority: Int {
            switch self {
            case .today: return 0
            case .tomorrow: return 1
            case .thisWeek: return 2
            case .later: return 3
            case .history: return 4
            }
        }
    }

    private var groupedInterviews: [(group: DateGroup, interviews: [Interview])] {
        let now = Date()
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: now)
        let tomorrowStart = cal.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
        let tomorrowEnd = cal.date(bySettingHour: 23, minute: 59, second: 59, of: tomorrowStart) ?? tomorrowStart
        let daysToSunday = 7 - cal.component(.weekday, from: now)
        let weekEnd = cal.date(bySettingHour: 23, minute: 59, second: 59, of: cal.date(byAdding: .day, value: daysToSunday, to: todayStart)!) ?? now

        var today: [Interview] = []
        var tomorrow: [Interview] = []
        var thisWeek: [Interview] = []
        var later: [Interview] = []
        var history: [Interview] = []

        for interview in interviews {
            guard let date = interview.interviewDate else {
                later.append(interview)
                continue
            }
            let dayStart = cal.startOfDay(for: date)
            if dayStart == todayStart {
                today.append(interview)
            } else if dayStart == tomorrowStart {
                tomorrow.append(interview)
            } else if date >= todayStart && date <= weekEnd {
                thisWeek.append(interview)
            } else if date > weekEnd {
                later.append(interview)
            } else {
                history.append(interview)
            }
        }

        // Sort within groups
        let sortFn: (Interview, Interview) -> Bool = {
            ($0.interviewDate ?? .distantFuture) < ($1.interviewDate ?? .distantFuture)
        }
        today.sort(by: sortFn)
        tomorrow.sort(by: sortFn)
        thisWeek.sort(by: sortFn)
        later.sort(by: sortFn)
        history.sort(by: { ($0.interviewDate ?? .distantPast) > ($1.interviewDate ?? .distantPast) })

        var result: [(DateGroup, [Interview])] = []
        for group in [.today, .tomorrow, .thisWeek, .later] as [DateGroup] {
            let items: [Interview]
            switch group {
            case .today: items = today
            case .tomorrow: items = tomorrow
            case .thisWeek: items = thisWeek
            case .later: items = later
            default: items = []
            }
            result.append((group, items))
        }
        result.append((.history, history))
        return result
    }

    // MARK: - Body

    var body: some View {
        Group {
            if interviews.isEmpty {
                ContentUnavailableView("暂无面试安排", systemImage: "calendar.badge.clock", description: Text("在面试管理页面添加面试"))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(groupedInterviews, id: \.group) { (group, items) in
                            if !items.isEmpty {
                                sectionView(group: group, interviews: items)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("面试日历")
    }

    // MARK: - Section

    private func sectionView(group: DateGroup, interviews: [Interview]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.rawValue)
                .font(.headline)
                .foregroundStyle(group == .history ? .secondary : .primary)

            VStack(spacing: 8) {
                ForEach(interviews) { interview in
                    interviewCard(interview)
                }
            }
        }
    }

    // MARK: - Card

    private func interviewCard(_ interview: Interview) -> some View {
        HStack(spacing: 12) {
            // Type badge
            Text(INTERVIEW_TYPE_LABELS[interview.interviewType] ?? interview.interviewType)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(typeColor(interview.interviewType), in: Capsule())

            VStack(alignment: .leading, spacing: 2) {
                if let app = interview.application {
                    Text(app.company?.name ?? "未知公司")
                        .font(.subheadline.weight(.medium))
                    Text(app.position)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Result badge
            if let result = interview.result {
                Text(RESULT_LABELS[result] ?? result)
                    .font(.caption2)
                    .foregroundStyle(resultColor(result))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(resultColor(result).opacity(0.12), in: Capsule())
            }

            VStack(alignment: .trailing, spacing: 2) {
                if let date = interview.interviewDate {
                    Text(date.formatted(.dateTime.month(.twoDigits).day(.twoDigits).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
                        .font(.caption.monospacedDigit())
                }
                if let interviewer = interview.interviewer, !interviewer.isEmpty {
                    Text(interviewer)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }

    private func typeColor(_ type: String) -> Color {
        switch type {
        case "phone": return .blue
        case "video": return .purple
        case "onsite": return .orange
        default: return .gray
        }
    }

    private func resultColor(_ result: String) -> Color {
        switch result {
        case "passed": return .green
        case "failed": return .red
        default: return .gray
        }
    }
}
