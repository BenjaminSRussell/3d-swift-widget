import SwiftUI
import RealityKit
import OmniCore
import OmniCoordinator
import OmniData
import OmniWidgets

@main
struct OmniversalDemoApp: App {
    @StateObject private var gpu = GPUHealthMonitor()

    var body: some SwiftUI.Scene {
        WindowGroup("Omniversal: 3D Data Viz") {
            ContentView(gpu: gpu)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1024, height: 768)
    }
}

struct ContentView: View {
    @ObservedObject var gpu: GPUHealthMonitor
    @State private var tab = Tab.data

    enum Tab: String, CaseIterable, Identifiable {
        case data = "Dataset (Metal)"
        case grid = "Grid (RealityKit)"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Scene", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(8)

            switch tab {
            case .data: DemoDatasetScene(gpu: gpu)
            case .grid: RealityKitGridView().ignoresSafeArea()
            }
        }
    }
}

/// Loads the bundled sample CSV through OmniData and shows it in the resilient Metal scene.
struct DemoDatasetScene: View {
    @ObservedObject var gpu: GPUHealthMonitor
    @State private var buffer: Result<DatasetBuffer, Error>?

    static let mapping = VertexMapping(x: "x_km", y: "y_km", z: "elevation_m", value: "rainfall_mm")

    var body: some View {
        Group {
            switch buffer {
            case .success(let buf)?:
                ResilientDatasetScene(buffer: buf, monitor: gpu)
            case .failure(let error)?:
                ContentUnavailableView("Could not load sample data", systemImage: "tablecells.badge.ellipsis",
                                       description: Text(String(describing: error)))
            case nil:
                ProgressView("Loading sample_terrain.csv…")
            }
        }
        .task(id: gpu.generation) { load() }
    }

    private func load() {
        buffer = Result {
            guard let url = Bundle.module.url(forResource: "sample_terrain", withExtension: "csv", subdirectory: "Resources") else {
                throw CocoaError(.fileNoSuchFile)
            }
            return try DatasetBuffer(contentsOf: url, mapping: Self.mapping, device: gpu.device)
        }
    }
}
