import SwiftUI
import SwiftData

struct CompanyFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var company: Company?

    @State private var name: String = ""
    @State private var website: String = ""
    @State private var contactPerson: String = ""
    @State private var contactEmail: String = ""
    @State private var notes: String = ""
    @State private var showNameError = false

    private var isEditing: Bool { company != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text(isEditing ? "编辑公司" : "添加公司")
                .font(.title2.bold())
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 8)

            Divider()

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("名称 *").font(.headline)
                        TextField("公司名称", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: name) { _, _ in showNameError = false }
                        if showNameError {
                            Text("名称不能为空").font(.caption).foregroundStyle(.red)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("官网").font(.headline)
                        TextField("https://example.com", text: $website)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("联系人").font(.headline)
                            TextField("姓名", text: $contactPerson)
                                .textFieldStyle(.roundedBorder)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("联系邮箱").font(.headline)
                            TextField("email@company.com", text: $contactEmail)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("备注").font(.headline)
                        TextEditor(text: $notes)
                            .font(.body)
                            .frame(minHeight: 100)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary, lineWidth: 1))
                    }
                }
                .padding()
            }

            Divider()

            // Footer buttons
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

    // MARK: -

    private func populateFields() {
        guard let company else { return }
        name = company.name
        website = company.website ?? ""
        contactPerson = company.contactPerson ?? ""
        contactEmail = company.contactEmail ?? ""
        notes = company.notes ?? ""
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showNameError = true
            return
        }

        if let company {
            // Edit mode: update existing
            company.name = trimmed
            company.website = website.isEmpty ? nil : website.trimmingCharacters(in: .whitespacesAndNewlines)
            company.contactPerson = contactPerson.isEmpty ? nil : contactPerson.trimmingCharacters(in: .whitespacesAndNewlines)
            company.contactEmail = contactEmail.isEmpty ? nil : contactEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            company.notes = notes.isEmpty ? nil : notes
        } else {
            // Add mode: insert new
            let newCompany = Company(
                name: trimmed,
                website: website.isEmpty ? nil : website.trimmingCharacters(in: .whitespacesAndNewlines),
                contactPerson: contactPerson.isEmpty ? nil : contactPerson.trimmingCharacters(in: .whitespacesAndNewlines),
                contactEmail: contactEmail.isEmpty ? nil : contactEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.isEmpty ? nil : notes
            )
            modelContext.insert(newCompany)
        }

        dismiss()
    }
}
