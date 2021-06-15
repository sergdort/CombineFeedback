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
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-case-paths.git",
            from: Version(0, 2, 0)
        ),
        .package(
          url: "https://github.com/pointfreeco/combine-schedulers.git",
          from: Version(0, 5, 0)
        )
    ],
    targets: [
        .target(name: "CombineFeedback", dependencies: ["CasePaths", "CombineSchedulers"]),
        .testTarget(name: "CombineFeedbackTests", dependencies: ["CombineFeedback"])
    ],
    swiftLanguageVersions: [.v5]
)
