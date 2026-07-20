import Foundation
import SwiftUI
import Combine

enum AppRoute: Hashable {
    case overview
    case company(UUID)
    case reading
    case readingItem(UUID)
    case documents
    case journal
    case todos
}

@MainActor
final class NavigationStore: ObservableObject {
    @Published private(set) var stack: [AppRoute] = [.overview]
    @Published private(set) var index: Int = 0
    /// Right-side calendar drawer (not a full page).
    @Published var isCalendarPanelOpen = false

    var current: AppRoute {
        guard stack.indices.contains(index) else { return .overview }
        return stack[index]
    }

    var canGoBack: Bool { index > 0 }
    var canGoForward: Bool { index < stack.count - 1 }

    func navigate(to route: AppRoute) {
        if current == route { return }
        if index < stack.count - 1 {
            stack = Array(stack.prefix(index + 1))
        }
        stack.append(route)
        index = stack.count - 1
    }

    func openCompany(_ id: UUID) {
        isCalendarPanelOpen = false
        navigate(to: .company(id))
    }

    func openReading() {
        isCalendarPanelOpen = false
        navigate(to: .reading)
    }

    func openReadingItem(_ id: UUID) {
        isCalendarPanelOpen = false
        navigate(to: .readingItem(id))
    }

    func openDocuments() {
        isCalendarPanelOpen = false
        navigate(to: .documents)
    }

    func openJournal() {
        isCalendarPanelOpen = false
        navigate(to: .journal)
    }

    func openTodos() {
        isCalendarPanelOpen = false
        navigate(to: .todos)
    }

    func openCalendar() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            isCalendarPanelOpen = true
        }
    }

    func closeCalendar() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            isCalendarPanelOpen = false
        }
    }

    func back() {
        guard canGoBack else { return }
        index -= 1
    }

    func forward() {
        guard canGoForward else { return }
        index += 1
    }

    func goOverview() {
        isCalendarPanelOpen = false
        if case .overview = current { return }
        if let overviewIndex = stack.lastIndex(of: .overview) {
            index = overviewIndex
        } else {
            navigate(to: .overview)
        }
    }
}
