import SwiftUI
import SwiftData

struct CompanyListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Company.createdAt, order: .reverse) private var companies: [Company]

    @State private var showForm = false
    @State private var editingCompany: Company?
    @State private var companyToDelete: Company?

    var body: some View {
        Group {
            if companies.isEmpty {
                ContentUnavailableView("暂无公司", systemImage: "building.2", description: Text("点击上方按钮添加第一家公司"))
            } else {
                List {
                    ForEach(companies) { company in
                        companyRow(company)
                            .contextMenu { companyContextMenu(company) }
                    }
                }
            }
        }
        .navigationTitle("公司管理")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showForm = true }) {
                    Label("添加公司", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showForm) {
            editingCompany = nil
        } content: {
            CompanyFormView(company: nil)
                .frame(minWidth: 400, minHeight: 350)
        }
        .sheet(item: $editingCompany) { company in
            CompanyFormView(company: company)
                .frame(minWidth: 400, minHeight: 350)
        }
        .confirmationDialog("确认删除", isPresented: Binding(
            get: { companyToDelete != nil },
            set: { if !$0 { companyToDelete = nil } }
        )) {
            Button("删除", role: .destructive) {
                if let company = companyToDelete {
                    deleteCompany(company)
                }
            }
            Button("取消", role: .cancel) {
                companyToDelete = nil
            }
        } message: {
            if let company = companyToDelete {
                Text("确定要删除「\(company.name)」吗？关联的所有投递和面试也会被删除。")
            }
        }
    }

    // MARK: - Row

    private func companyRow(_ company: Company) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(company.name)
                .font(.headline)
            HStack(spacing: 12) {
                if let website = company.website, !website.isEmpty {
                    Text(website)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let person = company.contactPerson, !person.isEmpty {
                    Text(person)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                let count = company.applications?.count ?? 0
                Text("\(count) 条投递")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.1), in: Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Context Menu

    private func companyContextMenu(_ company: Company) -> some View {
        Group {
            Button(action: { editingCompany = company }) {
                Label("编辑", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive, action: { companyToDelete = company }) {
                Label("删除", systemImage: "trash")
            }
        }
    }

    // MARK: - Actions

    private func deleteCompany(_ company: Company) {
        modelContext.delete(company)
    }
}
