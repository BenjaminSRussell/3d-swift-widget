import Metal
import OmniCoreTypes

/// Phase 15.3: Post-Processing Controller
/// Orchestrates Bloom passes and the final lens effect composition.
public final class PostProcessor {
    
    private let thresholdKernel: ComputeKernel
    private let blurKernel: ComputeKernel
    private let downsampleKernel: ComputeKernel
    private let finalPassKernel: ComputeKernel
    private let taaResolveKernel: ComputeKernel
    
    // Expert Panel: Rendering Architect - Enhanced Pipeline
    private let lensDirtKernel: ComputeKernel
    private let toneMappingKernel: ComputeKernel
    private let ditherKernel: ComputeKernel
    
    // Managed Textures (Pyramid)
    private var bloomHalf: MTLTexture?
    private var bloomQuarter: MTLTexture?
    private var bloomEighth: MTLTexture?
    private var bloomSixteenth: MTLTexture?
    
    // TAA History
    private var historyTexture: MTLTexture?
    private var accumulationTexture: MTLTexture?
    private var compositionTexture: MTLTexture? // HDR Composition Target
    
    // Static Assets
    private var glassTexture: MTLTexture?
    
    // Expert Panel: Enhanced Assets
    private var lensDirtTexture: MTLTexture?
    private var blueNoiseTexture: MTLTexture?
    
    public init() throws {
        self.thresholdKernel = try ComputeKernel(functionName: "bloom_threshold")
        self.downsampleKernel = try ComputeKernel(functionName: "dual_kawase_down")
        self.finalPassKernel = try ComputeKernel(functionName: "apply_post_process")
        self.blurKernel = try ComputeKernel(functionName: "dual_kawase_up")
        self.taaResolveKernel = try ComputeKernel(functionName: "taa_resolve")
        
        // Expert Panel: New Kernels
        self.lensDirtKernel = try ComputeKernel(functionName: "apply_lens_dirt")
        self.toneMappingKernel = try ComputeKernel(functionName: "aces_tone_map")
        self.ditherKernel = try ComputeKernel(functionName: "apply_blue_noise_dither")
    }
    
