import SwiftUI
import SwiftData
import AppKit

struct CompanyDetailView: View {
    let companyID: UUID

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var navigation: NavigationStore
    @Query private var companies: [Company]
    @Query(sort: \Application.lastUpdated, order: .reverse) private var allApplications: [Application]
    @Query private var allStageNodes: [StageNode]

    @State private var isFormatting = false
    @State private var formattingSection: DetailSection?
    @State private var formatError: String?
    @State private var formatNotice: String?
    @State private var expandedSection: DetailSection?
    @State private var previewImage: NSImage?

    private enum DetailSection: String, CaseIterable, Identifiable {
        case companyDescription
        case jobDescription
        case feedback
        case review
        case code
        case interviewDocs

        var id: String { rawValue }

        var title: String {
            switch self {
            case .companyDescription: return "公司介绍"
            case .jobDescription: return "岗位 JD"
            case .feedback: return "反馈"
            case .review: return "复盘"
            case .code: return "代码区"
            case .interviewDocs: return "面试题文档"
            }
        }

        var placeholder: String {
            switch self {
            case .companyDescription: return "粘贴或聊天归纳公司介绍…"
            case .jobDescription: return "粘贴职位描述…"
            case .feedback: return "面试官 / HR 反馈…"
            case .review: return "自己的复盘…"
            case .code: return "手撕代码 / 算法题…"
            case .interviewDocs: return "面试题、笔记文档…"
            }
        }

        var isCode: Bool { self == .code }
        var needsApplication: Bool { self != .companyDescription }
    }

    private var company: Company? {
        companies.first { $0.id == companyID }
    }

    private var application: Application? {
        companyApplications.max { $0.lastUpdated < $1.lastUpdated }
    }

    private var companyApplications: [Application] {
        allApplications.filter { $0.company?.id == companyID }
    }

    private var companyStageNodes: [StageNode] {
        allStageNodes.filter { $0.application?.company?.id == companyID }
    }

    private var visibleSections: [DetailSection] {
        if application == nil {
            return [.companyDescription]
        }
        return DetailSection.allCases
    }

