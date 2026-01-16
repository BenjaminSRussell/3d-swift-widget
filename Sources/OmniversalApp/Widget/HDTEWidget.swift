import WidgetKit
import SwiftUI

// MARK: - Widget View

struct HDTEWidgetView: View {
    let entry: HDTEEntry
    
    var body: some View {
        ZStack {
            // Rendered snapshot
            Image(decorative: entry.snapshot, scale: 1.0, orientation: .up)
                .resizable()
                .aspectRatio(contentMode: .fill)
            
            // Overlay UI
            VStack {
                Spacer()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("HDTE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Text(entry.date, style: .time)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    // Status indicator (Visual style indicator)
                    Circle()
                        .fill(entry.configuration.visualStyle == .volumetric ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                }
                .padding(8)
                .background(.ultraThinMaterial)
            }
        }
    }
}

// MARK: - Widget Definition

struct HDTEWidget: Widget {
    let kind: String = "HDTEWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigureHDTEIntent.self,
            provider: HDTEProvider()
        ) { entry in
            HDTEWidgetView(entry: entry)
        }
        .configurationDisplayName("Hyper-Dimensional Topography")
        .description("Visualizes high-dimensional data as evolving 3D terrain")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    HDTEWidget()
} timeline: {
    // Manually create an entry for preview without needing a context
    let provider = HDTEProvider()
    let config = ConfigureHDTEIntent()
    
    // Generate snapshot directly using the internal helper
    let snapshot = provider.generateSnapshot(
        config: config,
        size: CGSize(width: 300, height: 150)
    )
    
    HDTEEntry(date: Date(), snapshot: snapshot, configuration: config)
}