    public func process(commandBuffer: MTLCommandBuffer, 
                        sceneTexture: MTLTexture, 
                        bloomPing: MTLTexture, // Kept for compatibility but unused if we manage our own
                        bloomPong: MTLTexture,
                        outputTexture: MTLTexture,
                        frameUniforms: MTLBuffer,
                        settingsBuffer: MTLBuffer? = nil) {
        
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        ensureTextures(device: sceneTexture.device, width: sceneTexture.width, height: sceneTexture.height)
        
        guard let half = bloomHalf, 
              let quarter = bloomQuarter, 
              let eighth = bloomEighth, 
              let sixteenth = bloomSixteenth else {
            encoder.endEncoding()
            return
        }
        
        // 1. Threshold (On Full/Half or pre-downsample)
        // For efficiency, threshold the half-res
        encoder.setTexture(sceneTexture, index: 0)
        encoder.setTexture(half, index: 1)
        thresholdKernel.dispatch(encoder: encoder, gridSize: MTLSize(width: half.width, height: half.height, depth: 1))
        
        // 2. Downsampling Chain (Dual Kawase Down)
        // Half -> Quarter
        encoder.setTexture(half, index: 0)
        encoder.setTexture(quarter, index: 1)
        downsampleKernel.dispatch(encoder: encoder, gridSize: MTLSize(width: quarter.width, height: quarter.height, depth: 1))
        
        // Quarter -> Eighth
        encoder.setTexture(quarter, index: 0)
        encoder.setTexture(eighth, index: 1)
        downsampleKernel.dispatch(encoder: encoder, gridSize: MTLSize(width: eighth.width, height: eighth.height, depth: 1))
        
        // Eighth -> Sixteenth
        encoder.setTexture(eighth, index: 0)
        encoder.setTexture(sixteenth, index: 1)
        downsampleKernel.dispatch(encoder: encoder, gridSize: MTLSize(width: sixteenth.width, height: sixteenth.height, depth: 1))
        
        // 3. Upsampling Chain (Dual Kawase Up)
        var offset: Float = 1.0
        
        // Sixteenth -> Eighth
        encoder.setTexture(sixteenth, index: 0)
        encoder.setTexture(eighth, index: 1)
        encoder.setBytes(&offset, length: 4, index: 0)
        blurKernel.dispatch(encoder: encoder, gridSize: MTLSize(width: eighth.width, height: eighth.height, depth: 1))
        
        // Eighth -> Quarter
        encoder.setTexture(eighth, index: 0)
        encoder.setTexture(quarter, index: 1)
        blurKernel.dispatch(encoder: encoder, gridSize: MTLSize(width: quarter.width, height: quarter.height, depth: 1))
        
        // Quarter -> Half
        encoder.setTexture(quarter, index: 0)
        encoder.setTexture(half, index: 1)
        blurKernel.dispatch(encoder: encoder, gridSize: MTLSize(width: half.width, height: half.height, depth: 1))
        
        // 4. TAA Resolve
        guard let accumulation = accumulationTexture, 
              let history = historyTexture,
              let half = bloomHalf,
              let comp = compositionTexture else {
            encoder.endEncoding()
            return
        }
        
        encoder.setTexture(sceneTexture, index: 0)
        encoder.setTexture(history, index: 1)
        encoder.setTexture(accumulation, index: 2)
        encoder.setBuffer(frameUniforms, offset: 0, index: 0)
        if let settings = settingsBuffer {
            encoder.setBuffer(settings, offset: 0, index: 1)
        }
        taaResolveKernel.dispatch(encoder: encoder, gridSize: MTLSize(width: sceneTexture.width, height: sceneTexture.height, depth: 1))
        
        // Expert Panel: Inject Lens Dirt into Bloom Result (Half)
        if let dirt = lensDirtTexture {
             // We reuse 'half' which is bloom result.
             // Kernel combines dirt texture into it additively or multiplicatively
             encoder.setTexture(half, index: 0)
             encoder.setTexture(dirt, index: 1)
             lensDirtKernel.dispatch(encoder: encoder, gridSize: MTLSize(width: half.width, height: half.height, depth: 1))
        }
        
        // 5. Final Compose -> HDR Texture (NOT Display)
        // Writes combined Scene + Bloom + Glass to 'compositionTexture' (HDR)
        encoder.setTexture(accumulation, index: 0) // Scene (HDR)
        encoder.setTexture(half, index: 1)         // Bloom (HDR)
        if let glass = glassTexture {
            encoder.setTexture(glass, index: 2)
        }
        encoder.setTexture(comp, index: 3) // Writes to HDR Composition
        encoder.setBuffer(frameUniforms, offset: 0, index: 0)
        if let settings = settingsBuffer {
            encoder.setBuffer(settings, offset: 0, index: 1)
        }
        finalPassKernel.dispatch(encoder: encoder, gridSize: MTLSize(width: comp.width, height: comp.height, depth: 1))
        
        // 6. ACES Tone Mapping (HDR -> SDR)
        // Reads 'comp', Writes 'outputTexture' (Display)
        encoder.setTexture(comp, index: 0)
        encoder.setTexture(outputTexture, index: 1)
        toneMappingKernel.dispatch(encoder: encoder, gridSize: MTLSize(width: outputTexture.width, height: outputTexture.height, depth: 1))
        
        // 7. Blue Noise Dithering (SDR refinement)
        if let blueNoise = blueNoiseTexture {
             encoder.setTexture(outputTexture, index: 0) // Read/Write
             encoder.setTexture(blueNoise, index: 1)
             ditherKernel.dispatch(encoder: encoder, gridSize: MTLSize(width: outputTexture.width, height: outputTexture.height, depth: 1))
        }
        
        encoder.endEncoding()
        
        // Finalize: Copy accumulation to history for next frame
        if let copyEncoder = commandBuffer.makeBlitCommandEncoder() {
            copyEncoder.copy(from: accumulation, to: history)
            copyEncoder.endEncoding()
        }
    }
    
    private func ensureTextures(device: MTLDevice, width: Int, height: Int) {
        if bloomHalf?.width != width / 2 || bloomHalf?.height != height / 2 {
            let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: width / 2, height: height / 2, mipmapped: false)
            desc.usage = [.shaderRead, .shaderWrite]
            bloomHalf = device.makeTexture(descriptor: desc)
            
            desc.width = width / 4
            desc.height = height / 4
            bloomQuarter = device.makeTexture(descriptor: desc)
            
            desc.width = width / 8
            desc.height = height / 8
            bloomEighth = device.makeTexture(descriptor: desc)
            
            // Full resolution HDR Composition target (Pre-ToneMap)
            desc.width = width
            desc.height = height
            self.compositionTexture = device.makeTexture(descriptor: desc)
            
            desc.width = width / 16
            desc.height = height / 16
            bloomSixteenth = device.makeTexture(descriptor: desc)
            
            // TAA Textures
            let taaDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: width, height: height, mipmapped: false)
            taaDesc.usage = [.shaderRead, .shaderWrite]
            historyTexture = device.makeTexture(descriptor: taaDesc)
            accumulationTexture = device.makeTexture(descriptor: taaDesc)
            
