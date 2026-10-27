// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PocketTalkCore",
    platforms: [
        .iOS("27.0"),
        .macOS("27.0"),
    ],
    products: [
        .library(name: "PocketTalkCore", targets: ["PocketTalkCore"]),
    ],
    targets: [
        .target(name: "PocketTalkCore"),
        .testTarget(
            name: "PocketTalkCoreTests",
            dependencies: ["PocketTalkCore"]
        ),
        .executableTarget(
            name: "EvalRunner",
            dependencies: ["PocketTalkCore"]
        ),
    ]
)
