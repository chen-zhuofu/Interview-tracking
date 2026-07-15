import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .kanban

    enum Tab: String, CaseIterable, Identifiable {
        case dashboard = "仪表盘"
        case kanban = "看板视图"
        case applications = "投递管理"
        case companies = "公司管理"
        case calendar = "面试日历"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .dashboard: return "chart.bar"
            case .kanban: return "rectangle.split.3x1"
            case .applications: return "doc.text"
            case .companies: return "building.2"
            case .calendar: return "calendar"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(Tab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .navigationTitle("面试管理")
            .listStyle(.sidebar)
        } detail: {
            switch selectedTab {
            case .dashboard:
                Text("仪表盘")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            case .kanban:
                Text("看板视图")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            case .applications:
                Text("投递管理")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            case .companies:
                Text("公司管理")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            case .calendar:
                Text("面试日历")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
