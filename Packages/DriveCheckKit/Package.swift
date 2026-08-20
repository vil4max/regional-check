// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DriveCheckKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v26)
    ],
    products: [
        .library(
            name: "DriveCheckKit",
            targets: ["DriveCheckKit"]
        )
    ],
    targets: [
        .target(
            name: "DriveCheckKit",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("ActivityKit"),
                .linkedFramework("AppIntents"),
                .linkedFramework("WidgetKit")
            ]
        )
    ]
)
