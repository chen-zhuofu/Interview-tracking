// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "InterviewTracker",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "InterviewTracker", targets: ["InterviewTracker"]),
        .library(name: "InterviewTrackerLogic", targets: ["InterviewTrackerLogic"])
    ],
    targets: [
        .target(
            name: "InterviewTrackerLogic",
            path: "Sources/InterviewTrackerLogic"
        ),
        .executableTarget(
            name: "InterviewTracker",
            dependencies: ["InterviewTrackerLogic"],
            path: "Sources/InterviewTracker",
            resources: [
                .copy("Resources/Langbridge_Graph.svg")
            ]
        ),
        .testTarget(
            name: "InterviewTrackerLogicTests",
            dependencies: ["InterviewTrackerLogic"],
            path: "Tests/InterviewTrackerLogicTests"
        )
    ]
)
