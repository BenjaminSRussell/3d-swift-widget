import SwiftUI
import MetalKit
import OmniCore
import OmniData
import QuartzCore // Phase 1: Diagnostic Timing
// import OmniCoordinator // Self

/// HDTEInteractiveView: The modern, consolidation-ready 3D view for the Main App.
/// Replaces the legacy TopographyWidgetView.
public struct HDTEInteractiveView: NSViewRepresentable {
    
    // Dependencies
    @State private var pipeline: HDTEPipeline?
    @State private var navigation: TopologicalNavigationController?
    @State private var metalContext = MetalContext.shared
    
    // Expert Panel: Creative Director - Camera rotation binding
    @Binding var parallaxOffset: SIMD2<Float>
    
    public init(parallaxOffset: Binding<SIMD2<Float>>) {
        self._parallaxOffset = parallaxOffset
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    public func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView(frame: CGRect(x: 0, y: 0, width: 1024, height: 768))
        print("DEBUG: HDTEInteractiveView Created with Frame: \(mtkView.frame)")
        
        // Use autolayout
        mtkView.translatesAutoresizingMaskIntoConstraints = false
        
        let device = GPUContext.shared.device
        mtkView.device = device
        mtkView.delegate = context.coordinator
        
        // Configure standard HDTE visual specs
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.framebufferOnly = false // Phase 5: Required for Compute Output
        
        // Expert Panel: True Transparency
        mtkView.clearColor = MTLClearColor(red: 0, green: 1, blue: 0, alpha: 1) // Phase 1 Debug: Solid Green Background
        mtkView.layer?.isOpaque = true // Force Opaque to debug composition
        mtkView.layer?.backgroundColor = NSColor.yellow.cgColor // Phase 1 Debug: Yellow (View Created, Draw Ignored)
        
        // Add Interaction Gestures
        let pan = NSPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        mtkView.addGestureRecognizer(pan)
        
        let zoom = NSMagnificationGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMagnify(_:)))
        mtkView.addGestureRecognizer(zoom)
        
        // Initialize Pipeline asynchronously
        Task {
            do {
                let pipe = try HDTEPipeline(device: metalContext.device)
                let library = ShaderLibrary(device: metalContext.device)
                let nav = TopologicalNavigationController(topologyEngine: HDTEPersistentHomology(context: metalContext, shaderLibrary: library))
                
                await MainActor.run {
                    context.coordinator.setPipeline(pipe)
                    context.coordinator.setNavigation(nav)
                }
            } catch {
                print("HDTE Critical Error: Failed to initialize pipeline: \(error)")
            }
        }
        
        return mtkView
    }
    
    public func updateNSView(_ nsView: MTKView, context: Context) {
        if nsView.frame.size.width == 0 {
             print("DEBUG WARNING: HDTEInteractiveView Frame is ZERO: \(nsView.frame)")
        } else {
             // print("DEBUG: HDTE Frame: \(nsView.frame)")
        }
        
        context.coordinator.parent = self
        // context.coordinator.update(view: nsView) // Removed: No update method exists/needed
    }
    
    public class Coordinator: NSObject, MTKViewDelegate {
        var parent: HDTEInteractiveView
        var pipeline: HDTEPipeline?
        var navigation: TopologicalNavigationController?
        
        // Phase 2: Mesh State
        var vertexBuffer: MTLBuffer?
        var indexBuffer: MTLBuffer?
        var indexCount: Int = 0
        var pipelineState: MTLRenderPipelineState?
        
        // Phase 5: Volumetric State
        var volumetricPipelineState: MTLComputePipelineState?
        
        // Phase 6: Coordinate Mapping State
        var lastProjectionMatrix: matrix_float4x4 = matrix_identity_float4x4
        var lastViewMatrix: matrix_float4x4 = matrix_identity_float4x4
        var lastViewportSize: SIMD2<Float> = .zero
        
        init(parent: HDTEInteractiveView) {
            self.parent = parent
            super.init()
            
            // Initialize Grid Mesh (Legacy Phase 2)
            setupMesh(device: MetalContext.shared.device)
            setupPipeline(device: MetalContext.shared.device)
        }
        
        func setupMesh(device: MTLDevice) {
             // Kept for fallback/overlay
            if let (vBuf, iBuf, count) = GridMeshGenerator.generateGrid(device: device, size: 20.0, segments: 40) {
                self.vertexBuffer = vBuf
                self.indexBuffer = iBuf
                self.indexCount = count
            }
        }
        
        func setupPipeline(device: MTLDevice) {
            // Fix: Use ShaderBundle.shared instead of device.makeDefaultLibrary()
            // This ensures we find shaders in the OmniCore module
            
            // Load Phase 5 Compute Kernel
            if let kernel = ShaderBundle.shared.makeFunction(name: "volumetric_grid_compute") {
                do {
                    self.volumetricPipelineState = try device.makeComputePipelineState(function: kernel)
                    print("Phase 5: Volumetric Pipeline Loaded")
                } catch {
                    print("Phase 5 Error: Failed to create compute pipeline: \(error)")
                }
            } else {
                print("Phase 5 Error: volumetric_grid_compute kernel not found!")
            }
            
            // Legacy Wireframe (Optional)
            let vert = ShaderBundle.shared.makeFunction(name: "wireframe_vertex")
            let frag = ShaderBundle.shared.makeFunction(name: "wireframe_fragment")
            
            if let vertFunc = vert, let fragFunc = frag {
                let desc = MTLRenderPipelineDescriptor()
                desc.vertexFunction = vertFunc
                desc.fragmentFunction = fragFunc
                desc.colorAttachments[0].pixelFormat = .bgra8Unorm
                desc.depthAttachmentPixelFormat = .depth32Float
                
                 // Define Vertex Descriptor (Simplified, assuming standard layout match)
                let vertexDesc = MTLVertexDescriptor()
                vertexDesc.attributes[0].format = .float3
                vertexDesc.attributes[0].offset = 0
                vertexDesc.attributes[0].bufferIndex = 0
                vertexDesc.attributes[1].format = .float4
                vertexDesc.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride 
                vertexDesc.attributes[1].bufferIndex = 0
                vertexDesc.layouts[0].stride = MemoryLayout<Vertex>.stride
                vertexDesc.layouts[0].stepRate = 1
                vertexDesc.layouts[0].stepFunction = .perVertex
                desc.vertexDescriptor = vertexDesc
                
                self.pipelineState = try? device.makeRenderPipelineState(descriptor: desc)
            }
        }
        
        func setPipeline(_ pipeline: HDTEPipeline) {
            self.pipeline = pipeline
        }
        
        func setNavigation(_ navigation: TopologicalNavigationController) {
            self.navigation = navigation
        }
        
        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
        
        public func draw(in view: MTKView) {
            print("RENDERING FRAME - View size: \(view.frame.size)")
            
            guard let drawable = view.currentDrawable,
                  let commandBuffer = MetalContext.shared.commandQueue.makeCommandBuffer() else { 
                print("Draw Error: Failed to get drawable or command buffer")
                return 
            }
            
            // Phase 5: Volumetric Ray-Marching (Compute)
            
            // 1. Uniforms
            let width = Float(drawable.texture.width)
            let height = Float(drawable.texture.height)
            let aspectRatio = width / height
            
            let projectionMatrix = matrix_perspective_right_hand(fovyRadians: Float.pi / 3, aspectRatio: aspectRatio, nearZ: 0.1, farZ: 1000.0)
            
            // FORCE HARDCODED CAMERA to bypass Navigation Controller defaults
            // Look from High Up and Angled Down
            let eye = SIMD3<Float>(0, 10, 10) 
            // let eye = navigation?.cameraPosition ?? SIMD3<Float>(0, 5, 5)
            let center = navigation?.cameraTarget ?? SIMD3<Float>(0, 0, 0)
            let up = SIMD3<Float>(0, 1, 0)
            let viewMatrix = matrix_look_at_right_hand(eye: eye, target: center, up: up)
            
            let animationTime = Float(CACurrentMediaTime())
            
            struct WireframeUniforms {
                var mvpMatrix: matrix_float4x4
                var time: Float
            }
            
            let mvp = projectionMatrix * viewMatrix
            var wireUniforms = WireframeUniforms(mvpMatrix: mvp, time: animationTime)
            
            // 0.5 Render Pass (Clear & Draw)
            let renderPass = view.currentRenderPassDescriptor
            renderPass?.colorAttachments[0].loadAction = .clear
            renderPass?.colorAttachments[0].clearColor = MTLClearColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0) // BRIGHT RED
            
            if let rpd = renderPass, let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: rpd) {
                renderEncoder.label = "Wireframe Grid"
                
                if let pso = self.pipelineState, let vBuf = vertexBuffer, let iBuf = indexBuffer {
                    renderEncoder.setRenderPipelineState(pso)
                    renderEncoder.setDepthStencilState(makeDepthState(device: MetalContext.shared.device))
                    
                    renderEncoder.setVertexBuffer(vBuf, offset: 0, index: 0)
                    renderEncoder.setVertexBytes(&wireUniforms, length: MemoryLayout<WireframeUniforms>.stride, index: 1)
                    
                    renderEncoder.setTriangleFillMode(.lines) // Wireframe Mode
                    renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                        indexCount: indexCount,
                                                        indexType: .uint32,
                                                        indexBuffer: iBuf,
                                                        indexBufferOffset: 0)
                }
                renderEncoder.endEncoding()
            }
            
            // Disable Compute (User requested "Simple Grid")
            /*
            // 2. Dispatch Compute
            if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
               // ...
            }
            */
            
            commandBuffer.addCompletedHandler { cb in
                if let error = cb.error {
                    print("CRITICAL GPU ERROR: \(error)")
                }
            }
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
        
        func makeDepthState(device: MTLDevice) -> MTLDepthStencilState? {
            let desc = MTLDepthStencilDescriptor()
            desc.depthCompareFunction = .less
            desc.isDepthWriteEnabled = true
            return device.makeDepthStencilState(descriptor: desc)
        }
        
        // MARK: - Gestures
        
        @objc func handlePan(_ gesture: NSPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            let delta = SIMD2<Float>(Float(translation.x), Float(translation.y))
            
            let viewport = SIMD2<Float>(Float(gesture.view?.bounds.width ?? 1), Float(gesture.view?.bounds.height ?? 1))
            
            navigation?.handleDrag(delta: delta, inViewportSize: viewport)
            gesture.setTranslation(.zero, in: gesture.view)
        }
        
        @objc func handleMagnify(_ gesture: NSMagnificationGestureRecognizer) {
            guard let nav = navigation else { return }
            // gesture.magnification is delta
            // +1.0 doubles size, so we invert logic for radius
            let zoomDelta = Float(gesture.magnification) * 10.0
            nav.handleZoom(delta: zoomDelta)
            gesture.magnification = 0
        }
    }
}

