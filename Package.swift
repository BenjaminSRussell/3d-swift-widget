// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HDTE_Masterpiece",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "OmniCore", targets: ["OmniCore"]),
        .library(name: "OmniDesignSystem", targets: ["OmniDesignSystem"]),
        .library(name: "OmniUI", targets: ["OmniUI"]),
        .library(name: "OmniKit", targets: ["OmniKit"]),
        .library(name: "OmniWidgets", targets: ["OmniWidgets"]),
        .library(name: "OmniData", targets: ["OmniData"]),
        .library(name: "OmniCoordinator", targets: ["OmniCoordinator"]),
        .executable(name: "OmniversalApp", targets: ["OmniversalApp"]),
    ],
    targets: [
        // MARK: - Core Engine
        .target(
            name: "OmniCoreTypes",
            path: "Sources/OmniCore/Include",
            publicHeadersPath: "."
        ),
        .target(
            name: "OmniCore",
            dependencies: ["OmniCoreTypes"],
            path: "Sources/OmniCore",
            exclude: [
                "Include", 
                "Documentation", 
                "Resources", 
                "Compute/Math", 
                "Rendering/Primitives", 
                "Simulation" 
            ],
            resources: [
                .process("Rendering/Shaders"),
                .process("Resources")
            ]
        ),
        .target(
            name: "OmniMath", // Mapped to Compute/Math
            dependencies: ["OmniCore", "OmniCoreTypes"],
            path: "Sources/OmniCore/Compute/Math",
            exclude: ["Kernels"], // Processed as resource
            resources: [
                .process("Kernels")
            ]
        ),
        .target(
            name: "OmniGeometry", // Mapped to Rendering/Primitives
            dependencies: ["OmniCore"],
            path: "Sources/OmniCore/Rendering/Primitives",
            resources: [
                .process("Shaders") 
            ]
        ),
        .target(
            name: "OmniStochastic", // Mapped to Simulation
            dependencies: ["OmniCore"],
            path: "Sources/OmniCore/Simulation",
             resources: [
                .process("Kernels")
            ]
        ),
        
        // MARK: - Middleware (OmniKit)
        .target(
            name: "OmniKit",
            dependencies: ["OmniCore", "OmniCoreTypes", "OmniGeometry", "OmniMath"],
            path: "Sources/OmniKit"
        ),
        
        // MARK: - Design System & UI (OmniUI)
        .target(
            name: "OmniUI",  // Formerly OmniDesignSystem - The Frontend Layer
            dependencies: ["OmniCore", "OmniKit"], // Depends on Kit for Theme
            path: "Sources/OmniUI"
        ),
        .target(
            name: "OmniDesignSystem", // Legacy Alias, kept for build safety
            dependencies: ["OmniUI"],
            path: "Sources/OmniDesignSystem",
            resources: [.process("Materials")]
        ),
        
        // MARK: - Data Layer
        .target(
            name: "OmniData",
            dependencies: ["OmniCore"],
            path: "Sources/OmniData"
        ),
        
        // MARK: - Widgetry (Implementations)
        .target(
            name: "OmniWidgets",
            dependencies: [
                "OmniCore", 
                "OmniUI", 
                "OmniKit",
                "OmniDesignSystem",
                "OmniData",
                "OmniStochastic"
            ],
            path: "Sources/OmniWidgets",
            exclude: ["Extension"] // Widget extension has @main, conflicts with App
        ),
        
        // MARK: - Coordinator
        .target(
            name: "OmniCoordinator",
            dependencies: [
                "OmniCore",
                "OmniKit", // New dependency
                "OmniUI",  // New dependency
                "OmniGeometry",
                "OmniStochastic",
                "OmniMath",
                "OmniCoreTypes",
                "OmniWidgets"
            ],
            path: "Sources/OmniCoordinator"
        ),
        
        // MARK: - App
        .executableTarget(
            name: "OmniversalApp",
            dependencies: [
                // "OmniCore", // Disabled to fix Metal build errors
                // "OmniUI",
                // "OmniKit",
                // "OmniCoordinator",
                // "OmniWidgets"
            ],
            path: "Sources/OmniversalApp"
        ),
        
        // MARK: - Tests
        .testTarget(
            name: "OmniCoreTests",
            dependencies: ["OmniCore"],
            path: "Tests/OmniCoreTests"
        ),
        .testTarget(
            name: "OmniDesignSystemTests",
            dependencies: ["OmniUI", "OmniCore"],
            path: "Tests/OmniUITests"
        )
    ]
)
