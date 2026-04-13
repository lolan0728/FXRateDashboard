// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "FXRateDashboard",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "FXRateDashboardKit",
            targets: ["FXRateDashboardKit"]
        ),
        .executable(
            name: "FXRateDashboard",
            targets: ["FXRateDashboardApp"]
        )
    ],
    targets: [
        .target(
            name: "FXRateDashboardKit",
            path: "Sources/FXRateDashboardKit"
        ),
        .executableTarget(
            name: "FXRateDashboardApp",
            dependencies: ["FXRateDashboardKit"],
            path: "Sources/FXRateDashboardApp"
        )
    ]
)
