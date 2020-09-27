// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FeatureConfig-LaunchDarkly", // Named using a dash instead of underscore because Xcode warns against underscores.
    platforms: [
        .macOS(.v11),
        .iOS(.v14),
    ],
    products: [
        .library(name: "FeatureConfig-LaunchDarkly", targets: ["FeatureConfig-LaunchDarkly"]),
    ],
    dependencies: [
        .package(name: "FeatureConfig", url: "https://github.com/rogerluan/FeatureConfig", .branch("main")),
        .package(name: "LaunchDarkly", url: "https://github.com/launchdarkly/ios-client-sdk", .upToNextMajor(from: "5.4.1")),
        .package(name: "CwlPreconditionTesting", url: "https://github.com/mattgallagher/CwlPreconditionTesting", .upToNextMajor(from: "2.1.0")),
    ],
    targets: [
        .target(
            name: "FeatureConfig-LaunchDarkly",
            dependencies: ["FeatureConfig", "LaunchDarkly"],
            path: "Sources"
        ),
        .testTarget(
            name: "FeatureConfig-LaunchDarklyTests",
            dependencies: ["FeatureConfig-LaunchDarkly", "CwlPreconditionTesting"],
            path: "Tests"
        ),
    ]
)
