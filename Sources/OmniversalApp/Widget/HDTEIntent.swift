import AppIntents

struct ConfigureHDTEIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configuration"
    static var description = IntentDescription("Customize the topography visualization.")
    
    @Parameter(title: "Data Source", default: .live)
    var dataSource: DataSourceType
    
    @Parameter(title: "Visual Style", default: .volumetric)
    var visualStyle: VisualStyle
    
    init() {}
    
    init(dataSource: DataSourceType, visualStyle: VisualStyle) {
        self.dataSource = dataSource
        self.visualStyle = visualStyle
    }
}

enum DataSourceType: String, AppEnum {
    case live = "Live Data"
    case cached = "Cached"
    case demo = "Demo Mode"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Data Source"
    static var caseDisplayRepresentations: [DataSourceType : DisplayRepresentation] = [
        .live: "Live Data",
        .cached: "Cached",
        .demo: "Demo Mode"
    ]
}

enum VisualStyle: String, AppEnum {
    case volumetric = "Volumetric"
    case wireframe = "Wireframe"
    case solid = "Solid"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Visual Style"
    static var caseDisplayRepresentations: [VisualStyle : DisplayRepresentation] = [
        .volumetric: "Volumetric",
        .wireframe: "Wireframe",
        .solid: "Solid"
    ]
}
