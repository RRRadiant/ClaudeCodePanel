// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClaudeCodePanel",
    platforms: [.macOS("26")],
    targets: [
        .executableTarget(
            name: "ClaudeCodePanel",
            path: "ClaudeCodePanel",
            resources: []
        ),
        .testTarget(
            name: "ClaudeCodePanelTests",
            dependencies: ["ClaudeCodePanel"],
            path: "Tests"
        ),
    ]
)