            // Generate Glass
            createGlassTexture(device: device)
            
            // Expert Panel: Generate Lens Dirt and Blue Noise
            createLensDirtTexture(device: device)
            createBlueNoiseTexture(device: device)
        }
    }
    
    private func createGlassTexture(device: MTLDevice) {
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 512, height: 512, mipmapped: false)
        desc.usage = [.shaderRead]
        self.glassTexture = device.makeTexture(descriptor: desc)
        
        var data = [UInt8](repeating: 0, count: 512 * 512 * 4)
        for i in 0..<512*512 {
            // Procedural noise for scratches (r) and fingerprints (g)
            let x = Float(i % 512) / 512.0
            let y = Float(i / 512) / 512.0
            
            let scratch = sin(x * 100 + y * 20) * 0.5 + 0.5 > 0.98 ? UInt8(255) : 0
            let fingerprint = sin(x * 5 + y * 5) * 0.5 + 0.5 > 0.8 ? UInt8(128) : 0
            
            data[i*4 + 0] = scratch
            data[i*4 + 1] = fingerprint
            data[i*4 + 2] = 0
            data[i*4 + 3] = 255
        }
        
        glassTexture?.replace(region: MTLRegionMake2D(0, 0, 512, 512), mipmapLevel: 0, withBytes: data, bytesPerRow: 512 * 4)
    }
    
    // MARK: - Expert Panel: Enhanced Texture Generation
    
    /// Creates lens dirt texture for physically grounded bloom
    /// Expert Panel: Rendering Architect - Bloom catches invisible scratches/dust
    private func createLensDirtTexture(device: MTLDevice) {
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: 512, height: 512, mipmapped: false)
        desc.usage = [.shaderRead]
        self.lensDirtTexture = device.makeTexture(descriptor: desc)
        
        var data = [UInt8](repeating: 0, count: 512 * 512)
        
        // Generate procedural lens dirt (fingerprints, dust, scratches)
        for y in 0..<512 {
            for x in 0..<512 {
                let fx = Float(x) / 512.0
                let fy = Float(y) / 512.0
                
                // Radial falloff (dirt accumulates at edges)
                let centerDist = sqrt(pow(fx - 0.5, 2) + pow(fy - 0.5, 2))
                let radialFalloff = smoothstep(0.0, 0.7, centerDist)
                
                // Fingerprint smudges (low frequency)
                let smudge = (sin(fx * 3.0) * cos(fy * 3.0) * 0.5 + 0.5) * 0.3
                
                // Dust particles (high frequency)
                let dust = (sin(fx * 50.0 + fy * 30.0) * 0.5 + 0.5) > 0.95 ? 0.5 : 0.0
                
                // Scratches (directional)
                let scratch = (sin(fx * 100.0 + fy * 20.0) * 0.5 + 0.5) > 0.98 ? 0.7 : 0.0
                
                // Combine all dirt components
                let dirtBase = Float(radialFalloff * 0.2)
                let dirtSum = dirtBase + Float(smudge) + Float(dust) + Float(scratch)
                let dirt = min(Float(1.0), dirtSum)
                data[y * 512 + x] = UInt8(dirt * 255.0)
            }
        }
        
        lensDirtTexture?.replace(region: MTLRegionMake2D(0, 0, 512, 512), mipmapLevel: 0, withBytes: data, bytesPerRow: 512)
    }
    
    /// Creates blue noise texture for gradient dithering
    /// Expert Panel: Color Scientist - Eliminates banding in transparent gradients
    private func createBlueNoiseTexture(device: MTLDevice) {
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: 64, height: 64, mipmapped: false)
        desc.usage = [.shaderRead]
        self.blueNoiseTexture = device.makeTexture(descriptor: desc)
        
        var data = [UInt8](repeating: 0, count: 64 * 64)
        
        // Generate pseudo-blue noise (simplified)
        // In production, use pre-generated blue noise texture
        var seed: UInt32 = 12345
        for i in 0..<(64 * 64) {
            // Simple LCG random
            seed = seed &* 1664525 &+ 1013904223
            let noise = Float(seed) / Float(UInt32.max)
            data[i] = UInt8(noise * 255.0)
        }
        
        blueNoiseTexture?.replace(region: MTLRegionMake2D(0, 0, 64, 64), mipmapLevel: 0, withBytes: data, bytesPerRow: 64)
    }
    
    /// Smoothstep interpolation
    private func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }
}

