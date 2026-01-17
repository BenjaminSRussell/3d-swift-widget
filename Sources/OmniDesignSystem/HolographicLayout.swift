import SwiftUI
#if os(iOS)
import CoreMotion
#endif

/// Phase 18.1: Holographic Layout Wrapper
/// Applies a subtle 3D parallax effect to child views based on input.
public struct HolographicView<Content: View>: View {
    let content: Content
    
    // Config
    var intensity: Double = 5.0 // Degrees of rotation
    
    // Expert Panel: Creative Director - Camera rotation binding (NOT view rotation)
    @Binding var cameraRotation: SIMD2<Float>
    
    #if os(iOS)
    let motionManager = CMMotionManager()
    #endif
    
    public init(intensity: Double = 5.0, cameraRotation: Binding<SIMD2<Float>>, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.intensity = intensity
        self._cameraRotation = cameraRotation
    }
    
    public var body: some View {
        content
            // DELETED: .rotation3DEffect - This broke the 2D window illusion!
            // The window frame must remain 100% static 2D
            // Only the camera matrix inside the 3D scene should pivot
            .onAppear {
                startMonitoring()
            }
            #if os(macOS)
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    updateCameraRotation(location: location)
                case .ended:
                    withAnimation(.spring()) {
                        cameraRotation = .zero
                    }
                }
            }
            #endif
    }
    
    #if os(macOS)
    private func updateCameraRotation(location: CGPoint) {
        // Calculate rotation based on mouse position
        // This will be passed to Metal shader to rotate the camera matrix
        // NOT the SwiftUI view itself
    }
    #endif
    
    private func startMonitoring() {
        #if os(iOS)
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.02
            motionManager.startDeviceMotionUpdates(to: .main) { motion, _ in
                guard let motion = motion else { return }
                withAnimation(.linear(duration: 0.1)) {
                    // Update camera rotation binding instead of view rotation
                    let pitch = Float(motion.attitude.pitch * intensity)
                    let roll = Float(motion.attitude.roll * intensity)
                    self.cameraRotation = SIMD2<Float>(roll, pitch)
                }
            }
        }
        #endif
    }
}


// Improved implementation with GeometryReader for mouse tracking
public struct HolographicContainer<Content: View>: View {
    let content: Content
    let intensity: Double
    @Binding var parallaxOffset: SIMD2<Float>
    
    public init(intensity: Double = 10.0, parallaxOffset: Binding<SIMD2<Float>>, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.intensity = intensity
        self._parallaxOffset = parallaxOffset
    }
    
    public var body: some View {
        GeometryReader { geo in
            content
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .modifier(ParallaxModifier(size: geo.size, intensity: intensity, offset: $parallaxOffset))
        }
    }
}

struct ParallaxModifier: ViewModifier {
    let size: CGSize
    let intensity: Double
    @Binding var offset: SIMD2<Float>
    
    // Expert Panel: Creative Director - NO view rotation!
    // Removed rotationX and rotationY state variables
    
    func body(content: Content) -> some View {
        content
            // DELETED: .rotation3DEffect - View stays 100% flat!
            // Only the offset binding is updated, which Metal uses for camera rotation
            #if os(macOS)
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let deltaX = (location.x - center.x) / center.x
                    let deltaY = (location.y - center.y) / center.y
                    
                    // Update binding for camera rotation in Metal
                    withAnimation(.interactiveSpring()) {
                        offset = SIMD2<Float>(Float(deltaX) * Float(intensity), Float(-deltaY) * Float(intensity))
                    }
                    
                case .ended:
                    withAnimation(.spring()) {
                        offset = .zero
                    }
                }
            }
            #endif
    }
}

