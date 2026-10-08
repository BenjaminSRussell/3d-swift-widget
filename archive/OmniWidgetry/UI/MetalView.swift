import SwiftUI
import MetalKit
import OmniCore
import OmniCoreTypes // Explicit import for FrameUniforms
import OmniDesignSystem
import CoreImage
import OmniStochastic

#if os(macOS)
typealias PlatformViewRepresentable = NSViewRepresentable
#else
typealias PlatformViewRepresentable = UIViewRepresentable
#endif

public struct MetalView: PlatformViewRepresentable {
    
    // Expert Panel: Creative Director - Camera rotation binding
    var cameraRotation: SIMD2<Float>
    var helperRenderer: Any? // Type erased to avoid strict dependency here, cast in Coordinator
    
    public init(cameraRotation: SIMD2<Float> = .zero, renderer: Any? = nil) {
        self.cameraRotation = cameraRotation
        self.helperRenderer = renderer
    }
    
    #if os(macOS)
    public func makeNSView(context: Context) -> MTKView {
        return makeView(context: context)
    }
    
    public func updateNSView(_ nsView: MTKView, context: Context) {
        updateView(nsView, context: context)
    }
    #else
    public func makeUIView(context: Context) -> MTKView {
        return makeView(context: context)
    }
    
    public func updateUIView(_ uiView: MTKView, context: Context) {
        updateView(uiView, context: context)
    }
    #endif
    
    func makeView(context: Context) -> MTKView {
        let mtkView = MTKView()
        
        let device = GPUContext.shared.device
        
        mtkView.device = device
        
        // CRITICAL INTEGRATION: Wide Color Gamut (P3)
        mtkView.colorPixelFormat = .bgra10_xr // Extended Range for HDR Glows
        mtkView.depthStencilPixelFormat = .depth32Float
        // mtkView.depthStencilTextureUsage = [.renderTarget, .shaderRead] // Not supported on MTKView directly
        mtkView.framebufferOnly = false
        mtkView.preferredFramesPerSecond = 120 // Expert Panel: Target 120Hz
        
        // CRITICAL INTEGRATION: Enable Transparency
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        #if os(macOS)
        mtkView.layer?.isOpaque = false
        mtkView.layer?.backgroundColor = NSColor.clear.cgColor
        #else
        mtkView.isOpaque = false
        mtkView.backgroundColor = .clear
        #endif
        
        // If we have a helper definition (e.g. from App), use it.
        // But context.coordinator is created by makeCoordinator.
        // If helperRenderer is used, we might bypass the default coordinator logic?
        if helperRenderer == nil {
             context.coordinator.setupRenderer(view: mtkView)
        }
        
        return mtkView
    }
    
    func updateView(_ view: MTKView, context: Context) {
        // Pass binding to coordinator
        context.coordinator.cameraRotation = cameraRotation
        
        // Wiring Step: IF helperRenderer is provided, set it as delegate
        if let customDelegate = helperRenderer as? MTKViewDelegate {
             view.delegate = customDelegate
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    public class Coordinator: NSObject, MTKViewDelegate {
        var meshRenderer: MeshRenderer?
        var physicsEngine: PhysicsEngine?
        var particles: ParticleSystem?
        var fluid: FluidSystem?
        var interaction: InteractionSystem?
        var stochasticPipeline: StochasticPipeline?
        var frameUniforms: MTLBuffer?
        
        // Phase 3: G-Buffer Textures
        var albedoTexture: MTLTexture?
        var normalTexture: MTLTexture?
        var depthTexture: MTLTexture?
        var sdfEngine: HDTESDFEngine?
        
        var cameraRotation: SIMD2<Float> = .zero
        var time: Float = 0
        
        // Expert Panel: Helper for ICB
        var didInitICB = false
        
        func setupRenderer(view: MTKView) {
            view.delegate = self
            
            do {
                let device = view.device!
                
                self.meshRenderer = try MeshRenderer(device: device)
                self.physicsEngine = try PhysicsEngine()
                self.particles = ParticleSystem(device: device, maxParticles: 100000)
                self.fluid = FluidSystem(device: device, width: 64, height: 64)
                self.interaction = InteractionSystem(device: device)
                self.stochasticPipeline = try StochasticPipeline(device: device)
                self.sdfEngine = HDTESDFEngine(context: MetalContext.shared, shaderLibrary: ShaderLibrary(device: device))
                
                self.frameUniforms = device.makeBuffer(length: MemoryLayout<FrameUniforms>.stride, options: .storageModeShared)
                
                // Expert Panel: Initialize ICBs for endless math
                MetalContext.shared.setupIndirectCommandBuffers(maxCommands: 1_000_000)
                self.didInitICB = true
                
                // Expert Panel: Initialize Watchdog
                _ = GPUWatchdog.shared
                
            } catch {
                print("Failed to initialize OMNI engine: \(error)")
            }
        }
        
        // Helper to manage G-Buffer textures
        func ensureTextures(device: MTLDevice, size: CGSize) {
            let width = Int(size.width)
            let height = Int(size.height)
            
            if albedoTexture?.width != width || albedoTexture?.height != height {
                let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
                desc.usage = [.renderTarget, .shaderRead]
                albedoTexture = device.makeTexture(descriptor: desc)
                
                let normDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: width, height: height, mipmapped: false)
                normDesc.usage = [.renderTarget, .shaderRead]
                normalTexture = device.makeTexture(descriptor: normDesc)
                
                let depthDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: width, height: height, mipmapped: false)
                depthDesc.usage = [.renderTarget, .shaderRead]
                depthDesc.storageMode = .private
                depthTexture = device.makeTexture(descriptor: depthDesc)
                
                // Also resize SDF engine
                sdfEngine?.resize(width: width, height: height)
            }
        }

        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            if let device = view.device {
                ensureTextures(device: device, size: size)
            }
        }
        
