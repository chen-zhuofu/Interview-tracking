import SwiftUI
import SwiftData

struct ApplicationFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Company.name) private var companies: [Company]

    var application: Application?

    @State private var selectedCompany: Company?
    @State private var position: String = ""
    @State private var appliedDate: Date = Date()
    @State private var jobDescriptionURL: String = ""
    @State private var notes: String = ""
    @State private var showPositionError = false

    private var isEditing: Bool { application != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(isEditing ? "编辑投递" : "添加投递")
                .font(.title2.bold())
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("公司 *").font(.headline)
                        Picker("选择公司", selection: $selectedCompany) {
                            Text("选择公司…").tag(nil as Company?)
                            ForEach(companies) { company in
                                Text(company.name).tag(company as Company?)
                            }
                        }
                        .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("职位 *").font(.headline)
                        TextField("职位名称", text: $position)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: position) { _, _ in showPositionError = false }
                        if showPositionError {
                            Text("职位不能为空").font(.caption).foregroundStyle(.red)
                        }
                    }

                    DatePicker("投递日期", selection: $appliedDate, displayedComponents: .date)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("职位链接").font(.headline)
                        TextField("https://...", text: $jobDescriptionURL)
                            .textFieldStyle(.roundedBorder)
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
        guard let application else { return }
        selectedCompany = application.company
        position = application.position
        appliedDate = application.appliedDate ?? Date()
        jobDescriptionURL = application.jobDescriptionURL ?? ""
        notes = application.notes ?? ""
    }

    private func save() {
        let trimmed = position.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showPositionError = true
            return
        }

        if let application {
            application.company = selectedCompany
            application.position = trimmed
            application.appliedDate = appliedDate
            application.jobDescriptionURL = jobDescriptionURL.isEmpty ? nil : jobDescriptionURL.trimmingCharacters(in: .whitespacesAndNewlines)
            application.notes = notes.isEmpty ? nil : notes
            application.lastUpdated = Date()
        } else {
            let newApp = Application(
                position: trimmed,
                company: selectedCompany,
                jobDescriptionURL: jobDescriptionURL.isEmpty ? nil : jobDescriptionURL.trimmingCharacters(in: .whitespacesAndNewlines),
                status: "applied",
                appliedDate: appliedDate,
                notes: notes.isEmpty ? nil : notes
            )
            modelContext.insert(newApp)
        }

        dismiss()
    }
}
