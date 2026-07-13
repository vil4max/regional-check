// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RegionalCheckData",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(name: "RegionalCheckData", targets: ["RegionalCheckData"])
    ],
    dependencies: [
        .package(path: "../RegionalCheckDomain")
    ],
    targets: [
        .target(
            name: "RegionalCheckData",
            dependencies: ["RegionalCheckDomain"]
        )
    ]
)
