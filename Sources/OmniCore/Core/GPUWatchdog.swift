import Foundation
import Combine

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// GPUWatchdog: Proactive thermal and performance management
/// Expert Panel: Performance Engineer - Auto-adjusts quality to save battery
public class GPUWatchdog {
    
    public static let shared = GPUWatchdog()
    
    private var thermalSubscription: AnyCancellable?
    private var qualitySettings = QualitySettings()
    
    // Quality adjustment callbacks
    public var onQualityChanged: ((QualitySettings) -> Void)?
    
    private init() {
        startMonitoring()
    }
    
    // MARK: - Monitoring
    
    private func startMonitoring() {
        #if os(iOS)
        thermalSubscription = NotificationCenter.default
            .publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .sink { [weak self] _ in
                self?.handleThermalStateChange()
            }
        #endif
        
        // Initial check
        handleThermalStateChange()
    }
    
    private func handleThermalStateChange() {
        let thermalState = ProcessInfo.processInfo.thermalState
        
        switch thermalState {
        case .nominal:
            adjustQuality(level: .ultra)
            
        case .fair:
            adjustQuality(level: .high)
            
        case .serious:
            adjustQuality(level: .medium)
            
        case .critical:
            adjustQuality(level: .low)
            
        @unknown default:
            adjustQuality(level: .medium)
        }
    }
    
    private func adjustQuality(level: QualityLevel) {
        guard qualitySettings.level != level else { return }
        
        qualitySettings.level = level
        
        switch level {
        case .ultra:
            qualitySettings.raymarchSteps = 128
            qualitySettings.particleCount = 100_000
            qualitySettings.bloomQuality = 4  // Full pyramid
            qualitySettings.enableTAA = true
            qualitySettings.shadowResolution = 2048
            
        case .high:
            qualitySettings.raymarchSteps = 64
            qualitySettings.particleCount = 50_000
            qualitySettings.bloomQuality = 3
            qualitySettings.enableTAA = true
            qualitySettings.shadowResolution = 1024
            
        case .medium:
            qualitySettings.raymarchSteps = 32
            qualitySettings.particleCount = 25_000
            qualitySettings.bloomQuality = 2
            qualitySettings.enableTAA = false
            qualitySettings.shadowResolution = 512
            
        case .low:
            qualitySettings.raymarchSteps = 16
            qualitySettings.particleCount = 10_000
            qualitySettings.bloomQuality = 1
            qualitySettings.enableTAA = false
            qualitySettings.shadowResolution = 256
        }
        
        print("GPUWatchdog: Adjusted quality to \(level) (thermal: \(ProcessInfo.processInfo.thermalState))")
        onQualityChanged?(qualitySettings)
    }
    
    // MARK: - Manual Overrides
    
    public func setQualityLevel(_ level: QualityLevel) {
        adjustQuality(level: level)
    }
    
    public func getCurrentSettings() -> QualitySettings {
        return qualitySettings
    }
}

// MARK: - Quality Settings

public enum QualityLevel: String {
    case ultra
    case high
    case medium
    case low
}

public struct QualitySettings {
    public var level: QualityLevel = .high
    public var raymarchSteps: Int = 64
    public var particleCount: Int = 50_000
    public var bloomQuality: Int = 3
    public var enableTAA: Bool = true
    public var shadowResolution: Int = 1024
    
    public init() {}
}

// MARK: - Performance Metrics

extension GPUWatchdog {
    
    /// Monitors frame time and adjusts quality if needed
    public func reportFrameTime(_ milliseconds: Double) {
        // If frame time exceeds budget (e.g., 16.67ms for 60fps)
        if milliseconds > 16.67 {
            // Consider downgrading quality
            let currentLevel = qualitySettings.level
            
            switch currentLevel {
            case .ultra:
                adjustQuality(level: .high)
            case .high:
                adjustQuality(level: .medium)
            case .medium:
                adjustQuality(level: .low)
            case .low:
                break  // Already at minimum
            }
        } else if milliseconds < 10.0 {
            // Frame time is very good, consider upgrading
            let currentLevel = qualitySettings.level
            let thermalState = ProcessInfo.processInfo.thermalState
            
            // Only upgrade if thermal state allows
            if thermalState == .nominal {
                switch currentLevel {
                case .low:
                    adjustQuality(level: .medium)
                case .medium:
                    adjustQuality(level: .high)
                case .high:
                    adjustQuality(level: .ultra)
                case .ultra:
                    break  // Already at maximum
                }
            }
        }
    }
    
    /// Reports GPU memory pressure
    public func reportMemoryPressure(_ pressure: MemoryPressure) {
        switch pressure {
        case .normal:
            break
            
        case .warning:
            // Reduce particle count
            qualitySettings.particleCount = max(10_000, qualitySettings.particleCount / 2)
            onQualityChanged?(qualitySettings)
            
        case .critical:
            // Aggressive reduction
            adjustQuality(level: .low)
        }
    }
}

public enum MemoryPressure {
    case normal
    case warning
    case critical
}
