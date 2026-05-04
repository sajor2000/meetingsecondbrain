// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RecallOSCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "RecallOSCore", targets: ["RecallOSCore"])
    ],
    targets: [
        .target(name: "RecallOSCore"),
        .testTarget(
            name: "RecallOSCoreTests",
            dependencies: ["RecallOSCore"]
        )
    ]
)
