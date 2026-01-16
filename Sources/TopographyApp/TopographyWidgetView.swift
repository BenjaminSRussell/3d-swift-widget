import SwiftUI
import MetalKit
import TopographyRender
import TopographyCore

// Coordinator to handle MKViewDelegate and interaction
class Coordinator: NSObject {
    var parent: TopographyWidgetView
    var renderer: MetalRenderer?
    
    init(_ parent: TopographyWidgetView) {
        self.parent = parent
    }
    
    @objc func handlePan(_ gesture: NSPanGestureRecognizer) {
        let translation = gesture.translation(in: gesture.view)
        let sensitivity: Float = 0.01
        
        renderer?.rotationY -= Float(translation.x) * sensitivity
        renderer?.rotationX = max(0.1, min(Float.pi / 2 - 0.1, (renderer?.rotationX ?? 0) - Float(translation.y) * sensitivity))
        
        gesture.setTranslation(.zero, in: gesture.view)
    }
    
    @objc func handleMagnification(_ gesture: NSMagnificationGestureRecognizer) {
        // Zoom logic
        let scale = Float(1.0 - gesture.magnification)
        renderer?.distance *= scale
        gesture.magnification = 0
    }
}

struct TopographyWidgetView: NSViewRepresentable {
    @Binding var terrainData: TerrainData?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        
        if let renderer = MetalRenderer(metalKitView: mtkView) {
            context.coordinator.renderer = renderer
            mtkView.delegate = renderer
            
            // Initial data if available
            if let data = terrainData {
                renderer.updateTerrain(data: data)
            }
        }
        
        // Add Gestures
        let pan = NSPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        mtkView.addGestureRecognizer(pan)
        
        let zoom = NSMagnificationGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMagnification(_:)))
        mtkView.addGestureRecognizer(zoom)

        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        // Check if data changed
        if let data = terrainData {
            context.coordinator.renderer?.updateTerrain(data: data)
        }
    }
}
