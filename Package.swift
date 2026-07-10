// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "WindowAnchor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "WindowAnchor",
            path: "Sources/WindowAnchor"
        ),
        .testTarget(
            name: "WindowAnchorTests",
            dependencies: ["WindowAnchor"],
            path: "Tests/WindowAnchorTests"
        ),
    ]
)
