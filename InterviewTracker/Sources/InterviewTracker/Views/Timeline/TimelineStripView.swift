import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Payload for drag-and-drop reschedule (move a node to another day).
struct TimelineDragItem: Codable, Transferable, Hashable {
    let nodeID: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

/// Lightweight row for the strip — one per StageNode.
struct TimelineDisplayEvent: Identifiable, Hashable {
    let id: UUID
    let title: String
    let bucket: OpportunityBucket
    let eventDate: Date
    let hasTime: Bool
    let companyName: String?
    let companyID: UUID?

    init(from node: StageNode) {
        self.id = node.id
        self.title = node.title
        self.bucket = OpportunityBucket(rawValue: node.bucket) ?? .notStarted
        self.eventDate = node.date
        self.hasTime = node.hasTime
        self.companyName = node.application?.company?.name
        self.companyID = node.application?.company?.id
    }

    static func fromNodes(_ nodes: [StageNode]) -> [TimelineDisplayEvent] {
        nodes.map(TimelineDisplayEvent.init).sorted { $0.eventDate < $1.eventDate }
    }
}

private struct TimelineCreateDraft: Identifiable {
    let id = UUID()
    let day: Date
}

/// One horizontal track: same-day chips stack overlapping, hover fans them out.
/// Click expands to week rows; vertical scroll moves earlier/later weeks.
struct TimelineStripView: View {
    let events: [TimelineDisplayEvent]
    var title: String = "时间线"
    var onExpandedChange: ((Bool) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var navigation: NavigationStore
    @EnvironmentObject private var chat: ChatViewModel

    @State private var isExpanded = false
    @State private var hoveredDayKey: String?
    @State private var draggingNodeID: UUID?
    @State private var dropHighlightDayKey: String?
    @State private var createDraft: TimelineCreateDraft?
    @State private var detailNodeID: UUID?
    @State private var pendingDelete: TimelineDisplayEvent?

    private let dayWidth: CGFloat = 118
    private let trackHeight: CGFloat = 120
    private let weekRowHeight: CGFloat = 108
    private let expandedVisibleWeeks = 4

    /// Height the dashboard should reserve when expanded (header + 4 week rows + padding).
    static var expandedCardHeight: CGFloat {
        let weekRow: CGFloat = 108
        let weeks = 4
        let spacing: CGFloat = 10
        let header: CGFloat = 44
        let padding: CGFloat = 36
        let gap: CGFloat = 12
        return padding + header + gap
            + CGFloat(weeks) * weekRow
            + CGFloat(weeks - 1) * spacing
    }

    /// Relative week indices (0 = this week). Earlier weeks first so continuous scroll feels natural.
    private var scrollableWeekIndices: [Int] {
        let cal = Calendar.current
        guard let thisMonday = WeekBounds.mondayToSunday()?.start else {
            return Array(-16...8)
        }
        var minWeek = -16
        var maxWeek = 8
        for event in events {
            let day = cal.startOfDay(for: event.eventDate)
            guard let monday = WeekBounds.mondayToSunday(containing: day)?.start else { continue }
            let days = cal.dateComponents([.day], from: thisMonday, to: monday).day ?? 0
            let week = Int((Double(days) / 7.0).rounded(.towardZero))
            minWeek = min(minWeek, week - 3)
            maxWeek = max(maxWeek, week + 3)
        }
        return Array(minWeek...maxWeek)
    }

    private func weekDays(relativeWeek: Int) -> [Date] {
        let cal = Calendar.current
        guard let thisMonday = WeekBounds.mondayToSunday()?.start,
              let monday = cal.date(byAdding: .weekOfYear, value: relativeWeek, to: thisMonday)
        else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
    }

    private var eventsByDay: [String: [TimelineDisplayEvent]] {
        Dictionary(grouping: events) { dayKey($0.eventDate) }
            .mapValues { $0.sorted { lhs, rhs in
                let ln = lhs.companyName ?? ""
                let rn = rhs.companyName ?? ""
                if ln != rn { return ln.localizedCaseInsensitiveCompare(rn) == .orderedAscending }
                return lhs.title < rhs.title
            }}
    }

    /// Wide day range for collapsed horizontal pan (today ± events ± padding).
    private var collapsedDays: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let eventDates = events.map { cal.startOfDay(for: $0.eventDate) }
        let earliestEvent = eventDates.min() ?? today
        let latestEvent = eventDates.max() ?? today
        let start = cal.date(
            byAdding: .day,
            value: -3,
            to: min(earliestEvent, cal.date(byAdding: .day, value: -14, to: today)!)
        )!
        let end = cal.date(
            byAdding: .day,
            value: 3,
            to: max(latestEvent, cal.date(byAdding: .day, value: 14, to: today)!)
        )!
        var result: [Date] = []
        var cursor = start
        while cursor <= end {
            result.append(cursor)
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                if isExpanded {
                    collapseExpanded()
                } else {
                    expandTimeline()
                }
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer(minLength: 8)
                    if isExpanded {
                        Text("收起")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isExpanded ? "收起时间线" : "展开时间线")

            if isExpanded {
                expandedWeeksPanel
            } else if events.isEmpty {
                Text("还没有时间线节点。右键任意一天可以新建，或在聊天里说一句。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { expandTimeline() }
            } else {
                collapsedStrip
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.card.opacity(0.8), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
        .sheet(item: $createDraft) { draft in
            StageNodeCreateSheet(day: draft.day) { company, title, day, isInterview in
                createNodeLocally(companyName: company, title: title, day: day, isInterview: isInterview)
            }
        }
        .sheet(isPresented: Binding(
            get: { detailNodeID != nil },
            set: { if !$0 { detailNodeID = nil } }
        )) {
            if let id = detailNodeID {
                StageNodeDetailView(nodeID: id)
            }
        }
        .confirmationDialog(
            deleteDialogTitle,
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let pendingDelete {
                    performDelete(pendingDelete)
                }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text("会立刻删掉这个阶段节点（含备注和附件）。")
        }
        .onChange(of: isExpanded) { _, value in
            onExpandedChange?(value)
        }
    }

    private var deleteDialogTitle: String {
        guard let event = pendingDelete else { return "删除节点" }
        return "删除「\(nodeLabel(event))」？"
    }

    /// Horizontal pan around today; scroller chrome removed so layout does not jitter.
    private var collapsedStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    dayHeader(days: collapsedDays, width: dayWidth)
                    singleTrack(days: collapsedDays, width: dayWidth, height: trackHeight)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture { expandTimeline() }
            }
            .scrollIndicators(.hidden)
            .withoutScrollers()
            .onAppear {
                proxy.scrollTo(dayKey(Calendar.current.startOfDay(for: Date())), anchor: .center)
            }
        }
        .frame(minHeight: trackHeight + 28)
    }

