import SwiftUI
import SwiftData
import AppKit

/// 论文 / tech blog 收藏页：卡片墙 + 筛选 + 标签。
struct ReadingLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var navigation: NavigationStore
    @Query(sort: \ReadingItem.createdAt, order: .reverse) private var items: [ReadingItem]

    private enum KindFilter: String, CaseIterable {
        case all = "全部"
        case paper = "论文"
        case blog = "博客"
        case video = "视频"

        var kind: ReadingKind? {
            switch self {
            case .all: return nil
            case .paper: return .paper
            case .blog: return .blog
            case .video: return .video
            }
        }
    }

    @State private var kindFilter: KindFilter = .all
    @State private var unreadOnly = false
    @State private var searchText = ""
    @State private var activeTag: String?
    @State private var editingItem: ReadingItem?
    @State private var showAddSheet = false
    @State private var dropTargeted = false

    private var filtered: [ReadingItem] {
        items.filter { item in
            if let kind = kindFilter.kind, item.readingKind != kind { return false }
            if unreadOnly && item.isRead { return false }
            if let tag = activeTag, !item.tagList.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
                return false
            }
            let query = searchText.trimmingCharacters(in: .whitespaces)
            if !query.isEmpty {
                let haystack = "\(item.title) \(item.domain) \(item.tags) \(item.note ?? "") \(item.readingNotes ?? "")"
                if !haystack.localizedCaseInsensitiveContains(query) { return false }
            }
            return true
        }
    }

    private var allTags: [String] {
        var seen: [String] = []
        for item in items {
            for tag in item.tagList where !seen.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
                seen.append(tag)
            }
        }
        return seen
    }

    private var unreadCount: Int {
        items.filter { !$0.isRead }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                controls
                if !allTags.isEmpty {
                    tagRow
                }
                if filtered.isEmpty {
                    emptyState
                } else {
                    cardGrid
                }
            }
            .padding(28)
            .padding(.bottom, 40)
        }
        .background(Color.clear)
        .sheet(isPresented: $showAddSheet) {
            ReadingItemFormSheet(existing: nil)
        }
        .sheet(item: $editingItem) { item in
            ReadingItemFormSheet(existing: item)
        }
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
            importDroppedFiles(providers)
        }
        .overlay {
            if dropTargeted {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.accent.opacity(0.08))
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(AppTheme.accent, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(AppTheme.accent)
                        Text("松手把 PDF 加入论文收藏")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
                .padding(14)
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Header & controls

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("阅读收藏")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("论文 PDF、tech blog、YouTube 都丢进来，读完打个勾，笔记就写在旁边")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            HStack(spacing: 14) {
                statBadge(value: items.count, label: "收藏", color: AppTheme.accent)
                statBadge(value: unreadCount, label: "未读", color: AppTheme.orange)
            }
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
        .frame(minWidth: 52)
        .padding(.vertical, 8)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Picker("", selection: $kindFilter) {
                ForEach(KindFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 280)
            .labelsHidden()

            Toggle("只看未读", isOn: $unreadOnly)
                .toggleStyle(.checkbox)
                .foregroundStyle(AppTheme.textSecondary)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.muted)
                TextField("搜标题 / 域名 / 标签 / 备注", text: $searchText)
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
            .frame(maxWidth: 320)

            Spacer()

            Button {
                showAddSheet = true
            } label: {
                Label("添加收藏", systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.accent, in: Capsule())
            }
            .buttonStyle(.hoverCue)
            .keyboardShortcut("n", modifiers: .command)
            .help("添加论文或博客（⌘N）")
        }
    }

    private var tagRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(allTags, id: \.self) { tag in
                    let selected = activeTag?.caseInsensitiveCompare(tag) == .orderedSame
                    Button {
                        activeTag = selected ? nil : tag
                    } label: {
                        Text("#\(tag)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selected ? .black : AppTheme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                selected ? AnyShapeStyle(AppTheme.accent) : AnyShapeStyle(AppTheme.elevated),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.hoverCue)
                }
            }
        }
    }

    // MARK: - Cards

    private var cardGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 290, maximum: 420), spacing: 14)],
            spacing: 14
        ) {
            ForEach(filtered) { item in
                ReadingCard(
                    item: item,
                    onOpen: { open(item) },
                    onToggleRead: { toggleRead(item) },
                    onEdit: { editingItem = item },
                    onNotes: { navigation.openReadingItem(item.id) },
                    onDelete: { remove(item) },
                    onTagTap: { tag in activeTag = tag }
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(AppTheme.muted)
            Text(items.isEmpty ? "还没有收藏" : "没有匹配的收藏")
                .font(.headline)
                .foregroundStyle(AppTheme.textSecondary)
            Text(items.isEmpty
                 ? "把 PDF 直接拖进这个页面，或点「添加收藏」（⌘N）贴博客 / YouTube 链接。"
                 : "换个筛选条件或搜索词试试。")
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    // MARK: - Actions

    private func open(_ item: ReadingItem) {
        if let fileName = item.fileName {
            NSWorkspace.shared.open(AttachmentStore.url(for: fileName))
        } else if let url = item.url {
            NSWorkspace.shared.open(url)
        } else {
            return
        }
        if !item.isRead {
            item.isRead = true
            try? modelContext.save()
        }
    }

    private func toggleRead(_ item: ReadingItem) {
        item.isRead.toggle()
        try? modelContext.save()
    }

    private func remove(_ item: ReadingItem) {
        if let fileName = item.fileName {
            AttachmentStore.delete(fileName: fileName)
        }
        modelContext.delete(item)
        try? modelContext.save()
    }

    /// 拖入的 PDF 直接建为论文收藏（标题用文件名，可再编辑）。
    private func importDroppedFiles(_ providers: [NSItemProvider]) -> Bool {
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
            let pdfs = urls.filter { $0.pathExtension.lowercased() == "pdf" }
            for pdf in pdfs {
                guard let fileName = AttachmentStore.copyIn(from: pdf) else { continue }
                let item = ReadingItem(
                    title: pdf.deletingPathExtension().lastPathComponent,
                    urlString: "",
                    kind: .paper,
                    fileName: fileName
                )
                modelContext.insert(item)
            }
            if !pdfs.isEmpty {
                try? modelContext.save()
            }
        }
        return true
    }
}

// MARK: - Card

private struct ReadingCard: View {
    let item: ReadingItem
    let onOpen: () -> Void
    let onToggleRead: () -> Void
    let onEdit: () -> Void
    let onNotes: () -> Void
    let onDelete: () -> Void
    let onTagTap: (String) -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    DomainMonogram(domain: item.domain, title: item.title)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            kindBadge
                            if !item.isRead {
                                Circle()
                                    .fill(AppTheme.orange)
                                    .frame(width: 6, height: 6)
                                    .help("未读")
                            }
                        }
                        Text(item.domain.isEmpty ? "链接" : item.domain)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.muted)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button(action: onNotes) {
                        Image(systemName: item.hasNotes ? "note.text" : "square.and.pencil")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(item.hasNotes ? AppTheme.accent : AppTheme.muted)
                    }
                    .buttonStyle(.hoverCue)
                    .help(item.hasNotes ? "查看 / 编辑阅读笔记" : "写阅读笔记")

                    Button(action: onToggleRead) {
                        Image(systemName: item.isRead ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(item.isRead ? AppTheme.green : AppTheme.muted)
                    }
                    .buttonStyle(.hoverCue)
                    .help(item.isRead ? "标为未读" : "标为已读")
                }

                Text(item.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(item.isRead ? AppTheme.textSecondary : AppTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let note = item.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                HStack(spacing: 6) {
                    ForEach(item.tagList.prefix(4), id: \.self) { tag in
                        Button {
                            onTagTap(tag)
                        } label: {
                            Text("#\(tag)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppTheme.accent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(AppTheme.accent.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.hoverCue)
                    }
                    Spacer()
                    Text(item.createdAt.formatted(.dateTime.month(.twoDigits).day(.twoDigits)))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(AppTheme.muted)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(hovering ? AppTheme.accent.opacity(0.45) : AppTheme.stroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(hovering ? 0.30 : 0), radius: 10, y: 4)
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
            Button(item.fileName != nil ? "打开 PDF" : "打开链接", action: onOpen)
            Button("阅读笔记…", action: onNotes)
            Button(item.isRead ? "标为未读" : "标为已读", action: onToggleRead)
            Button("编辑…", action: onEdit)
            if item.fileName != nil {
                Button("在 Finder 中显示") {
                    if let fileName = item.fileName {
                        NSWorkspace.shared.activateFileViewerSelecting([AttachmentStore.url(for: fileName)])
                    }
                }
            }
            if !item.urlString.isEmpty {
                Button("复制链接") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.urlString, forType: .string)
                }
            }
            Divider()
            Button("删除", role: .destructive, action: onDelete)
        }
        .help("点击打开 · 右键更多操作")
    }

    private var kindBadge: some View {
        let color: Color = {
            switch item.readingKind {
            case .paper: return AppTheme.softBlue
            case .blog: return AppTheme.purple
            case .video: return AppTheme.rose
            }
        }()
        return Label(item.readingKind.label, systemImage: item.readingKind.icon)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
    }
}

