import SwiftUI
import OmniCoordinator
import OmniGeometry
import MetalKit

// Bridge to Metal
struct MetalView: NSViewRepresentable {
    let renderer: Renderer
    
    func makeCoordinator() -> Coordinator {
        Coordinator(renderer: renderer)
    }
    
    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = renderer.device
        view.delegate = renderer
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        
        // Gestures
        let pan = NSPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan))
        view.addGestureRecognizer(pan)
        
        let magnify = NSMagnificationGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMagnify))
        view.addGestureRecognizer(magnify)
        
        return view
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {}
    
    class Coordinator {
        let renderer: Renderer
        
        init(renderer: Renderer) {
            self.renderer = renderer
        }
        
        @objc func handlePan(_ gesture: NSPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            Task {
                await renderer.camera.rotate(
                    deltaAzimuth: Float(translation.x) * 0.01,
                    deltaElevation: Float(-translation.y) * 0.01
                )
            }
            gesture.setTranslation(.zero, in: gesture.view)
        }
        
        @objc func handleMagnify(_ gesture: NSMagnificationGestureRecognizer) {
            Task {
                await renderer.camera.zoom(delta: -Float(gesture.magnification) * 10.0)
            }
            gesture.magnification = 0
        }
    }
}

@main
struct OmniversalApp: App {
    // Retain the renderer
    @State private var renderer = Renderer()
    
    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .topLeading) {
                // 3D Engine Layer
                MetalView(renderer: renderer)
                    .ignoresSafeArea()
                
                // Dashboard Layer (HUD)
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Header
                    VStack(alignment: .leading) {
                        Text("OMNIVERSAL")
                            .font(.custom("HelveticaNeue-CondensedBold", size: 32))
                            .tracking(2)
                        Text("2026 ARCHITECTURAL SPEC • TYPE 14")
                            .font(.caption)
                            .tracking(1)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)
                    .padding(.leading, 40)
                    
                    Spacer()
                    
                    // Controls
                    VStack(alignment: .leading, spacing: 16) {
                        // Camera Controls
                        VStack(alignment: .leading) {
                            Text("CAMERA")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                            
                            Button(action: {
                                Task {
                                    await renderer.camera.reset()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Reset View")
                                }
                                .font(.caption)
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Divider().background(.white.opacity(0.3))
                        
                        // Theme
                        Text("THEME CONFIGURATION")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                        
                        Divider().background(.white.opacity(0.3))
                        
                        // Signal Strength
                        HStack {
                            Text("SIGNAL")
                                .font(.caption)
                                .monospaced()
                            Slider(value: Binding(
                                get: { Double(renderer.theme.signalStrength) },
                                set: { renderer.theme.signalStrength = Float($0) }
                            ), in: 0...5)
                        }
                        
                        Divider().background(.white.opacity(0.3))
                        
                        // 2D Data Slice Overlay
                        DataSliceView()
                            .frame(width: 300, height: 150)
                    }
                    .frame(width: 320)
                    .padding()
                    .background(.thinMaterial)
                    .cornerRadius(16)
                    .padding(.leading, 40)
                    .padding(.bottom, 40)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
