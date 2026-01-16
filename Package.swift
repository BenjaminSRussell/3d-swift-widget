// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OmniversalEngine",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .executable(name: "OmniversalApp", targets: ["OmniversalApp"]),
        .library(name: "OmniGeometry", type: .dynamic, targets: ["OmniGeometry"]),
        .library(name: "OmniStochastic", type: .dynamic, targets: ["OmniStochastic"]),
        .library(name: "OmniCoordinator", type: .dynamic, targets: ["OmniCoordinator"]),
    ],
    targets: [
        .target(
            name: "OmniGeometry",
            dependencies: [],
            resources: [.process("Shaders")]
        ),
        .target(
            name: "OmniStochastic",
            dependencies: [],
            resources: [.process("Kernels")]
        ),
        .target(
            name: "OmniCoordinator",
            dependencies: ["OmniGeometry", "OmniStochastic"]
        ),
        .executableTarget(
            name: "OmniversalApp",
            dependencies: ["OmniCoordinator"]
        ),
        
        // Test Targets
        .testTarget(
            name: "MemoryTests",
            dependencies: ["OmniCoordinator"]
        ),
        .testTarget(
            name: "PipelineTests",
            dependencies: ["OmniCoordinator", "OmniGeometry", "OmniStochastic"]
        )
    ]
)
