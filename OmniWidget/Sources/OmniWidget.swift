import WidgetKit
import SwiftUI

struct OmniWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: String // Placeholder for intent configuration
}

struct OmniWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> OmniWidgetEntry {
        OmniWidgetEntry(date: Date(), configuration: "Preview")
    }

    func getSnapshot(in context: Context, completion: @escaping (OmniWidgetEntry) -> ()) {
        let entry = OmniWidgetEntry(date: Date(), configuration: "Snapshot")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OmniWidgetEntry>) -> ()) {
        var entries: [OmniWidgetEntry] = []

        // Refresh every 15 minutes to save battery, or use a pseudo-live approach if active
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: hourOffset * 15, to: currentDate)!
            let entry = OmniWidgetEntry(date: entryDate, configuration: "Update")
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct OmniWidgetEntryView : View {
    var entry: OmniWidgetProvider.Entry

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Phase 17.2: Bridge to Metal Renderer
            MetalView()
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                Text("OMNI | \(entry.date, style: .time)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
}

struct OmniWidget: Widget {
    let kind: String = "OmniWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OmniWidgetProvider()) { entry in
            OmniWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("OMNI Topography")
        .description("A live topographical liquid simulation.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
