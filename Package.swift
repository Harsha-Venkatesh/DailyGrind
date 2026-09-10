// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "JobGrindWidget",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "JobGrindWidget",
            path: "Sources/JobGrindWidget"
        )
    ]
)
