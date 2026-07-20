import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var language: LanguageStore

    @State private var apiKey: String = ""
    @State private var saved = false
    @State private var testStatus: String?
    @State private var geminiKey: String = ""
    @State private var geminiSaved = false
    @State private var geminiStatus: String?
    @State private var exportStatus: String?
    @State private var isExporting = false
    @State private var importStatus: String?
    @State private var isImporting = false
    @State private var pendingImportURL: URL?
    @State private var showImportChoice = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(language.t("Settings", "设置"))
                .font(.title2.weight(.semibold))

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    languageSection
                    Divider()
                    deepSeekSection
                    Divider()
                    geminiSection
                    Divider()
                    googleSection
                    Divider()
                    dataSection
                }
            }

            HStack {
                Spacer()
                Button(language.t("Done", "完成")) { dismiss() }
            }
        }
        .padding(24)
        .frame(width: 520, height: 580)
        .onAppear {
            apiKey = APIKeyStore.load() ?? ""
            geminiKey = GeminiKeyStore.load() ?? ""
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(language.t("Language", "语言"))
                .font(.headline)
            Picker("", selection: $language.language) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.pickerLabel).tag(lang)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text(language.t(
                "Default is English. Switch anytime — UI updates immediately.",
                "默认英文。随时可切换，界面立刻更新。"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var geminiSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(language.t("Gemini API Key (image recognition)", "Gemini API Key（图片识别）"))
                .font(.headline)
            SecureField("AIza…", text: $geminiKey)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            Text(language.t(
                "Model: \(ChatVisionConfig.imageModel) · Images are transcribed here, then passed to the agent. Stored on this Mac only.",
                "模型：\(ChatVisionConfig.imageModel) · 上传/粘贴的图片交给它识别成文字，再交给 agent。保存在本机。"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button(language.t("Save", "保存")) {
                    _ = GeminiKeyStore.save(geminiKey)
                    geminiSaved = true
                    geminiStatus = language.t("Saved", "已保存")
                }

                Button(language.t("Test connection", "测试连接")) {
                    Task { await testGemini() }
                }
                .disabled(geminiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let geminiStatus {
                Text(geminiStatus)
                    .font(.caption)
                    .foregroundStyle(geminiSaved || geminiStatus.localizedCaseInsensitiveContains("success") || geminiStatus.contains("成功") ? .green : .orange)
            }
        }
    }

    private var deepSeekSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DeepSeek API Key")
                .font(.headline)
            SecureField("sk-…", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            Text(language.t(
                "Model: deepseek-v4-pro · Stored under Application Support on this Mac.",
                "模型：deepseek-v4-pro · 保存在本机 Application Support。"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button(language.t("Save", "保存")) {
                    _ = APIKeyStore.save(apiKey)
                    saved = true
                    testStatus = language.t("Saved", "已保存")
                }
                .keyboardShortcut(.defaultAction)

                Button(language.t("Test connection", "测试连接")) {
                    Task { await testConnection() }
                }
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let testStatus {
                Text(testStatus)
                    .font(.caption)
                    .foregroundStyle(saved || testStatus.localizedCaseInsensitiveContains("success") || testStatus.contains("成功") ? .green : .orange)
            }

            Text("Agent traces：\(AgentTraceStore.fileURL.path)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            Text(language.t(
                "User feedback memory: \(UserFeedbackMemoryStore.fileURL.path)",
                "User feedback 记忆：\(UserFeedbackMemoryStore.fileURL.path)"
            ))
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button(language.t("Reveal traces in Finder", "在 Finder 中显示 traces")) {
                    NSWorkspace.shared.activateFileViewerSelecting([AgentTraceStore.fileURL])
                }
                .font(.caption)

                Button(language.t("Reveal feedback memory", "显示 feedback 记忆")) {
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
            Text(language.t(
                "Calendar sync is off for now. Ask if you want it re-enabled.",
                "日历同步已停用（按你的要求先不接 Google）。需要时再说一声，我把它接回来。"
            ))
            .font(.caption)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(language.t("Data backup", "数据备份"))
                .font(.headline)
            Text(language.t(
                "Export all job records, reading notes, documents, attachments, and agent memory. API keys and Google credentials are not exported.",
                "导出全部求职记录、阅读笔记、资料文件、附件和 Agent 记忆。不会导出 API Key 或 Google 凭证。"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button {
                    exportAllData()
                } label: {
                    Label(
                        isExporting
                            ? language.t("Exporting…", "正在导出…")
                            : language.t("Export all data…", "导出所有数据…"),
                        systemImage: "square.and.arrow.up"
                    )
                }
                .disabled(isExporting || isImporting)

                Button {
                    chooseImportFolder()
                } label: {
                    Label(
                        isImporting
                            ? language.t("Importing…", "正在导入…")
                            : language.t("Import backup…", "导入备份…"),
                        systemImage: "square.and.arrow.down"
                    )
                }
                .disabled(isExporting || isImporting)
            }

            Text(language.t(
                "Import reads a backup folder from export (data.json + attachments). Everything exportable can be restored.",
                "导入会读取导出生成的备份文件夹（含 data.json 和 attachments）。所有能导出的内容都能导回来。"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            if let exportStatus {
                Text(exportStatus)
                    .font(.caption)
                    .foregroundStyle(
                        exportStatus.hasPrefix("Export failed") || exportStatus.hasPrefix("导出失败") ? .red : .green
                    )
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let importStatus {
                Text(importStatus)
                    .font(.caption)
                    .foregroundStyle(
                        importStatus.hasPrefix("Import failed") || importStatus.hasPrefix("导入失败") ? .red : .green
                    )
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .confirmationDialog(
            language.t("How should this backup be imported?", "怎么导入这份备份？"),
            isPresented: $showImportChoice,
            titleVisibility: .visible
        ) {
            Button(language.t(
                "Merge (update same ids, add new, keep existing)",
                "合并（同 id 更新，新的补上，不删现有）"
            )) {
                runImport(mode: .merge)
            }
            Button(language.t(
                "Replace (wipe current data, then restore backup)",
                "替换（清空现有，全部换成备份）"
            ), role: .destructive) {
                runImport(mode: .replace)
            }
            Button(language.t("Cancel", "取消"), role: .cancel) {
                pendingImportURL = nil
            }
        } message: {
            Text(language.t(
                "Merge is safest — adds and updates only. Replace clears everything first and cannot be undone.",
                "合并最安全，只增不删。替换会先清空当前所有数据，再导入备份，无法撤销。"
            ))
        }
    }

    private func exportAllData() {
        let panel = NSSavePanel()
        panel.title = language.t("Export Interview Tracker data", "导出 Interview Tracker 数据")
        panel.prompt = language.t("Export", "导出")
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.folder]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        panel.nameFieldStringValue = "InterviewTracker-Backup-\(formatter.string(from: Date()))"

        guard panel.runModal() == .OK, let destination = panel.url else { return }
        isExporting = true
        exportStatus = nil
        do {
            try DataExportService.exportAll(from: modelContext, to: destination)
            exportStatus = language.t(
                "Exported to: \(destination.path)",
                "导出成功：\(destination.path)"
            )
            NSWorkspace.shared.activateFileViewerSelecting([destination])
        } catch {
            exportStatus = language.t(
                "Export failed: \(error.localizedDescription)",
                "导出失败：\(error.localizedDescription)"
            )
        }
        isExporting = false
    }

    private func chooseImportFolder() {
        let panel = NSOpenPanel()
        panel.title = language.t("Choose a backup folder", "选择要导入的备份文件夹")
        panel.prompt = language.t("Choose", "选择")
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.folder, .json]

        guard panel.runModal() == .OK, let url = panel.url else { return }
        pendingImportURL = url
        showImportChoice = true
    }

    private func runImport(mode: DataImportService.Mode) {
        guard let source = pendingImportURL else { return }
        pendingImportURL = nil
        isImporting = true
        importStatus = nil
        do {
            let summary = try DataImportService.importAll(from: source, mode: mode, into: modelContext)
            let total = summary.counts.values.reduce(0, +)
            let modeLabel = mode == .merge
                ? language.t("merge", "合并")
                : language.t("replace", "替换")
            var line = language.t(
                "Import OK (\(modeLabel)): \(total) records",
                "导入成功（\(modeLabel)）：共 \(total) 条记录"
            )
            if summary.copiedAttachments > 0 {
                line += language.t(
                    ", \(summary.copiedAttachments) attachments",
                    "，附件 \(summary.copiedAttachments) 个"
                )
            }
            if summary.missingAttachments > 0 {
                line += language.t(
                    ", \(summary.missingAttachments) missing",
                    "，缺失附件 \(summary.missingAttachments) 个"
                )
            }
            importStatus = line
        } catch {
            importStatus = language.t(
                "Import failed: \(error.localizedDescription)",
                "导入失败：\(error.localizedDescription)"
            )
        }
        isImporting = false
    }

    private func testGemini() async {
        geminiStatus = language.t("Testing…", "测试中…")
        let key = geminiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = GeminiKeyStore.save(key)
        do {
            let reply = try await GeminiClient.shared.testConnection(apiKey: key)
            geminiStatus = language.t("Connected: \(reply)", "连接成功：\(reply)")
            geminiSaved = true
        } catch {
            geminiStatus = language.t("Failed: \(error.localizedDescription)", "失败：\(error.localizedDescription)")
            geminiSaved = false
        }
    }

    private func testConnection() async {
        testStatus = language.t("Testing…", "测试中…")
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = APIKeyStore.save(key)
        let startedAt = Date()
        do {
            let reply = try await DeepSeekClient.shared.testConnection(apiKey: key)
            testStatus = language.t("Connected: \(reply)", "连接成功：\(reply)")
            saved = true
            AgentTraceStore.append(
                AgentTraceRecord(
                    startedAt: startedAt,
                    endedAt: Date(),
                    kind: "settings_test",
                    userMessage: "Test API Key",
                    assistantMessage: testStatus
                )
            )
        } catch {
            testStatus = language.t("Failed: \(error.localizedDescription)", "失败：\(error.localizedDescription)")
            saved = false
            AgentTraceStore.append(
                AgentTraceRecord(
                    startedAt: startedAt,
                    endedAt: Date(),
                    kind: "settings_test",
                    userMessage: "Test API Key",
                    assistantMessage: testStatus,
                    error: error.localizedDescription
                )
            )
        }
    }
}
