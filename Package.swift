// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TodoAgent",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TodoAgent",
            path: "Sources/TodoAgent"
        ),
        .testTarget(
            name: "TodoAgentTests",
            dependencies: ["TodoAgent"],
            path: "Tests/TodoAgentTests"
        ),
    ]
)
