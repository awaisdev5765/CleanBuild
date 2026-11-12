// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CleanBuildCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "CleanBuildCore", targets: ["CleanBuildCore"])],
    targets: [
        .target(name: "CleanBuildCore", path: "CleanBuild", exclude: ["App", "Features", "DesignSystem", "Resources"]),
        .testTarget(name: "CleanBuildCoreTests", dependencies: ["CleanBuildCore"], path: "Tests/Core")
    ]
)

