// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "CombineFeedbackk",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)
    ],
    products: [
        .library(name: "CombineFeedback", targets: ["CombineFeedback"]),
        .library(name: "CombineFeedbackUI", targets: ["CombineFeedbackUI"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(name: "CombineFeedback"),
        .target(name: "CombineFeedbackUI", dependencies: ["CombineFeedback"]),
        .testTarget(name: "CombineFeedbackTests", dependencies: ["CombineFeedback"]),
        .testTarget(name: "CombineFeedbackUITests", dependencies: ["CombineFeedback", "CombineFeedbackUI"]),
    ],
    swiftLanguageVersions: [.v5]
)
