import Metal
import OmniCoreTypes

/// Phase 16.1: Interaction System
/// Converts screen-space touches into world-space interactions with the fluid surface.
public final class InteractionSystem {
    
    public struct TouchPoint {
        var position: SIMD2<Float> // 0..1 range
        var intensity: Float
        var radius: Float
    }
    
    public private(set) var touchBuffer: MTLBuffer
    private var activeTouches: [TouchPoint] = []
    
    public init(device: MTLDevice) {
        // Support up to 10 simultaneous touches
        let bufferSize = 10 * MemoryLayout<TouchPoint>.stride
        self.touchBuffer = device.makeBuffer(length: bufferSize, options: .storageModeShared)!
        self.touchBuffer.label = "Active Touches Buffer"
    }
    
    public func addTouch(at normalizedPos: SIMD2<Float>, intensity: Float = 1.0, radius: Float = 0.05) {
        if activeTouches.count < 10 {
            activeTouches.append(TouchPoint(position: normalizedPos, intensity: intensity, radius: radius))
            updateBuffer()
        }
    }
    
    public func clearTouches() {
        activeTouches.removeAll()
        updateBuffer()
    }
    
    private func updateBuffer() {
        let pointer = touchBuffer.contents().assumingMemoryBound(to: TouchPoint.self)
        for (index, touch) in activeTouches.enumerated() {
            pointer[index] = touch
        }
        // Fill remaining with zero intensity
        if activeTouches.count < 10 {
            for i in activeTouches.count..<10 {
                pointer[i] = TouchPoint(position: .zero, intensity: 0, radius: 0)
            }
        }
    }
    
    public var touchCount: Int {
        return activeTouches.count
    }
}
