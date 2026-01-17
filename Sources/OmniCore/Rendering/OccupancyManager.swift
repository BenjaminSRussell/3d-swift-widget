import Foundation
import Combine

/// Phase 2.5: Occupancy Manager (Dynamic Resolution Scaling)
/// Tracks widget screen real-estate and throttles Metal draw calls.
public final class OccupancyManager: ObservableObject {
    public static let shared = OccupancyManager()
    
    // State for each registered widget
    public struct WidgetState {
        var id: UUID
        var screenArea: Double // Percentage 0.0 - 1.0 (or pixels)
        var isFocused: Bool
    }
    
    @Published public var widgetStates: [UUID: WidgetState] = [:]
    
    // Computed Scaling Factors (published to potential subscribers)
    // Or accessed via `getScale(for: uuid)`
    
    private init() {}
    
    public func registerWidget(_ id: UUID) {
        widgetStates[id] = WidgetState(id: id, screenArea: 0.1, isFocused: false)
    }
    
    public func updateOccupancy(id: UUID, areaPixels: Double, totalScreenPixels: Double) {
        let percent = areaPixels / max(totalScreenPixels, 1.0)
        widgetStates[id]?.screenArea = percent
        
        // Auto-Focus logic? (Not described, but keeping it simple)
    }
    
    public func setFocus(id: UUID, focused: Bool) {
        widgetStates[id]?.isFocused = focused
    }
    
    /// Returns the recommended resolution scale (0.5x to 2.0x)
    public func resolutionScale(for id: UUID) -> Float {
        guard let state = widgetStates[id] else { return 1.0 }
        
        if state.isFocused {
            return 2.0 // Supersampling
        }
        
        // Heuristic: If tiny (< 5%), lower resolution
        if state.screenArea < 0.05 {
            return 0.5
        } else if state.screenArea < 0.2 {
            return 0.75
        }
        
        return 1.0
    }
    
    /// Returns the recommended frame skip (1 = 60fps, 2 = 30fps)
    public func throttleFactor(for id: UUID) -> Int {
        guard let state = widgetStates[id] else { return 1 }
        
        if state.isFocused { return 1 }
        
        // If very small, update less frequently
        if state.screenArea < 0.05 {
            return 4 // 15fps
        } else if state.screenArea < 0.1 {
            return 2 // 30fps
        }
        
        return 1
    }
}