    /// Exact height for N full week rows (no clipping).
    private var expandedViewportHeight: CGFloat {
        let spacing: CGFloat = 10
        return CGFloat(expandedVisibleWeeks) * weekRowHeight
            + CGFloat(max(expandedVisibleWeeks - 1, 0)) * spacing
    }

    /// Top week of the default window (bottom = this week = 0).
    private var defaultWindowTopWeek: Int {
        -(expandedVisibleWeeks - 1)
    }

    private var expandedWeeksPanel: some View {
        GeometryReader { geo in
            let cellWidth = max(44, geo.size.width / 7)

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    // VStack (not Lazy): scroll targets exist on first layout.
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(scrollableWeekIndices, id: \.self) { weekIndex in
                            weekRow(
                                days: weekDays(relativeWeek: weekIndex),
                                cellWidth: cellWidth
                            )
                            .id(weekIndex)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
                .withoutScrollers()
                .frame(width: geo.size.width, height: expandedViewportHeight, alignment: .top)
                .onAppear {
                    jumpToDefaultWindow(proxy)
                }
                .onChange(of: isExpanded) { _, expanded in
                    guard expanded else { return }
                    jumpToDefaultWindow(proxy)
                }
            }
        }
        .frame(width: nil, height: expandedViewportHeight)
    }

