// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "cairn",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ProfileKit", targets: ["ProfileKit"]),
        .executable(name: "cairn", targets: ["cairn"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.24.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
    ],
    targets: [
        // Models, block vocabulary, plugin protocol, theme. Foundation only —
        // this is the product third-party plugin authors depend on.
        .target(name: "ProfileKit"),
        .target(name: "Collect", dependencies: [
            "ProfileKit",
            .product(name: "AsyncHTTPClient", package: "async-http-client"),
            .product(name: "Logging", package: "swift-log"),
        ]),
        .target(name: "Render", dependencies: [
            "ProfileKit",
            .product(name: "Yams", package: "Yams"),
        ]),
        .target(name: "Plugins", dependencies: [
            "ProfileKit", "Collect", "Render",
            .product(name: "Logging", package: "swift-log"),
        ]),
        .executableTarget(name: "cairn", dependencies: [
            "ProfileKit", "Collect", "Render", "Plugins",
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
            .product(name: "Yams", package: "Yams"),
            .product(name: "Logging", package: "swift-log"),
        ]),
        .testTarget(name: "ProfileKitTests", dependencies: ["ProfileKit"]),
        .testTarget(name: "CollectTests", dependencies: ["Collect"]),
        .testTarget(name: "RenderTests", dependencies: ["Render", "Plugins"]),
        .testTarget(name: "PluginTests", dependencies: ["Plugins"]),
    ]
)
