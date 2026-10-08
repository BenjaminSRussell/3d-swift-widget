import SwiftUI
import OmniDesignSystem

/// Phase 6.2: Widget Editor View (Inspector Overlay)
/// Appears when a user right-clicks ("Inspect") a widget.
/// Explodes the layers (Z-axis) or flips the card to reveal settings.

public struct WidgetEditorView: View {
    @Binding var isPresented: Bool
    @ObservedObject var typography = GlobalTypographyCoordinator.shared
    @ObservedObject var theme = ThemeManager.shared
    
    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
    public var body: some View {
        if isPresented {
            ZStack {
                // Glassy Background
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(radius: 10)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Widget Inspector")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.3))
                    
                    // Typography Control
                    Text("Typography")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    HStack {
                        Text("Weight")
                        Slider(value: $typography.currentWeight, in: 100...900)
                    }
                    
                    // Theme Control
                    Text("Theme Seed")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    HStack {
                        ColorPicker("Pick Seed High-Tech Color", selection: Binding(get: {
                            theme.currentTheme.primary
                        }, set: { newColor in
                            theme.generateTheme(from: newColor)
                        }))
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .frame(width: 300, height: 400)
            .transition(.scale.combined(with: .opacity))
        }
    }
}
