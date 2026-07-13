// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexPetUsageMacOS",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CodexPetUsageCore", targets: ["CodexPetUsageCore"]),
        .executable(name: "CodexPetUsage", targets: ["CodexPetUsageApp"]),
    ],
    targets: [
        .target(
            name: "CodexPetUsageCore",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .executableTarget(
            name: "CodexPetUsageApp",
            dependencies: ["CodexPetUsageCore"]
        ),
        .executableTarget(
            name: "CodexPetUsageTests",
            dependencies: ["CodexPetUsageCore"],
            path: "Tests/CodexPetUsageTests"
        ),
    ]
)
