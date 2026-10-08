import Foundation

public class TerrainGenerator {
    public static func generateSineWave(width: Int, depth: Int, frequency: Float = 0.1, amplitude: Float = 1.0) -> TerrainData {
        var heights = [Float]()
        heights.reserveCapacity(width * depth)
        
        for z in 0..<depth {
            for x in 0..<width {
                let height = sin(Float(x) * frequency) * cos(Float(z) * frequency) * amplitude
                heights.append(height)
            }
        }
        
        return TerrainData(width: width, depth: depth, heights: heights)
    }
    
    public static func generateRandomNoise(width: Int, depth: Int, scale: Float = 1.0) -> TerrainData {
        var heights = [Float]()
        heights.reserveCapacity(width * depth)
        
        for _ in 0..<(width * depth) {
            heights.append(Float.random(in: 0...1) * scale)
        }
        
        return TerrainData(width: width, depth: depth, heights: heights)
    }

    public static func generateFBM(width: Int, depth: Int, octaves: Int = 6, persistence: Float = 0.5, lacunarity: Float = 2.0, scale: Float = 1.0) -> TerrainData {
        var heights = [Float](repeating: 0, count: width * depth)
        
        // Simple seeded random noise for base
        let seed = Int.random(in: 0...10000)
        
        for z in 0..<depth {
            for x in 0..<width {
                var amplitude: Float = 1.0
                var frequency: Float = 1.0
                var noiseHeight: Float = 0.0
                
                for _ in 0..<octaves {
                    // Very simple pseudo-noise for demonstration
                    // In a real app we'd use Perlin/Simplex noise
                    let nx = Float(x) / Float(width) * frequency
                    let nz = Float(z) / Float(depth) * frequency
                    
                    // Simple hash-based noise approximation
                    let val = sin(nx * 10 + Float(seed)) * cos(nz * 10 + Float(seed))
                    
                    noiseHeight += val * amplitude
                    
                    amplitude *= persistence
                    frequency *= lacunarity
                }
                
                heights[z * width + x] = noiseHeight * scale
            }
        }
        
        // Normalize
        let minH = heights.min() ?? 0
        let maxH = heights.max() ?? 1
        let range = maxH - minH
        
        if range > 0.0001 {
            for i in 0..<heights.count {
                heights[i] = (heights[i] - minH) / range * scale * 2.0 // Scale up a bit
            }
        }
        
        return TerrainData(width: width, depth: depth, heights: heights)
    }
}
