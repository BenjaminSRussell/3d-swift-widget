import Metal
import MetalKit
import SwiftUI
import OmniGeometry
import OmniStochastic

// Pillar 3: OmniCoordinator - render loop
@globalActor public actor RenderActor {
    public static let shared = RenderActor()
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
    
    // Camera
    public let camera = CameraController()
    
    // Theme
    public var theme: ThemeConfig = ThemeConfig() {
        didSet { updateThemeBuffer() }
    }
    
    public override init() {
        guard let d = MTLCreateSystemDefaultDevice() else { fatalError("Metal not supported") }
        self.device = d
        self.commmandQueue = d.makeCommandQueue()!
        self.dataActor = DataActor(device: d)
        
        // Create MVP buffer
        var identity = matrix_identity_float4x4
        mvpBuffer = d.makeBuffer(bytes: &identity, length: MemoryLayout<simd_float4x4>.stride, options: .storageModeShared)
        
        super.init()
        
        // Setup Watchdog
        self.watchdog = GPUWatchdog(device: d)
        
        // Setup Theme
        updateThemeBuffer()
    }
    
    func updateThemeBuffer() {
        var t = self.theme
        themeBuffer = device.makeBuffer(bytes: &t, length: MemoryLayout<ThemeConfig>.stride, options: .storageModeShared)
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    public func draw(in view: MTKView) {
        Task { await watchdog?.ping() } // Signal health
        
        // Initialize pipelines exactly ONCE on the first draw frame if lazy loading
        // In production, do this async in init
        if geometryPipeline == nil {
            do {
                geometryPipeline = try GeometryPipeline(device: device, pixelFormat: view.colorPixelFormat)
                print("OmniGeometry Pipeline Created")
                
                // Create ICB
                let icbDescriptor = MTLIndirectCommandBufferDescriptor()
                icbDescriptor.commandTypes = .drawMeshThreadgroups
                icbDescriptor.inheritBuffers = false 
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
                print("OmniStochastic Pipeline Created")
            } catch {
                print("Failed to create stochastic pipeline: \(error)")
            }
        }

        guard let commandBuffer = commmandQueue.makeCommandBuffer(),
              let descriptor = view.currentRenderPassDescriptor,
              let geometryPSO = geometryPipeline?.pipelineState,
              let icbPSO = geometryPipeline?.icbPipelineState,
              let stochasticPSO = stochasticPipeline?.nutsSamplerState,
              let icb = icb,
              let icbArgFn = icbArgumentBuffer,
              let spectrogram = spectrogramTexture,
              let themeBuf = themeBuffer,
              let mvpBuf = mvpBuffer else { return }
        
        // Update MVP matrix
        Task {
            let aspect = Float(view.bounds.width / view.bounds.height)
            let mvp = await camera.viewProjectionMatrix(aspect: aspect)
            var mvpCopy = mvp
            mvpBuf.contents().copyMemory(from: &mvpCopy, byteCount: MemoryLayout<simd_float4x4>.stride)
        }
        
        // 1. Compute Pass (OmniStochastic)
        if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
            computeEncoder.setComputePipelineState(stochasticPSO)
            computeEncoder.setTexture(spectrogram, index: 0)
            computeEncoder.dispatchThreadgroups(MTLSize(width: 1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 1, depth: 1))
            computeEncoder.endEncoding()
        }
        
        // 2. ICB Update Pass (OmniGeometry - Genesis)
        if let icbEncoder = commandBuffer.makeComputeCommandEncoder() {
            icbEncoder.setComputePipelineState(icbPSO)
            icbEncoder.setBuffer(icbArgFn, offset: 0, index: 1)
            icbEncoder.useResource(icb, usage: .write) // Identify that we write to it
            icbEncoder.dispatchThreadgroups(MTLSize(width: 1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
            icbEncoder.endEncoding()
        }
        
        // 3. Render Pass (Execute ICB)
        if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) {
            // Use Ridge Line Pipeline (Type 14)
            if let ridgePSO = geometryPipeline?.ridgeLinePipelineState {
                renderEncoder.setRenderPipelineState(ridgePSO)
                renderEncoder.setFragmentTexture(spectrogram, index: 0) 
                renderEncoder.setMeshBuffer(mvpBuf, offset: 0, index: 0) // MVP Matrix
                renderEncoder.setMeshBuffer(themeBuf, offset: 0, index: 1) // Bind Theme to Buffer 1 for Mesh
                renderEncoder.setFragmentBuffer(themeBuf, offset: 0, index: 0) // Bind Theme to Buffer 0 for Frag
            } else {
                renderEncoder.setRenderPipelineState(geometryPSO)
            }
            
            // Execute the commands generated by the GPU
            renderEncoder.executeCommandsInBuffer(icb, range: 0..<1) 
            renderEncoder.endEncoding()
        }
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
    }
}
