// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OmniCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "OmniCore",
            targets: ["OmniCore"]),
        .library(
            name: "OmniUI",
            targets: ["OmniUI"]),
        .library(
            name: "OmniWidgetExtension",
            targets: ["OmniWidgetExtension"]),
    ],
    targets: [
        .target(
            name: "OmniCoreTypes",
            path: "OmniCore/Include",
            publicHeadersPath: "."
        ),
        .target(
            name: "OmniCore",
            dependencies: ["OmniCoreTypes"],
            path: "OmniCore",
            exclude: ["Shaders", "Tests", "Include"],
            sources: ["Sources"],
            resources: [
                .process("Resources/OmniShaders.metallib")
            ]
        ),
        .target(
            name: "OmniUI",
            dependencies: ["OmniCore"],
            path: "OmniUI",
            sources: ["Sources"]
        ),
        .target(
            name: "OmniWidgetExtension",
            dependencies: ["OmniCore", "OmniUI"],
            path: "OmniWidget",
            sources: ["Sources"]
        ),
        .testTarget(
            name: "OmniCoreTests",
            dependencies: ["OmniCore"],
            path: "OmniCore/Tests",
            sources: ["OmniCoreTests"]
        ),
    ]
)
