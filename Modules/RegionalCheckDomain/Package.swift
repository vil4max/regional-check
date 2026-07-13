// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RegionalCheckDomain",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(name: "RegionalCheckDomain", targets: ["RegionalCheckDomain"])
    ],
    targets: [
        .target(
            name: "RegionalCheckDomain"
        ),
        .testTarget(
            name: "RegionalCheckDomainTests",
            dependencies: ["RegionalCheckDomain"]
        )
    ]
)

