// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Operator",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "Operator",
            targets: ["Operator"]
        ),
    ],
    dependencies: [
        .package(url: "git@git.mattebox.com:ben/LLM.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Operator",
            dependencies: [
                .product(name: "LLM", package: "LLM"),
            ]
        ),
        .testTarget(
            name: "OperatorTests",
            dependencies: [
                "Operator",
                .product(name: "LLM", package: "LLM"),
            ]
        ),
    ]
)
