import SwiftUI
import SwiftData

struct InterviewFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Application.position) private var applications: [Application]

    var interview: Interview?

    @State private var selectedApplication: Application?
    @State private var interviewType: String = "phone"
    @State private var interviewDate: Date = Date()
    @State private var interviewer: String = ""
    @State private var result: String = "pending"
    @State private var notes: String = ""

    private var isEditing: Bool { interview != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(isEditing ? "编辑面试" : "添加面试")
                .font(.title2.bold())
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("关联投递").font(.headline)
                        Picker("选择投递", selection: $selectedApplication) {
                            Text("选择投递…").tag(nil as Application?)
                            ForEach(applications) { app in
                                Text("\(app.company?.name ?? "?") — \(app.position)").tag(app as Application?)
                            }
                        }
                        .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("面试类型").font(.headline)
                        Picker("类型", selection: $interviewType) {
                            Text("电话面").tag("phone")
                            Text("视频面").tag("video")
                            Text("现场面").tag("onsite")
                        }
                        .pickerStyle(.segmented)
                    }

                    DatePicker("面试时间", selection: $interviewDate)

                    TextField("面试官", text: $interviewer)
                        .textFieldStyle(.roundedBorder)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("面试结果").font(.headline)
                        Picker("结果", selection: $result) {
                            Text("待定").tag("pending")
                            Text("通过").tag("passed")
                            Text("未通过").tag("failed")
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("备注").font(.headline)
                        TextEditor(text: $notes)
                            .font(.body)
                            .frame(minHeight: 80)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary, lineWidth: 1))
                    }
                }
                .padding()
            }

            Divider()

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("保存") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .onAppear { populateFields() }
    }

    private func populateFields() {
        guard let interview else { return }
        selectedApplication = interview.application
        interviewType = interview.interviewType
        interviewDate = interview.interviewDate ?? Date()
        interviewer = interview.interviewer ?? ""
        result = interview.result ?? "pending"
        notes = interview.notes ?? ""
    }

    private func save() {
        if let interview {
            interview.application = selectedApplication
            interview.interviewType = interviewType
            interview.interviewDate = interviewDate
            interview.interviewer = interviewer.isEmpty ? nil : interviewer.trimmingCharacters(in: .whitespacesAndNewlines)
            interview.result = result
            interview.notes = notes.isEmpty ? nil : notes
        } else {
            let newInterview = Interview(
                interviewType: interviewType,
                application: selectedApplication,
                interviewDate: interviewDate,
                interviewer: interviewer.isEmpty ? nil : interviewer.trimmingCharacters(in: .whitespacesAndNewlines),
                result: result,
                notes: notes.isEmpty ? nil : notes
            )
            modelContext.insert(newInterview)
        }

        dismiss()
    }
}
