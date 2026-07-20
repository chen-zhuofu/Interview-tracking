import SwiftUI
import SwiftData

/// 「时间记录」区：按天看每段活动（几点到几点、多久、状态），以及各类活动的总时长。
/// 记录可以靠聊天里跟 agent 说「几点开始干活 / 收工了」，也可以在这里手动加 / 改。
struct ActivityLogSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActivitySession.startAt, order: .reverse) private var sessions: [ActivitySession]

    @State private var editorSession: ActivitySession?
    @State private var showAdd = false

    private var cal: Calendar { Calendar.current }

    /// 所有记录按天分组，最近的一天在最上面；每天内部按开始时间排。
    private var dayGroups: [(day: Date, sessions: [ActivitySession])] {
        let groups = Dictionary(grouping: sessions) { cal.startOfDay(for: $0.startAt) }
        return groups
            .map { (day: $0.key, sessions: $0.value.sorted { $0.startAt < $1.startAt }) }
            .sorted { $0.day > $1.day }
    }

    /// 用过的活动名，给手动添加时当快捷选项。
    private var recentCategories: [String] {
        var seen: [String] = []
        for session in sessions {
            let name = session.category.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty, !seen.contains(name) { seen.append(name) }
            if seen.count >= 8 { break }
        }
        return seen
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Group {
                if sessions.isEmpty {
                    Text("还没有记录。跟 agent 说「9点开始干活」「收工了」，或点右上角＋手动加一段。")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            ForEach(dayGroups, id: \.day) { group in
                                dayGroupView(group.day, group.sessions)
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.bottom, 2)
                    }
                }
            }
            .frame(height: 340)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
        .sheet(isPresented: $showAdd) {
            ActivityEditorSheet(existing: nil, defaultDay: cal.startOfDay(for: Date()), suggestions: recentCategories)
        }
        .sheet(item: $editorSession) { session in
            ActivityEditorSheet(existing: session, defaultDay: session.day, suggestions: recentCategories)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("时间与状态记录")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Button {
                showAdd = true
            } label: {
                Label("加一段", systemImage: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            .buttonStyle(.hoverCue)
            .help("手动添加一段时间记录")
        }
    }

    @ViewBuilder
    private func dayGroupView(_ day: Date, _ daySessions: [ActivitySession]) -> some View {
        let total = daySessions.reduce(0) { $0 + $1.durationSeconds }
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("\(JournalDateFormat.dayLabel(day)) · \(JournalDateFormat.weekday(day))")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(JournalDateFormat.isToday(day) ? AppTheme.accent : AppTheme.textPrimary)
                Spacer(minLength: 4)
                if total > 0 {
                    Text("共 \(ActivityDuration.label(total))")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.muted)
                }
            }

            VStack(spacing: 8) {
                ForEach(daySessions) { session in
                    ActivityRow(
                        session: session,
                        onTap: { editorSession = session },
                        onStop: { stop(session) }
                    )
                }
            }
        }
    }

    private func stop(_ session: ActivitySession) {
        session.endAt = Date()
        session.updatedAt = Date()
        try? modelContext.save()
        AutoBackupService.snapshotThrottled(context: modelContext)
    }
}

// MARK: - Status color

enum ActivityStatusStyle {
    static func color(_ status: String) -> Color {
        switch status {
        case "已完成": return AppTheme.accent
        case "进行中": return AppTheme.orange
        case "未完成": return AppTheme.rose
        case "暂停": return AppTheme.muted
        default: return AppTheme.textSecondary
        }
    }
}

// MARK: - One activity row (compact, tap to edit)

private struct ActivityRow: View {
    @Bindable var session: ActivitySession
    let onTap: () -> Void
    let onStop: () -> Void

    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(timeRange)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer(minLength: 4)
                Text(session.isOngoing ? "进行中 · \(ActivityDuration.label(session.durationSeconds))"
                                       : ActivityDuration.label(session.durationSeconds))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(session.isOngoing ? AppTheme.orange : AppTheme.muted)
            }

            HStack(spacing: 6) {
                Text(session.category)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(session.isOngoing ? AppTheme.orange : AppTheme.accent, in: Capsule())

                if let mood = ActivityMood.from(session.mood) {
                    Text(mood.emoji)
                        .font(.system(size: 13))
                        .help(mood.label)
                }

                if !session.status.isEmpty {
                    Text(session.status)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ActivityStatusStyle.color(session.status))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .overlay(
                            Capsule().stroke(ActivityStatusStyle.color(session.status).opacity(0.5), lineWidth: 1)
                        )
                }

                Spacer(minLength: 4)

                if session.isOngoing {
                    Button("结束") { onStop() }
                        .buttonStyle(.hoverCue)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.orange)
                }
            }

            if !session.note.isEmpty {
                Text(session.note)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.elevated.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    session.isOngoing ? AppTheme.orange.opacity(0.4)
                        : (hovering ? AppTheme.accent.opacity(0.4) : Color.clear),
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onHover { value in
            withAnimation(.easeOut(duration: 0.15)) { hovering = value }
        }
        .help("点一下编辑这段")
    }

    private var timeRange: String {
        let start = ActivityRow.clock.string(from: session.startAt)
        if let end = session.endAt {
            return "\(start)–\(ActivityRow.clock.string(from: end))"
        }
        return "\(start)– …"
    }

    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()
}

// MARK: - Pick a day to view

struct ActivityDayPickerSheet: View {
    let day: Date
    let onPick: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var chosen: Date

