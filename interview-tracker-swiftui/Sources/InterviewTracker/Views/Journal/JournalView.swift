import SwiftUI
import SwiftData

/// 日常记录页：今天的编辑器常驻在上面；过去的日子在下面，点一下就地展开来写。
struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var language: LanguageStore
    @Query(sort: \JournalEntry.day, order: .reverse) private var entries: [JournalEntry]
    @Query(sort: \JournalTag.sortOrder) private var tags: [JournalTag]
    @Query(sort: \InterviewInsight.updatedAt, order: .reverse) private var insights: [InterviewInsight]

    @State private var showAddTag = false
    @State private var showBackfill = false
    @State private var backfillTarget: Date?
    @State private var expandedIDs: Set<UUID> = []
    @State private var expandedInsightIDs: Set<UUID> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                HStack(alignment: .top, spacing: 22) {
                    // 左列＝「日志」一整套：今天 + 回顾（过去的日子）。
                    VStack(alignment: .leading, spacing: 22) {
                        todaySection
                        historySection
                    }
                    .frame(maxWidth: .infinity, alignment: .top)

                    HStack(alignment: .top, spacing: 22) {
                        ActivityLogSection()
                            .frame(maxWidth: .infinity, alignment: .top)
                        insightSection
                            .frame(maxWidth: .infinity, alignment: .top)
                    }
                    .containerRelativeFrame(.horizontal) { width, _ in
                        max(320, width * 0.4)
                    }
                }
            }
            .padding(28)
            .padding(.bottom, 40)
            .background(
                // 点空白处收起所有展开的卡片（卡片自身会挡住点击，不受影响）。
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { collapseAll() }
            )
        }
        .background(Color.clear)
        .onExitCommand { collapseAll() }
        .onAppear { _ = todayEntry() }
        .onDisappear { cleanupEmpties() }
        .sheet(isPresented: $showAddTag) {
            AddJournalTagSheet(nextOrder: (tags.map(\.sortOrder).max() ?? -1) + 1)
        }
        .sheet(isPresented: $showBackfill, onDismiss: {
            if let day = backfillTarget {
                backfillTarget = nil
                let created = entry(for: day)
                if !Calendar.current.isDateInToday(day) {
                    expandedIDs.insert(created.id)
                }
            }
        }) {
            JournalBackfillSheet { chosen in
                backfillTarget = chosen
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(language.t("Journal", "日志"))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(language.t(
                    "Tap a tag to add a line, then write what you did today",
                    "点一个标签，就多一行；后面接着写今天做了什么"
                ))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            statBadge(
                value: entries.filter { !$0.isEmpty }.count,
                label: language.t("Days logged", "记录天数"),
                color: AppTheme.accent
            )
        }
    }

    private func statBadge(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.muted)
        }
        .frame(minWidth: 64)
        .padding(.vertical, 8)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
    }

    // MARK: - Today

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(language.t("Today", "今天"))
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(JournalDateFormat.weekday(Date()))
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                Spacer()
                Button {
                    showBackfill = true
                } label: {
                    Label(language.t("Backfill", "补记过去"), systemImage: "calendar.badge.plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .buttonStyle(.hoverCue)
                .help(language.t("Pick a past day to fill in", "选一个过去的日期补写日志"))
            }

            JournalEditorBody(
                entry: todayEntry(),
                palette: tags,
                onAddTag: { showAddTag = true },
                onDeleteTag: deleteTag
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
    }

    // MARK: - Interview insights

    private var insightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Text(language.t("Insights", "心得"))
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button {
                    let insight = InterviewInsight()
                    modelContext.insert(insight)
                    try? modelContext.save()
                    expandedInsightIDs.insert(insight.id)
                } label: {
                    Label(language.t("Write one", "写一条"), systemImage: "square.and.pencil")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.hoverCue)
                .help(language.t("Create a new insight", "新建一条心得"))
            }

            let visible = insights.filter { !$0.isEmpty || expandedInsightIDs.contains($0.id) }
            if visible.isEmpty {
                Text(language.t(
                    "Jot something down, or tell chat “save an insight for me.”",
                    "随手记，或在聊天里说「帮我记一条心得」。"
                ))
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 10) {
                    ForEach(visible) { insight in
                        InterviewInsightCard(
                            insight: insight,
                            isExpanded: insightExpandBinding(insight.id)
                        )
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
    }

    private func insightExpandBinding(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { expandedInsightIDs.contains(id) },
            set: { expanded in
                if expanded { expandedInsightIDs.insert(id) } else { expandedInsightIDs.remove(id) }
            }
        )
    }

    // MARK: - History

    private var pastEntries: [JournalEntry] {
        // Show non-empty past days, plus any day the user just opened to backfill
        // (freshly created entries are empty until written, so keep them while expanded).
        entries.filter {
            !Calendar.current.isDateInToday($0.day)
                && (!$0.isEmpty || expandedIDs.contains($0.id))
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text(language.t("History", "回顾"))
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                if !pastEntries.isEmpty {
                    Text("\(pastEntries.count)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(AppTheme.accent.opacity(0.85))
                }
            }

            Group {
                if pastEntries.isEmpty {
                    Text(language.t(
                        "No past days yet. Tap “Backfill” to pick a day.",
                        "过去的日子还没记。点「补记过去」挑一天补上。"
                    ))
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(pastEntries) { entry in
                                JournalPastCard(
                                    entry: entry,
                                    palette: tags,
                                    isExpanded: expandBinding(entry.id),
                                    onAddTag: { showAddTag = true },
                                    onDeleteTag: deleteTag
                                )
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.bottom, 2)
                    }
                }
            }
            .frame(height: 320)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
    }

    // MARK: - Actions

    /// 收起所有展开的日志 / 心得卡片。点空白或按 Esc 时调用。
    private func collapseAll() {
        guard !expandedIDs.isEmpty || !expandedInsightIDs.isEmpty else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            expandedIDs.removeAll()
            expandedInsightIDs.removeAll()
        }
    }

    private func expandBinding(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { expandedIDs.contains(id) },
            set: { expanded in
                if expanded { expandedIDs.insert(id) } else { expandedIDs.remove(id) }
            }
        )
    }

    @discardableResult
    private func todayEntry() -> JournalEntry {
        entry(for: Date())
    }

    /// 找到某天的日志，没有就新建一条。
    private func entry(for day: Date) -> JournalEntry {
        let target = Calendar.current.startOfDay(for: day)
        if let existing = entries.first(where: { Calendar.current.isDate($0.day, inSameDayAs: target) }) {
            return existing
        }
        let entry = JournalEntry(day: target)
        modelContext.insert(entry)
        try? modelContext.save()
        return entry
    }

    private func deleteTag(_ tag: JournalTag) {
        modelContext.delete(tag)
        try? modelContext.save()
    }

    /// 离开页面时清掉没写任何东西的空日志/空心得（比如自动建的今天、点了「写一条」又没写）。
    private func cleanupEmpties() {
        var changed = false
        for entry in entries where entry.isEmpty {
            modelContext.delete(entry)
            changed = true
        }
        for insight in insights where insight.isEmpty {
            modelContext.delete(insight)
            changed = true
        }
        if changed { try? modelContext.save() }
    }
}

