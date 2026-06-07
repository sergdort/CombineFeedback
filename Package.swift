// swift-tools-version:6.1
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
        .target(
            name: "CombineFeedback",
            dependencies: [
                .product(name: "CasePaths", package: "swift-case-paths"),
                .product(name: "CombineSchedulers", package: "combine-schedulers")
            ],
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "CombineFeedbackTests",
            dependencies: ["CombineFeedback"],
            exclude: ["Info.plist"]
        )
    ],
    swiftLanguageModes: [.v6]
)
