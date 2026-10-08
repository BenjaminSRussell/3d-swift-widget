import SwiftUI
import MetalKit
import OmniData

/// Demo scene: renders a dataset with Metal and survives GPU loss.
///
/// * `.ready`: Metal point cloud (`DatasetPointRenderer`). The MTKView is keyed on
///   `monitor.generation`, so a recovered device gets a fresh view, queue and pipeline.
/// * `.recovering`: the last frame stays up with a "Recovering GPU…" overlay.
/// * `.fallback`, or a Metal setup error: the Canvas renderer (`DatasetScatterWidget`)
///   with a banner that gives the reason and a Retry button. Never a blank view.
public struct ResilientDatasetScene: View {
    public let buffer: DatasetBuffer
    @ObservedObject public var monitor: GPUHealthMonitor
    @State private var setupError: String?
    public var showsDebugControls: Bool

    public init(buffer: DatasetBuffer, monitor: GPUHealthMonitor, showsDebugControls: Bool = true) {
        self.buffer = buffer
        self._monitor = ObservedObject(wrappedValue: monitor)
        self.showsDebugControls = showsDebugControls
    }

    public var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0.04, green: 0.05, blue: 0.08)
            content
            VStack(spacing: 8) {
                if let banner = bannerText {
                    FallbackBanner(text: banner) { setupError = nil; monitor.retry() }
                }
                Spacer()
                HStack {
                    Text(monitor.stateDescription)
                    Spacer()
                    Text("\(buffer.datasetName) · \(buffer.vertexCount) pts")
                    if showsDebugControls {
                        Menu("Debug") {
                            Button("Simulate GPU reset") { monitor.simulateDeviceLoss() }
                            Button("Simulate permanent GPU loss") { monitor.simulateDeviceLoss(permanently: true) }
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(12)
        }
    }

    /// Text for the fallback banner, or nil while Metal is healthy.
    var bannerText: String? {
        if case .fallback(let reason) = monitor.state { return "GPU unavailable, showing software rendering. \(reason)" }
        if let setupError { return "Metal setup failed, showing software rendering. \(setupError)" }
        return nil
    }

    @ViewBuilder private var content: some View {
        switch monitor.state {
        case .ready:
            if let device = monitor.device, setupError == nil {
                MetalDatasetView(buffer: buffer, device: device,
                                 onFailure: { monitor.reportFailure($0) },
                                 onSetupError: { setupError = $0 })
                    .id(monitor.generation)
            } else {
                DatasetScatterWidget(buffer: buffer, style: .flat)
            }
        case .recovering:
            ZStack {
                DatasetScatterWidget(buffer: buffer, style: .flat, rotates: false).opacity(0.4)
                ProgressView("Recovering GPU…").controlSize(.large)
            }
        case .fallback:
            DatasetScatterWidget(buffer: buffer, style: .flat)
        }
    }
}

struct FallbackBanner: View {
    let text: String
    let retry: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            Text(text).font(.callout).lineLimit(2)
            Spacer()
            Button("Retry", action: retry)
        }
        .padding(10)
        .background(.orange.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.orange.opacity(0.6)))
        .accessibilityIdentifier("gpu-fallback-banner")
    }
}

/// MTKView host for `DatasetPointRenderer`.
struct MetalDatasetView: NSViewRepresentable {
    let buffer: DatasetBuffer
    let device: MTLDevice
    let onFailure: (String) -> Void
    let onSetupError: (String) -> Void

    final class Coordinator { var renderer: DatasetPointRenderer? }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: device)
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        view.clearColor = MTLClearColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 1)
        view.preferredFramesPerSecond = 60
        do {
            let renderer = try DatasetPointRenderer(device: device, buffer: buffer)
            renderer.onFailure = onFailure
            context.coordinator.renderer = renderer
            view.delegate = renderer
        } catch {
            let message = String(describing: error)
            DispatchQueue.main.async { onSetupError(message) }
        }
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {}
}
