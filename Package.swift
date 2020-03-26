// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "CombineFeedback",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(name: "CombineFeedback", targets: ["CombineFeedback"]),
        .library(name: "CombineFeedbackUI", targets: ["CombineFeedbackUI"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-case-paths.git",
            from: Version(0, 1, 0)
        )
    ],
    targets: [
        .target(name: "CombineFeedback", dependencies: ["CasePaths"]),
        .target(name: "CombineFeedbackUI", dependencies: ["CombineFeedback"]),
        .testTarget(name: "CombineFeedbackTests", dependencies: ["CombineFeedback"]),
        .testTarget(name: "CombineFeedbackUITests", dependencies: ["CombineFeedback", "CombineFeedbackUI"]),
    ],
    swiftLanguageVersions: [.v5]
)
