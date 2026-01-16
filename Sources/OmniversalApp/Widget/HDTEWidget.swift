import WidgetKit
import SwiftUI

// MARK: - Widget View

struct HDTEWidgetView: View {
    let entry: HDTEEntry
    
    var body: some View {
        ZStack {
            // Rendered snapshot
            if let uiImage = UIImage(cgImage: entry.snapshot) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            
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
                    
                    // Status indicator
                    Circle()
                        .fill(Color.green)
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
    let device = MTLCreateSystemDefaultDevice()!
    let provider = HDTEProvider()
    
    // Generate preview snapshot
    let snapshot = provider.placeholder(in: TimelineProviderContext())
    HDTEEntry(date: Date(), snapshot: snapshot.snapshot, configuration: HDTEConfiguration())
}
