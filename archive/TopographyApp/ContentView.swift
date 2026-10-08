import SwiftUI
import TopographyCore
import TopographyRender

struct ContentView: View {
    @State private var terrainData: TerrainData?
    
    var body: some View {
        VStack {
            TopographyWidgetView(terrainData: $terrainData)
                .frame(minWidth: 800, minHeight: 600) // Larger default size
            
            HStack {
                Button("Generate Mountains (FBM)") {
                    // High resolution 4k-ish detail (reduced to 256x256 for performance, but scalable)
                    // "4k details" usually means high res texture/mesh. 512x512 is quite dense for a widget.
                    terrainData = TerrainGenerator.generateFBM(width: 256, depth: 256, octaves: 8, persistence: 0.5, scale: 30.0)
                }
                
                Button("Simple Noise") {
                    terrainData = TerrainGenerator.generateRandomNoise(width: 128, depth: 128, scale: 10.0)
                }
            }
            .padding()
        }
        .onAppear {
            terrainData = TerrainGenerator.generateFBM(width: 256, depth: 256, scale: 30.0)
        }
    }
}
