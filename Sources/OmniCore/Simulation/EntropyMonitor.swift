import Foundation
import simd

/// Phase 27.1: Neural Focus Tracking
/// Analyzes mouse/touch movement entropy to determine "User Focus".
public final class EntropyMonitor {
    private var lastPositions: [SIMD2<Float>] = []
    private let windowSize = 30 // ~0.5s at 60Hz
    
    public private(set) var normalizedEntropy: Float = 0.0
    
    public init() {}
    
    /// Updates with new cursor/touch position
    public func update(position: SIMD2<Float>) {
        lastPositions.append(position)
        if lastPositions.count > windowSize {
            lastPositions.removeFirst()
        }
        
        calculateEntropy()
    }
    
    private func calculateEntropy() {
        guard lastPositions.count >= 2 else { return }
        
        // Calculate velocity vectors
        var jitter: Float = 0.0
        for i in 1..<lastPositions.count {
            let v1 = lastPositions[i] - lastPositions[i-1]
            let d = length(v1)
            
            // If movement is very small, ignore
            if d > 0.001 {
                // Check change in direction (acceleration/jitter)
                if i > 1 {
                    let v0 = lastPositions[i-1] - lastPositions[i-2]
                    let angle = acos(max(-1.0, min(1.0, dot(normalize(v1), normalize(v0)))))
                    jitter += angle * d // Weight angle by speed
                }
            }
        }
        
        // Scale jitter to [0, 1] Focus Score
        // High jitter = Low Focus (Score 1.0 in this context means "High Entropy")
        let maxExpectedJitter: Float = 5.0 
        self.normalizedEntropy = min(jitter / maxExpectedJitter, 1.0)
    }
}
