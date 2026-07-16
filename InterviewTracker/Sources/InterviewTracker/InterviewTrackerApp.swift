import SwiftUI
import SwiftData
import AppKit

@main
struct InterviewTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Company.self,
            Application.self,
            Interview.self,
            TimelineEvent.self,
            StageNode.self,
            MediaAttachment.self,
            ReadingItem.self,
            CareerDocument.self
        ])
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // SPM executables default to accessory/background; force a normal app window.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
