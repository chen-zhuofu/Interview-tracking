import SwiftUI
import SwiftData
import Charts
import AppKit

private struct InterviewScrollMetrics: Equatable {
    var offsetY: CGFloat = 0
    var contentHeight: CGFloat = 0
    var viewportHeight: CGFloat = 0

    var atTop: Bool {
        contentHeight <= viewportHeight + 4 || offsetY <= 4
    }

    var atBottom: Bool {
        guard contentHeight > viewportHeight + 4 else { return true }
        return offsetY + viewportHeight >= contentHeight - 4
    }

    /// Pull-to-refresh style: how far past the top, in points.
    var overscrollTop: CGFloat { max(0, -offsetY) }

    /// How far past the bottom, in points.
    var overscrollBottom: CGFloat {
        let maxScroll = max(0, contentHeight - viewportHeight)
        return max(0, offsetY - maxScroll)
    }
}

private struct InterviewScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct InterviewScrollContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Edge switch using pull-to-refresh style distance (~70pt), not raw flick inertia.
@MainActor
final class InterviewPanelSwipeSwitcher: ObservableObject {
    var hovering = false
    var showingPast = false
    var atTop = true
    var atBottom = true
    var onShowPast: ((Bool) -> Void)?

    private var monitor: Any?
    /// Active finger travel past the edge, in points (precise trackpad deltas ≈ points).
    private var pulledPoints: CGFloat = 0
    private var resetItem: DispatchWorkItem?
    private var didTrigger = false

    /// Same ballpark as iOS pull-to-refresh (tunable).
    private let triggerPoints: CGFloat = 140

    func start() {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        resetItem?.cancel()
        resetItem = nil
        pulledPoints = 0
        didTrigger = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    /// Also accept elastic geometry overscroll (when the scroll view reports it).
    func considerGeometry(overscrollTop: CGFloat, overscrollBottom: CGFloat) {
        guard hovering else { return }
        if !showingPast, overscrollTop >= triggerPoints {
            fire(goPast: true)
        } else if showingPast, overscrollBottom >= triggerPoints {
            fire(goPast: false)
        } else if overscrollTop < 8, overscrollBottom < 8 {
            didTrigger = false
            pulledPoints = 0
        }
    }

    private func handle(_ event: NSEvent) {
        guard hovering else {
            pulledPoints = 0
            didTrigger = false
            return
        }

        // Ignore inertia — only count while fingers are moving (pull-to-refresh style).
        if !event.momentumPhase.isEmpty {
            if event.momentumPhase.contains(.began) {
                pulledPoints = 0
            }
            return
        }

        let raw = event.scrollingDeltaY
        // Precise trackpad deltas are in points.
        let delta = event.hasPreciseScrollingDeltas ? raw : raw * 10
        guard abs(delta) > 0.2 else { return }

        let towardPast = delta > 0
        let towardUpcoming = delta < 0

        let armed: Bool
        if !showingPast {
            armed = atTop && towardPast
        } else {
            armed = atBottom && towardUpcoming
        }

        guard armed else {
            pulledPoints = 0
            didTrigger = false
            return
        }

        pulledPoints += abs(delta)

        resetItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.pulledPoints = 0
            self?.didTrigger = false
        }
        resetItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)

        guard pulledPoints >= triggerPoints else { return }
        fire(goPast: towardPast)
    }

    private func fire(goPast: Bool) {
        guard !didTrigger else { return }
        guard goPast != showingPast else { return }
        didTrigger = true
        pulledPoints = 0
        onShowPast?(goPast)
    }
}