    init(day: Date, onPick: @escaping (Date) -> Void) {
        self.day = day
        self.onPick = onPick
        _chosen = State(initialValue: day)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("挑一天看")
                .font(.headline)
            Text("选一个日期，看那天的时间记录。")
                .font(.caption)
                .foregroundStyle(AppTheme.muted)

            DatePicker(
                "日期",
                selection: $chosen,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .frame(maxWidth: 320)

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("看这天") {
                    onPick(chosen)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}

// MARK: - Add / edit sheet

struct ActivityEditorSheet: View {
    let existing: ActivitySession?
    let defaultDay: Date
    let suggestions: [String]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var category = ""
    @State private var status = ""
    @State private var mood = ""
    @State private var note = ""
    @State private var startAt = Date()
    @State private var hasEnd = false
    @State private var endAt = Date()
    @State private var loaded = false

    private var isEditing: Bool { existing != nil }

    /// 强制 24 小时制的 locale（语言沿用系统，只把时钟改成 0–23 点）。
    private var clockLocale: Locale {
        var components = Locale.Components(locale: .current)
        components.hourCycle = .zeroToTwentyThree
        return Locale(components: components)
    }

    private var canSave: Bool {
        !category.trimmingCharacters(in: .whitespaces).isEmpty
            && (!hasEnd || endAt >= startAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isEditing ? "编辑这段" : "加一段时间记录")
                .font(.headline)

            field("做了什么") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("活动名，如 工作 / 看博客 / 做饭", text: $category)
                        .textFieldStyle(.roundedBorder)
                    if !suggestions.isEmpty {
                        FlowLayout(spacing: 6, lineSpacing: 6) {
                            ForEach(suggestions, id: \.self) { name in
                                chip(name, selected: category == name) { category = name }
                            }
                        }
                    }
                }
            }

            field("状态") {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(ActivityMood.allCases) { m in
                        moodChip(m, selected: mood == m.rawValue) {
                            mood = (mood == m.rawValue) ? "" : m.rawValue
                        }
                    }
                }
            }

            field("完成情况") {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(ActivitySession.statusPresets, id: \.self) { preset in
                        chip(preset, selected: status == preset) {
                            status = (status == preset) ? "" : preset
                        }
                    }
                }
            }

            field("开始") {
                DatePicker("", selection: $startAt, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .environment(\.locale, clockLocale)
            }

            field("结束") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("已经结束", isOn: $hasEnd)
                    if hasEnd {
                        // 不给范围限制，否则结束时间调不到比「开始」更早的点（比如上午 0:30）。
                        // 顺序是否合理交给 canSave 校验：结束早于开始时保存按钮会禁用。
                        DatePicker("", selection: $endAt, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .environment(\.locale, clockLocale)
                        if endAt < startAt {
                            Text("结束早于开始，把「开始」往前调，或改结束时间。")
                                .font(.caption)
                                .foregroundStyle(AppTheme.orange)
                        }
                    } else {
                        Text("不打开就是「进行中」。")
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                    }
                }
            }

            field("备注（可选）") {
                TextField("补一句这段做了什么", text: $note, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
            }

            HStack {
                if isEditing {
                    Button("删除", role: .destructive) { deleteExisting() }
                        .foregroundStyle(AppTheme.rose)
                }
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("保存") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear(perform: loadIfNeeded)
    }

    @ViewBuilder
    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
            content()
        }
    }

    private func chip(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selected ? .black : AppTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? AppTheme.accent : AppTheme.elevated, in: Capsule())
        }
        .buttonStyle(.hoverCue)
    }

    private func moodChip(_ mood: ActivityMood, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(mood.emoji)
                    .font(.system(size: 14))
                Text(mood.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(selected ? .black : AppTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(selected ? AppTheme.accent : AppTheme.elevated, in: Capsule())
        }
        .buttonStyle(.hoverCue)
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        if let existing {
            category = existing.category
            status = existing.status
            mood = existing.mood ?? ""
            note = existing.note
            startAt = existing.startAt
            if let end = existing.endAt {
                hasEnd = true
                endAt = end
            } else {
                hasEnd = false
                endAt = existing.startAt
            }
        } else {
            // 默认落在所选那天，钟点取现在的时分。
            let now = Date()
            let comps = Calendar.current.dateComponents([.hour, .minute], from: now)
            startAt = Calendar.current.date(
                bySettingHour: comps.hour ?? 9, minute: comps.minute ?? 0, second: 0, of: defaultDay
            ) ?? defaultDay
            endAt = startAt
        }
    }

    private func save() {
        let name = category.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let cleanStatus = status.trimmingCharacters(in: .whitespaces)
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let end = hasEnd ? max(startAt, endAt) : nil

        let cleanMood = mood.isEmpty ? nil : mood
        if let existing {
            existing.category = name
            existing.status = cleanStatus
            existing.mood = cleanMood
            existing.note = cleanNote
            existing.startAt = startAt
            existing.endAt = end
            existing.updatedAt = Date()
        } else {
            let session = ActivitySession(
                category: name,
                startAt: startAt,
                endAt: end,
                note: cleanNote,
                status: cleanStatus,
                mood: cleanMood
            )
            modelContext.insert(session)
        }
        try? modelContext.save()
        AutoBackupService.snapshotThrottled(context: modelContext)
        dismiss()
    }

    private func deleteExisting() {
        if let existing {
            modelContext.delete(existing)
            try? modelContext.save()
            AutoBackupService.snapshotThrottled(context: modelContext)
        }
        dismiss()
    }
}