        public func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let device = view.device else { return }
            
            // Phase 3: Resize check
            ensureTextures(device: device, size: view.drawableSize)
            
            // Phase 3.3: Async Stochastic Tick
            stochasticPipeline?.dispatchAsync(device: device)
            
            // Phase 3.1: Render SDF (Async/Compute)
            // Note: In a fully optimized engine, we'd pass the command buffer to sync
            sdfEngine?.render(time: time, cameraPosition: SIMD3<Float>(0, 0, 5)) 
            
            // Main Render Loop
            guard let commandBuffer = MetalContext.shared.makeCommandBuffer() else { return }
            
            time += 0.016
            
            // 1. Physics (Compute)
            if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
                if let fluid = fluid, let interactions = interaction {
                     physicsEngine?.stepFluid(encoder: computeEncoder, fluid: fluid, interactions: interactions)
                }
                computeEncoder.endEncoding()
            }
            
            // 2. G-Buffer Pass (Render)
            // We create a custom descriptor to render to our offscreen textures
            let renderPass = MTLRenderPassDescriptor()
            renderPass.colorAttachments[0].texture = albedoTexture
            renderPass.colorAttachments[0].loadAction = .clear
            renderPass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            renderPass.colorAttachments[0].storeAction = .store
            
            renderPass.colorAttachments[1].texture = normalTexture
            renderPass.colorAttachments[1].loadAction = .clear
            renderPass.colorAttachments[1].clearColor = MTLClearColor(red: 0.5, green: 0.5, blue: 1.0, alpha: 0)
            renderPass.colorAttachments[1].storeAction = .store
            
            // Use custom depth texture
            if let depthTex = depthTexture {
                renderPass.depthAttachment.texture = depthTex
                renderPass.depthAttachment.loadAction = .clear
                renderPass.depthAttachment.storeAction = .store // Keep for composite
                renderPass.depthAttachment.clearDepth = 1.0
            }
            
            if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) {
                // Pass uniforms (omitted for brevity, would set buffers here)
                meshRenderer?.draw(encoder: renderEncoder, meshletCount: 100)
                renderEncoder.endEncoding()
            }
            
            // 3. Composite Pass (Compute)
            if let computeEncoder = commandBuffer.makeComputeCommandEncoder(),
               let albedo = albedoTexture,
               let normal = normalTexture,
               let depth = depthTexture,
               let sdf = sdfEngine?.outputTexture {
                
                meshRenderer?.composite(encoder: computeEncoder, 
                                      color: albedo, 
                                      normal: normal, 
                                      depth: depth, 
                                      sdf: sdf, 
                                      output: drawable.texture)
                computeEncoder.endEncoding()
            }
            
            // Expert Panel: Performance Metrics
            let startTime = CFAbsoluteTimeGetCurrent()
            commandBuffer.addCompletedHandler { _ in
                 let endTime = CFAbsoluteTimeGetCurrent()
                 let duration = (endTime - startTime) * 1000.0
                 GPUWatchdog.shared.reportFrameTime(duration)
            }
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
