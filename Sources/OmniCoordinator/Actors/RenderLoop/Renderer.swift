import Metal
import MetalKit
import SwiftUI
import OmniGeometry
import OmniStochastic
import OmniCore
import OmniCoreTypes
import OmniMath

// Pillar 3: OmniCoordinator - render loop
@globalActor public actor RenderActor {
    public static let shared = RenderActor()
}

public struct RenderSettings {
    public var bloomIntensity: Float = 0.5
    public var chromaticAberration: Float = 0.005
}

@Observable
public class Renderer: NSObject, MTKViewDelegate {
    public let device: MTLDevice
    public let commmandQueue: MTLCommandQueue
    
    // Pipelines
    var geometryPipeline: GeometryPipeline?
    var stochasticPipeline: StochasticPipeline?
    
    // Actors
    var dataActor: DataActor
    
    // Infrastructure
    var icb: MTLIndirectCommandBuffer?
    var icbArgumentBuffer: MTLBuffer?
    var spectrogramTexture: MTLTexture?
    var watchdog: GPUWatchdog?
    var themeBuffer: MTLBuffer?
    var mvpBuffer: MTLBuffer?
    
    // Post-Processing
    var postProcessor: PostProcessor?
    var hdrSceneTexture: MTLTexture?
    public var postProcessSettings = RenderSettings()
    
    // Phase 4: Modern Infrastructure
    private let renderGraph: RenderGraph
    private var frameIndex: UInt = 0
    private var prevViewProj: simd_float4x4 = matrix_identity_float4x4
    private let haltonSequence: [SIMD2<Float>] = [
        SIMD2(0.5, 0.333), SIMD2(0.25, 0.666), SIMD2(0.75, 0.111), SIMD2(0.125, 0.444),
        SIMD2(0.625, 0.777), SIMD2(0.375, 0.222), SIMD2(0.875, 0.555), SIMD2(0.0625, 0.888)
    ]
    
    // Camera
    public let camera = CameraController()
    
    // Interaction
    public let interactionSystem: InteractionSystem
    
    // Stochastic data
    public var stochasticDataChannel: StochasticDataChannel?
    private let pointsCount = 1000 // Number of data points to decompose
    
    // Theme
    public var theme: ThemeConfig = ThemeConfig.standard {
        didSet { updateThemeBuffer() }
    }
    
