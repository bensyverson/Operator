// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TimeAgent",
    platforms: [
        .macOS(.v15),
    ],
    dependencies: [
        .package(path: "../../"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "TimeAgent",
            dependencies: [
                .product(name: "Operator", package: "Operator"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
    ]
)
