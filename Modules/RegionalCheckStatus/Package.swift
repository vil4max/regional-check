// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RegionalCheckStatus",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(name: "RegionalCheckStatus", targets: ["RegionalCheckStatus"])
    ],
    dependencies: [
        .package(path: "../RegionalCheckDomain")
    ],
    targets: [
        .target(
            name: "RegionalCheckStatus",
            dependencies: ["RegionalCheckDomain"]
        )
    ]
)
