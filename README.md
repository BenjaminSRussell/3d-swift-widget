# 3d-swift-widget

[![Build and Test](https://github.com/BenjaminSRussell/3d-swift-widget/actions/workflows/ci.yml/badge.svg)](https://github.com/BenjaminSRussell/3d-swift-widget/actions/workflows/ci.yml)

A Metal-based 3D environment for data visualization: a GPU core, rendering and simulation
modules, SwiftUI design-system pieces, and WidgetKit widgets. The package is named
`HDTE_Masterpiece` (Hyper-Dimensional Topography Engine).

## Requirements

- macOS 14 or later, Xcode 15.4 or later (Swift 5.9 or later)
- A Metal-capable GPU. Tests that need a GPU skip themselves when no device is available.

## Build and test

```bash
./compile_shaders.sh      # compile every Sources/**/*.metal file to AIR; fails on any shader error
swift build
swift test
swift run OmniversalApp   # demo app executable
```

CI (`.github/workflows/ci.yml`) runs these same steps on macOS for every PR.

## Package map

Every directory under `Sources/` is a declared target. Retired trees live in [`archive/`](archive/README.md).

| Product / target | Path | Role | Depends on |
| --- | --- | --- | --- |
| `OmniCoreTypes` | `Sources/OmniCore/Include` | C header shared by Swift and Metal (`OmniShaderTypes.h`) | none |
| **`OmniCore`** | `Sources/OmniCore` (excluding the sub-targets below) | Metal context, GPU heap, shader bundle, compute kernels, core rendering | `OmniCoreTypes` |
| `OmniMath` | `Sources/OmniCore/Compute/Math` | Math and compute kernels (TDA, t-SNE, noise) | `OmniCore`, `OmniCoreTypes` |
| `OmniGeometry` | `Sources/OmniCore/Rendering/Primitives` | Mesh, meshlet and terrain geometry, plus their shaders | `OmniCore` |
| `OmniStochastic` | `Sources/OmniCore/Simulation` | Particle systems and integrators | `OmniCore` |
| **`OmniKit`** | `Sources/OmniKit` | Middleware: themes and render orchestration | `OmniCore`, `OmniCoreTypes`, `OmniGeometry`, `OmniMath` |
| **`OmniUI`** | `Sources/OmniUI` | Front-end design layer | `OmniCore`, `OmniKit` |
| **`OmniDesignSystem`** | `Sources/OmniDesignSystem` | Legacy alias of `OmniUI`, plus materials | `OmniUI` |
| **`OmniData`** | `Sources/OmniData` | Data layer: transfer functions and loaders | `OmniCore` |
| **`OmniWidgets`** | `Sources/OmniWidgets` | Widget implementations and registry | `OmniCore`, `OmniUI`, `OmniKit`, `OmniDesignSystem`, `OmniData`, `OmniStochastic` |
| **`OmniCoordinator`** | `Sources/OmniCoordinator` | HDTE pipeline: wires compute, render and widgets together | all of the above |
| **`OmniversalApp`** (executable) | `Sources/OmniversalApp` | Demo app | (see #3) |

Bold names are library products.

### Target graph

```
OmniCoreTypes ─▶ OmniCore ─┬─▶ OmniMath ───────┐
                           ├─▶ OmniGeometry ───┼─▶ OmniKit ─▶ OmniUI ─▶ OmniDesignSystem ─┐
                           ├─▶ OmniStochastic ─┼──────────────────────────────────────────┼─▶ OmniWidgets ─▶ OmniCoordinator ─▶ OmniversalApp
                           └─▶ OmniData ───────┘──────────────────────────────────────────┘
```

### `@main` entry points

- `Sources/OmniversalApp/App.swift` is the package's only `@main`.
- `Sources/OmniWidgets/Extension/OmniWidgetBundle.swift` is a WidgetKit `@main`. It is
  **excluded** from the `OmniWidgets` target (`exclude: ["Extension"]`), so it doesn't conflict
  with the app. Add it to a widget-extension target in an Xcode project to ship widgets.
- The archived `TopographyApp` and `OmniWidgetry` `@main`s are outside `Sources/` and never built.

### Naming

`OmniWidgets` is the canonical widget module. `OmniWidgetry` was an earlier copy and is archived.
`OmniDesignSystem` is kept as a thin alias of `OmniUI` for source compatibility.

## Shaders

Shaders live next to the target that uses them and are processed as SwiftPM resources. When no
precompiled `default.metallib` is found (plain `swift build`), `ShaderBundle` compiles the
sources at runtime. It produces one library per file, and kernels are looked up across all of
them. `compile_shaders.sh` is the CI gate: it compiles each `.metal` file on its own.

## Docs

`Outline/` holds the research notes that motivated the design: Metal GPU architecture,
topological data analysis, advanced rendering, and `HDTE_Infrastructure_Guide.md`. They are
background reading, not API docs. The code layout above is the source of truth.

## License

See [LICENSE](LICENSE).
