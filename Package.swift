// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Billed",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BilledCore", targets: ["BilledCore"]),
        .executable(name: "Billed", targets: ["BilledApp"]),
    ],
    targets: [
        .target(
            name: "BilledCore",
            path: "Sources/BilledCore",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .executableTarget(
            name: "BilledApp",
            dependencies: ["BilledCore"],
            path: "Sources/BilledApp",
            resources: [
                .process("Resources/Logos")
            ]
        ),
        .testTarget(
            name: "BilledCoreTests",
            dependencies: ["BilledCore"],
            path: "Tests/BilledCoreTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