    private func jumpToDefaultWindow(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            proxy.scrollTo(defaultWindowTopWeek, anchor: .top)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            proxy.scrollTo(defaultWindowTopWeek, anchor: .top)
        }
    }

    private func weekRow(days: [Date], cellWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            dayHeader(days: days, width: cellWidth)
            singleTrack(days: days, width: cellWidth, height: weekRowHeight - 22)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .frame(height: weekRowHeight)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.elevated.opacity(0.35))
        )
    }

    private func dayHeader(days: [Date], width: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                let key = dayKey(day)
                Text(dayLabel(day))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(
                        dropHighlightDayKey == key
                        ? AppTheme.orange
                        : (Calendar.current.isDateInToday(day) ? AppTheme.accent : AppTheme.muted)
                    )
                    .frame(width: width)
                    .id(key)
            }
        }
    }

    private func singleTrack(days: [Date], width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(AppTheme.stroke)
                .frame(height: 2)
                .frame(width: CGFloat(days.count) * width)
                .padding(.horizontal, 4)

            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    let key = dayKey(day)
                    dayCluster(day: day, dayKey: key, events: eventsByDay[key] ?? [])
                        .frame(width: width, height: height)
                }
            }
        }
        .frame(height: height)
    }

    private func dayCluster(day: Date, dayKey: String, events: [TimelineDisplayEvent]) -> some View {
        let hovering = hoveredDayKey == dayKey || draggingNodeID != nil && hoveredDayKey == dayKey
        let isToday = Calendar.current.isDateInToday(day)
        // 只有今天默认展开；其他日期显示圆点，悬停才展开。
        let showChips = !events.isEmpty && (hovering || isToday)
        return ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(dropHighlightDayKey == dayKey ? AppTheme.accent.opacity(0.12) : Color.clear)

            if events.isEmpty {
                Color.clear
            } else if showChips {
                VStack(spacing: 4) {
                    ForEach(Array(events.prefix(8))) { event in
                        interactiveChip(event, emphasize: isToday || hovering)
                    }
                    if events.count > 8 {
                        Text("+\(events.count - 8)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppTheme.muted)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
            } else {
                dotsCluster(events)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onHover { isHovering in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                if isHovering, !events.isEmpty || draggingNodeID != nil {
                    hoveredDayKey = dayKey
                } else if hoveredDayKey == dayKey, draggingNodeID == nil {
                    hoveredDayKey = nil
                }
            }
        }
        .dropDestination(for: TimelineDragItem.self) { items, _ in
            guard let item = items.first else { return false }
            return moveNode(item.nodeID, toDay: day)
        } isTargeted: { targeted in
            dropHighlightDayKey = targeted ? dayKey : (dropHighlightDayKey == dayKey ? nil : dropHighlightDayKey)
        }
        .contextMenu {
            Button("在这天新建节点…") {
                createDraft = TimelineCreateDraft(day: day)
            }
        }
        .help(events.isEmpty ? "右键新建节点" : events.map(nodeLabel).joined(separator: "\n"))
        .onTapGesture {
            if !isExpanded {
                expandTimeline()
            }
        }
    }

    /// Collapsed (non-hover) look for a day with several nodes — a small dot per node,
    /// wrapping into rows. Hovering swaps to the full fan-out (see `dayCluster`).
    private func dotsCluster(_ events: [TimelineDisplayEvent]) -> some View {
        let dotsShown = Array(events.prefix(12))
        let columns = Array(
            repeating: GridItem(.fixed(7), spacing: 5),
            count: min(4, max(dotsShown.count, 1))
        )
        return VStack(spacing: 4) {
            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(dotsShown) { event in
                    Circle()
                        .fill(chipColor(event))
                        .frame(width: 7, height: 7)
                }
            }
            if events.count > dotsShown.count {
                Text("+\(events.count - dotsShown.count)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.94)))
    }

    private func expandTimeline() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            isExpanded = true
        }
    }

    private func collapseExpanded() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            isExpanded = false
        }
    }

    // MARK: - Local writes (UI is source of truth; agent not needed)

    private func createNodeLocally(companyName: String, title: String, day: Date, isInterview: Bool) {
        let cal = Calendar.current
        let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: cal.startOfDay(for: day))
            ?? day
        let formatted = StageClassifier.formatTitle(title)
        guard !formatted.isEmpty else { return }

        do {
            let company = try AgentToolbox.findOrCreateCompany(named: companyName, in: modelContext)
            let app = try AgentToolbox.ensureApplication(for: company, in: modelContext)
            let node = StageNode(
                title: formatted,
                bucket: StageClassifier.bucket(forTitle: formatted).rawValue,
                date: noon,
                hasTime: false,
                isInterview: isInterview,
                application: app
            )
            modelContext.insert(node)
            if app.appliedDate == nil { app.appliedDate = noon }
            app.lastUpdated = Date()
            try modelContext.save()
            chat.recordLocalEdit(
                userText: "【时间线】新建节点「\(formatted)」@ \(company.name)（\(chineseDate(day))）",
                assistantText: "已创建 \(company.name) 的「\(formatted)」节点。"
            )
        } catch {
            chat.recordLocalEdit(
                userText: "【时间线】新建节点「\(formatted)」@ \(companyName)",
                assistantText: "创建失败:\(error.localizedDescription)"
            )
        }
    }

    /// Drag to another day: change the calendar day only, keep clock time.
    @discardableResult
    private func moveNode(_ nodeID: UUID, toDay day: Date) -> Bool {
        guard let node = fetchNode(id: nodeID) else { return false }
        let cal = Calendar.current
        let targetStart = cal.startOfDay(for: day)
        let time = cal.dateComponents([.hour, .minute, .second], from: node.date)
        node.date = cal.date(
            bySettingHour: time.hour ?? 12,
            minute: time.minute ?? 0,
            second: 0,
            of: targetStart
        ) ?? targetStart
        node.application?.lastUpdated = Date()
        try? modelContext.save()

        draggingNodeID = nil
        dropHighlightDayKey = nil
        hoveredDayKey = dayKey(targetStart)
        chat.recordLocalEdit(
            userText: "【时间线】把「\(node.application?.company?.name ?? "?")·\(node.title)」挪到 \(chineseDate(day))",
            assistantText: "已把节点日期改为 \(chineseDate(day))，其余信息不变。"
        )
        return true
    }

    /// Delete by node id; clean up shell companies with nothing left.
    private func performDelete(_ event: TimelineDisplayEvent) {
        guard let node = fetchNode(id: event.id) else { return }
        let label = nodeLabel(event)
        let company = node.application?.company
        for attachment in node.attachments ?? [] {
            AttachmentStore.delete(fileName: attachment.fileName)
        }
        node.application?.lastUpdated = Date()
        modelContext.delete(node)
        try? modelContext.save()

        var assistant = "已删除「\(label)」。"
        if let company, (company.applications ?? []).allSatisfy({ ($0.stageNodes ?? []).isEmpty }),
           (AgentToolbox.preferredApplication(for: company)?.position ?? "") == AgentToolbox.placeholderPosition {
            let name = company.name
            modelContext.delete(company)
            try? modelContext.save()
            assistant += " 同时清掉了空壳机会「\(name)」。"
        }

        if draggingNodeID == event.id {
            draggingNodeID = nil
        }
        chat.recordLocalEdit(
            userText: "【时间线】删除「\(label)」（\(chineseDate(event.eventDate))）",
            assistantText: assistant
        )
    }

    private func interactiveChip(_ event: TimelineDisplayEvent, emphasize: Bool) -> some View {
        Button {
            detailNodeID = event.id
        } label: {
            nodeChipLabel(event, emphasize: emphasize)
        }
        .buttonStyle(.hoverCue)
        .contextMenu {
            Button("查看 / 编辑详情…") {
                detailNodeID = event.id
            }
            if let companyID = event.companyID {
                Button("打开公司") {
                    navigation.openCompany(companyID)
                }
            }
            Button("删除节点…", role: .destructive) {
                pendingDelete = event
            }
        }
        .help("点击查看详情 · 拖动改日期")
        .draggable(TimelineDragItem(nodeID: event.id)) {
            nodeChipLabel(event, emphasize: true)
                .opacity(0.9)
                .onAppear { draggingNodeID = event.id }
                .onDisappear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if draggingNodeID == event.id {
                            draggingNodeID = nil
                        }
                    }
                }
        }
    }

    private func nodeChipLabel(_ event: TimelineDisplayEvent, emphasize: Bool) -> some View {
        Text(nodeLabel(event))
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(chipColor(event), in: Capsule())
            .shadow(
                color: emphasize ? chipColor(event).opacity(0.45) : chipColor(event).opacity(0.2),
                radius: emphasize ? 6 : 3,
                y: 1
            )
            .fixedSize()
            .opacity(draggingNodeID == event.id ? 0.35 : 1)
    }

    private func fetchNode(id: UUID) -> StageNode? {
        var descriptor = FetchDescriptor<StageNode>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func nodeLabel(_ event: TimelineDisplayEvent) -> String {
        let title = event.title
        guard let name = event.companyName, !name.isEmpty else { return title }
        let short = CompanyNameNormalizer.chartLabel(name)
        return "\(short)·\(title)"
    }

    private func chipColor(_ event: TimelineDisplayEvent) -> Color {
        switch event.bucket {
        case .notStarted:
            return AppTheme.accent
        case .inProgress:
            return AppTheme.orange
        case .closed:
            return event.title.contains("拒") ? AppTheme.rose : AppTheme.green
        }
    }

    private func dayKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M/d"
        return f.string(from: date)
    }

    private func chineseDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日"
        return f.string(from: date)
    }
}

