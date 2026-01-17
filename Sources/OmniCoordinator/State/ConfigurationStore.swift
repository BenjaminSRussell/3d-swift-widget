import SwiftUI
import Combine
import OmniCoreTypes
import OmniCore
// Note: ThemeConfig is in OmniCore (Core)

/// Phase 17.1: Configuration Injection System
/// Observable store that updates the RenderActor when UI changes.
@Observable
public class ConfigurationStore {
    @MainActor public static let shared = ConfigurationStore()
    
    // Visual Settings
    public var bloomIntensity: Float = 0.5 {
        didSet { updateRenderer() }
    }
    
    public var chromaticAberration: Float = 0.005 {
        didSet { updateRenderer() }
    }
    
    // Theme
    public var currentTheme: ThemeConfig = ThemeConfig() {
        didSet { updateRenderer() }
    }
    
    // Internal
    private var updateTask: Task<Void, Never>?
    public weak var renderer: Renderer?
    
    private init() {
        // Load default theme
        if let theme = ThemeManager.shared.loadTheme(from: ThemeManager.shared.defaultThemeJson()) {
            self.currentTheme = theme
        }
    }
    
    private func updateRenderer() {
        updateTask?.cancel()
        updateTask = Task { @MainActor in
            guard let renderer = self.renderer else { return }
            
            // Update Theme (Mesh/Geometry)
            renderer.theme = self.currentTheme
            
            // Update Post Process Settings
            // We need to expose these on Renderer or pass them via a settings struct
            renderer.postProcessSettings.bloomIntensity = self.bloomIntensity
            renderer.postProcessSettings.chromaticAberration = self.chromaticAberration
        }
    }
    
    public func loadThemePreset(json: String) {
        if let theme = ThemeManager.shared.loadTheme(from: json) {
            self.currentTheme = theme
        }
    }
}
