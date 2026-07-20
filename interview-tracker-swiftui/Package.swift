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
            exclude: [
                // Legacy list/form UIs (superseded by agent + dashboard); they still reference removed fields.
                "Views/Applications",
                "Views/Interviews",
                "Views/Kanban",
                "Views/Companies/CompanyListView.swift",
                "Views/Companies/CompanyFormView.swift"
            ],
            resources: [
                .copy("Resources/Langbridge_Graph.svg"),
                .copy("Resources/DeepSpace.png")
            ]
        ),
        .testTarget(
            name: "InterviewTrackerLogicTests",
            dependencies: ["InterviewTrackerLogic"],
            path: "Tests/InterviewTrackerLogicTests"
        )
    ]
)
