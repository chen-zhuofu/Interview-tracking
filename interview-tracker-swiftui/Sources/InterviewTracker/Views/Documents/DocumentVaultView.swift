import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

/// 求职资料库：简历 / slides / cover letter，拖入即存，一键复制去投递。
struct DocumentVaultView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var language: LanguageStore
    @Query(sort: \CareerDocument.updatedAt, order: .reverse) private var documents: [CareerDocument]

    private enum KindFilter: CaseIterable, Hashable {
        case all, resume, slides, coverLetter, other

        var kind: DocumentKind? {
            switch self {
            case .all: return nil
            case .resume: return .resume
            case .slides: return .slides
            case .coverLetter: return .coverLetter
            case .other: return .other
            }
        }

        func label(_ language: LanguageStore) -> String {
            switch self {
            case .all: return L10n.t("All", "全部")
            case .resume: return L10n.t("Resume", "简历")
            case .slides: return "Slides"
            case .coverLetter: return "Cover Letter"
            case .other: return L10n.t("Other", "其他")
            }
        }
    }

    @State private var kindFilter: KindFilter = .all
    @State private var searchText = ""
    @State private var editingDocument: CareerDocument?
    @State private var dropTargeted = false
    @State private var copiedID: UUID?

    private var filtered: [CareerDocument] {
        documents.filter { doc in
            if let kind = kindFilter.kind, doc.documentKind != kind { return false }
            let query = searchText.trimmingCharacters(in: .whitespaces)
            if !query.isEmpty {
                let haystack = "\(doc.title) \(doc.note ?? "") \(doc.targetCompany ?? "") \(doc.originalFileName)"
                if !haystack.localizedCaseInsensitiveContains(query) { return false }
            }
            return true
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                controls
                if filtered.isEmpty {
                    emptyState
                } else {
                    grid
                }
            }
            .padding(28)
            .padding(.bottom, 40)
        }
        .background(Color.clear)
        .sheet(item: $editingDocument) { doc in
            DocumentEditSheet(document: doc)
        }
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
            importDropped(providers)
        }
        .overlay {
            if dropTargeted {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.orange.opacity(0.08))
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(AppTheme.orange, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    VStack(spacing: 8) {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(AppTheme.orange)
                        Text(language.t("Drop to save into vault", "松手存入资料库"))
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
                .padding(14)
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(language.t("Document vault", "求职资料库"))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(language.t(
                    "Drop in resumes, slides, and cover letters; Copy file then ⌘V into email or upload dialogs",
                    "简历、slides、cover letter 拖进来；投递时「复制文件」直接 ⌘V 进邮件或上传框"
                ))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            HStack(spacing: 10) {
                ForEach([DocumentKind.resume, .slides, .coverLetter], id: \.self) { kind in
                    let count = documents.filter { $0.documentKind == kind }.count
                    VStack(spacing: 2) {
                        Text("\(count)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(kindColor(kind))
                        Text(kind.label)
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
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Picker("", selection: $kindFilter) {
                ForEach(KindFilter.allCases, id: \.self) { filter in
                    Text(filter.label(language)).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 380)
            .labelsHidden()

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.muted)
                TextField(language.t("Search title / notes / company / filename", "搜标题 / 备注 / 公司 / 文件名"), text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.stroke, lineWidth: 1)
            )
            .frame(maxWidth: 300)

            Spacer()

            Button {
                importViaPanel()
            } label: {
                Label(language.t("Import files", "导入文件"), systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.orange, in: Capsule())
            }
            .buttonStyle(.hoverCue)
            .help(language.t("You can also drag files onto this page", "也可以直接把文件拖进页面"))
        }
    }

    // MARK: - Grid

    private var grid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 250, maximum: 360), spacing: 14)],
            spacing: 14
        ) {
            ForEach(filtered) { doc in
                DocumentCard(
                    document: doc,
                    justCopied: copiedID == doc.id,
                    onOpen: { open(doc) },
                    onCopy: { copyFile(doc) },
                    onReveal: { reveal(doc) },
                    onEdit: { editingDocument = doc },
                    onDelete: { remove(doc) }
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray.full")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(AppTheme.muted)
            Text(documents.isEmpty
                 ? language.t("Vault is empty", "资料库是空的")
                 : language.t("No matching documents", "没有匹配的资料"))
                .font(.headline)
                .foregroundStyle(AppTheme.textSecondary)
            Text(documents.isEmpty
                 ? language.t(
                    "Drop resumes, slides, or cover letters onto this page, or tap Import files.",
                    "把简历、slides、cover letter 直接拖进这个页面，或点右上角「导入文件」。"
                 )
                 : language.t("Try a different filter or search.", "换个筛选条件或搜索词试试。"))
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    // MARK: - Actions

    private func kindColor(_ kind: DocumentKind) -> Color {
        switch kind {
        case .resume: return AppTheme.accent
        case .slides: return AppTheme.orange
        case .coverLetter: return AppTheme.softBlue
        case .other: return AppTheme.purple
        }
    }

    private func open(_ doc: CareerDocument) {
        NSWorkspace.shared.open(AttachmentStore.url(for: doc.fileName))
    }

    /// 把文件放进剪贴板，可直接 ⌘V 到邮件 / 上传对话框。
    private func copyFile(_ doc: CareerDocument) {
        let url = AttachmentStore.url(for: doc.fileName)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([url as NSURL])
        copiedID = doc.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if copiedID == doc.id { copiedID = nil }
        }
    }

    private func reveal(_ doc: CareerDocument) {
        NSWorkspace.shared.activateFileViewerSelecting([AttachmentStore.url(for: doc.fileName)])
    }

    private func remove(_ doc: CareerDocument) {
        AttachmentStore.delete(fileName: doc.fileName)
        modelContext.delete(doc)
        try? modelContext.save()
    }

    // MARK: - Import

    private func importViaPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        importFiles(panel.urls)
    }

    private func importDropped(_ providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        var urls: [URL] = []
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url { urls.append(url) }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            importFiles(urls)
        }
        return true
    }

    private func importFiles(_ urls: [URL]) {
        var imported = false
        for url in urls {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue,
                  let stored = AttachmentStore.copyIn(from: url)
            else { continue }
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            let doc = CareerDocument(
                title: url.deletingPathExtension().lastPathComponent,
                kind: DocumentKind.guess(fromFileName: url.lastPathComponent),
                fileName: stored,
                originalFileName: url.lastPathComponent,
                fileSize: size ?? 0
            )
            modelContext.insert(doc)
            imported = true
        }
        if imported {
            try? modelContext.save()
        }
    }
}

