// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Core",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "Core", targets: ["Core"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/FluidInference/FluidAudio.git",
            exact: "0.14.3"
        ),
    ],
    targets: [
        .target(
            name: "Core",
            dependencies: ["FluidAudio"]
        ),
        .executableTarget(
            name: "CoreSelfTests",
            dependencies: ["Core"]
        ),
    ]
)
