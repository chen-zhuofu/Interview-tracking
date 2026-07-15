import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query private var applications: [Application]
    @Query private var interviews: [Interview]

    // MARK: - Computed stats

    private var totalApplications: Int {
        applications.count
    }

    private var interviewingCount: Int {
        applications.filter { INTERVIEWING_STAGES.contains($0.status) }.count
    }

    private var offerCount: Int {
        applications.filter { $0.status == "offer" }.count
    }

    private var thisWeekInterviewCount: Int {
        thisWeekInterviews.count
    }

    private var stageDistribution: [(stage: String, label: String, count: Int)] {
        STAGE_ORDER.map { stage in
            (stage, STAGE_LABELS[stage] ?? stage, applications.filter { $0.status == stage }.count)
        }
    }

    private var maxStageCount: Int {
        stageDistribution.map(\.count).max() ?? 1
    }

    private var thisWeekInterviews: [Interview] {
        let now = Date()
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: now)
        let daysToMonday = (weekday + 5) % 7
        guard let monday = cal.date(bySettingHour: 0, minute: 0, second: 0, of: cal.date(byAdding: .day, value: -daysToMonday, to: now)!) else { return [] }
        guard let sundayEnd = cal.date(bySettingHour: 23, minute: 59, second: 59, of: cal.date(byAdding: .day, value: 6, to: monday)!) else { return [] }

        return interviews
            .filter { interview in
                guard let date = interview.interviewDate else { return false }
                return date >= monday && date <= sundayEnd
            }
            .sorted { ($0.interviewDate ?? .distantFuture) < ($1.interviewDate ?? .distantFuture) }
    }

    private var upcomingInterviews: [Interview] {
        interviews
            .filter { ($0.interviewDate ?? .distantPast) >= Date() }
            .sorted { ($0.interviewDate ?? .distantFuture) < ($1.interviewDate ?? .distantFuture) }
    }

    private var recentActivities: [Application] {
        applications
            .sorted { ($0.lastUpdated) > ($1.lastUpdated) }
            .prefix(10)
            .map { $0 }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Stat cards
                statCardsSection

                // Stage distribution
                stageDistributionSection

                // This week interviews
                thisWeekSection

                // Recent activities
                recentActivitiesSection
            }
            .padding()
        }
        .navigationTitle("仪表盘")
    }

    // MARK: - Stat Cards

    private var statCardsSection: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            StatCard(title: "投递总数", value: "\(totalApplications)", color: .blue, icon: "doc.text")
            StatCard(title: "面试中", value: "\(interviewingCount)", color: .orange, icon: "person.2.wave.2")
            StatCard(title: "已发 Offer", value: "\(offerCount)", color: .green, icon: "checkmark.seal")
            StatCard(title: "本周面试", value: "\(thisWeekInterviewCount)", color: .purple, icon: "calendar.badge.clock")
        }
    }

    // MARK: - Stage Distribution

    private var stageDistributionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("阶段分布").font(.headline)

            if totalApplications == 0 {
                Text("暂无数据").font(.subheadline).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(stageDistribution, id: \.stage) { item in
                        HStack(spacing: 8) {
                            Text(item.label)
                                .font(.caption)
                                .frame(width: 60, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(.quaternary)
                                        .frame(height: 20)
                                    if item.count > 0 {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(.blue.opacity(0.6))
                                            .frame(
                                                width: max(CGFloat(item.count) / CGFloat(max(maxStageCount, 1)) * geo.size.width, 4),
                                                height: 20
                                            )
                                    }
                                }
                            }
                            .frame(height: 20)
                            Text("\(item.count)")
                                .font(.caption.monospacedDigit())
                                .frame(width: 30, alignment: .trailing)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - This Week

    private var thisWeekSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("本周面试").font(.headline)

            if thisWeekInterviews.isEmpty {
                Text("暂无数据").font(.subheadline).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(thisWeekInterviews) { interview in
                        interviewCard(interview)
                    }
                }
            }
        }
    }

    // MARK: - Recent Activities

    private var recentActivitiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("近期活动").font(.headline)

            if recentActivities.isEmpty {
                Text("暂无数据").font(.subheadline).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(recentActivities) { app in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(app.position) @ \(app.company?.name ?? "-")")
                                    .font(.subheadline)
                                Text("→ \(STAGE_LABELS[app.status] ?? app.status)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(app.lastUpdated.formatted(date: .numeric, time: .omitted))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Interview Card

    private func interviewCard(_ interview: Interview) -> some View {
        HStack(spacing: 12) {
            Text(INTERVIEW_TYPE_LABELS[interview.interviewType] ?? interview.interviewType)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.purple.opacity(0.12), in: Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text(interview.application?.company?.name ?? "-")
                    .font(.subheadline.weight(.medium))
                Text(interview.application?.position ?? "-")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let date = interview.interviewDate {
                Text(date.formatted(.dateTime.month(.twoDigits).day(.twoDigits).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
                    .font(.caption.monospacedDigit())
            }
        }
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}
