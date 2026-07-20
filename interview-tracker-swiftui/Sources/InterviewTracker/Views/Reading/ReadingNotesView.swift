import SwiftUI
import SwiftData
import AppKit

/// 全页阅读笔记：Markdown 编辑 + 预览、论文模板、自动保存。
struct ReadingNotesView: View {
    let itemID: UUID

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var navigation: NavigationStore
    @EnvironmentObject private var language: LanguageStore
    @Query private var items: [ReadingItem]

    private enum Mode: CaseIterable, Hashable {
        case edit, split, preview

        func label(_ language: LanguageStore) -> String {
            switch self {
            case .edit: return L10n.t("Edit", "编辑")
            case .split: return L10n.t("Split", "对照")
            case .preview: return L10n.t("Preview", "预览")
            }
        }
    }

    @State private var text = ""
    @State private var loaded = false
    @State private var mode: Mode = .split
    @State private var lastSavedAt: Date?
    @State private var editingMeta = false

    private var item: ReadingItem? {
        items.first { $0.id == itemID }
    }

    var body: some View {
        Group {
            if let item {
                VStack(alignment: .leading, spacing: 0) {
                    header(item)
                    Divider().overlay(AppTheme.stroke)
                    editorArea
                    Divider().overlay(AppTheme.stroke)
                    statusBar
                }
            } else {
                ContentUnavailableView(
                    language.t("Item not found", "收藏不存在"),
                    systemImage: "questionmark.circle"
                )
            }
        }
        // Notes are wall-to-wall text; keep this page nearly opaque for readability.
        .background(AppTheme.background.opacity(0.88))
        .onAppear { loadIfNeeded() }
        .onDisappear { persist() }
        .sheet(isPresented: $editingMeta) {
            if let item {
                ReadingItemFormSheet(existing: item)
            }
        }
    }

    // MARK: - Header