// MARK: - Create sheet

private struct StageNodeCreateSheet: View {
    let day: Date
    let onSave: (String, String, Date, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var companyName = ""
    @State private var stageTitle = ""
    @State private var selectedDay: Date
    /// 必填：这是不是一轮面试。自由文本系统猜不准，所以由用户明确选择。
    @State private var isInterview: Bool?
    @State private var interviewTouched = false

    init(day: Date, onSave: @escaping (String, String, Date, Bool) -> Void) {
        self.day = day
        self.onSave = onSave
        _selectedDay = State(initialValue: Calendar.current.startOfDay(for: day))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新建时间线节点")
                .font(.headline)
            Text("阶段名以你写的为准，例如：准备投 / 官网投 / 猎头联系Leslie / 内推 / 预约HR Call / Phone Interview 1…")
                .font(.caption)
                .foregroundStyle(AppTheme.muted)

            DatePicker("日期", selection: $selectedDay, displayedComponents: .date)
                .datePickerStyle(.field)

            TextField("公司（可新建，别名自动规范）", text: $companyName)
                .textFieldStyle(.roundedBorder)

            TextField("阶段", text: $stageTitle)
                .textFieldStyle(.roundedBorder)
                .onChange(of: stageTitle) { _, value in
                    // 建议值，用户改过就不再覆盖。
                    guard !interviewTouched else { return }
                    let trimmed = value.trimmingCharacters(in: .whitespaces)
                    isInterview = trimmed.isEmpty ? nil : StageClassifier.isInterview(forTitle: trimmed)
                }

            HStack(spacing: 8) {
                ForEach(["内推", "官网投", "猎头联系", "Recruiter联系"], id: \.self) { label in
                    Button(label) {
                        stageTitle = label
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("这是一轮面试吗？（必选）")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Picker("", selection: Binding(
                    get: { isInterview },
                    set: { value in
                        isInterview = value
                        interviewTouched = true
                    }
                )) {
                    Text("是面试").tag(Bool?.some(true))
                    Text("不是面试").tag(Bool?.some(false))
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text("面试从 HR Call 起算；猎头Call、各种「预约X」不算面试。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("保存") {
                    onSave(companyName, stageTitle, selectedDay, isInterview ?? false)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(
                    companyName.trimmingCharacters(in: .whitespaces).isEmpty
                    || stageTitle.trimmingCharacters(in: .whitespaces).isEmpty
                    || isInterview == nil
                )
            }
        }
        .padding(24)
        .frame(minWidth: 400)
    }
}
