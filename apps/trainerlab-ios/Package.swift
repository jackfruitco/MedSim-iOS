// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TrainerLabiOS",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v26),
        .macOS(.v14),
    ],
    products: [
        .library(name: "Auth", targets: ["Auth"]),
        .library(name: "Sessions", targets: ["Sessions"]),
        .library(name: "Presets", targets: ["Presets"]),
        .library(name: "RunConsole", targets: ["RunConsole"]),
        .library(name: "Summary", targets: ["Summary"]),
        .library(name: "Networking", targets: ["Networking"]),
        .library(name: "Realtime", targets: ["Realtime"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "SharedModels", targets: ["SharedModels"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "SharedModels"
        ),
        .target(
            name: "DesignSystem",
            dependencies: []
        ),
        .target(
            name: "Persistence",
            dependencies: [
                "SharedModels",
                .product(name: "GRDB", package: "grdb.swift"),
            ]
        ),
        .target(
            name: "Networking",
            dependencies: [
                "SharedModels",
                "Persistence",
            ]
        ),
        .target(
            name: "Realtime",
            dependencies: [
                "SharedModels",
                "Networking",
                "Persistence",
            ]
        ),
        .target(
            name: "Auth",
            dependencies: [
                "Networking",
                "Persistence",
                "DesignSystem",
            ]
        ),
        .target(
            name: "Sessions",
            dependencies: [
                "SharedModels",
                "Networking",
                "Realtime",
                "Persistence",
                "DesignSystem",
            ]
        ),
        .target(
            name: "Presets",
            dependencies: [
                "SharedModels",
                "Networking",
                "DesignSystem",
            ]
        ),
        .target(
            name: "RunConsole",
            dependencies: [
                "SharedModels",
                "Sessions",
                "DesignSystem",
            ]
        ),
        .target(
            name: "Summary",
            dependencies: [
                "SharedModels",
                "Networking",
                "DesignSystem",
            ]
        ),
        .testTarget(
            name: "SessionsTests",
            dependencies: ["Sessions", "SharedModels", "Networking", "Realtime", "Persistence"]
        ),
        .testTarget(
            name: "NetworkingTests",
            dependencies: ["Networking", "SharedModels", "Persistence"]
        ),
        .testTarget(
            name: "RealtimeTests",
            dependencies: ["Realtime", "SharedModels"]
        ),
        .testTarget(
            name: "RunConsoleTests",
            dependencies: ["RunConsole", "SharedModels"]
        ),
        .testTarget(
            name: "PresetsTests",
            dependencies: ["Presets", "SharedModels"]
        ),
        .testTarget(
            name: "SummaryTests",
            dependencies: ["Summary", "Networking", "SharedModels"]
        ),
        .testTarget(
            name: "AuthTests",
            dependencies: ["Auth", "Networking", "SharedModels", "Persistence"]
        ),
    ]
)