/// 不联网的“favicon”：按域名哈希取色的首字母圆徽章。
private struct DomainMonogram: View {
    let domain: String
    let title: String

    private static let palette: [Color] = [
        AppTheme.accent, AppTheme.orange, AppTheme.softBlue,
        AppTheme.purple, AppTheme.green, AppTheme.rose
    ]

    var body: some View {
        let seed = domain.isEmpty ? title : domain
        let color = Self.palette[abs(seed.hashValue) % Self.palette.count]
        let letter = String((domain.isEmpty ? title : domain).prefix(1)).uppercased()

        Text(letter)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
    }
}

// MARK: - Add / edit sheet

struct ReadingItemFormSheet: View {
    let existing: ReadingItem?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @State private var urlString = ""
    @State private var kind: ReadingKind = .paper
    @State private var tags = ""
    @State private var note = ""
    @State private var storedFileName: String?
    @State private var pickedPDF: URL?
    @State private var loaded = false

    private var hasPDF: Bool {
        pickedPDF != nil || storedFileName != nil
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && (!urlString.trimmingCharacters(in: .whitespaces).isEmpty || hasPDF)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existing == nil ? "添加收藏" : "编辑收藏")
                .font(.headline)

            Picker("类型", selection: $kind) {
                ForEach(ReadingKind.allCases, id: \.self) { kind in
                    Label(kind.label, systemImage: kind.icon).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if kind == .paper {
                pdfRow
            }

            HStack(spacing: 8) {
                TextField(
                    kind == .paper ? "链接（选了本地 PDF 可留空）" : "链接（https://…）",
                    text: $urlString
                )
                .textFieldStyle(.roundedBorder)
                Button("从剪贴板粘贴") {
                    if let raw = NSPasteboard.general.string(forType: .string) {
                        urlString = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                .controlSize(.small)
            }

            TextField("标题", text: $title)
                .textFieldStyle(.roundedBorder)

            TextField("标签（逗号分隔，如 LLM, RLHF, Agent）", text: $tags)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("备注（为什么值得读 / 重点是什么）")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                TextEditor(text: $note)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 70)
                    .background(AppTheme.elevated.opacity(0.75), in: RoundedRectangle(cornerRadius: 10))
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(existing == nil ? "收藏" : "保存") {
                    save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(24)
        .frame(width: 460)
        .onAppear { loadIfNeeded() }
    }

    private var pdfRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.fill")
                .foregroundStyle(hasPDF ? AppTheme.softBlue : AppTheme.muted)
            if let pickedPDF {
                Text(pickedPDF.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else if storedFileName != nil {
                Text("已存本地 PDF")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textPrimary)
            } else {
                Text("还没选 PDF")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
            Button(hasPDF ? "换一个…" : "选择本地 PDF…") { pickPDF() }
                .controlSize(.small)
            if hasPDF {
                Button("移除") {
                    pickedPDF = nil
                    storedFileName = nil
                }
                .controlSize(.small)
            }
        }
        .padding(10)
        .background(AppTheme.elevated.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    private func pickPDF() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.pdf]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        pickedPDF = url
        if title.trimmingCharacters(in: .whitespaces).isEmpty {
            title = url.deletingPathExtension().lastPathComponent
        }
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let existing else { return }
        title = existing.title
        urlString = existing.urlString
        kind = existing.readingKind
        tags = existing.tags
        note = existing.note ?? ""
        storedFileName = existing.fileName
    }

    private func save() {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        // 新选的 PDF 拷进 AttachmentStore；被替换/移除的旧文件删掉。
        var fileName = storedFileName
        if let pickedPDF {
            fileName = AttachmentStore.copyIn(from: pickedPDF)
        }
        if let old = existing?.fileName, old != fileName {
            AttachmentStore.delete(fileName: old)
        }

        if let existing {
            existing.title = title.trimmingCharacters(in: .whitespaces)
            existing.urlString = urlString.trimmingCharacters(in: .whitespaces)
            existing.kind = kind.rawValue
            existing.tags = tags
            existing.note = trimmedNote.isEmpty ? nil : trimmedNote
            existing.fileName = fileName
        } else {
            let item = ReadingItem(
                title: title.trimmingCharacters(in: .whitespaces),
                urlString: urlString.trimmingCharacters(in: .whitespaces),
                kind: kind,
                tags: tags,
                note: trimmedNote.isEmpty ? nil : trimmedNote,
                fileName: fileName
            )
            modelContext.insert(item)
        }
        try? modelContext.save()
    }
}

