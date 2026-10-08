# Archive

These trees are **not** part of the Swift package. They are kept for reference only and are
not built, tested or shader-checked (`compile_shaders.sh` only scans `Sources/`).

| Path | What it was | Replaced by |
| --- | --- | --- |
| `TopographyApp/` | Early SwiftUI terrain demo app (`@main`) | `Sources/OmniversalApp` |
| `TopographyCore/` | Terrain data and generator | `OmniCore` simulation and compute (`OmniMath`, `OmniStochastic`) |
| `TopographyRender/` | Standalone Metal terrain renderer and shaders | `OmniGeometry` (`Sources/OmniCore/Rendering/Primitives`) |
| `OmniWidgetry/` | Older copy of the widget layer | `Sources/OmniWidgets` (the `OmniWidgets` target) |
| `Tests/MemoryTests`, `Tests/PipelineTests`, `Tests/VisualTests` | Test folders never declared as test targets | `Tests/OmniCoreTests`, `Tests/OmniUITests` |

To revive one of these, move it back under `Sources/` (or `Tests/`) and declare a target for it
in `Package.swift`.
