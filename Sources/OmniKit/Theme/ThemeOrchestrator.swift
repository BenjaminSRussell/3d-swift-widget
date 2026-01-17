import Foundation
import Metal
import Combine
import SwiftUI
import OmniCore // For MetalContext and Types
import OmniCoreTypes // Phase 1: Expose C-Structs

/// The "Neural System" of the Masterpiece Architecture.
/// Controls all visual aspects of the application from a single source of truth.
/// "Expert Perspective 3": Global Event Bus for Style.
public class ThemeOrchestrator: ObservableObject {
    
    public static let shared = ThemeOrchestrator()
    
    // Reactive Publishers for SwiftUI
    @Published public var currentTheme: ThemeConfig
    
    // Metal Buffer for Zero-Copy updates to GPU
    public var themeBuffer: MTLBuffer?
    
    private var subscribers = Set<AnyCancellable>()
    private let device = MetalContext.shared.device
    
    private init() {
        // Default "Cyber-Glass" Theme
        self.currentTheme = ThemeConfig(
            primary: SIMD4<Float>(0.0, 1.0, 0.9, 1.0),   // Cyan
            secondary: SIMD4<Float>(1.0, 0.2, 0.5, 1.0), // Magenta
            background: SIMD4<Float>(0.02, 0.02, 0.05, 0.0), // Deep Blue Void
            grid: SIMD4<Float>(0.1, 0.1, 0.2, 1.0)       // Subtle Grid
        )
        
        setupBuffer()
        startAnimationLoop()
    }
    
    // Initialize the shared Metal buffer
    private func setupBuffer() {
        let size = MemoryLayout<GlobalThemeUniforms>.stride
        self.themeBuffer = device.makeBuffer(length: size, options: .storageModeShared)
        self.themeBuffer?.label = "GlobalThemeBuffer"
        updateBuffer()
    }
    
    // Push Swift State -> Metal Buffer
    // "Expert Perspective 6": Efficient memory updates
    public func updateBuffer() {
        guard let buffer = themeBuffer else { return }
        
        var uniforms = GlobalThemeUniforms()
        uniforms.primaryColor = currentTheme.primary
        uniforms.secondaryColor = currentTheme.secondary
        uniforms.backgroundColor = currentTheme.background
        uniforms.gridColor = currentTheme.grid
        
        uniforms.baseFontSize = 12.0
        uniforms.strokeWidth = 1.0
        uniforms.density = currentTheme.density
        uniforms.time = Float(CACurrentMediaTime())
        
        uniforms.glassRefraction = 1.45 // Glass
        uniforms.glassBlurSigs = 2.0
        uniforms.chromaticAberration = 0.02
        uniforms.vignetteStrength = 0.5
        
        uniforms.mousePosition = currentTheme.mousePos
        uniforms.hoverIntensity = currentTheme.hoverIntensity
        
        memcpy(buffer.contents(), &uniforms, MemoryLayout<GlobalThemeUniforms>.size)
    }
    
    private func startAnimationLoop() {
        // Simple heartbeat to update 'time' in the buffer
        Timer.publish(every: 1.0/60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateBuffer()
            }
            .store(in: &subscribers)
    }
}

// Swift Representation of the Theme
public struct ThemeConfig {
    var primary: SIMD4<Float>
    var secondary: SIMD4<Float>
    var background: SIMD4<Float>
    var grid: SIMD4<Float>
    
    var density: Float = 1.0
    var mousePos: SIMD2<Float> = .zero
    var hoverIntensity: Float = 0.0
}
