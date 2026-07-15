import SwiftUI
import SwiftData

struct InterviewListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Interview.interviewDate, order: .reverse) private var interviews: [Interview]

    @State private var showForm = false
    @State private var editingInterview: Interview?
    @State private var interviewToDelete: Interview?

    var body: some View {
        Group {
            if interviews.isEmpty {
                ContentUnavailableView("暂无面试记录", systemImage: "calendar.badge.clock", description: Text("点击上方按钮添加面试"))
            } else {
                List {
                    ForEach(interviews) { interview in
                        interviewRow(interview)
                            .contextMenu { interviewContextMenu(interview) }
                    }
                }
            }
        }
        .navigationTitle("面试管理")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showForm = true }) {
                    Label("添加面试", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showForm) {
            editingInterview = nil
        } content: {
            InterviewFormView(interview: nil)
                .frame(minWidth: 450, minHeight: 400)
        }
        .sheet(item: $editingInterview) { interview in
            InterviewFormView(interview: interview)
                .frame(minWidth: 450, minHeight: 400)
        }
        .confirmationDialog("确认删除", isPresented: Binding(
            get: { interviewToDelete != nil },
            set: { if !$0 { interviewToDelete = nil } }
        )) {
            Button("删除", role: .destructive) {
                if let interview = interviewToDelete { modelContext.delete(interview) }
            }
            Button("取消", role: .cancel) { interviewToDelete = nil }
        } message: {
            Text("确定要删除这条面试记录吗？")
        }
    }

    // MARK: - Row

    private func interviewRow(_ interview: Interview) -> some View {
        HStack(spacing: 12) {
            // Type badge
            Text(INTERVIEW_TYPE_LABELS[interview.interviewType] ?? interview.interviewType)
                .font(.caption.weight(.medium))
                .foregroundStyle(typeColor(interview.interviewType))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(typeColor(interview.interviewType).opacity(0.12), in: Capsule())

            VStack(alignment: .leading, spacing: 2) {
                if let app = interview.application {
                    Text(app.position)
                        .font(.headline)
                    Text(app.company?.name ?? "未知公司")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Result badge
            if let result = interview.result {
                Text(RESULT_LABELS[result] ?? result)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(resultColor(result))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(resultColor(result).opacity(0.12), in: Capsule())
            }

            VStack(alignment: .trailing, spacing: 2) {
                if let date = interview.interviewDate {
                    Text(date.formatted(date: .numeric, time: .shortened))
                        .font(.caption)
                }
                if let interviewer = interview.interviewer, !interviewer.isEmpty {
                    Text(interviewer)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Context Menu

    private func interviewContextMenu(_ interview: Interview) -> some View {
        Group {
            Button(action: { editingInterview = interview }) {
                Label("编辑", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive, action: { interviewToDelete = interview }) {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private func typeColor(_ type: String) -> Color {
        switch type {
        case "phone": return .blue
        case "video": return .purple
        case "onsite": return .orange
        default: return .gray
        }
    }

    private func resultColor(_ result: String) -> Color {
        switch result {
        case "passed": return .green
        case "failed": return .red
        default: return .gray
        }
    }
}
