import SwiftUI
import SwiftData
import AppKit

@main
struct InterviewTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// 用显式版本化 Schema + 迁移计划打开数据库，防止 SwiftData 自作主张静默清空。
    let container: ModelContainer = AppModelContainerFactory.make()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
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
