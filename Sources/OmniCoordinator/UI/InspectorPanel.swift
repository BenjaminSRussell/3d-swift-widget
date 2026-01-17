import SwiftUI
import OmniCore
import OmniCoreTypes
// InspectorPanel lives in OmniCoordinator (or App) to access ConfigurationStore
// OmniUI is for generic components.

/// Phase 17.3: The Inspector Panel
/// A floating, glassmorphic settings panel for "God-Tier" customization.
public struct InspectorPanel: View {
    @State private var store = ConfigurationStore.shared
    @State private var isExpanded: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Circle()
                    .fill(Color(red: Double(store.currentTheme.primaryColor.x),
                                green: Double(store.currentTheme.primaryColor.y),
                                blue: Double(store.currentTheme.primaryColor.z)))
                    .frame(width: 10, height: 10)
                    .shadow(color: .white.opacity(0.5), radius: 5)
                
                Text("OMNI INSPECTOR")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.down" : "slider.horizontal.3")
                        .foregroundColor(.white)
                        .font(.system(size: 12))
                }
            }
            
            if isExpanded {
                Divider().background(Color.white.opacity(0.2))
                
                // Group 1: Atmospherics
                Group {
                    Label("ATMOSPHERE", systemImage: "cloud.fog")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Aberration")
                            .font(.caption)
                            .foregroundColor(.white)
                        Spacer()
                        Slider(value: Binding(get: {
                            store.chromaticAberration
                        }, set: {
                            store.chromaticAberration = $0
                        }), in: 0...0.05)
                        .frame(width: 120)
                    }
                    
                    HStack {
                        Text("Bloom")
                            .font(.caption)
                            .foregroundColor(.white)
                        Spacer()
                        Slider(value: Binding(get: {
                            store.bloomIntensity
                        }, set: {
                            store.bloomIntensity = $0
                        }), in: 0...2.0)
                        .frame(width: 120)
                    }
                }
                
                Divider().background(Color.white.opacity(0.2))
                
                // Group 2: Theme
                Group {
                    Label("THEME", systemImage: "paintpalette")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ThemeButton(color: .pink, name: "Cyberpunk") {
                                store.loadThemePreset(json: ThemeManager.shared.defaultThemeJson())
                            }
                            ThemeButton(color: .blue, name: "Ice") {
                                // Load Ice preset
                            }
                            ThemeButton(color: .orange, name: "Mars") {
                                // Load Mars preset
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .frame(width: 320)
        .padding(.leading, 40)
        .padding(.bottom, 40)
    }
}

struct ThemeButton: View {
    let color: Color
    let name: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Circle()
                    .fill(color)
                    .frame(width: 24, height: 24)
                Text(name)
                    .font(.caption2)
                    .foregroundColor(.white)
            }
            .padding(8)
            .background(Color.black.opacity(0.2))
            .cornerRadius(8)
        }
    }
}
