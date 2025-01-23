// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EvernoteKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "EvernoteKit",
            targets: ["EvernoteKit"]
        ),
        .executable(
            name: "ever",
            targets: ["ever"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "EvernoteKit",
            dependencies: []
        ),
        .executableTarget(
            name: "ever",
            dependencies: [
                "EvernoteKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
    ]
)