// MARK: - Interview insight card (collapsed → inline editor)

private struct InterviewInsightCard: View {
    @Bindable var insight: InterviewInsight
    @Binding var isExpanded: Bool

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var language: LanguageStore
    @State private var hovering = false
    @FocusState private var editing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    Text(insight.createdAt.formatted(.dateTime.month(.twoDigits).day(.twoDigits)))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(AppTheme.accent)
                        .padding(.top, 1)
                    if !isExpanded {
                        Text(insight.body.isEmpty ? language.t("(empty)", "（空）") : insight.body)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                ZStack(alignment: .topLeading) {
                    if insight.body.isEmpty {
                        Text(language.t("Write something…", "写点什么…"))
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.muted)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $insight.body)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 54, maxHeight: 220)
                        .focused($editing)
                        .onChange(of: insight.body) { _, _ in touch() }
                }
                .padding(4)
                .background(AppTheme.elevated.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))

                Button {
                    modelContext.delete(insight)
                    try? modelContext.save()
                } label: {
                    Text(language.t("Delete", "删除"))
                        .font(.caption)
                        .foregroundStyle(AppTheme.rose)
                }
                .buttonStyle(.hoverCue)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.elevated.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke((hovering || isExpanded) ? AppTheme.accent.opacity(0.4) : AppTheme.stroke, lineWidth: 1)
        )
        .onHover { value in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { hovering = value }
        }
        .onChange(of: isExpanded) { _, expanded in
            // 展开就直接把光标放进输入框，展开即可打字。
            editing = expanded
        }
        .onChange(of: editing) { _, isEditing in
            // 点到框外（输入框失焦）就收起卡片。
            if !isEditing && isExpanded {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                    isExpanded = false
                }
            }
        }
    }

    private func touch() {
        insight.updatedAt = Date()
        try? modelContext.save()
    }
}

// MARK: - Past day card (collapsed summary → inline editor)

private struct JournalPastCard: View {
    @Bindable var entry: JournalEntry
    let palette: [JournalTag]
    @Binding var isExpanded: Bool
    let onAddTag: () -> Void
    let onDeleteTag: (JournalTag) -> Void

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var language: LanguageStore
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(JournalDateFormat.weekday(entry.day))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.muted)
                        Text(JournalDateFormat.dayLabel(entry.day))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .frame(width: 76, alignment: .leading)

                    if isExpanded {
                        Spacer()
                    } else {
                        Text(entry.summaryLine)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                JournalEditorBody(
                    entry: entry,
                    palette: palette,
                    onAddTag: onAddTag,
                    onDeleteTag: onDeleteTag
                )
                HStack {
                    Button(language.t("Delete this day", "删除这天"), role: .destructive) {
                        modelContext.delete(entry)
                        try? modelContext.save()
                    }
                    .foregroundStyle(AppTheme.rose)
                    Spacer()
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke((hovering || isExpanded) ? AppTheme.accent.opacity(0.45) : AppTheme.stroke, lineWidth: 1)
        )
        .onHover { value in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { hovering = value }
        }
    }
}

