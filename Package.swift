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
    ],
    targets: [
        .target(
            name: "OmniCore",
            dependencies: [],
            path: "OmniCore",
            exclude: ["Shaders", "Tests"],
            sources: ["Sources"],
            resources: [
                .process("Resources/OmniShaders.metallib")
            ],
            publicHeadersPath: "Include",
            cSettings: [
                .headerSearchPath("Include")
            ]
        ),
        .testTarget(
            name: "OmniCoreTests",
            dependencies: ["OmniCore"],
            path: "OmniCore/Tests",
            sources: ["OmniCoreTests"]
        ),
    ]
)