    private func header(_ item: ReadingItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Label(item.readingKind.label, systemImage: item.readingKind.icon)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(kindColor(item))
                        if !item.domain.isEmpty {
                            Text(item.domain)
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                        }
                        ForEach(item.tagList.prefix(6), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppTheme.accent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(AppTheme.accent.opacity(0.12), in: Capsule())
                        }
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        openSource(item)
                    } label: {
                        Label(
                            item.fileName != nil
                            ? language.t("Open PDF", "打开 PDF")
                            : language.t("Open source", "打开原文"),
                            systemImage: "arrow.up.forward.square"
                        )
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .help(language.t("Open in default reader / browser while you take notes", "在默认阅读器 / 浏览器中打开，边看边记"))

                    Button {
                        item.isRead.toggle()
                        try? modelContext.save()
                    } label: {
                        Label(
                            item.isRead
                            ? language.t("Read", "已读")
                            : language.t("Mark read", "标已读"),
                            systemImage: item.isRead ? "checkmark.circle.fill" : "circle"
                        )
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(item.isRead ? AppTheme.green : AppTheme.textSecondary)
                    }

                    Button(language.t("Edit info…", "编辑信息…")) { editingMeta = true }
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack(spacing: 10) {
                Picker("", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { mode in
                        Text(mode.label(language)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .labelsHidden()

                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        text = Self.template(for: item.readingKind)
                        persist()
                    } label: {
                        Label(language.t("Insert note template", "插入笔记模板"), systemImage: "square.grid.2x2")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Spacer()

                Text(language.t(
                    "Markdown: # heading · **bold** · - list · > quote · ```code```",
                    "支持 Markdown：# 标题 · **粗体** · - 列表 · > 引用 · ```代码```"
                ))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
    }

    private func kindColor(_ item: ReadingItem) -> Color {
        switch item.readingKind {
        case .paper: return AppTheme.softBlue
        case .blog: return AppTheme.purple
        case .video: return AppTheme.rose
        }
    }

    private func openSource(_ item: ReadingItem) {
        if let fileName = item.fileName {
            NSWorkspace.shared.open(AttachmentStore.url(for: fileName))
        } else if let url = item.url {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Editor / preview

    private var editorArea: some View {
        HStack(spacing: 0) {
            if mode != .preview {
                editor
                    .frame(maxWidth: .infinity)
            }
            if mode == .split {
                Divider().overlay(AppTheme.stroke)
            }
            if mode != .edit {
                ScrollView {
                    MarkdownPreview(text: text)
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(AppTheme.backgroundDeep.opacity(0.4))
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var editor: some View {
        TextEditor(text: $text)
            .font(.system(size: 13.5, design: .monospaced))
            .lineSpacing(4)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.clear)
            .onChange(of: text) { _, _ in
                persist()
            }
    }

    private var statusBar: some View {
        HStack(spacing: 14) {
            Text(language.t("\(text.count) chars", "\(text.count) 字"))
                .font(.caption2.monospacedDigit())
            if let lastSavedAt {
                Label(
                    language.t(
                        "Autosaved \(lastSavedAt.formatted(.dateTime.hour().minute().second()))",
                        "已自动保存 \(lastSavedAt.formatted(.dateTime.hour().minute().second()))"
                    ),
                    systemImage: "checkmark.circle"
                )
                .font(.caption2)
                .foregroundStyle(AppTheme.green.opacity(0.85))
            }
            Spacer()
            if let updated = item?.notesUpdatedAt {
                Text(language.t(
                    "Notes updated \(updated.formatted(.dateTime.month().day().hour().minute()))",
                    "笔记更新于 \(updated.formatted(.dateTime.month().day().hour().minute()))"
                ))
                    .font(.caption2)
            }
        }
        .foregroundStyle(AppTheme.muted)
        .padding(.horizontal, 28)
        .padding(.vertical, 8)
    }

    // MARK: - Persistence

    private func loadIfNeeded() {
        guard !loaded, let item else { return }
        loaded = true
        text = item.readingNotes ?? ""
        if text.isEmpty { mode = .edit }
    }

    private func persist() {
        guard loaded, let item else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let newValue: String? = trimmed.isEmpty ? nil : text
        guard newValue != item.readingNotes else { return }
        item.readingNotes = newValue
        item.notesUpdatedAt = Date()
        try? modelContext.save()
        lastSavedAt = Date()
    }

    // MARK: - Templates

    static func template(for kind: ReadingKind) -> String {
        switch kind {
        case .paper:
            return """
            # TL;DR
            > \(L10n.t("One line: what problem this paper solves, and the conclusion", "一句话：这篇论文解决什么问题，结论是什么"))

            ## \(L10n.t("Method", "方法"))
            - 

            ## \(L10n.t("Experiments & results", "实验 & 结果"))
            - 

            ## \(L10n.t("My thoughts", "我的想法"))
            - 

            ## \(L10n.t("References to chase", "值得追的参考"))
            - 
            """
        case .blog:
            return """
            # \(L10n.t("Core idea", "核心观点"))
            > 

            ## \(L10n.t("Evidence / examples", "论据 / 例子"))
            - 

            ## \(L10n.t("My thoughts", "我的想法"))
            - 
            """
        case .video:
            return """
            # \(L10n.t("Main content", "主要内容"))
            > 

            ## \(L10n.t("Timestamps", "时间点标记"))
            - 00:00 

            ## \(L10n.t("My thoughts", "我的想法"))
            - 
            """
        }
    }
}

// MARK: - Markdown preview renderer

/// 轻量 Markdown 渲染：标题 / 列表 / 引用 / 代码块 / 分割线 + 行内粗斜体代码链接。
struct MarkdownPreview: View {
    let text: String

    @EnvironmentObject private var language: LanguageStore

    private enum Block: Identifiable {
        case heading(level: Int, text: String)
        case bullet([String])
        case numbered([String])
        case quote([String])
        case code(String)
        case divider
        case paragraph(String)
        case blank

        var id: UUID { UUID() }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(language.t("(Preview: start writing something)", "（右侧预览：开始写点什么吧）"))
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            } else {
                ForEach(Array(parse().enumerated()), id: \.offset) { _, block in
                    render(block)
                }
            }
        }
    }

    @ViewBuilder
    private func render(_ block: Block) -> some View {
        switch block {
        case .heading(let level, let content):
            inline(content)
                .font(headingFont(level))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.top, level == 1 ? 4 : 2)
        case .bullet(let lines):
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(AppTheme.accent)
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)
                        inline(line)
                            .foregroundStyle(AppTheme.textPrimary.opacity(0.9))
                    }
                }
            }
        case .numbered(let lines):
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(AppTheme.accent)
                        inline(line)
                            .foregroundStyle(AppTheme.textPrimary.opacity(0.9))
                    }
                }
            }
        case .quote(let lines):
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppTheme.orange.opacity(0.7))
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        inline(line)
                            .foregroundStyle(AppTheme.textSecondary)
                            .italic()
                    }
                }
            }
            .padding(.vertical, 2)
        case .code(let code):
            Text(code)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(AppTheme.accent.opacity(0.95))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.backgroundDeep, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppTheme.stroke, lineWidth: 1)
                )
        case .divider:
            Divider().overlay(AppTheme.stroke)
        case .paragraph(let content):
            inline(content)
                .foregroundStyle(AppTheme.textPrimary.opacity(0.9))
        case .blank:
            Spacer().frame(height: 2)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .system(size: 22, weight: .bold, design: .rounded)
        case 2: return .system(size: 18, weight: .bold, design: .rounded)
        default: return .system(size: 15, weight: .semibold, design: .rounded)
        }
    }

    /// 行内 Markdown（粗体 / 斜体 / 代码 / 链接）交给系统解析。
    private func inline(_ raw: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: raw,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attributed)
        }
        return Text(raw)
    }

    private func parse() -> [Block] {
        var blocks: [Block] = []
        var codeBuffer: [String] = []
        var inCode = false
        var bulletBuffer: [String] = []
        var numberBuffer: [String] = []
        var quoteBuffer: [String] = []

        func flushLists() {
            if !bulletBuffer.isEmpty {
                blocks.append(.bullet(bulletBuffer))
                bulletBuffer = []
            }
            if !numberBuffer.isEmpty {
                blocks.append(.numbered(numberBuffer))
                numberBuffer = []
            }
            if !quoteBuffer.isEmpty {
                blocks.append(.quote(quoteBuffer))
                quoteBuffer = []
            }
        }

        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("```") {
                if inCode {
                    blocks.append(.code(codeBuffer.joined(separator: "\n")))
                    codeBuffer = []
                    inCode = false
                } else {
                    flushLists()
                    inCode = true
                }
                continue
            }
            if inCode {
                codeBuffer.append(rawLine)
                continue
            }

            if line.isEmpty {
                flushLists()
                blocks.append(.blank)
            } else if line.hasPrefix("### ") {
                flushLists()
                blocks.append(.heading(level: 3, text: String(line.dropFirst(4))))
            } else if line.hasPrefix("## ") {
                flushLists()
                blocks.append(.heading(level: 2, text: String(line.dropFirst(3))))
            } else if line.hasPrefix("# ") {
                flushLists()
                blocks.append(.heading(level: 1, text: String(line.dropFirst(2))))
            } else if line == "---" || line == "***" {
                flushLists()
                blocks.append(.divider)
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                bulletBuffer.append(String(line.dropFirst(2)))
            } else if let range = line.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                numberBuffer.append(String(line[range.upperBound...]))
            } else if line.hasPrefix("> ") {
                quoteBuffer.append(String(line.dropFirst(2)))
            } else if line == ">" {
                quoteBuffer.append("")
            } else {
                flushLists()
                blocks.append(.paragraph(rawLine))
            }
        }
        if inCode, !codeBuffer.isEmpty {
            blocks.append(.code(codeBuffer.joined(separator: "\n")))
        }
        flushLists()
        return blocks
    }
}
