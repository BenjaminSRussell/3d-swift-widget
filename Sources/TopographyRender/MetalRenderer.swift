import MetalKit
import TopographyCore
import simd

public class MetalRenderer: NSObject, MTKViewDelegate {
    public var device: MTLDevice!
    public var commandQueue: MTLCommandQueue!
    public var pipelineState: MTLRenderPipelineState!
    public var depthStencilState: MTLDepthStencilState!
    
    private var vertexBuffer: MTLBuffer?
    private var indexBuffer: MTLBuffer?
    private var indexCount: Int = 0
    
    // Camera / Interactivity
    public var rotationX: Float = 0
    public var rotationY: Float = 0
    public var distance: Float = 100.0 // Adjusted for larger terrain
    
    private var currentData: TerrainData?
    
    public init?(metalKitView: MTKView) {
        super.init()
        
        let context = MetalContext.shared
        self.device = context.device
        self.commandQueue = context.commandQueue
        
        metalKitView.device = device
        metalKitView.colorPixelFormat = .bgra8Unorm
        metalKitView.depthStencilPixelFormat = .depth32Float
        metalKitView.delegate = self
        
        // Target 120 FPS for ProMotion displays
        metalKitView.preferredFramesPerSecond = 120
        
        buildPipeline()
        buildDepthState()
    }
    
    private func buildPipeline() {
        let library = try? device.makeDefaultLibrary(bundle: Bundle.module)
        let vertexFunction = library?.makeFunction(name: "terrain_vertex")
        let fragmentFunction = library?.makeFunction(name: "terrain_fragment")
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.depthAttachmentPixelFormat = .depth32Float
        
        let vertexDescriptor = MTLVertexDescriptor()
        // Position
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        // Normal
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = 0
        vertexDescriptor.attributes[1].bufferIndex = 1
        
        vertexDescriptor.layouts[0].stride = MemoryLayout<simd_float3>.stride
        vertexDescriptor.layouts[1].stride = MemoryLayout<simd_float3>.stride
        
        descriptor.vertexDescriptor = vertexDescriptor
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("Failed to create pipeline state: \(error)")
        }
    }
    
    private func buildDepthState() {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.isDepthWriteEnabled = true
        descriptor.depthCompareFunction = .less
        depthStencilState = device.makeDepthStencilState(descriptor: descriptor)
    }
    
    public func updateTerrain(data: TerrainData) {
        self.currentData = data
        
        var vertices = [simd_float3]()
        var normals = [simd_float3]()
        var indices = [UInt32]()
        
        let width = data.width
        let depth = data.depth
        let scale: Float = 1.0
        
        // Generate Vertices (Centered)
        let offsetX = -Float(width) * scale / 2.0
        let offsetZ = -Float(depth) * scale / 2.0
        
        for z in 0..<depth {
            for x in 0..<width {
                let h = data.height(at: x, z: z)
                let px = Float(x) * scale + offsetX
                let pz = Float(z) * scale + offsetZ
                vertices.append(simd_float3(px, h, pz))
                
                // Placeholder Normals (Up) - For 4k detail we should calculate these properly
                // Simple finite difference for normals
                let hL = data.height(at: max(0, x-1), z: z)
                let hR = data.height(at: min(width-1, x+1), z: z)
                let hD = data.height(at: x, z: max(0, z-1))
                let hU = data.height(at: x, z: min(depth-1, z+1))
                
                let normal = normalize(simd_float3(hL - hR, 2.0, hD - hU))
                normals.append(normal)
            }
        }
        
        // Generate Indices
        for z in 0..<(depth - 1) {
            for x in 0..<(width - 1) {
                let tl = UInt32(z * width + x)
                let tr = UInt32(tl + 1)
                let bl = UInt32((z + 1) * width + x)
                let br = UInt32(bl + 1)
                
                indices.append(contentsOf: [tl, bl, tr, tr, bl, br])
            }
        }
        
        indexCount = indices.count
        
        // Create Buffers
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<simd_float3>.stride, options: .storageModeShared)
        
        // Separate buffer for normals to match vertex descriptor binding
        let normalBuffer = device.makeBuffer(bytes: normals, length: normals.count * MemoryLayout<simd_float3>.stride, options: .storageModeShared)
        
        indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt32>.stride, options: .storageModeShared)
        
        // Hack: Store normal buffer in a way we can access it draw time if needed, 
        // or just recreate a combined buffer. For now, let's just make a member var
        self.normalBufferVar = normalBuffer
    }
    
    private var normalBufferVar: MTLBuffer?
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    public func draw(in view: MTKView) {
        guard let commandBuffer = MetalContext.shared.makeCommandBuffer(),
              let descriptor = view.currentRenderPassDescriptor,
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor),
              let pipelineState = pipelineState,
              let vertexBuffer = vertexBuffer,
              let normalBuffer = normalBufferVar,
              let indexBuffer = indexBuffer else { return }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        
        // Uniforms
        let aspect = Float(view.drawableSize.width / view.drawableSize.height)
        let projectionMatrix = Matrix4x4.perspective(fovy: Float.pi / 4, aspect: aspect, near: 0.1, far: 1000.0)
        
        // Camera View
        let eyeX = distance * sin(rotationY) * cos(rotationX)
        let eyeY = distance * sin(rotationX) + 20.0 // Keep a bit above
        let eyeZ = distance * cos(rotationY) * cos(rotationX)
        let viewMatrix = Matrix4x4.lookAt(eye: simd_float3(eyeX, eyeY, eyeZ), center: simd_float3(0, 0, 0), up: simd_float3(0, 1, 0))
        
        let modelMatrix = Matrix4x4.identity()
        
        struct Uniforms {
            var modelMatrix: matrix_float4x4
            var viewMatrix: matrix_float4x4
            var projectionMatrix: matrix_float4x4
        }
        
        var uniforms = Uniforms(modelMatrix: modelMatrix, viewMatrix: viewMatrix, projectionMatrix: projectionMatrix)
        
        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 2)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(normalBuffer, offset: 0, index: 1)
        
        renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: indexCount, indexType: .uint32, indexBuffer: indexBuffer, indexBufferOffset: 0)
        
        renderEncoder.endEncoding()
        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
        commandBuffer.commit()
    }
}
