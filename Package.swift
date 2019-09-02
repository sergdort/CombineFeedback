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
        .package(url: "https://github.com/mluisbrown/Thresher.git", .branch("master")),
    ],
    targets: [
        .target(name: "CombineFeedback"),
        .target(name: "CombineFeedbackUI", dependencies: ["CombineFeedback"]),
        .testTarget(name: "CombineFeedbackTests", dependencies: ["CombineFeedback", "Thresher"]),
        .testTarget(name: "CombineFeedbackUITests", dependencies: ["CombineFeedback", "CombineFeedbackUI"]),
    ],
    swiftLanguageVersions: [.v5]
)
