import SwiftUI
import MetalKit
import OmniCore
import OmniCoreTypes // Explicit import for FrameUniforms
import OmniUI

#if os(macOS)
typealias PlatformViewRepresentable = NSViewRepresentable
#else
typealias PlatformViewRepresentable = UIViewRepresentable
#endif

struct MetalView: PlatformViewRepresentable {
    
    #if os(macOS)
    func makeNSView(context: Context) -> MTKView {
        return makeView(context: context)
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        updateView(nsView, context: context)
    }
    #else
    func makeUIView(context: Context) -> MTKView {
        return makeView(context: context)
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        updateView(uiView, context: context)
    }
    #endif
    
    func makeView(context: Context) -> MTKView {
        let mtkView = MTKView()
        
        let device = GPUContext.shared.device // Forced unwrap in source, so just assign
        
        mtkView.device = device
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.framebufferOnly = false
        mtkView.preferredFramesPerSecond = 30
        
        context.coordinator.setupRenderer(view: mtkView)
        
        return mtkView
    }
    
    func updateView(_ view: MTKView, context: Context) {
        // Handle updates
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var meshRenderer: MeshRenderer?
        var physicsEngine: PhysicsEngine?
        var particles: ParticleSystem?
        var fluid: FluidSystem?
        var interaction: InteractionSystem?
        var frameUniforms: MTLBuffer?
        
        var time: Float = 0
        
        func setupRenderer(view: MTKView) {
            view.delegate = self
            
            do {
                let device = view.device!
                
                self.meshRenderer = try MeshRenderer(device: device)
                self.physicsEngine = try PhysicsEngine()
                self.particles = ParticleSystem(device: device, maxParticles: 100000)
                self.fluid = FluidSystem(device: device, width: 64, height: 64)
                self.interaction = InteractionSystem(device: device)
                
                self.frameUniforms = device.makeBuffer(length: MemoryLayout<FrameUniforms>.stride, options: .storageModeShared)
                
            } catch {
                print("Failed to initialize OMNI engine: \(error)")
            }
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }
        
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let renderPassDescriptor = view.currentRenderPassDescriptor,
                  let commandBuffer = GPUContext.shared.commandQueue.makeCommandBuffer(),
                  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
                  let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
            
            time += 0.016
            
            // 1. Physics Step
            if let fluid = fluid, let interactions = interaction, let _ = frameUniforms {
                physicsEngine?.stepFluid(encoder: computeEncoder, fluid: fluid, interactions: interactions)
            }
            computeEncoder.endEncoding()
            
            // 2. Render Step (Stubbed meshlet count)
            meshRenderer?.draw(encoder: renderEncoder, meshletCount: 100)
            renderEncoder.endEncoding()
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
