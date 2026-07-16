import SwiftUI
import SwiftData
import AppKit

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
            Button {
                dismissChat()
            } label: {
                HStack {
                    Text("聊天记录")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ChatTheme.secondaryText)
                    Spacer(minLength: 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("收起聊天")

            Button {
                viewModel.showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(ChatTheme.secondaryText)
            .help("API Key 设置")

            Button {
                dismissChat()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
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
        }
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

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("", text: $viewModel.draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(ChatTheme.primaryText)
                .lineLimit(1...5)
                .focused($inputFocused)
                .onSubmit {
                    Task { await viewModel.send(using: modelContext) }
                }
                .onKeyPress(.escape) {
                    dismissChat()
                    return .handled
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
                    .foregroundStyle(
                        viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending
                        ? ChatTheme.secondaryText.opacity(0.45)
                        : ChatTheme.accent
                    )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
            .help("发送")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        // Don't put onTapGesture on the whole bar — it blocks select / copy / paste in the field.
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
