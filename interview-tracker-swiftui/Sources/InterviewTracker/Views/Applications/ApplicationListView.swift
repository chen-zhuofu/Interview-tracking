import SwiftUI
import SwiftData

struct ApplicationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Application.lastUpdated, order: .reverse) private var applications: [Application]

    @State private var showForm = false
    @State private var editingApplication: Application?
    @State private var appToDelete: Application?
    @State private var filterStage: String = "all"

    private var filteredApplications: [Application] {
        if filterStage == "all" { return applications }
        return applications.filter { $0.status == filterStage }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Stage filter picker
            Picker("阶段", selection: $filterStage) {
                Text("全部").tag("all")
                ForEach(STAGE_ORDER, id: \.self) { stage in
                    Text(STAGE_LABELS[stage] ?? stage).tag(stage)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if filteredApplications.isEmpty {
                ContentUnavailableView("暂无投递记录", systemImage: "doc.text", description: Text("点击上方按钮添加第一条投递"))
            } else {
                List {
                    ForEach(filteredApplications) { app in
                        applicationRow(app)
                            .contextMenu { applicationContextMenu(app) }
                    }
                }
            }
        }
        .navigationTitle("投递管理")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showForm = true }) {
                    Label("添加投递", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: { CSVExporter.exportApplications(applications) }) {
                    Label("导出 CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(applications.isEmpty)
            }
        }
        .sheet(isPresented: $showForm) {
            editingApplication = nil
        } content: {
            ApplicationFormView(application: nil)
                .frame(minWidth: 450, minHeight: 400)
        }
        .sheet(item: $editingApplication) { app in
            ApplicationFormView(application: app)
                .frame(minWidth: 450, minHeight: 400)
        }
        .confirmationDialog("确认删除", isPresented: Binding(
            get: { appToDelete != nil },
            set: { if !$0 { appToDelete = nil } }
        )) {
            Button("删除", role: .destructive) {
                if let app = appToDelete { deleteApplication(app) }
            }
            Button("取消", role: .cancel) { appToDelete = nil }
        } message: {
            if let app = appToDelete {
                Text("确定要删除「\(app.position)」的投递记录吗？关联的面试也会被删除。")
            }
        }
    }

    // MARK: - Row

    private func applicationRow(_ app: Application) -> some View {
        HStack(spacing: 12) {
            // Stage badge
            Text(STAGE_LABELS[app.status] ?? app.status)
                .font(.caption.weight(.medium))
                .foregroundStyle(stageColor(app.status))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(stageColor(app.status).opacity(0.12), in: Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text(app.position)
                    .font(.headline)
                Text(app.company?.name ?? "未知公司")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Stage move buttons
            HStack(spacing: 4) {
                Button(action: { moveStage(app, direction: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(.borderless)
                .disabled(isFirstStage(app.status))

                Button(action: { moveStage(app, direction: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(.borderless)
                .disabled(isLastStage(app.status))
            }

            if let date = app.appliedDate {
                Text(date.formatted(date: .numeric, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Context Menu

    private func applicationContextMenu(_ app: Application) -> some View {
        Group {
            Button(action: { editingApplication = app }) {
                Label("编辑", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive, action: { appToDelete = app }) {
                Label("删除", systemImage: "trash")
            }
        }
    }

    // MARK: - Stage helpers

    private func moveStage(_ app: Application, direction: Int) {
        guard let idx = STAGE_ORDER.firstIndex(of: app.status) else { return }
        let newIdx = idx + direction
        guard STAGE_ORDER.indices.contains(newIdx) else { return }
        app.status = STAGE_ORDER[newIdx]
        app.lastUpdated = Date()
    }

    private func isFirstStage(_ stage: String) -> Bool {
        STAGE_ORDER.first == stage
    }

    private func isLastStage(_ stage: String) -> Bool {
        STAGE_ORDER.last == stage
    }

    private func stageColor(_ stage: String) -> Color {
        switch stage {
        case "applied": return .gray
        case "resume_screening": return .blue
        case "first_interview": return .indigo
        case "second_interview": return .purple
        case "third_interview": return .purple
        case "hr_interview": return .orange
        case "offer": return .green
        case "accepted": return .mint
        case "rejected": return .red
        default: return .gray
        }
    }

    // MARK: - Actions

    private func deleteApplication(_ app: Application) {
        modelContext.delete(app)
    }
}
