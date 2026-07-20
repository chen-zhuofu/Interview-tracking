import SwiftUI
import SwiftData
import AppKit

@main
struct InterviewTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var languageStore = LanguageStore()

    /// Open DB with an explicit versioned schema + migration plan.
    let container: ModelContainer = AppModelContainerFactory.make()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(languageStore)
                .environment(\.locale, languageStore.language.locale)
                .id(languageStore.language) // force refresh of static labels on switch
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