// MARK: - Shared editor body (tag palette + tagged lines)

struct JournalEditorBody: View {
    @Bindable var entry: JournalEntry
    let palette: [JournalTag]
    let onAddTag: () -> Void
    let onDeleteTag: (JournalTag) -> Void

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var language: LanguageStore
    @FocusState private var focusedLine: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            tagPalette
            linesArea
        }
    }

    private var tagPalette: some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(palette) { tag in
                Button {
                    append(tag.name)
                } label: {
                    Text(tag.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppTheme.elevated, in: Capsule())
                }
                .buttonStyle(.hoverCue)
                .contextMenu {
                    Button(language.t("Delete tag “\(tag.name)”", "删除标签「\(tag.name)」"), role: .destructive) {
                        onDeleteTag(tag)
                    }
                }
                .help(language.t("Tap to add a “\(tag.name)” line", "点一下加一行「\(tag.name)」"))
            }

            Button {
                onAddTag()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                    Text(language.t("Add tag", "添加标签"))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(AppTheme.muted)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .overlay(
                    Capsule().strokeBorder(AppTheme.stroke, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
            }
            .buttonStyle(.hoverCue)
        }
    }

    @ViewBuilder
    private var linesArea: some View {
        if entry.lines.isEmpty {
            Text(language.t(
                "Tap a tag above to add a line and start writing.",
                "点上面的标签，加一行开始记。"
            ))
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
                .padding(.vertical, 6)
        } else {
            VStack(spacing: 8) {
                ForEach(entry.lines) { line in
                    lineRow(line)
                }
            }
        }
    }

    private func lineRow(_ line: JournalLine) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(line.tag)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.accent, in: Capsule())
                .padding(.top, 2)

            TextField(language.t("Write something…", "写点什么…"), text: textBinding(line.id), axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1...12)
                .focused($focusedLine, equals: line.id)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                deleteLine(line.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.muted)
            }
            .buttonStyle(.hoverCue)
            .help(language.t("Delete this line", "删除这一行"))
        }
        .padding(10)
        .background(AppTheme.elevated.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Line mutations

    private func append(_ name: String) {
        entry.appendLine(tag: name)
        try? modelContext.save()
        focusedLine = entry.lines.last?.id
    }

    private func textBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { entry.lines.first(where: { $0.id == id })?.text ?? "" },
            set: { newValue in
                var arr = entry.lines
                guard let idx = arr.firstIndex(where: { $0.id == id }) else { return }
                arr[idx].text = newValue
                entry.lines = arr
                try? modelContext.save()
            }
        )
    }

    private func deleteLine(_ id: UUID) {
        var arr = entry.lines
        arr.removeAll { $0.id == id }
        entry.lines = arr
        try? modelContext.save()
    }
}

// MARK: - Add tag sheet

struct AddJournalTagSheet: View {
    let nextOrder: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var language: LanguageStore
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language.t("Add tag", "添加标签"))
                .font(.headline)
            TextField(
                language.t("Tag name, e.g. LeetCode / blogging", "标签名，如 刷题 / 写博客"),
                text: $name
            )
                .textFieldStyle(.roundedBorder)
                .onSubmit { save() }
            HStack {
                Spacer()
                Button(language.t("Cancel", "取消")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(language.t("Add", "添加")) { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 340)
    }

    private func save() {
        let clean = name.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return }
        modelContext.insert(JournalTag(name: clean, sortOrder: nextOrder))
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Backfill (pick a past day)

struct JournalBackfillSheet: View {
    let onPick: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var language: LanguageStore
    @State private var day = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language.t("Backfill journal", "补记日志"))
                .font(.headline)
            Text(language.t(
                "Pick a past day, then open it to write.",
                "选一个过去的日期，展开那天来写。"
            ))
                .font(.caption)
                .foregroundStyle(AppTheme.muted)

            DatePicker(
                language.t("Date", "日期"),
                selection: $day,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .frame(maxWidth: 320)

            HStack {
                Spacer()
                Button(language.t("Cancel", "取消")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(language.t("Open this day", "打开这天")) {
                    onPick(day)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}

// MARK: - Date helpers

enum JournalDateFormat {
    static func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    static func dayLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return L10n.t("Today", "今天")
        }
        if Calendar.current.isDateInYesterday(date) {
            return L10n.t("Yesterday", "昨天")
        }
        let f = DateFormatter()
        f.locale = AppLanguage.current.locale
        if AppLanguage.current == .chinese {
            f.dateFormat = "M月d日"
        } else {
            f.dateFormat = "MMM d"
        }
        return f.string(from: date)
    }

    static func weekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = AppLanguage.current.locale
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }
}

// MARK: - Flow layout (wrap chips)

/// 简单的自动换行布局：塞满一行就换下一行。
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                totalHeight += rowHeight + lineSpacing
                totalWidth = max(totalWidth, rowWidth)
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth)
        return CGSize(
            width: proposal.width ?? totalWidth,
            height: totalHeight
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width - bounds.minX > maxWidth {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
