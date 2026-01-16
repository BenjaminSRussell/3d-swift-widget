import WidgetKit
import SwiftUI
import Metal
import simd
import OmniCoordinator

struct HDTEEntry: TimelineEntry {
    let date: Date
    let snapshot: CGImage
    let configuration: HDTEConfiguration
}

struct HDTEConfiguration {
    var dataSource: DataSourceType = .live
    var visualStyle: VisualStyle = .volumetric
    var updateInterval: TimeInterval = 300 // 5 minutes
    
    enum DataSourceType {
        case live, cached, demo
    }
    
    enum VisualStyle {
        case volumetric, wireframe, solid
    }
}

struct HDTEProvider: TimelineProvider {
    private let device = MTLCreateSystemDefaultDevice()!
    private lazy var pipeline = HDTEPipeline(device: device)
    
    // MARK: - TimelineProvider Protocol
    
    func placeholder(in context: Context) -> HDTEEntry {
        // Static placeholder for widget gallery
        let snapshot = generateSnapshot(config: HDTEConfiguration(), size: context.displaySize)
        return HDTEEntry(date: Date(), snapshot: snapshot, configuration: HDTEConfiguration())
    }
    
    func getSnapshot(in context: Context, completion: @escaping (HDTEEntry) -> Void) {
        // Quick snapshot for widget preview
        let config = HDTEConfiguration()
        let snapshot = generateSnapshot(config: config, size: context.displaySize)
        let entry = HDTEEntry(date: Date(), snapshot: snapshot, configuration: config)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<HDTEEntry>) -> Void) {
        // Generate 12-hour timeline with 5-minute intervals
        var entries: [HDTEEntry] = []
        let currentDate = Date()
        let config = HDTEConfiguration()
        
        // Generate 144 snapshots (12 hours * 12 per hour)
        for offset in 0..<144 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: offset * 5, to: currentDate)!
            
            // Generate snapshot with time-varying data
            let snapshot = generateSnapshot(
                config: config,
                size: context.displaySize,
                timeOffset: Double(offset) * 5.0
            )
            
            entries.append(HDTEEntry(
                date: entryDate,
                snapshot: snapshot,
                configuration: config
            ))
        }
        
        // Timeline refreshes after 12 hours
        let refreshDate = Calendar.current.date(byAdding: .hour, value: 12, to: currentDate)!
        let timeline = Timeline(entries: entries, policy: .after(refreshDate))
        
        completion(timeline)
    }
    
    // MARK: - Snapshot Generation
    
    private func generateSnapshot(
        config: HDTEConfiguration,
        size: CGSize,
        timeOffset: Double = 0.0
    ) -> CGImage {
        let width = Int(size.width)
        let height = Int(size.height)
        
        // Create output texture
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.renderTarget, .shaderRead]
        
        guard let outputTexture = device.makeTexture(descriptor: textureDescriptor) else {
            fatalError("Failed to create output texture")
        }
        
        // Generate synthetic 10D data (in production, fetch from API)
        let dataPoints = 1024
        var inputData = [Float](repeating: 0, count: dataPoints * 10)
        
        for i in 0..<dataPoints {
            let t = Double(i) / Double(dataPoints) + timeOffset * 0.01
            // Synthetic 10D features (temperature, pressure, etc.)
            for j in 0..<10 {
                inputData[i * 10 + j] = Float(sin(t * Double(j + 1)) + cos(t * 0.5))
            }
        }
        
        // Render using HDTE pipeline
        let viewMatrix = createViewMatrix(timeOffset: timeOffset)
        pipeline.render(inputData: inputData, outputTexture: outputTexture, viewMatrix: viewMatrix)
        
        // Convert MTLTexture to CGImage
        return textureToCGImage(texture: outputTexture)
    }
    
    private func createViewMatrix(timeOffset: Double) -> simd_float4x4 {
        // Slowly rotating camera for animation
        let angle = Float(timeOffset * 0.001)
        let distance: Float = 50.0
        
        let eye = simd_float3(
            distance * cos(angle),
            20.0,
            distance * sin(angle)
        )
        let center = simd_float3(0, 0, 0)
        let up = simd_float3(0, 1, 0)
        
        return createLookAtMatrix(eye: eye, center: center, up: up)
    }
    
    private func createLookAtMatrix(eye: simd_float3, center: simd_float3, up: simd_float3) -> simd_float4x4 {
        let z = normalize(eye - center)
        let x = normalize(cross(up, z))
        let y = cross(z, x)
        
        return simd_float4x4(
            simd_float4(x.x, y.x, z.x, 0),
            simd_float4(x.y, y.y, z.y, 0),
            simd_float4(x.z, y.z, z.z, 0),
            simd_float4(-dot(x, eye), -dot(y, eye), -dot(z, eye), 1)
        )
    }
    
    private func textureToCGImage(texture: MTLTexture) -> CGImage {
        let width = texture.width
        let height = texture.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = height * bytesPerRow
        
        var pixelData = [UInt8](repeating: 0, count: totalBytes)
        
        texture.getBytes(
            &pixelData,
            bytesPerRow: bytesPerRow,
            from: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0
        )
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let dataProvider = CGDataProvider(data: Data(pixelData) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: dataProvider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            fatalError("Failed to create CGImage")
        }
        
        return cgImage
    }
}
