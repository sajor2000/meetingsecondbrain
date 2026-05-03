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
        .library(name: "ParakeetTranscription", targets: ["ParakeetTranscription"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/FluidInference/FluidAudio.git",
            exact: "0.14.3"
        ),
    ],
    targets: [
        .target(name: "Core"),
        .target(
            name: "ParakeetTranscription",
            dependencies: [
                "Core",
                "FluidAudio",
            ]
        ),
        .executableTarget(
            name: "CoreSelfTests",
            dependencies: ["Core"]
        ),
        .executableTarget(
            name: "ParakeetTranscriptionSelfTests",
            dependencies: ["ParakeetTranscription"]
        ),
    ]
)
