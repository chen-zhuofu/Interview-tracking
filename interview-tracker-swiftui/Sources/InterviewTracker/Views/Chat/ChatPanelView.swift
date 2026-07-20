import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct ChatPanelView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.modelContext) private var modelContext
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isExpanded {
                expandedHeader
                Divider().opacity(0.35)
                messageList
                if let error = viewModel.errorText {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                }
            }
            inputBar
        }
        .background(ChatTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: viewModel.isExpanded ? 16 : 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: viewModel.isExpanded ? 16 : 14, style: .continuous)
                .stroke(ChatTheme.stroke, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: viewModel.isExpanded ? 24 : 10, y: 8)
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: viewModel.isExpanded)
        .background(escapeShortcut)
        .onChange(of: viewModel.isExpanded) { _, expanded in
            if !expanded { inputFocused = false }
        }
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView()
        }
    }

    /// Esc works whether the panel is open or just the input bar is focused.
    private var escapeShortcut: some View {
        Button("收起聊天") { dismissChat() }
            .keyboardShortcut(.escape, modifiers: [])
            .frame(width: 0, height: 0)
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var expandedHeader: some View {
        HStack {
            Text("聊天记录")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ChatTheme.secondaryText)

            Spacer(minLength: 8)

            Button {
                viewModel.showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.hoverCueContained)
            .foregroundStyle(ChatTheme.secondaryText)
            .help("API Key 设置")

            Button {
                dismissChat()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.hoverCueContained)
            .foregroundStyle(ChatTheme.secondaryText)
            .help("收起聊天（Esc）")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func dismissChat() {
        viewModel.collapse()
        inputFocused = false
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        messageBubble(message)
                            .id(message.id)
                    }
                    if let approval = viewModel.pendingApproval {
                        approvalCard(approval)
                            .id(approval.id)
                    }
                    if viewModel.isSending {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("正在归纳…")
                                .font(.caption)
                                .foregroundStyle(ChatTheme.secondaryText)
                        }
                        .padding(.leading, 4)
                        .id("typing")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(maxHeight: 320)
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation {
                    proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                }
            }
            .onChange(of: viewModel.isSending) { _, sending in
                if sending {
                    withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                }
            }
            .onChange(of: viewModel.pendingApproval?.id) { _, id in
                if let id {
                    withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
        }
    }

    private func approvalCard(_ approval: PendingAgentApproval) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "checkmark.shield")
                    .foregroundStyle(AppTheme.orange)
                Text("批准后才会写入")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ChatTheme.primaryText)
                Spacer()
                Text("\(approval.writes.count) 项")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(ChatTheme.secondaryText)
            }

            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(approval.writes.enumerated()), id: \.element.id) { index, write in
                    HStack(alignment: .top, spacing: 7) {
                        Text("\(index + 1).")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(ChatTheme.secondaryText)
                        Text(write.preview)
                            .font(.caption)
                            .foregroundStyle(ChatTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            HStack {
                Button("取消") {
                    viewModel.rejectPendingWrites()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("批准并执行") {
                    Task { await viewModel.approvePendingWrites(using: modelContext) }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .foregroundStyle(.black)
            }
        }
        .padding(12)
        .background(AppTheme.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.orange.opacity(0.35), lineWidth: 1)
        )
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text)
                .font(.system(size: 13.5))
                .foregroundStyle(message.role == .user ? Color.white : ChatTheme.primaryText)
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    message.role == .user ? ChatTheme.accent : ChatTheme.bubbleAssistant,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .contextMenu {
                    Button("复制") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(message.text, forType: .string)
                    }
                }
            if message.role != .user { Spacer(minLength: 40) }
        }
    }

    private var canSend: Bool {
        let hasText = !viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (hasText || viewModel.hasAttachment)
            && !viewModel.isSending
            && viewModel.pendingApproval == nil
    }

    private var inputBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = viewModel.attachedImage {
                attachmentPreview(image)
            }

            HStack(alignment: .center, spacing: 10) {
                voiceButton

                TextField("", text: $viewModel.draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(ChatTheme.primaryText)
                    .lineLimit(1...5)
                    .focused($inputFocused)
                    .disabled(viewModel.pendingApproval != nil)
                    .onSubmit {
                        Task { await viewModel.send(using: modelContext) }
                    }
                    .onKeyPress(.escape) {
                        dismissChat()
                        return .handled
                    }
                    // Paste an image (e.g. a screenshot) straight into the input.
                    // Text paste is unaffected: this only fires when the clipboard holds an image.
                    .onPasteCommand(of: [.image]) { providers in
                        loadPastedImage(from: providers)
                    }
                    .onChange(of: viewModel.draft) { _, newValue in
                        if !newValue.isEmpty { viewModel.expand() }
                    }
                    .onChange(of: inputFocused) { _, focused in
                        if focused { viewModel.expand() }
                    }

                Button {
                    Task { await viewModel.send(using: modelContext) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(canSend ? ChatTheme.accent : ChatTheme.secondaryText.opacity(0.45))
                }
                .buttonStyle(.hoverCue)
                .disabled(!canSend)
                .help("发送")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        // Tap anywhere on the bar to focus. Put it on the background layer so it
        // doesn't swallow select / copy / paste inside the field or button taps.
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { inputFocused = true }
        )
    }

    private var voiceButton: some View {
        Button {
            viewModel.startVoiceInput()
        } label: {
            LangbridgeLogoView(size: 22)
        }
        .buttonStyle(.hoverCue)
        .disabled(viewModel.pendingApproval != nil)
        .help("语音输入（模型待定）")
    }

    private func attachmentPreview(_ image: NSImage) -> some View {
        HStack(spacing: 8) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(ChatTheme.stroke, lineWidth: 1)
                )

            Text("已附带图片")
                .font(.caption)
                .foregroundStyle(ChatTheme.secondaryText)

            Spacer(minLength: 4)

            Button {
                viewModel.clearAttachment()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(ChatTheme.secondaryText)
            }
            .buttonStyle(.hoverCue)
            .help("移除图片")
        }
        .padding(.leading, 2)
    }

    private func loadPastedImage(from providers: [NSItemProvider]) {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSImage.self) }) else { return }
        _ = provider.loadObject(ofClass: NSImage.self) { object, _ in
            guard let image = object as? NSImage else { return }
            DispatchQueue.main.async {
                viewModel.attachImage(image)
                inputFocused = true
            }
        }
    }
}

enum ChatTheme {
    static let panelBackground = AppTheme.card
    static let bubbleAssistant = AppTheme.elevated
    static let stroke = AppTheme.stroke
    static let primaryText = AppTheme.textPrimary
    static let secondaryText = AppTheme.textSecondary
    static let accent = AppTheme.accent
}
