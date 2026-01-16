import AppIntents
import WidgetKit

// MARK: - Configuration Intent

struct ConfigureHDTEIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configure HDTE"
    static var description = IntentDescription("Customize the Hyper-Dimensional Topography visualization")
    
    @Parameter(title: "Data Source")
    var dataSource: DataSourceOption
    
    @Parameter(title: "Visual Style")
    var visualStyle: VisualStyleOption
    
    @Parameter(title: "Update Frequency")
    var updateFrequency: UpdateFrequencyOption
    
    init() {
        self.dataSource = .live
        self.visualStyle = .volumetric
        self.updateFrequency = .fiveMinutes
    }
}

// MARK: - Configuration Options

enum DataSourceOption: String, AppEnum {
    case live = "Live Data"
    case cached = "Cached"
    case demo = "Demo Mode"
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Data Source")
    static var caseDisplayRepresentations: [DataSourceOption: DisplayRepresentation] = [
        .live: "Live Data Stream",
        .cached: "Cached Snapshot",
        .demo: "Demo Visualization"
    ]
}

enum VisualStyleOption: String, AppEnum {
    case volumetric = "Volumetric"
    case wireframe = "Wireframe"
    case solid = "Solid"
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Visual Style")
    static var caseDisplayRepresentations: [VisualStyleOption: DisplayRepresentation] = [
        .volumetric: "Volumetric Fog",
        .wireframe: "Wireframe Mesh",
        .solid: "Solid Terrain"
    ]
}

enum UpdateFrequencyOption: String, AppEnum {
    case oneMinute = "1min"
    case fiveMinutes = "5min"
    case fifteenMinutes = "15min"
    case thirtyMinutes = "30min"
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Update Frequency")
    static var caseDisplayRepresentations: [UpdateFrequencyOption: DisplayRepresentation] = [
        .oneMinute: "Every Minute",
        .fiveMinutes: "Every 5 Minutes",
        .fifteenMinutes: "Every 15 Minutes",
        .thirtyMinutes: "Every 30 Minutes"
    ]
    
    var timeInterval: TimeInterval {
        switch self {
        case .oneMinute: return 60
        case .fiveMinutes: return 300
        case .fifteenMinutes: return 900
        case .thirtyMinutes: return 1800
        }
    }
}

// MARK: - High-Fidelity Re-bake Intent

struct RebakeHDTEIntent: AppIntent {
    static var title: LocalizedStringResource = "Re-bake Visualization"
    static var description = IntentDescription("Trigger a high-fidelity re-computation of the terrain")
    
    @Parameter(title: "Quality Level")
    var quality: QualityOption
    
    init() {
        self.quality = .high
    }
    
    func perform() async throws -> some IntentResult {
        // Trigger widget timeline refresh with high-quality settings
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

enum QualityOption: String, AppEnum {
    case standard = "Standard"
    case high = "High"
    case ultra = "Ultra"
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Quality")
    static var caseDisplayRepresentations: [QualityOption: DisplayRepresentation] = [
        .standard: "Standard (Fast)",
        .high: "High Quality",
        .ultra: "Ultra (Slow)"
    ]
}