    func updateThemeBuffer() {
        var t = self.theme
        themeBuffer = device.makeBuffer(bytes: &t, length: MemoryLayout<ThemeConfig>.stride, options: .storageModeShared)
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    // 2. Add the Math Pipeline State
    private let terrainGenerator: ProceduralTerrainGenerator // From OmniMath
    private let fluidSolver: FluidDynamicsSolver // From OmniMath

    public override init() {
        // Use shared context device
        let d = MetalContext.shared.device
        self.device = d
        self.commmandQueue = MetalContext.shared.commandQueue // Use shared queue
        self.dataActor = DataActor(device: d)
        self.interactionSystem = InteractionSystem(device: d)
        self.renderGraph = RenderGraph(device: d)
        
        // 3. Initialize the Endless Math Engines
        // Use shared MetalContext
        let metalContext = MetalContext.shared
        self.terrainGenerator = ProceduralTerrainGenerator(context: metalContext)
        self.fluidSolver = FluidDynamicsSolver(context: metalContext)

        
        // Create MVP buffer
        var identity = matrix_identity_float4x4
        mvpBuffer = d.makeBuffer(bytes: &identity, length: MemoryLayout<simd_float4x4>.stride, options: .storageModeShared)
        
        super.init()
        
        // Setup Watchdog
        self.watchdog = GPUWatchdog(device: d)
        
        // Setup PostProcessor
        do {
            self.postProcessor = try PostProcessor()
        } catch {
            print("Failed to init PostProcessor: \(error)")
        }
        
        // Setup Stochastic Channel
        do {
            self.stochasticDataChannel = try StochasticDataChannel(device: d, numPoints: pointsCount)
        } catch {
            print("Failed to init StochasticDataChannel: \(error)")
        }
        
        // Setup Theme
        updateThemeBuffer()
    }

    // Helper for Math Kernels
    var cameraUniforms: FrameUniforms {
        // Construct uniforms based on current state. 
        // Note: Resolution and specific jitter might be frame-dependent and ideally passed in, 
        // but for this integration we approximate or use cached values if available.
        // We will return a basic uniform set here to satisfy the compiler and runtime.
        return FrameUniforms(
            viewMatrix: matrix_identity_float4x4, // Should be updated with real camera data if possible
            projectionMatrix: matrix_identity_float4x4,
            viewProjectionMatrix: self.prevViewProj, // Using stored MVP
            inverseViewProjectionMatrix: simd_inverse(self.prevViewProj),
            prevViewProjectionMatrix: self.prevViewProj,
            cameraPosition: SIMD3<Float>(0,0,0), // Should get from camera controller
            time: Float(CACurrentMediaTime()),
            resolution: [1920, 1080], // Default/Placeholder
            jitter: SIMD2<Float>(0,0),
            deltaTime: 1.0/60.0,
            frameCount: UInt32(self.frameIndex),
            lights: (PointLight(), PointLight(), PointLight(), PointLight()),
            lightCount: 0
        )
    }

    public func draw(in view: MTKView) {
        let cpuStart = CFAbsoluteTimeGetCurrent()
        Task { await watchdog?.ping() } // Signal health
        
        // Initialize pipelines exactly ONCE on the first draw frame if lazy loading
        if geometryPipeline == nil {
            do {
                geometryPipeline = try GeometryPipeline(device: device, pixelFormat: view.colorPixelFormat)
                
                // Create ICB
                let icbDescriptor = MTLIndirectCommandBufferDescriptor()
                icbDescriptor.commandTypes = .drawMeshThreadgroups
                icbDescriptor.inheritBuffers = true 
                icbDescriptor.maxVertexBufferBindCount = 0
                icbDescriptor.maxFragmentBufferBindCount = 0
                icbDescriptor.inheritPipelineState = true 
                
                icb = device.makeIndirectCommandBuffer(descriptor: icbDescriptor, maxCommandCount: 1, options: [])
                
                // Create Argument Buffer for ICB
                if let icbFunc = geometryPipeline?.icbFunction.makeArgumentEncoder(bufferIndex: 1) {
                    icbArgumentBuffer = device.makeBuffer(length: icbFunc.encodedLength, options: [])
                    icbFunc.setArgumentBuffer(icbArgumentBuffer, offset: 0)
                    icbFunc.setIndirectCommandBuffer(icb, index: 0)
                }
                
                // Create Spectrogram Texture (Data Flow)
                let textureDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float, width: 256, height: 256, mipmapped: false)
                textureDesc.usage = [.shaderRead, .shaderWrite]
                spectrogramTexture = device.makeTexture(descriptor: textureDesc)
                
            } catch {
                print("Failed to create geometry pipeline: \(error)")
            }
        }
        
        if stochasticPipeline == nil {
            do {
                stochasticPipeline = try StochasticPipeline(device: device)
            } catch {
                print("Failed to create stochastic pipeline: \(error)")
            }
        }

        guard let commandBuffer = commmandQueue.makeCommandBuffer() else { return }
        
        // 4. INTEGRATION: Run the Math Kernels FIRST
        // This generates the geometry and moves the fluid particles
        if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
            terrainGenerator.dispatch(encoder: computeEncoder, camera: self.cameraUniforms)
            fluidSolver.dispatch(encoder: computeEncoder, dt: 1.0/60.0)
            computeEncoder.endEncoding()
        }

        
        // 1. Prepare Frame Data & Jitter
        frameIndex &+= 1
        let jitter = haltonSequence[Int(frameIndex % 8)]
        let pixelSize = SIMD2<Float>(1.0 / Float(view.drawableSize.width), 1.0 / Float(view.drawableSize.height))
        let subpixelJitter = (jitter - 0.5) * pixelSize
        
        let aspect = Float(view.bounds.width / view.bounds.height)
        
        // 2. Build RenderGraph
        renderGraph.reset()
        
        // Pass A: Compute (OmniStochastic)
        renderGraph.addPass(name: "Stochastic Compute") { cb in
            if let stochasticPSO = self.stochasticPipeline?.nutsSamplerState,
               let spectrogram = self.spectrogramTexture,
               let encoder = cb.makeComputeCommandEncoder() {
                encoder.setComputePipelineState(stochasticPSO)
                encoder.setTexture(spectrogram, index: 0)
                encoder.dispatchThreadgroups(MTLSize(width: 1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 1, depth: 1))
                encoder.endEncoding()
            }
        }
        
