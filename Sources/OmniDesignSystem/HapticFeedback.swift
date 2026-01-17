#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Phase 16.4: Haptic Feedback Integration
/// Provides platform-agnostic tactile feedback for interactions.
public final class HapticFeedback {
    
    public static let shared = HapticFeedback()
    
    private init() {}
    
    /// Triggers a light impact feedback (e.g., for ripples).
    public func triggerImpact(style: ImpactStyle = .light) {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: style.uiStyle)
        generator.prepare()
        generator.impactOccurred()
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        #endif
    }
    
    /// Triggers a selection feedback (e.g., for UI clicks).
    public func triggerSelection() {
        #if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        #endif
    }
    
    public enum ImpactStyle {
        case light, medium, heavy, soft, rigid
        
        #if os(iOS)
        var uiStyle: UIImpactFeedbackGenerator.FeedbackStyle {
            switch self {
            case .light: return .light
            case .medium: return .medium
            case .heavy: return .heavy
            case .soft: return .soft
            case .rigid: return .rigid
            }
        }
        #endif
    }
}
