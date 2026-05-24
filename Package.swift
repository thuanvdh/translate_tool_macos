// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ToolTranslate",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ToolTranslate", targets: ["ToolTranslate"])
    ],
    targets: [
        .executableTarget(
            name: "ToolTranslate",
            path: "Sources/ToolTranslate"
        ),
        .testTarget(
            name: "ToolTranslateTests",
            dependencies: ["ToolTranslate"],
            path: "Tests/ToolTranslateTests"
        )
    ]
)
