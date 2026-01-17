import SwiftUI
import RealityKit

@main
struct SimpleGridApp: App {
    var body: some SwiftUI.Scene {
        WindowGroup("3D GRID - REALITYKIT") {
            RealityKitGridView()
                .ignoresSafeArea()
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1024, height: 768)
    }
}