    var body: some View {
        Group {
            if let company {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header(company)
                        detailGrid(company)
                        if expandedSection == nil {
                            TimelineStripView(
                                events: TimelineDisplayEvent.fromNodes(companyStageNodes),
                                title: "\(company.name) · 时间线"
                            )
                        }
                    }
                    .padding(28)
                    // Tap empty space to collapse expanded box.
                    .background(
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                    expandedSection = nil
                                }
                            }
                    )
                }
            } else {
                ContentUnavailableView("找不到这家公司", systemImage: "building.2")
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .background(Color.clear)
        .alert("整理失败", isPresented: Binding(
            get: { formatError != nil },
            set: { if !$0 { formatError = nil } }
        )) {
            Button("好", role: .cancel) { formatError = nil }
        } message: {
            Text(formatError ?? "")
        }
        .sheet(isPresented: Binding(
            get: { previewImage != nil },
            set: { if !$0 { previewImage = nil } }
        )) {
            if let previewImage {
                VStack(spacing: 12) {
                    Image(nsImage: previewImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 820, maxHeight: 600)
                    Button("关闭") { self.previewImage = nil }
                }
                .padding(20)
            }
        }
    }

    private func header(_ company: Company) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                Text(company.name)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                if let app = application {
                    Text("\(app.position) | \(app.currentStageTitle)")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                if let notice = formatNotice {
                    Text(notice)
                        .font(.caption)
                        .foregroundStyle(AppTheme.accent)
                }
            }
            Spacer()
            Button {
                if let section = expandedSection {
                    Task { await formatSection(section) }
                } else {
                    Task { await formatAllWithAI() }
                }
            } label: {
                HStack(spacing: 6) {
                    if isFormatting && (formattingSection == nil || formattingSection == expandedSection) {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(headerAIButtonTitle)
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(AppTheme.accent.opacity(0.2), in: Capsule())
                .foregroundStyle(AppTheme.accent)
            }
            .buttonStyle(.hoverCue)
            .disabled(isFormatting)
            .help(expandedSection == nil ? "整理所有栏目" : "只整理当前扩大的栏目")
        }
    }

    private var headerAIButtonTitle: String {
        if isFormatting {
            if expandedSection != nil { return "整理中…" }
            if formattingSection == nil { return "整理中…" }
        }
        if let section = expandedSection {
            return "AI 整理\(section.title)"
        }
        return "AI 整理格式"
    }

    private func detailGrid(_ company: Company) -> some View {
        let sections = visibleSections
        return VStack(alignment: .leading, spacing: 14) {
            if let expanded = expandedSection, sections.contains(expanded) {
                editableBox(section: expanded, company: company, expanded: true)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14)
                    ],
                    spacing: 14
                ) {
                    ForEach(sections) { section in
                        editableBox(section: section, company: company, expanded: false)
                    }
                }
            }

            if application == nil {
                Text("这家公司还没有岗位记录。用聊天补一条即可。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
        }
    }

    private func editableBox(section: DetailSection, company: Company, expanded: Bool) -> some View {
        let binding = textBinding(for: section, company: company)
        let busy = isFormatting && formattingSection == section
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(section.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer(minLength: 0)

                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        if expandedSection == section {
                            expandedSection = nil
                        } else {
                            expandedSection = section
                        }
                    }
                } label: {
                    Image(systemName: expanded
                          ? "arrow.down.right.and.arrow.up.left"
                          : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.hoverCue)
                .help(expanded ? "还原" : "扩大")

                Button {
                    Task { await formatSection(section) }
                } label: {
                    Group {
                        if busy {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.hoverCue)
                .disabled(isFormatting || binding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("只整理这一栏")
            }

            TextEditor(text: binding)
                .font(section.isCode ? .system(.body, design: .monospaced) : .body)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: expanded ? 280 : (section.isCode || section == .interviewDocs ? 140 : 110))
                .background(AppTheme.elevated.opacity(0.75), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            expanded ? AppTheme.accent.opacity(0.45) : AppTheme.stroke,
                            lineWidth: expanded ? 1.5 : 1
                        )
                )
                .overlay(alignment: .topLeading) {
                    if binding.wrappedValue.isEmpty {
                        Text(section.placeholder)
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                            .padding(18)
                            .allowsHitTesting(false)
                    }
                }

            // 正文里的链接自动识别成可点击的一行（代码区除外）。
            if !section.isCode {
                let urls = detectedLinks(in: binding.wrappedValue)
                if !urls.isEmpty {
                    FlowLinks(urls: urls)
                }
            }

            // 代码区只放代码，其它栏目支持图片附件。
            if !section.isCode, expanded || !sectionAttachments(section, company: company).isEmpty {
                AttachmentGridView(
                    attachments: sectionAttachments(section, company: company),
                    onAdd: { addSectionAttachments(section, company: company) },
                    onPaste: { pasteSectionImage(section, company: company) },
                    onOpen: { attachment in
                        previewImage = AttachmentStore.image(for: attachment.fileName)
                    },
                    onDelete: { attachment in
                        AttachmentStore.delete(fileName: attachment.fileName)
                        modelContext.delete(attachment)
                        try? modelContext.save()
                    },
                    onDropURLs: { urls in
                        importSectionFiles(urls, section: section, company: company)
                    }
                )
            }
        }
        .padding(expanded ? 4 : 0)
    }

    /// 从正文里抽出 URL（去重、保持出现顺序），显示成可点击链接。
    private func detectedLinks(in text: String) -> [URL] {
        guard !text.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return [] }
        let matches = detector.matches(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        )
        var seen = Set<String>()
        var urls: [URL] = []
        for match in matches {
            guard let url = match.url,
                  url.scheme == "http" || url.scheme == "https" || url.scheme == nil
            else { continue }
            let normalized = url.scheme == nil
                ? URL(string: "https://" + url.absoluteString)
                : url
            guard let normalized, seen.insert(normalized.absoluteString).inserted else { continue }
            urls.append(normalized)
        }
        return urls
    }

    private func sectionAttachments(_ section: DetailSection, company: Company) -> [MediaAttachment] {
        (company.attachments ?? [])
            .filter { $0.sectionKey == section.rawValue }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func addSectionAttachments(_ section: DetailSection, company: Company) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image, .pdf]
        guard panel.runModal() == .OK else { return }
        importSectionFiles(panel.urls, section: section, company: company)
    }

    private func importSectionFiles(_ urls: [URL], section: DetailSection, company: Company) {
        for url in urls {
            guard let name = AttachmentStore.copyIn(from: url) else { continue }
            let attachment = MediaAttachment(
                fileName: name,
                sectionKey: section.rawValue,
                company: company
            )
            modelContext.insert(attachment)
        }
        try? modelContext.save()
    }

    private func pasteSectionImage(_ section: DetailSection, company: Company) {
        let pasteboard = NSPasteboard.general
        guard
            let data = pasteboard.data(forType: .png)
                ?? pasteboard.data(forType: .tiff).flatMap({ tiff in
                    NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
                }),
            let name = AttachmentStore.saveImageData(data)
        else { return }
        let attachment = MediaAttachment(
            fileName: name,
            sectionKey: section.rawValue,
            company: company
        )
        modelContext.insert(attachment)
        try? modelContext.save()
    }

    private func textBinding(for section: DetailSection, company: Company) -> Binding<String> {
        switch section {
        case .companyDescription:
            return Binding(
                get: { company.companyDescription ?? "" },
                set: { company.companyDescription = $0.isEmpty ? nil : $0 }
            )
        case .jobDescription:
            return Binding(
                get: { application?.jobDescriptionText ?? "" },
                set: { application?.jobDescriptionText = $0.isEmpty ? nil : $0 }
            )
        case .feedback:
            return Binding(
                get: { application?.feedback ?? "" },
                set: { application?.feedback = $0.isEmpty ? nil : $0 }
            )
        case .review:
            return Binding(
                get: { application?.reviewNotes ?? "" },
                set: { application?.reviewNotes = $0.isEmpty ? nil : $0 }
            )
        case .code:
            return Binding(
                get: { application?.codeSnippets ?? "" },
                set: { application?.codeSnippets = $0.isEmpty ? nil : $0 }
            )
        case .interviewDocs:
            return Binding(
                get: { application?.interviewDocs ?? "" },
                set: { application?.interviewDocs = $0.isEmpty ? nil : $0 }
            )
        }
    }

    @MainActor
    private func formatSection(_ section: DetailSection) async {
        guard let company else { return }
        let text = textBinding(for: section, company: company).wrappedValue
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let apiKey = APIKeyStore.load(), !apiKey.isEmpty else {
            formatError = "请先在设置里填写 DeepSeek API Key"
            return
        }
        isFormatting = true
        formattingSection = section
        formatNotice = nil
        defer {
            isFormatting = false
            formattingSection = nil
        }
        do {
            let kind: ContentFormatService.FormatKind = section.isCode ? .code : .markdown
            let prompt = ContentFormatService.formatPrompt(kind: kind, text: text)
            let startedAt = Date()
            let result = try await DeepSeekClient.shared.complete(
                system: prompt.system, user: prompt.user, apiKey: apiKey
            )
            textBinding(for: section, company: company).wrappedValue = result
            application?.lastUpdated = Date()
            try modelContext.save()
            formatNotice = "已整理「\(section.title)」"
            AgentTraceStore.append(
                AgentTraceRecord(
                    startedAt: startedAt,
                    endedAt: Date(),
                    kind: "format",
                    userMessage: "整理栏目 \(section.title) @ \(company.name)",
                    rawModelContent: result,
                    assistantMessage: formatNotice
                )
            )
        } catch {
            formatError = error.localizedDescription
            AgentTraceStore.append(
                AgentTraceRecord(
                    kind: "format",
                    userMessage: "整理栏目 \(section.title) @ \(company.name)",
                    error: error.localizedDescription
                )
            )
        }
    }

    @MainActor
    private func formatAllWithAI() async {
        guard let company else { return }
        guard let apiKey = APIKeyStore.load(), !apiKey.isEmpty else {
            formatError = "请先在设置里填写 DeepSeek API Key"
            return
        }
        isFormatting = true
        formattingSection = nil
        formatNotice = nil
        defer { isFormatting = false }

        do {
            for section in visibleSections {
                let text = textBinding(for: section, company: company).wrappedValue
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                let kind: ContentFormatService.FormatKind = section.isCode ? .code : .markdown
                let prompt = ContentFormatService.formatPrompt(kind: kind, text: text)
                let startedAt = Date()
                let result = try await DeepSeekClient.shared.complete(
                    system: prompt.system, user: prompt.user, apiKey: apiKey
                )
                textBinding(for: section, company: company).wrappedValue = result
                AgentTraceStore.append(
                    AgentTraceRecord(
                        startedAt: startedAt,
                        endedAt: Date(),
                        kind: "format",
                        userMessage: "整理栏目 \(section.title) @ \(company.name)",
                        rawModelContent: result,
                        assistantMessage: "已整理「\(section.title)」"
                    )
                )
            }
            application?.lastUpdated = Date()
            try modelContext.save()
            formatNotice = "已整理完成"
        } catch {
            formatError = error.localizedDescription
            AgentTraceStore.append(
                AgentTraceRecord(
                    kind: "format",
                    userMessage: "整理全部栏目 @ \(company.name)",
                    error: error.localizedDescription
                )
            )
        }
    }
}
