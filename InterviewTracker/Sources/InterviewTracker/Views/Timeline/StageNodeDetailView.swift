import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

/// Detail sheet for one stage node: title / date / time / note / links / images.
/// Edits write straight to the model — every view reads the same StageNode,
/// so consistency is automatic.
struct StageNodeDetailView: View {
    let nodeID: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var chat: ChatViewModel
    @Query private var nodes: [StageNode]

    @State private var title = ""
    @State private var day = Date()
    @State private var hasTime = false
    @State private var time = Date()
    @State private var bucket: OpportunityBucket = .notStarted
    @State private var isInterview = false
    @State private var note = ""
    @State private var links = ""
    @State private var loaded = false
    @State private var previewImage: NSImage?

    private var node: StageNode? {
        nodes.first { $0.id == nodeID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let node {
                header(node)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        stageFields
                        noteSection
                        linkSection
                        attachmentSection(node)
                    }
                    .padding(.vertical, 4)
                }
                footer(node)
            } else {
                ContentUnavailableView("节点不存在", systemImage: "questionmark.circle")
            }
        }
        .padding(22)
        .frame(width: 520, height: 620)
        .onAppear { loadIfNeeded() }
        .sheet(isPresented: Binding(
            get: { previewImage != nil },
            set: { if !$0 { previewImage = nil } }
        )) {
            if let previewImage {
                VStack(spacing: 12) {
                    Image(nsImage: previewImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 760, maxHeight: 560)
                    Button("关闭") { self.previewImage = nil }
                }
                .padding(20)
            }
        }
    }

    private func loadIfNeeded() {
        guard !loaded, let node else { return }
        loaded = true
        title = node.title
        day = Calendar.current.startOfDay(for: node.date)
        hasTime = node.hasTime
        time = node.date
        bucket = OpportunityBucket(rawValue: node.bucket) ?? .notStarted
        isInterview = node.isInterview
        note = node.note ?? ""
        links = node.links ?? ""
    }

    private func header(_ node: StageNode) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(node.application?.company?.name ?? "未知公司")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                if let outcome = displayedOutcome(node) {
                    Text(outcome.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(outcomeColor(outcome), in: Capsule())
                }
            }
            Text("阶段节点详情 · 改完点保存")
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
        }
    }

    /// 通过状态从时间线推导：进入下一轮 = 上一轮通过。未来的面试不显示「等结果」。
    private func displayedOutcome(_ node: StageNode) -> InterviewOutcome? {
        guard let outcome = node.application?.interviewOutcome(for: node) else { return nil }
        if outcome == .pending && node.date > Date() { return nil }
        return outcome
    }

    private func outcomeColor(_ outcome: InterviewOutcome) -> Color {
        switch outcome {
        case .passed: return AppTheme.green
        case .failed: return AppTheme.rose
        case .pending: return AppTheme.orange
        }
    }

    private var stageFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("阶段（以你写的为准）", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(.body.weight(.medium))

            HStack(spacing: 14) {
                DatePicker("日期", selection: $day, displayedComponents: .date)
                    .datePickerStyle(.field)
                Toggle("有具体时间", isOn: $hasTime)
                if hasTime {
                    DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.field)
                        .labelsHidden()
                }
            }

            Picker("看板桶", selection: $bucket) {
                ForEach(OpportunityBucket.allCases, id: \.self) { bucket in
                    Text(bucket.label).tag(bucket)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 2) {
                Toggle("这是一轮面试", isOn: $isInterview)
                Text("面试从 HR Call 起算；猎头Call、各种「预约X」不算面试。进入下一轮 = 上一轮通过。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("备注")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            TextEditor(text: $note)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 100)
                .background(AppTheme.elevated.opacity(0.75), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var linkSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("链接（每行一个）")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            TextEditor(text: $links)
                .font(.system(.callout, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 54)
                .background(AppTheme.elevated.opacity(0.75), in: RoundedRectangle(cornerRadius: 10))

            let urls = linkURLs
            if !urls.isEmpty {
                FlowLinks(urls: urls)
            }
        }
    }

    private var linkURLs: [URL] {
        links
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .compactMap { raw in
                guard !raw.isEmpty else { return nil }
                if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
                    return URL(string: raw)
                }
                return URL(string: "https://" + raw)
            }
    }

    private func attachmentSection(_ node: StageNode) -> some View {
        AttachmentGridView(
            attachments: node.attachments ?? [],
            onAdd: { addAttachments(to: node) },
            onPaste: { pasteImage(to: node) },
            onOpen: { attachment in
                previewImage = AttachmentStore.image(for: attachment.fileName)
            },
            onDelete: { attachment in
                AttachmentStore.delete(fileName: attachment.fileName)
                modelContext.delete(attachment)
                try? modelContext.save()
            },
            onDropURLs: { urls in
                importFiles(urls, to: node)
            }
        )
    }

    private func addAttachments(to node: StageNode) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image, .pdf]
        guard panel.runModal() == .OK else { return }
        importFiles(panel.urls, to: node)
    }

    private func importFiles(_ urls: [URL], to node: StageNode) {
        for url in urls {
            guard let name = AttachmentStore.copyIn(from: url) else { continue }
            let attachment = MediaAttachment(fileName: name, stageNode: node)
            modelContext.insert(attachment)
        }
        try? modelContext.save()
    }

    private func pasteImage(to node: StageNode) {
        let pasteboard = NSPasteboard.general
        guard
            let data = pasteboard.data(forType: .png)
                ?? pasteboard.data(forType: .tiff).flatMap({ tiff in
                    NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
                }),
            let name = AttachmentStore.saveImageData(data)
        else { return }
        let attachment = MediaAttachment(fileName: name, stageNode: node)
        modelContext.insert(attachment)
        try? modelContext.save()
    }

    private func footer(_ node: StageNode) -> some View {
        HStack {
            Button("删除节点", role: .destructive) {
                let label = "\(node.application?.company?.name ?? "?")·\(node.title)"
                for attachment in node.attachments ?? [] {
                    AttachmentStore.delete(fileName: attachment.fileName)
                }
                node.application?.lastUpdated = Date()
                modelContext.delete(node)
                try? modelContext.save()
                chat.recordLocalEdit(
                    userText: "【节点详情】删除「\(label)」",
                    assistantText: "已删除「\(label)」。"
                )
                dismiss()
            }
            Spacer()
            Button("取消") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("保存") {
                save(node)
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func save(_ node: StageNode) {
        let cal = Calendar.current
        let formatted = StageClassifier.formatTitle(title)
        let oldLabel = "\(node.application?.company?.name ?? "?")·\(node.title)"

        node.title = formatted
        node.bucket = bucket.rawValue
        node.isInterview = isInterview
        node.hasTime = hasTime
        if hasTime {
            let clock = cal.dateComponents([.hour, .minute], from: time)
            node.date = cal.date(
                bySettingHour: clock.hour ?? 10,
                minute: clock.minute ?? 0,
                second: 0,
                of: cal.startOfDay(for: day)
            ) ?? day
        } else {
            node.date = cal.date(
                bySettingHour: 12, minute: 0, second: 0,
                of: cal.startOfDay(for: day)
            ) ?? day
        }
        node.note = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
        node.links = links.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : links
        node.application?.lastUpdated = Date()
        try? modelContext.save()

        chat.recordLocalEdit(
            userText: "【节点详情】编辑「\(oldLabel)」",
            assistantText: "已保存：\(formatted) · \(node.date.formatted(date: .abbreviated, time: hasTime ? .shortened : .omitted))"
        )
    }
}

// MARK: - Shared attachment grid

struct AttachmentGridView: View {
    let attachments: [MediaAttachment]
    let onAdd: () -> Void
    let onPaste: () -> Void
    let onOpen: (MediaAttachment) -> Void
    let onDelete: (MediaAttachment) -> Void
    let onDropURLs: ([URL]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text("图片 / 附件")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Button("粘贴图片", action: onPaste)
                    .font(.caption)
                Button("添加文件…", action: onAdd)
                    .font(.caption)
            }

            if attachments.isEmpty {
                Text("拖入图片、点「添加文件…」或复制后点「粘贴图片」。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 14)
                    .background(AppTheme.elevated.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                    ForEach(attachments.sorted { $0.createdAt < $1.createdAt }) { attachment in
                        thumbnail(attachment)
                    }
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            var urls: [URL] = []
            let group = DispatchGroup()
            for provider in providers {
                group.enter()
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url { urls.append(url) }
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                if !urls.isEmpty { onDropURLs(urls) }
            }
            return true
        }
    }

    private func thumbnail(_ attachment: MediaAttachment) -> some View {
        Button {
            onOpen(attachment)
        } label: {
            Group {
                if let image = AttachmentStore.image(for: attachment.fileName) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "doc")
                        .font(.title2)
                        .foregroundStyle(AppTheme.muted)
                }
            }
            .frame(width: 92, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("在 Finder 中显示") {
                NSWorkspace.shared.activateFileViewerSelecting(
                    [AttachmentStore.url(for: attachment.fileName)]
                )
            }
            Button("删除", role: .destructive) {
                onDelete(attachment)
            }
        }
    }
}

/// Simple wrapping row of clickable links.
struct FlowLinks: View {
    let urls: [URL]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(urls, id: \.absoluteString) { url in
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.caption2)
                        Text(url.absoluteString)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }
}
