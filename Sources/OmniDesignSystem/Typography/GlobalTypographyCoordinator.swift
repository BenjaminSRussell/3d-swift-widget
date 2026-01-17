import Foundation
import Metal
import OmniCore
import CoreText

/// Phase 2.2: Global Typography Coordinator
/// Manages the "Hot-Swappable" typography engine using Multi-Channel Signed Distance Fields (MSDF).
/// This ensures infinite scaling and weight interpolation.
public final class GlobalTypographyCoordinator: ObservableObject {
    public static let shared = GlobalTypographyCoordinator()
    
    // Published properties for SwiftUI/Metal binding
    @Published public var currentFontName: String = "Inter"
    @Published public var currentWeight: Float = 400.0 // Variable weight 0-1000
    @Published public var crispness: Float = 0.5 // Edge sharpness
    
    // The Font Atlas Texture (Shared across all widgets)
    public var fontAtlas: MTLTexture?
    
    // Cache for loaded font descriptors
    private var fontCache: [String: CTFont] = [:]
    
    private init() {
        // Load default system font as placeholder
        loadFont(name: "Inter-Variable", size: 64)
    }
    
    /// Switches the global font family instantly.
    /// Triggers a regeneration of the MSDF Atlas (async).
    public func setFont(family: String) {
        print("Typography: Switching to \(family)")
        self.currentFontName = family
        
        Task {
            await regenerateAtlas(for: family)
        }
    }
    
    /// Adjusts the variable weight smoothly.
    public func setWeight(_ weight: Float) {
        self.currentWeight = weight
    }
    
    /// Generates the MSDF Atlas for the given font.
    /// Note: Real MSDF generation requires a C++ library like msdfgen.
    /// Here we simulate the result by loading a high-res bitmap or predefined atlas.
    private func regenerateAtlas(for fontName: String) async {
        // Simulation: Create a placeholder Metal texture
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: 2048, height: 2048, mipmapped: true)
        descriptor.usage = [.shaderRead]
        descriptor.storageMode = .private
        
        guard let device = GPUContext.shared.device as? MTLDevice else { return } // Safe cast if needed or shared returns correct type
        // Wait, GPUContext.device IS MTLDevice.
        
        self.fontAtlas = GlobalHeap.shared.allocateTexture(descriptor: descriptor)
        print("Typography: Atlas regenerated for \(fontName)")
    }
    
    private func loadFont(name: String, size: CGFloat) {
        // standard CoreText loading to verify availability
        let font = CTFontCreateWithName(name as CFString, size, nil)
        fontCache[name] = font
    }
}