        // Pass B: ICB Update
        renderGraph.addPass(name: "ICB Update") { cb in
            if let icbPSO = self.geometryPipeline?.icbPipelineState,
               let icb = self.icb,
               let icbArgFn = self.icbArgumentBuffer,
               let encoder = cb.makeComputeCommandEncoder() {
                encoder.setComputePipelineState(icbPSO)
                encoder.setBuffer(icbArgFn, offset: 0, index: 1)
                encoder.useResource(icb, usage: .write)
                encoder.dispatchThreadgroups(MTLSize(width: 1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
                encoder.endEncoding()
            }
        }
        
        // Pass C: Geometry Rendering
        renderGraph.addPass(name: "Geometry Pass") { cb in
            guard let hdrTexture = self.hdrSceneTexture,
                  let viewDescriptor = view.currentRenderPassDescriptor else { return }
            
            viewDescriptor.colorAttachments[0].texture = hdrTexture
            viewDescriptor.colorAttachments[0].loadAction = .clear
            viewDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            viewDescriptor.colorAttachments[0].storeAction = .store

            if let renderEncoder = cb.makeRenderCommandEncoder(descriptor: viewDescriptor),
               let ridgePSO = self.geometryPipeline?.ridgeLinePipelineState,
               let icb = self.icb,
               let mvpBuf = self.mvpBuffer,
               let themeBuf = self.themeBuffer {
                renderEncoder.setRenderPipelineState(ridgePSO)
                renderEncoder.setFragmentTexture(self.spectrogramTexture, index: 0) 
                renderEncoder.setMeshBuffer(mvpBuf, offset: 0, index: 0)
                renderEncoder.setMeshBuffer(themeBuf, offset: 0, index: 1)
                
                if let stochasticChannel = self.stochasticDataChannel {
                    renderEncoder.setMeshBuffer(stochasticChannel.positionBuffer, offset: 0, index: 2)
                    renderEncoder.setMeshBuffer(stochasticChannel.intensityBuffer, offset: 0, index: 3)
                }
                
                renderEncoder.setFragmentBuffer(themeBuf, offset: 0, index: 0)
                renderEncoder.executeCommandsInBuffer(icb, range: 0..<1) 
                renderEncoder.endEncoding()
            }
        }
        
        // Pass D: Post-Processing & TAA
        renderGraph.addPass(name: "Post-Processing") { cb in
            guard let hdrTexture = self.hdrSceneTexture,
                  let postProc = self.postProcessor,
                  let drawable = view.currentDrawable else { return }
            
            struct PPSettings {
                var bloomIntensity: Float
                var aberration: Float
                var focusScore: Float
                var taaWeight: Float
            }
            
            let focus = self.interactionSystem.entropyMonitor.normalizedEntropy
            var ppSettings = PPSettings(bloomIntensity: self.postProcessSettings.bloomIntensity, 
                                        aberration: self.postProcessSettings.chromaticAberration, 
                                        focusScore: focus,
                                        taaWeight: 0.9)
            
            var uniforms = FrameUniforms(
                viewMatrix: matrix_identity_float4x4, // Placeholder if not used in PP
                projectionMatrix: matrix_identity_float4x4,
                viewProjectionMatrix: matrix_identity_float4x4,
                inverseViewProjectionMatrix: matrix_identity_float4x4,
                prevViewProjectionMatrix: self.prevViewProj,
                cameraPosition: SIMD3<Float>(0,0,0),
                time: Float(CACurrentMediaTime()),
                resolution: [Float(hdrTexture.width), Float(hdrTexture.height)],
                jitter: subpixelJitter,
                deltaTime: 0.016,
                frameCount: UInt32(self.frameIndex),
                lights: (PointLight(), PointLight(), PointLight(), PointLight()),
                lightCount: 0
            )

            if let uniBuf = self.device.makeBuffer(bytes: &uniforms, length: MemoryLayout<FrameUniforms>.stride, options: []),
               let setBuf = self.device.makeBuffer(bytes: &ppSettings, length: MemoryLayout<PPSettings>.stride, options: []) {
                postProc.process(commandBuffer: cb,
                                 sceneTexture: hdrTexture,
                                 bloomPing: hdrTexture,
                                 bloomPong: hdrTexture, 
                                 outputTexture: drawable.texture,
                                 frameUniforms: uniBuf,
                                 settingsBuffer: setBuf)
            }
            cb.present(drawable)
        }
        
        // 3. Execution
        Task {
            // Stochastic Update
            if self.stochasticDataChannel != nil {
                let time = Float(CFAbsoluteTimeGetCurrent())
                var signal = [Float](repeating: 0, count: self.pointsCount * 10)
                for i in 0..<self.pointsCount {
                    for j in 0..<10 {
                        signal[i*10 + j] = sin(time * Float(j+1) * 0.5 + Float(i) * 0.1) * 0.5 + 0.5
                    }
                }
                // We'll dispatch this via a manual command buffer or just update the buffers
                // For now, assume it's buffered and updated.
            }
            
            // Update MVP Matrix with Jitter
            let viewMatrix = await camera.viewMatrix()
            var projectionMatrix = matrix_perspective_right_hand(fovyRadians: Float.pi / 3.0, aspectRatio: aspect, nearZ: 0.1, farZ: 100.0)
            
            // Apply Jitter to Projection Matrix
            projectionMatrix.columns.2.x += subpixelJitter.x * 2.0
            projectionMatrix.columns.2.y += subpixelJitter.y * 2.0
            
            let mvp = matrix_multiply(projectionMatrix, viewMatrix)
            var mvpCopy = mvp
            self.mvpBuffer?.contents().copyMemory(from: &mvpCopy, byteCount: MemoryLayout<simd_float4x4>.stride)
            
            // Store for next frame
            self.prevViewProj = mvp
        }
        
        renderGraph.execute(commandBuffer: commandBuffer)
        
        commandBuffer.addCompletedHandler { cb in
            let gpuDuration = cb.gpuEndTime - cb.gpuStartTime
            let cpuDuration = CFAbsoluteTimeGetCurrent() - cpuStart
            PerformanceMetrics.update(cpuDuration: cpuDuration, gpuDuration: gpuDuration)
        }
        
        commandBuffer.commit()
    }
}
