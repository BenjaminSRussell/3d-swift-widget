import Foundation
import Metal
import MetalKit
import QuartzCore
import simd
import OmniData

/// Draws a `DatasetBuffer` as round, depth-sorted-by-hardware points.
///
/// The shader is compiled from source at runtime, so the demo does not depend on the
/// prebuilt metallib from `compile_shaders.sh`. Command-buffer failures are forwarded to
/// `onFailure` (wired to `GPUHealthMonitor.reportFailure`).
public final class DatasetPointRenderer: NSObject, MTKViewDelegate {
    public static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct Uniforms { float4x4 mvp; float pointScale; };
    struct VOut { float4 position [[position]]; float size [[point_size]]; float value; };

    vertex VOut omni_dataset_vertex(const device float4 *verts [[buffer(0)]],
                                    constant Uniforms &u [[buffer(1)]],
                                    uint vid [[vertex_id]]) {
        float4 v = verts[vid];
        VOut o;
        o.position = u.mvp * float4(v.xyz, 1.0);
        o.size = u.pointScale * (3.0 + 7.0 * v.w);
        o.value = v.w;
        return o;
    }

    fragment float4 omni_dataset_fragment(VOut in [[stage_in]], float2 pc [[point_coord]]) {
        float d = length(pc - 0.5);
        if (d > 0.5) discard_fragment();
        float3 cold = float3(0.20, 0.55, 1.00);
        float3 warm = float3(1.00, 0.45, 0.20);
        float3 c = mix(cold, warm, saturate(in.value));
        return float4(c * (1.0 - d), 1.0);
    }
    """

    public struct Uniforms { var mvp: simd_float4x4; var pointScale: Float }

    public let device: MTLDevice
    public let vertexCount: Int
    public var yawSpeed: Float = 0.25 // radians / second
    public var onFailure: ((String) -> Void)?
    /// Frames whose command buffers completed successfully (used to detect "black screen").
    public private(set) var completedFrames = 0

    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let depth: MTLDepthStencilState
    private let vertexBuffer: MTLBuffer
    private let start = CACurrentMediaTime()
    private let lock = NSLock()

    public enum SetupError: Error, CustomStringConvertible {
        case noQueue, noVertexBuffer, emptyDataset
        public var description: String {
            switch self {
            case .noQueue: return "Could not create a command queue"
            case .noVertexBuffer: return "Could not allocate the vertex buffer"
            case .emptyDataset: return "Dataset has no plottable rows"
            }
        }
    }

    public init(device: MTLDevice, vertices: [SIMD4<Float>],
                colorFormat: MTLPixelFormat = .bgra8Unorm, depthFormat: MTLPixelFormat = .depth32Float) throws {
        guard !vertices.isEmpty else { throw SetupError.emptyDataset }
        guard let q = device.makeCommandQueue() else { throw SetupError.noQueue }
        guard let vb = vertices.withUnsafeBytes({
            device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)
        }) else { throw SetupError.noVertexBuffer }
        let lib = try device.makeLibrary(source: Self.shaderSource, options: nil)
        let desc = MTLRenderPipelineDescriptor()
        desc.label = "OmniData points"
        desc.vertexFunction = lib.makeFunction(name: "omni_dataset_vertex")
        desc.fragmentFunction = lib.makeFunction(name: "omni_dataset_fragment")
        desc.colorAttachments[0].pixelFormat = colorFormat
        desc.depthAttachmentPixelFormat = depthFormat
        let dsd = MTLDepthStencilDescriptor()
        dsd.depthCompareFunction = .less
        dsd.isDepthWriteEnabled = true
        self.device = device
        self.queue = q
        self.vertexBuffer = vb
        self.vertexCount = vertices.count
        self.pipeline = try device.makeRenderPipelineState(descriptor: desc)
        self.depth = device.makeDepthStencilState(descriptor: dsd)!
        super.init()
    }

    public convenience init(device: MTLDevice, buffer: DatasetBuffer) throws {
        try self.init(device: device, vertices: buffer.vertices)
    }

    public static func mvp(aspect: Float, yaw: Float) -> simd_float4x4 {
        let tilt: Float = -0.35
        // Data convention: x/y ground plane, z height → rotate so height is screen-up.
        let toYUp = simd_float4x4(rows: [SIMD4(1, 0, 0, 0), SIMD4(0, 0, 1, 0), SIMD4(0, 1, 0, 0), SIMD4(0, 0, 0, 1)])
        let rotY = simd_float4x4(simd_quatf(angle: yaw, axis: SIMD3(0, 1, 0)))
        let rotX = simd_float4x4(simd_quatf(angle: tilt, axis: SIMD3(1, 0, 0)))
        let s: Float = 0.55
        let scale = simd_float4x4(diagonal: SIMD4(s / max(aspect, 1), s * min(aspect, 1), s * 0.25, 1))
        var t = matrix_identity_float4x4
        t.columns.3 = SIMD4(0, 0, 0.5, 1) // push into [0,1] clip depth
        return t * scale * rotX * rotY * toYUp
    }

    /// Encodes one frame into `pass`. Shared by the on-screen view and offscreen tests.
    public func encode(into pass: MTLRenderPassDescriptor, commandBuffer: MTLCommandBuffer, aspect: Float, time: Float) {
        guard let enc = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        var u = Uniforms(mvp: Self.mvp(aspect: aspect, yaw: time * yawSpeed), pointScale: 1.5)
        enc.setRenderPipelineState(pipeline)
        enc.setDepthStencilState(depth)
        enc.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        enc.setVertexBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 1)
        enc.drawPrimitives(type: .point, vertexStart: 0, vertexCount: vertexCount)
        enc.endEncoding()
    }

    private func watch(_ cb: MTLCommandBuffer) {
        cb.addCompletedHandler { [weak self] cb in
            guard let self else { return }
            if let reason = cb.failureReason {
                DispatchQueue.main.async { self.onFailure?(reason) }
            } else {
                self.lock.lock(); self.completedFrames += 1; self.lock.unlock()
            }
        }
    }

    // MARK: MTKViewDelegate

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    public func draw(in view: MTKView) {
        guard let pass = view.currentRenderPassDescriptor, let drawable = view.currentDrawable,
              let cb = queue.makeCommandBuffer() else { return }
        cb.label = "OmniData frame"
        let size = view.drawableSize
        encode(into: pass, commandBuffer: cb, aspect: Float(size.width / max(size.height, 1)),
               time: Float(CACurrentMediaTime() - start))
        cb.present(drawable)
        watch(cb)
        cb.commit()
    }

    // MARK: Offscreen (tests, thumbnails)

    /// Renders one frame offscreen and returns BGRA8 pixels.
    public func renderOffscreen(width: Int, height: Int, time: Float = 0) throws -> [UInt8] {
        let cdesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        cdesc.usage = [.renderTarget, .shaderRead]
        cdesc.storageMode = .shared
        let ddesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: width, height: height, mipmapped: false)
        ddesc.usage = .renderTarget
        ddesc.storageMode = .private
        guard let color = device.makeTexture(descriptor: cdesc), let depthTex = device.makeTexture(descriptor: ddesc),
              let cb = queue.makeCommandBuffer() else { throw SetupError.noQueue }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = color
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        pass.colorAttachments[0].storeAction = .store
        pass.depthAttachment.texture = depthTex
        pass.depthAttachment.clearDepth = 1
        pass.depthAttachment.loadAction = .clear
        encode(into: pass, commandBuffer: cb, aspect: Float(width) / Float(height), time: time)
        cb.commit()
        cb.waitUntilCompleted()
        if let reason = cb.failureReason { throw NSError(domain: "DatasetPointRenderer", code: 1, userInfo: [NSLocalizedDescriptionKey: reason]) }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        color.getBytes(&pixels, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        return pixels
    }
}
