import SwiftUI
import SwiftData

@main
struct InterviewTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Company.self, Application.self, Interview.self])
    }
}
