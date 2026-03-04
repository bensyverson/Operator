// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Chat",
    platforms: [
        .macOS(.v26),
    ],
    dependencies: [
        .package(path: "../../"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/bensyverson/TextUI", branch: "main"),
    ],
    targets: [
        .target(
            name: "ChatCore",
            dependencies: [
                .product(name: "Operator", package: "Operator"),
            ],
            path: "Sources/ChatCore"
        ),
        .executableTarget(
            name: "Chat",
            dependencies: [
                "ChatCore",
                .product(name: "Operator", package: "Operator"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "TextUI", package: "TextUI"),
            ],
            path: "Sources",
            exclude: ["ChatCore"]
        ),
        .testTarget(
            name: "ChatTests",
            dependencies: [
                "ChatCore",
            ],
            path: "Tests"
        ),
    ]
)
