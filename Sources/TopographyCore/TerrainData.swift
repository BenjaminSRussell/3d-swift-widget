import Foundation

public struct TerrainData {
    public let width: Int
    public let depth: Int
    public var heights: [Float]

    public init(width: Int, depth: Int, heights: [Float]) {
        self.width = width
        self.depth = depth
        self.heights = heights
        
        assert(heights.count == width * depth, "Heights count must match width * depth")
    }
    
    public func height(at x: Int, z: Int) -> Float {
        guard x >= 0, x < width, z >= 0, z < depth else { return 0.0 }
        return heights[z * width + x]
    }
    
    public func normalized() -> TerrainData {
        let minHeight = heights.min() ?? 0
        let maxHeight = heights.max() ?? 1
        let range = maxHeight - minHeight
        
        let newHeights = heights.map { ($0 - minHeight) / (range > 0 ? range : 1.0) }
        return TerrainData(width: width, depth: depth, heights: newHeights)
    }
}
