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
        .testTarget(
            name: "CodexPetUsageCoreTests",
            dependencies: ["CodexPetUsageCore"],
            swiftSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                ]),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/usr/lib",
                ]),
                .linkedFramework("Testing"),
            ]
        ),
    ]
)
