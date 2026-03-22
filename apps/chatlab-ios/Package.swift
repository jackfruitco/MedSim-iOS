// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ChatLabiOS",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v26),
        .macOS(.v14),
    ],
    products: [
        .library(name: "ChatLabiOS", targets: ["ChatLabiOS"]),
    ],
    dependencies: [
        .package(path: "../trainerlab-ios"),
    ],
    targets: [
        .target(
            name: "ChatLabiOS",
            dependencies: [
                .product(name: "Networking", package: "trainerlab-ios"),
                .product(name: "Persistence", package: "trainerlab-ios"),
                .product(name: "DesignSystem", package: "trainerlab-ios"),
                .product(name: "SharedModels", package: "trainerlab-ios"),
            ],
        ),
        .testTarget(
            name: "ChatLabiOSTests",
            dependencies: [
                "ChatLabiOS",
                .product(name: "Networking", package: "trainerlab-ios"),
                .product(name: "SharedModels", package: "trainerlab-ios"),
                .product(name: "Persistence", package: "trainerlab-ios"),
            ],
        ),
    ],
)
