import Foundation

enum AppResourceBundle {
    static let bundle: Bundle = {
        let bundleName = "InterviewTracker_InterviewTracker.bundle"
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent(bundleName),
            Bundle.main.bundleURL.appendingPathComponent(bundleName)
        ]

        for candidate in candidates {
            if let candidate, let bundle = Bundle(url: candidate) {
                return bundle
            }
        }

        return Bundle.module
    }()
}