// MARK: - Math Helpers needed for Matrix construction locally if not in OmniGeometry yet
// (Ideally import OmniGeometry, but adding here for self-containment if needed)

func matrix_perspective_right_hand(fovyRadians fovy: Float, aspectRatio: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    let ys = 1 / tanf(fovy * 0.5)
    let xs = ys / aspectRatio
    let zs = farZ / (nearZ - farZ)
    return matrix_float4x4.init(columns: (vector_float4(xs,  0, 0,   0),
                                          vector_float4( 0, ys, 0,   0),
                                          vector_float4( 0,  0, zs, -1),
                                          vector_float4( 0,  0, nearZ * zs, 0)))
}

func matrix_look_at_right_hand(eye: SIMD3<Float>, target: SIMD3<Float>, up: SIMD3<Float>) -> matrix_float4x4 {
    let z = normalize(eye - target)
    let x = normalize(cross(up, z))
    let y = cross(z, x)
    return matrix_float4x4.init(columns: (vector_float4(x.x, y.x, z.x, 0),
                                          vector_float4(x.y, y.y, z.y, 0),
                                          vector_float4(x.z, y.z, z.z, 0),
                                          vector_float4(dot(-x, eye), dot(-y, eye), dot(-z, eye), 1)))
}

func matrix_float4x4_rotation(angle: Float, axis: SIMD3<Float>) -> matrix_float4x4 {
    let normalizedAxis = normalize(axis)
    let ct = cosf(angle)
    let st = sinf(angle)
    let ci = 1 - ct
    let x = normalizedAxis.x, y = normalizedAxis.y, z = normalizedAxis.z
    return matrix_float4x4(columns: (
        vector_float4(ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
        vector_float4(x * y * ci - z * st, ct + y * y * ci, z * y * ci + x * st, 0),
        vector_float4(x * z * ci + y * st, y * z * ci - x * st, ct + z * z * ci, 0),
        vector_float4(0, 0, 0, 1)
    ))
}

extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> {
        return SIMD3<Float>(x, y, z)
    }
}
