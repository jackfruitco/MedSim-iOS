// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MedSimShelliOS",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v26),
        .macOS(.v14),
    ],
    products: [
        .library(name: "AppShell", targets: ["AppShell"]),
    ],
    dependencies: [
        .package(path: "../trainerlab-ios"),
        .package(path: "../chatlab-ios"),
    ],
    targets: [
        .target(
            name: "AppShell",
            dependencies: [
                .product(name: "Auth", package: "trainerlab-ios"),
                .product(name: "Sessions", package: "trainerlab-ios"),
                .product(name: "Presets", package: "trainerlab-ios"),
                .product(name: "RunConsole", package: "trainerlab-ios"),
                .product(name: "Summary", package: "trainerlab-ios"),
                .product(name: "Networking", package: "trainerlab-ios"),
                .product(name: "Realtime", package: "trainerlab-ios"),
                .product(name: "Persistence", package: "trainerlab-ios"),
                .product(name: "SharedModels", package: "trainerlab-ios"),
                .product(name: "ChatLabiOS", package: "chatlab-ios"),
            ],
        ),
    ],
)
