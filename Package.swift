// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "uHosts",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "uHosts",
            path: "Sources/uHosts"
        )
    ]
)
