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
swift run OmniversalApp   # demo app (see "Running the demo app")
```

CI (`.github/workflows/ci.yml`) runs these same steps on macOS for every PR.

## Running the demo app

`swift run OmniversalApp` opens a window on macOS 14 or later, with two scenes:

- **Dataset (Metal)**: the bundled `Sources/OmniversalApp/Resources/sample_terrain.csv` (576 rows) is
  loaded through `OmniData` and drawn as a rotating point cloud by `DatasetPointRenderer`. Position is
  `x_km`/`y_km`/`elevation_m`, and colour and size come from `rainfall_mm`. The shader is compiled from
  source at runtime, so the demo doesn't depend on the prebuilt metallib.
- **Grid (RealityKit)**: the original RealityKit grid view.

The app links `OmniCore`, `OmniUI`, `OmniKit`, `OmniCoordinator`, `OmniWidgets` and `OmniData`.
You can also open `Package.swift` in Xcode and run the `OmniversalApp` scheme.

### GPU loss and fallback

`GPUHealthMonitor` (OmniWidgets) owns the `MTLDevice`. It listens for failures from three sources:

- **Command-buffer errors.** The renderer reports any failed frame: device removed, timeout, out of memory, and so on.
- **Device removal on macOS.** `MTLCopyAllDevicesWithObserver` reports `wasRemoved` / `removalRequested`, for example an eGPU unplug or a driver reset.
- **Manual or simulated loss.** Use the scene's **Debug** menu, `simulateDeviceLoss()`, or `retry()`.

On a failure, the monitor tries up to 3 times to get a new device. If one succeeds, `generation` increments.
`ResilientDatasetScene` keys its `MTKView` on `generation`, so the view, queue and pipeline are rebuilt,
and the app reloads the dataset buffer on the new device. If every attempt fails, or there is no GPU at
all, the scene switches to the Canvas renderer (`DatasetScatterWidget`). An orange banner then gives the
reason and offers **Retry**, so the view never goes silently black. Failures and recoveries are logged
to `os.Logger` (subsystem `HDTE.OmniWidgets`, category `gpu`) and kept in `monitor.events`.
`DeviceLossTests` covers recovery, permanent loss with the banner, retry, a provider that fails twice
and then recovers, and a non-blank offscreen frame before and after recovery.

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
| **`OmniData`** | `Sources/OmniData` | Data layer: transfer functions, CSV/TSV/JSON loaders, `DatasetBuffer` (see [Data schema](#data-schema-omnidata)) | `OmniCore` |
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

## Data schema (OmniData)

`OmniData` turns tabular files into GPU vertex buffers for the widgets:

```swift
import OmniData
let buffer = try DatasetBuffer(contentsOf: url,                       // .csv, .tsv or .json
                               mapping: VertexMapping(x: "lon", y: "lat", z: "elevation_m", value: "temp_c"))
StandardWidgetFactory.shared.makeWidget(for: .dataset(buffer), style: .glass)   // DatasetScatterWidget
```

Input expectations:

| Format | Layout |
| --- | --- |
| CSV / TSV | The first row is a header with unique column names. Fields follow RFC 4180: they can be quoted with `"`, quotes inside a quoted field are doubled (`""`), and quoted fields can span lines. CRLF or LF line endings are both fine, and a UTF-8 BOM is allowed. Every row needs the same number of fields. Blank lines are skipped. |
| JSON | Either an array of flat objects, `[{"lon": -72.1, "lat": 41.8, ...}, ...]`, or a table, `{"columns": ["lon", "lat"], "rows": [[-72.1, 41.8], ...]}`. Missing keys and `null` become empty cells. Booleans stay text. |

- **Column types are inferred.** A column is numeric (`Float`) when every non-empty cell parses as a number. Empty cells in a numeric column become `NaN`. Any other column is kept as text.
- **Mapping.** `VertexMapping` picks numeric columns for `x`, `y`, optional `z` (height) and optional `value`. Each row becomes one `SIMD4<Float>`: `xyz` is the position, normalised to `[-1, 1]`, and `w` is the value, normalised to `[0, 1]`. Without a `value` column, `w = 1`. Pass `normalize: false` to keep raw units.
- **Rows with `NaN` in any mapped column are dropped.** A text or missing column throws `DatasetError.nonNumericColumn` or `.missingColumn`.
- **`DatasetBuffer`** keeps the vertices on the CPU (for Canvas widgets) and in a shared-storage `MTLBuffer` (`buffer`, with a stride of `DatasetBuffer.stride`) for Metal passes.

Sample fixtures are in `Tests/OmniDataTests/Fixtures/` (`elevation_sample.csv` / `.json`). Parquet
and a dataset cache are not supported yet.

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