// MARK: - Card

private struct DocumentCard: View {
    let document: CareerDocument
    let justCopied: Bool
    let onOpen: () -> Void
    let onCopy: () -> Void
    let onReveal: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @EnvironmentObject private var language: LanguageStore
    @State private var hovering = false

    private var color: Color {
        switch document.documentKind {
        case .resume: return AppTheme.accent
        case .slides: return AppTheme.orange
        case .coverLetter: return AppTheme.softBlue
        case .other: return AppTheme.purple
        }
    }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    // 文件图腾：类型图标 + 扩展名角标
                    ZStack(alignment: .bottomTrailing) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.85), color.opacity(0.45)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 52, height: 52)
                        Image(systemName: document.documentKind.icon)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                        if !document.fileExtension.isEmpty {
                            Text(document.fileExtension.uppercased())
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1.5)
                                .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 4))
                                .offset(x: 4, y: 4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(document.documentKind.label)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(color)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(color.opacity(0.14), in: Capsule())
                        Text(document.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                }

                if let note = document.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                HStack(spacing: 8) {
                    if let company = document.targetCompany, !company.isEmpty {
                        Label(company, systemImage: "building.2")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(document.sizeLabel)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(AppTheme.muted)
                    Text(document.updatedAt.formatted(.dateTime.month(.twoDigits).day(.twoDigits)))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(AppTheme.muted)
                }

                // 常用操作一排放卡片上，投递时不用翻菜单。
                HStack(spacing: 8) {
                    actionChip(
                        justCopied
                        ? language.t("Copied ✓", "已复制 ✓")
                        : language.t("Copy file", "复制文件"),
                        icon: justCopied ? "checkmark" : "doc.on.doc",
                        emphasized: justCopied,
                        action: onCopy
                    )
                    actionChip("Finder", icon: "folder", action: onReveal)
                    actionChip(language.t("Edit", "编辑"), icon: "pencil", action: onEdit)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(hovering ? color.opacity(0.5) : AppTheme.stroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(hovering ? 0.3 : 0), radius: 10, y: 4)
            .scaleEffect(hovering ? 1.01 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { value in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                hovering = value
            }
        }
        .contextMenu {
            Button(language.t("Open", "打开"), action: onOpen)
            Button(language.t("Copy file (⌘V to apply)", "复制文件（⌘V 去投递）"), action: onCopy)
            Button(language.t("Show in Finder", "在 Finder 中显示"), action: onReveal)
            Button(language.t("Edit info…", "编辑信息…"), action: onEdit)
            Divider()
            Button(language.t("Delete", "删除"), role: .destructive, action: onDelete)
        }
        .help(language.t("Click to open · right-click for more", "点击打开 · 右键更多操作"))
    }

    private func actionChip(
        _ label: String,
        icon: String,
        emphasized: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(emphasized ? .black : AppTheme.textSecondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    emphasized ? AnyShapeStyle(AppTheme.green) : AnyShapeStyle(AppTheme.elevated),
                    in: Capsule()
                )
        }
        .buttonStyle(.hoverCue)
    }
}

// MARK: - Edit sheet

private struct DocumentEditSheet: View {
    let document: CareerDocument

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var language: LanguageStore

    @State private var title = ""
    @State private var kind: DocumentKind = .resume
    @State private var note = ""
    @State private var targetCompany = ""
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language.t("Edit document", "编辑资料"))
                .font(.headline)

            LabeledContent(language.t("File", "文件")) {
                Text(document.originalFileName)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            TextField(language.t("Title", "标题"), text: $title)
                .textFieldStyle(.roundedBorder)

            Picker(language.t("Type", "类型"), selection: $kind) {
                ForEach(DocumentKind.allCases, id: \.self) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            TextField(language.t("Related company (optional, e.g. OpenAI)", "关联公司（可选，如 OpenAI）"), text: $targetCompany)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text(language.t("Note (which version, which role it was tailored for)", "备注（哪个版本、针对什么岗位改的）"))
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                TextEditor(text: $note)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 64)
                    .background(AppTheme.elevated.opacity(0.75), in: RoundedRectangle(cornerRadius: 10))
            }

            HStack {
                Spacer()
                Button(language.t("Cancel", "取消")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(language.t("Save", "保存")) {
                    save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            title = document.title
            kind = document.documentKind
            note = document.note ?? ""
            targetCompany = document.targetCompany ?? ""
        }
    }

    private func save() {
        document.title = title.trimmingCharacters(in: .whitespaces)
        document.kind = kind.rawValue
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        document.note = trimmedNote.isEmpty ? nil : trimmedNote
        let trimmedCompany = targetCompany.trimmingCharacters(in: .whitespaces)
        document.targetCompany = trimmedCompany.isEmpty ? nil : trimmedCompany
        document.updatedAt = Date()
        try? modelContext.save()
    }
}
