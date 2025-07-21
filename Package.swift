// swift-tools-version: 5.9
// This Package.swift is for reference when adding AudioKit dependency to Xcode project

import PackageDescription

let package = Package(
    name: "SheetMusicScroller",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SheetMusicScroller",
            targets: ["SheetMusicScroller"]),
    ],
    dependencies: [
        // AudioKit dependencies for real-time pitch detection
        .package(url: "https://github.com/AudioKit/AudioKit.git", from: "5.6.0"),
        .package(url: "https://github.com/AudioKit/AudioKitEX.git", from: "5.6.0"),
    ],
    targets: [
        .target(
            name: "SheetMusicScroller",
            dependencies: [
                .product(name: "AudioKit", package: "AudioKit"),
                .product(name: "AudioKitEX", package: "AudioKitEX"),
            ]
        ),
    ]
)