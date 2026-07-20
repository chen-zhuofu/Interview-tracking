import SwiftUI
import SwiftData

/// 待办清单：添加「我要做的事」、勾选完成、设 P0–P3 优先级、分「生活 / 职业」两类。
struct TodoListView: View {
    @EnvironmentObject private var language: LanguageStore
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoItem.createdAt, order: .reverse) private var todos: [TodoItem]

    @State private var newTitle = ""
    @State private var newPriority: TodoPriority = .p2
    @State private var newCategory: TodoCategory = .career
    /// nil 表示「全部」。
    @State private var filter: TodoCategory?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                addBar
                filterBar
                listBody
            }
            .padding(28)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "checklist")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
            Text(language.t("Todo list", "待办清单"))
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            if activeCount > 0 {
                Text(language.t("\(activeCount) remaining", "还有 \(activeCount) 件"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
            }
        }
    }

    // MARK: - Add bar

    private var addBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TextField(language.t("Something to do…", "我要做的事…"), text: $newTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppTheme.elevated.opacity(0.7), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .onSubmit(addTodo)

                Button(action: addTodo) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 38, height: 38)
                        .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.hoverCueContained)
                .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                .help(language.t("Add", "添加"))
            }

            HStack(spacing: 14) {
                HStack(spacing: 6) {
                    ForEach(TodoCategory.allCases) { cat in
                        categoryChip(cat, selected: newCategory == cat) { newCategory = cat }
                    }
                }
                Divider().frame(height: 18).opacity(0.4)
                HStack(spacing: 6) {
                    ForEach(TodoPriority.allCases) { p in
                        priorityChip(p, selected: newPriority == p) { newPriority = p }
                    }
                }
                Spacer()
            }
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
    }

    // MARK: - Filter

    private var filterBar: some View {
        HStack(spacing: 8) {
            filterChip(title: language.t("All", "全部"), active: filter == nil) { filter = nil }
            ForEach(TodoCategory.allCases) { cat in
                filterChip(title: cat.label, active: filter == cat) { filter = cat }
            }
            Spacer()
        }
    }

    // MARK: - List

    @ViewBuilder
    private var listBody: some View {
        let active = visibleTodos.filter { !$0.isDone }
        let done = visibleTodos.filter { $0.isDone }

        if visibleTodos.isEmpty {
            Text(language.t(
                "No todos yet. Add something to do above.",
                "还没有待办。上面加一条「我要做的事」。"
            ))
                .font(.callout)
                .foregroundStyle(AppTheme.muted)
                .padding(.top, 8)
        } else {
            VStack(spacing: 10) {
                ForEach(active) { todo in
                    todoRow(todo)
                }
            }
            if !done.isEmpty {
                Text(language.t("Done \(done.count)", "已完成 \(done.count)"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
                    .padding(.top, 10)
                VStack(spacing: 10) {
                    ForEach(done) { todo in
                        todoRow(todo)
                    }
                }
            }
        }
    }

    private func todoRow(_ todo: TodoItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                toggle(todo)
            } label: {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(todo.isDone ? AppTheme.green : AppTheme.muted)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.hoverCue)

            priorityMenu(todo)

            Text(todo.title)
                .font(.system(size: 14))
                .foregroundStyle(todo.isDone ? AppTheme.muted : AppTheme.textPrimary)
                .strikethrough(todo.isDone, color: AppTheme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)

            categoryTag(todo.categoryValue)

            Button {
                delete(todo)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.muted)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.hoverCue)
            .help(language.t("Delete", "删除"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.card.opacity(todo.isDone ? 0.5 : 1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
    }

    // MARK: - Small pieces

    private func priorityMenu(_ todo: TodoItem) -> some View {
        Menu {
            ForEach(TodoPriority.allCases) { p in
                Button {
                    setPriority(todo, p)
                } label: {
                    Label(p.label, systemImage: todo.priorityValue == p ? "checkmark" : "")
                }
            }
        } label: {
            priorityBadge(todo.priorityValue)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(language.t("Change priority", "改优先级"))
    }

    private func priorityBadge(_ p: TodoPriority) -> some View {
        Text(p.label)
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundStyle(p.color)
            .frame(width: 30, height: 22)
            .background(p.color.opacity(0.16), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(p.color.opacity(0.5), lineWidth: 1)
            )
    }

    private func categoryTag(_ c: TodoCategory) -> some View {
        HStack(spacing: 4) {
            Image(systemName: c.icon)
                .font(.system(size: 9, weight: .semibold))
            Text(c.label)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(c.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(c.color.opacity(0.14), in: Capsule())
    }

    private func categoryChip(_ c: TodoCategory, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: c.icon).font(.system(size: 10, weight: .semibold))
                Text(c.label).font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(selected ? .black : c.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(selected ? c.color : c.color.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.hoverCue)
    }

    private func priorityChip(_ p: TodoPriority, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(p.label)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(selected ? .black : p.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(selected ? p.color : p.color.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.hoverCue)
    }

    private func filterChip(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(active ? .black : AppTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(active ? AppTheme.accent : AppTheme.elevated.opacity(0.7), in: Capsule())
        }
        .buttonStyle(.hoverCue)
    }

    // MARK: - Data

    private var visibleTodos: [TodoItem] {
        let filtered = filter == nil ? todos : todos.filter { $0.categoryValue == filter }
        return filtered.sorted { a, b in
            if a.isDone != b.isDone { return !a.isDone }          // 未完成在前
            if a.isDone {                                          // 都完成：新完成的在前
                return (a.doneAt ?? a.updatedAt) > (b.doneAt ?? b.updatedAt)
            }
            if a.priorityValue.rank != b.priorityValue.rank {      // 未完成：按优先级
                return a.priorityValue.rank < b.priorityValue.rank
            }
            return a.createdAt < b.createdAt
        }
    }

    private var activeCount: Int {
        visibleTodos.filter { !$0.isDone }.count
    }

    private func addTodo() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let item = TodoItem(title: title, priority: newPriority, category: newCategory)
        modelContext.insert(item)
        try? modelContext.save()
        AutoBackupService.snapshotThrottled(context: modelContext)
        newTitle = ""
    }

    private func toggle(_ todo: TodoItem) {
        todo.isDone.toggle()
        todo.doneAt = todo.isDone ? Date() : nil
        todo.updatedAt = Date()
        try? modelContext.save()
    }

    private func setPriority(_ todo: TodoItem, _ p: TodoPriority) {
        todo.priority = p.rawValue
        todo.updatedAt = Date()
        try? modelContext.save()
    }

    private func delete(_ todo: TodoItem) {
        modelContext.delete(todo)
        try? modelContext.save()
        AutoBackupService.snapshotThrottled(context: modelContext)
    }
}
