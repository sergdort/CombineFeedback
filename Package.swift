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
        .library(name: "CombineFeedbackTest", targets: ["CombineFeedbackTest"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-case-paths.git",
            from: Version(1, 0, 0)
        ),
        .package(
          url: "https://github.com/pointfreeco/combine-schedulers.git",
          from: Version(1, 0, 0)
        ),
        .package(
          url: "https://github.com/pointfreeco/swift-custom-dump.git",
          from: Version(1, 0, 0)
        ),
        .package(
          // Same repo as swift-issue-reporting (renamed); the rest of the graph
          // references it by this old URL, so match it to avoid a duplicate
          // package providing the IssueReporting / XCTestDynamicOverlay targets.
          url: "https://github.com/pointfreeco/xctest-dynamic-overlay",
          from: Version(1, 0, 0)
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
        .target(
            name: "CombineFeedbackTest",
            dependencies: [
                "CombineFeedback",
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
            ]
        ),
        .testTarget(
            name: "CombineFeedbackTests",
            dependencies: ["CombineFeedback", "CombineFeedbackTest"],
            exclude: ["Info.plist"]
        )
    ],
    swiftLanguageModes: [.v6]
)
