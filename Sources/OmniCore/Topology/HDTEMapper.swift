import Metal
import Foundation

// MARK: - Mapper Data Structures

public struct MapperNode {
    public let id: Int
    public let members: [Int] // Indices of data points
    public let avgValue: Float
}

public struct MapperEdge {
    public let sourceId: Int
    public let targetId: Int
    public let weight: Float // Simplicial intersection size
}

public struct MapperGraph {
    public let nodes: [MapperNode]
    public let edges: [MapperEdge]
}

/// HDTEMapper: Implements the Mapper algorithm for topological data summarization.
public final class HDTEMapper {
    
    // Lens function configuration
    public enum Lens {
        case height(dim: Int)
        case eccentricity
        case density
    }
    
    public init() {}
    
    /// Computes the Mapper graph from high-dimensional data.
    /// - Parameters:
    ///   - data: Array of data points (pointers to memory or copied).
    ///   - lensValues: Computed lens function values for each point.
    ///   - intervals: Number of intervals in the cover.
    ///   - overlap: Percentage overlap (0.0 - 1.0).
    ///   - dbscanEpsilon: Clustering distance threshold.
    public func computeGraph(pointCount: Int, 
                           lensValues: [Float], 
                           intervals: Int, 
                           overlap: Float, 
                           clustering: (([Int]) -> [[Int]])) -> MapperGraph {
        
        let (minVal, maxVal) = lensValues.reduce((Float.infinity, -Float.infinity)) { (min($0.0, $1), max($0.1, $1)) }
        let range = maxVal - minVal
        let intervalSize = range / (Float(intervals) * (1.0 - overlap))
        
        var nodes: [MapperNode] = []
        var nextNodeId = 0
        
        // 1. Cover & Cluster
        // We generate intervals and cluster points within them.
        // This acts as the "partial clustering" step.
        
        var intervalClusters: [Int: [Int]] = [:] // Map nodeID -> Interval Index (for debugging)
        
        // Simple uniform interval cover
        let step = range / Float(intervals)
        
        for i in 0..<intervals {
            // Define interval bounds with overlap
            let center = minVal + step * (Float(i) + 0.5)
            let halfWidth = (step * (1.0 + overlap)) / 2.0
            let low = center - halfWidth
            let high = center + halfWidth
            
            // Filter points in this interval
            let indicesInInterval = (0..<pointCount).filter { 
                let v = lensValues[$0]
                return v >= low && v <= high 
            }
            
            if indicesInInterval.isEmpty { continue }
            
            // Cluster the subset
            let clusters = clustering(indicesInInterval)
            
            // Create nodes for each cluster
            for cluster in clusters {
                let node = MapperNode(id: nextNodeId, members: cluster, avgValue: center)
                nodes.append(node)
                nextNodeId += 1
            }
        }
        
        // 2. Build Graph (Edges)
        // Connect nodes if they share common data points (simplicial intersection)
        
        var edges: [MapperEdge] = []
        
        for i in 0..<nodes.count {
            for j in (i+1)..<nodes.count {
                let nodeA = nodes[i]
                let nodeB = nodes[j]
                
                // Intersection check (naive O(N*M)) - optimize with Set if needed
                let setA = Set(nodeA.members)
                let common = nodeB.members.filter { setA.contains($0) }
                
                if !common.isEmpty {
                    edges.append(MapperEdge(sourceId: nodeA.id, targetId: nodeB.id, weight: Float(common.count)))
                }
            }
        }
        
        return MapperGraph(nodes: nodes, edges: edges)
    }
}