struct DashboardView: View {
    @EnvironmentObject private var navigation: NavigationStore
    @EnvironmentObject private var chat: ChatViewModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Application.lastUpdated, order: .reverse) private var applications: [Application]
    @Query private var stageNodes: [StageNode]

    @State private var showPastInterviews = false
    @State private var hoveringInterviewPanel = false
    @State private var hoveringTimeline = false
    @State private var timelineExpanded = false
    @State private var interviewScrollMetrics = InterviewScrollMetrics()
    @State private var pendingDeleteCompany: Company?
    @StateObject private var interviewSwipeSwitcher = InterviewPanelSwipeSwitcher()

    /// One application per company (company = smallest unit on the dashboard).
    private var companyApplications: [Application] {
        var best: [String: Application] = [:]
        for app in applications {
            let key = (app.company?.name ?? app.id.uuidString).lowercased()
            if let existing = best[key] {
                if Self.outranks(app, existing) {
                    best[key] = app
                }
            } else {
                best[key] = app
            }
        }
        return Array(best.values).sorted { $0.lastUpdated > $1.lastUpdated }
    }

    private static func outranks(_ lhs: Application, _ rhs: Application) -> Bool {
        func score(_ app: Application) -> (Int, Int, Date) {
            let bucket: Int
            switch app.opportunityBucket {
            case .inProgress: bucket = 2
            case .notStarted: bucket = 1
            case .closed: bucket = 0
            }
            return (bucket, app.stageNodes?.count ?? 0, app.lastUpdated)
        }
        return score(lhs) > score(rhs)
    }

    private var notStarted: [Application] {
        companyApplications.filter { $0.opportunityBucket == .notStarted }
    }

    private var inProgress: [Application] {
        companyApplications.filter { $0.opportunityBucket == .inProgress }
    }

    private var closed: [Application] {
        companyApplications.filter { $0.opportunityBucket == .closed }
    }

    /// 机会分布环：每家公司占一等份，按状态排序着色（未开始 → 进行中 → 已结束）。
    private struct CompanySlice: Identifiable {
        let id: UUID
        let name: String
        let bucket: OpportunityBucket
    }

    private var companySlices: [CompanySlice] {
        func order(_ bucket: OpportunityBucket) -> Int {
            switch bucket {
            case .notStarted: return 0
            case .inProgress: return 1
            case .closed: return 2
            }
        }
        return companyApplications
            .compactMap { app -> CompanySlice? in
                guard let company = app.company else { return nil }
                return CompanySlice(
                    id: company.id,
                    name: CompanyNameNormalizer.chartLabel(company.name),
                    bucket: app.opportunityBucket
                )
            }
            .sorted {
                if $0.bucket != $1.bucket { return order($0.bucket) < order($1.bucket) }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    /// Stack layers bottom → top in the bar (Charts stacks first series at the bottom).
    private enum DesireBarLayer: String, CaseIterable, Identifiable {
        case rejected
        case offer
        case inProgress
        case notStarted

        var id: String { rawValue }

        var label: String {
            switch self {
            case .rejected: return "拒绝"
            case .offer: return "Offer"
            case .inProgress: return "进行中"
            case .notStarted: return "未开始"
            }
        }

        static func from(app: Application) -> DesireBarLayer {
            switch app.opportunityBucket {
            case .closed:
                return app.currentStageTitle.contains("拒") ? .rejected : .offer
            case .inProgress:
                return .inProgress
            case .notStarted:
                return .notStarted
            }
        }
    }

    /// One company = one labeled block in the desire column.
    private struct DesireCompanySegment: Identifiable {
        let id: String
        let companyId: UUID
        let desire: Int
        let label: String
        let layer: DesireBarLayer
        let yStart: Double
        let yEnd: Double
    }

    private var desireSegments: [DesireCompanySegment] {
        var best: [String: (desire: Int, layer: DesireBarLayer, updated: Date, companyId: UUID)] = [:]
        for app in applications {
            guard let desire = app.desireLevel, (1...5).contains(desire),
                  let company = app.company else { continue }
            let name = company.name
            guard !name.isEmpty else { continue }
            let layer = DesireBarLayer.from(app: app)
            if let existing = best[name] {
                if desire > existing.desire
                    || (desire == existing.desire && app.lastUpdated > existing.updated) {
                    best[name] = (desire, layer, app.lastUpdated, company.id)
                }
            } else {
                best[name] = (desire, layer, app.lastUpdated, company.id)
            }
        }

        let layerOrder = DesireBarLayer.allCases
        var rows: [DesireCompanySegment] = []
        for desire in 1...5 {
            let companies = best
                .filter { $0.value.desire == desire }
                .map {
                    (
                        name: $0.key,
                        layer: $0.value.layer,
                        updated: $0.value.updated,
                        companyId: $0.value.companyId
                    )
                }
                .sorted { lhs, rhs in
                    let li = layerOrder.firstIndex(of: lhs.layer) ?? 0
                    let ri = layerOrder.firstIndex(of: rhs.layer) ?? 0
                    if li != ri { return li < ri }
                    return lhs.name < rhs.name
                }

            var y = 0.0
            let gap = 0.14
            for company in companies {
                rows.append(DesireCompanySegment(
                    id: "\(desire)-\(company.name)",
                    companyId: company.companyId,
                    desire: desire,
                    label: CompanyNameNormalizer.chartLabel(company.name),
                    layer: company.layer,
                    yStart: y + gap,
                    yEnd: y + 1
                ))
                y += 1
            }
        }
        return rows
    }

    private var hasDesireData: Bool {
        !desireSegments.isEmpty
    }

    private var desireYMax: Double {
        max(1, desireSegments.map(\.yEnd).max() ?? 1)
    }

    /// 是不是面试只看 isInterview 标记；有没有记录钟点不影响。
    private var interviewNodes: [StageNode] {
        stageNodes.filter(\.isInterview)
    }

    private var upcomingInterviews: [StageNode] {
        interviewNodes
            .filter { $0.date >= Calendar.current.startOfDay(for: Date()) }
            .sorted { $0.date < $1.date }
    }

    private var pastInterviews: [StageNode] {
        interviewNodes
            .filter { $0.date < Calendar.current.startOfDay(for: Date()) }
            .sorted { $0.date > $1.date }
    }

    private var visibleInterviews: [StageNode] {
        showPastInterviews ? pastInterviews : upcomingInterviews
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                timelineAndUpcomingRow
                chartsRow
                opportunityColumnsSection
            }
            .padding(28)
        }
        .scrollIndicators(.hidden)
        // While pointer is over timeline or interview panel, don't scroll the page.
        .scrollDisabled(hoveringInterviewPanel || hoveringTimeline)
        .background(AppTheme.background)
        .confirmationDialog(
            pendingDeleteCompany.map { "删除「\($0.name)」？" } ?? "删除公司",
            isPresented: Binding(
                get: { pendingDeleteCompany != nil },
                set: { if !$0 { pendingDeleteCompany = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除整家公司", role: .destructive) {
                if let company = pendingDeleteCompany {
                    deleteOpportunityCompany(company)
                }
                pendingDeleteCompany = nil
            }
            Button("取消", role: .cancel) {
                pendingDeleteCompany = nil
            }
        } message: {
            Text("会删掉该公司的投递、面试和时间线。助手也会记一笔。")
        }
    }

    private func deleteOpportunityCompany(_ company: Company) {
        let name = company.name
        for app in company.applications ?? [] {
            for node in app.stageNodes ?? [] {
                for attachment in node.attachments ?? [] {
                    AttachmentStore.delete(fileName: attachment.fileName)
                }
            }
        }
        for attachment in company.attachments ?? [] {
            AttachmentStore.delete(fileName: attachment.fileName)
        }
        modelContext.delete(company)
        try? modelContext.save()
        chat.recordLocalEdit(
            userText: "【机会列表】删除公司「\(name)」",
            assistantText: "已删除 \(name) 的全部记录。"
        )
    }

    private var timelineAndUpcomingRow: some View {
        let gap: CGFloat = 14
        let collapsedHeight: CGFloat = 240
        let expandedHeight = TimelineStripView.expandedCardHeight

        return GeometryReader { geo in
            let upcomingWidth = max(200, geo.size.width * 0.25)
            let timelineWidth = max(280, geo.size.width - upcomingWidth - gap)
            HStack(alignment: .top, spacing: gap) {
                TimelineStripView(
                    events: TimelineDisplayEvent.fromNodes(stageNodes),
                    title: "时间线",
                    onExpandedChange: { expanded in
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                            timelineExpanded = expanded
                        }
                    }
                )
                .frame(
                    width: timelineWidth,
                    height: timelineExpanded ? expandedHeight : collapsedHeight,
                    alignment: .top
                )
                .onHover { hoveringTimeline = $0 }

                upcomingPanel
                    .frame(width: upcomingWidth, height: collapsedHeight, alignment: .top)
            }
        }
        .frame(height: timelineExpanded ? expandedHeight : collapsedHeight)
    }

    private var upcomingPanel: some View {
        let accent = showPastInterviews ? AppTheme.orange : AppTheme.accent

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                ZStack(alignment: .leading) {
                    HStack(spacing: 6) {
                        Text(showPastInterviews ? "过去的面试" : "接下来的面试")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.textSecondary)
                        if !visibleInterviews.isEmpty {
                            Text("\(visibleInterviews.count)")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(accent.opacity(0.85))
                        }
                    }
                    .id(showPastInterviews ? "past-title" : "upcoming-title")
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: showPastInterviews ? .bottom : .top).combined(with: .opacity),
                            removal: .move(edge: showPastInterviews ? .top : .bottom).combined(with: .opacity)
                        )
                    )
                }
                .clipped()

                Spacer(minLength: 4)

                Button {
                    navigation.openCalendar()
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 28, height: 28)
                        .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("打开日历")
            }

            ZStack {
                if visibleInterviews.isEmpty {
                    Text(showPastInterviews ? "还没有过去的面试。" : "还没有即将到来的面试。")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .id(showPastInterviews ? "past-empty" : "upcoming-empty")
                        .transition(.opacity.combined(with: .offset(y: showPastInterviews ? 12 : -12)))
                } else {
                    GeometryReader { viewport in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 8) {
                                ForEach(visibleInterviews) { node in
                                    upcomingCard(node, isPast: showPastInterviews)
                                }
                            }
                            .padding(.bottom, 2)
                            .background(
                                GeometryReader { content in
                                    Color.clear.preference(
                                        key: InterviewScrollOffsetKey.self,
                                        value: -content.frame(in: .named("interviewPanelScroll")).minY
                                    )
                                    .preference(
                                        key: InterviewScrollContentHeightKey.self,
                                        value: content.size.height
                                    )
                                }
                            )
                        }
                        .coordinateSpace(name: "interviewPanelScroll")
                        .onAppear {
                            interviewScrollMetrics.viewportHeight = viewport.size.height
                            syncSwipeEdges()
                        }
                        .onChange(of: viewport.size.height) { _, height in
                            interviewScrollMetrics.viewportHeight = height
                            syncSwipeEdges()
                        }
                    }
                    .onPreferenceChange(InterviewScrollOffsetKey.self) { offset in
                        interviewScrollMetrics.offsetY = offset
                        syncSwipeEdges()
                    }
                    .onPreferenceChange(InterviewScrollContentHeightKey.self) { height in
                        interviewScrollMetrics.contentHeight = height
                        syncSwipeEdges()
                    }
                    .id(showPastInterviews ? "past-list" : "upcoming-list")
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: showPastInterviews ? .bottom : .top).combined(with: .opacity),
                            removal: .move(edge: showPastInterviews ? .top : .bottom).combined(with: .opacity)
                        )
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.card)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    accent.opacity(showPastInterviews ? 0.08 : 0.05),
                                    Color.clear
                                ],
                                startPoint: .topTrailing,
                                endPoint: .bottomLeading
                            )
                        )
                }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [accent.opacity(0.35), AppTheme.stroke],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveringInterviewPanel = hovering
            interviewSwipeSwitcher.hovering = hovering
        }
        .onAppear {
            interviewSwipeSwitcher.showingPast = showPastInterviews
            syncSwipeEdges()
            interviewSwipeSwitcher.onShowPast = { goPast in
                withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                    showPastInterviews = goPast
                }
            }
            interviewSwipeSwitcher.start()
        }
        .onDisappear {
            interviewSwipeSwitcher.stop()
        }
        .onChange(of: showPastInterviews) { _, newValue in
            interviewSwipeSwitcher.showingPast = newValue
            // New list starts at top; refresh edge flags after layout.
            interviewScrollMetrics.offsetY = 0
            syncSwipeEdges()
        }
        .onChange(of: visibleInterviews.count) { _, _ in
            syncSwipeEdges()
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.84), value: showPastInterviews)
    }

    private func syncSwipeEdges() {
        interviewSwipeSwitcher.atTop = interviewScrollMetrics.atTop
        interviewSwipeSwitcher.atBottom = interviewScrollMetrics.atBottom
        interviewSwipeSwitcher.considerGeometry(
            overscrollTop: interviewScrollMetrics.overscrollTop,
            overscrollBottom: interviewScrollMetrics.overscrollBottom
        )
    }

    private func upcomingCard(_ node: StageNode, isPast: Bool) -> some View {
        Button {
            if let id = node.application?.company?.id {
                navigation.openCompany(id)
            }
        } label: {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(node.application?.company?.name ?? "-")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)

                        Text(node.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                isPast ? AppTheme.orange.opacity(0.75) : AppTheme.orange,
                                in: Capsule()
                            )
                        // 进入下一轮 = 上一轮通过（由时间线推导）。
                        if isPast, let outcome = node.application?.interviewOutcome(for: node) {
                            Text(outcome.label)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(outcomeBadgeColor(outcome), in: Capsule())
                        }
                    }

                    Text(node.application?.position ?? "-")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(node.date.formatted(.dateTime.month(.twoDigits).day(.twoDigits)))
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(isPast ? AppTheme.textSecondary : AppTheme.textPrimary)
                    Text(interviewTimeLabel(node))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(AppTheme.muted)
                }
            }
            .padding(12)
            .background(
                AppTheme.elevated.opacity(isPast ? 0.72 : 1),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.stroke, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func outcomeBadgeColor(_ outcome: InterviewOutcome) -> Color {
        switch outcome {
        case .passed: return AppTheme.green
        case .failed: return AppTheme.rose
        case .pending: return AppTheme.orange.opacity(0.7)
        }
    }

    private func interviewTimeLabel(_ node: StageNode) -> String {
        // 没记录钟点的节点存的是中午 12 点，不能当成真实时间显示。
        guard node.hasTime else { return "时间待定" }
        return node.date.formatted(.dateTime.hour().minute())
    }

    /// 命中测试：SectorMark 从 12 点方向顺时针排；等分环里点到第几格就是第几家公司。
    private func slice(at point: CGPoint, in frame: CGRect, slices: [CompanySlice]) -> CompanySlice? {
        guard !slices.isEmpty else { return nil }
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let radius = sqrt(dx * dx + dy * dy)
        let outer = min(frame.width, frame.height) / 2
        let inner = outer * 0.58
        guard radius >= inner, radius <= outer else { return nil }
        // 0 在正上方，顺时针增加。
        var angle = atan2(dx, -dy)
        if angle < 0 { angle += 2 * .pi }
        let index = Int(angle / (2 * .pi / Double(slices.count)))
        return slices.indices.contains(index) ? slices[index] : nil
    }

    private var chartsRow: some View {
        let contentHeight: CGFloat = hasDesireData
            ? max(260, CGFloat(desireYMax) * 36 + 96)
            : 220
        // Title + vertical padding inside DashboardCard
        let panelHeight = contentHeight + 62

        return HStack(alignment: .top, spacing: 16) {
            DashboardCard(title: "机会分布") {
                if applications.isEmpty {
                    emptyHint
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    let slices = companySlices
                    Chart(slices) { item in
                        // 每家公司一等份，沿环排开。
                        SectorMark(
                            angle: .value("公司", 1),
                            innerRadius: .ratio(0.58),
                            angularInset: 1.5
                        )
                        .foregroundStyle(by: .value("状态", item.bucket.label))
                        .cornerRadius(4)
                        .annotation(position: .overlay) {
                            Text(item.name)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .chartForegroundStyleScale([
                        OpportunityBucket.notStarted.label: AppTheme.accent,
                        OpportunityBucket.inProgress.label: AppTheme.orange,
                        OpportunityBucket.closed.label: Color.white.opacity(0.28)
                    ])
                    .chartLegend(position: .bottom, spacing: 8)
                    .chartBackground { proxy in
                        GeometryReader { geo in
                            if let anchor = proxy.plotFrame {
                                let frame = geo[anchor]
                                VStack(spacing: 0) {
                                    Text("\(slices.count)")
                                        .font(.system(size: 30, weight: .bold, design: .rounded))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text("家公司")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.muted)
                                }
                                .position(x: frame.midX, y: frame.midY)
                            }
                        }
                    }
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture { location in
                                    guard let anchor = proxy.plotFrame else { return }
                                    let frame = geo[anchor]
                                    if let slice = slice(at: location, in: frame, slices: slices) {
                                        navigation.openCompany(slice.id)
                                    }
                                }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            DashboardCard(title: "想去程度") {
                if !hasDesireData {
                    Text("还没有想去程度。聊天里说「最想去 Moonshot，想去 5 分」就会写在对应宽柱里。")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    desireColumnsView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(height: panelHeight)
    }

    /// 想去程度：5 列淡色轨道，公司小卡片沉底堆叠。
    private var desireColumnsView: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(1...5, id: \.self) { desire in
                    let items = desireSegments.filter { $0.desire == desire }
                    VStack(spacing: 6) {
                        ForEach(Array(items.reversed())) { item in
                            desireChip(item)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(6)
                    .background(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 10,
                            bottomLeadingRadius: 2,
                            bottomTrailingRadius: 2,
                            topTrailingRadius: 10,
                            style: .continuous
                        )
                        .fill(Color.white.opacity(desire == 5 ? 0.05 : 0.025))
                    )
                }
            }

            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(height: 1)
                .padding(.top, 0)

            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { desire in
                    Text("\(desire)分")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(desire == 5 ? AppTheme.accent : AppTheme.muted)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 8)

            HStack(spacing: 14) {
                ForEach(DesireBarLayer.allCases.reversed()) { layer in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(desireLayerColor(layer))
                            .frame(width: 7, height: 7)
                        Text(layer.label)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.muted)
                    }
                }
                Spacer()
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func desireChip(_ item: DesireCompanySegment) -> some View {
        let color = desireLayerColor(item.layer)
        return Button {
            navigation.openCompany(item.companyId)
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                Text(item.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(color.opacity(0.32), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(item.label)
    }

    private var opportunityColumnsSection: some View {
        DashboardCard(title: "机会列表") {
            HStack(alignment: .top, spacing: 14) {
                opportunityColumn(
                    title: "未开始",
                    items: notStarted,
                    accent: AppTheme.accent,
                    embedded: true
                )
                opportunityColumn(
                    title: "进行中",
                    items: inProgress,
                    accent: AppTheme.orange,
                    embedded: true
                )
                opportunityColumn(
                    title: "已结束",
                    items: closed,
                    accent: Color.white.opacity(0.35),
                    embedded: true
                )
            }
        }
    }

    private func opportunityColumn(
        title: String,
        items: [Application],
        accent: Color,
        embedded: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(title)
                    .font(embedded ? .subheadline.weight(.semibold) : .headline)
                Text("\(items.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppTheme.muted)
            }

            if items.isEmpty {
                Text("暂无")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(items.prefix(8))) { app in
                        Button {
                            if let id = app.company?.id {
                                navigation.openCompany(id)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.company?.name ?? "未知公司")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .lineLimit(2)
                                Text(opportunitySubtitle(app))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.muted)
                                HStack(spacing: 6) {
                                    Text(opportunityDateText(app))
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.muted)
                                    if let desire = app.desireLevel {
                                        Text(String(repeating: "★", count: desire))
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.purple)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if let company = app.company {
                                Button("删除这家公司…", role: .destructive) {
                                    pendingDeleteCompany = company
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(embedded ? 14 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            embedded ? AppTheme.elevated.opacity(0.7) : Color.clear,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            embedded
            ? RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.stroke, lineWidth: 1)
            : nil
        )
    }

    private func opportunitySubtitle(_ app: Application) -> String {
        var parts = [app.position]
        parts.append(app.currentStageTitle)
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func opportunityDateText(_ app: Application) -> String {
        let date = app.displayActivityDate
        if app.displayActivityIsInterview {
            let hour = Calendar.current.component(.hour, from: date)
            let minute = Calendar.current.component(.minute, from: date)
            if hour == 0 && minute == 0 {
                return date.formatted(.dateTime.month(.twoDigits).day(.twoDigits))
            }
            return date.formatted(.dateTime.month(.twoDigits).day(.twoDigits).hour().minute())
        }
        return date.formatted(.dateTime.month(.twoDigits).day(.twoDigits))
    }

    private var emptyHint: some View {
        Text("暂无数据。底部聊天框说一句，就会自动出现在这里。")
            .font(.caption)
            .foregroundStyle(AppTheme.muted)
    }

    private func desireLayerColor(_ layer: DesireBarLayer) -> Color {
        switch layer {
        case .rejected: return Color.red.opacity(0.85)
        case .offer: return AppTheme.green
        case .inProgress: return AppTheme.orange
        case .notStarted: return AppTheme.accent
        }
    }

}

struct DashboardCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
    }
}
