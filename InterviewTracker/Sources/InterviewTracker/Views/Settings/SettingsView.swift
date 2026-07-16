import SwiftUI
import SwiftData
import AppKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey: String = ""
    @State private var saved = false
    @State private var testStatus: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("设置")
                .font(.title2.weight(.semibold))

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    deepSeekSection
                    Divider()
                    googleSection
                }
            }

            HStack {
                Spacer()
                Button("完成") { dismiss() }
            }
        }
        .padding(24)
        .frame(width: 480, height: 420)
        .onAppear {
            apiKey = APIKeyStore.load() ?? ""
        }
    }

    private var deepSeekSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DeepSeek API Key")
                .font(.headline)
            SecureField("sk-…", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            Text("模型：deepseek-v4-pro · 保存在本机 Application Support。")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("保存") {
                    _ = APIKeyStore.save(apiKey)
                    saved = true
                    testStatus = "已保存"
                }
                .keyboardShortcut(.defaultAction)

                Button("测试连接") {
                    Task { await testConnection() }
                }
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let testStatus {
                Text(testStatus)
                    .font(.caption)
                    .foregroundStyle(saved || testStatus.contains("成功") ? .green : .orange)
            }

            Text("Agent traces：\(AgentTraceStore.fileURL.path)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            Text("User feedback 记忆：\(UserFeedbackMemoryStore.fileURL.path)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button("在 Finder 中显示 traces") {
                    NSWorkspace.shared.activateFileViewerSelecting([AgentTraceStore.fileURL])
                }
                .font(.caption)

                Button("显示 feedback 记忆") {
                    NSWorkspace.shared.activateFileViewerSelecting([UserFeedbackMemoryStore.fileURL])
                }
                .font(.caption)
            }
        }
    }

    private var googleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Google Calendar")
                .font(.headline)
            Text("日历同步已停用（按你的要求先不接 Google）。需要时再说一声，我把它接回来。")
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func testConnection() async {
        testStatus = "测试中…"
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = APIKeyStore.save(key)
        let startedAt = Date()
        do {
            let reply = try await DeepSeekClient.shared.testConnection(apiKey: key)
            testStatus = "连接成功：\(reply)"
            saved = true
            AgentTraceStore.append(
                AgentTraceRecord(
                    startedAt: startedAt,
                    endedAt: Date(),
                    kind: "settings_test",
                    userMessage: "测试 API Key",
                    assistantMessage: testStatus
                )
            )
        } catch {
            testStatus = "失败：\(error.localizedDescription)"
            saved = false
            AgentTraceStore.append(
                AgentTraceRecord(
                    startedAt: startedAt,
                    endedAt: Date(),
                    kind: "settings_test",
                    userMessage: "测试 API Key",
                    assistantMessage: testStatus,
                    error: error.localizedDescription
                )
            )
        }
    }
}
