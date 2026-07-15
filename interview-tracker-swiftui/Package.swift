// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "InterviewTracker",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "InterviewTracker",
            path: "Sources/InterviewTracker"
        )
    ]
)
