// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DriveCheckKit",
    defaultLocalization: "en",
    platforms: [
        // .iOS(.v27) needs swift-tools-version 6.4; the string form keeps the 6.2 manifest.
        .iOS("27.0"),
    ],
    products: [
        .library(
            name: "DriveCheckKit",
            targets: ["DriveCheckKit"]
        ),
    ],
    targets: [
        .target(
            name: "DriveCheckKit",
            resources: [
                .process("Resources"),
            ],
            linkerSettings: [
                .linkedFramework("ActivityKit"),
                .linkedFramework("AppIntents"),
                .linkedFramework("WidgetKit"),
            ]
        ),
    ]
)
