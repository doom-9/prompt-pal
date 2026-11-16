// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PromptPal",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "PromptPalCore", targets: ["PromptPalCore"]),
        .executable(name: "PromptPal", targets: ["PromptPal"])
    ],
    targets: [
        .target(
            name: "PromptPalCore",
            path: "Sources/PromptPalCore"
        ),
        .executableTarget(
            name: "PromptPal",
            dependencies: ["PromptPalCore"],
            path: "Sources/PromptPal"
        ),
        .testTarget(
            name: "PromptPalTests",
            dependencies: ["PromptPalCore"],
            path: "Tests/PromptPalTests"
        )
    ]
)
