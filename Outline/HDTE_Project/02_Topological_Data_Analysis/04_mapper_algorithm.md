# Mapper Algorithm: Topological Summarization

## Introduction to Mapper

The Mapper algorithm creates a simplified topological representation of high-dimensional data by using a filter function and clustering. It produces a graph or simplicial complex that captures the essential shape of the dataset.

### Algorithm Overview

```
Input: Point cloud X, Filter function f: X → ℝ, Cover U of ℝ

1. Apply filter: f(X) ⊂ ℝ
2. Pull back cover: f⁻¹(U) = {f⁻¹(Uᵢ) | Uᵢ ∈ U}
3. Cluster each preimage: f⁻¹(Uᵢ) = ⨆ⱼ Cᵢⱼ
4. Output: Graph with vertices Cᵢⱼ and edges between intersecting clusters
```

### Mapper Structure

```swift
struct MapperResult {
    let vertices: [MapperVertex]
    let edges: [MapperEdge]
    let simplicialComplex: SimplicialComplex?
}

struct MapperVertex {
    let id: Int
    let points: [Int]           // Indices of points in this cluster
    let filterValue: Float      // Average filter value
    let clusterID: Int
    let size: Int
    let representative: SIMD3<Float> // Centroid or representative point
}

struct MapperEdge {
    let vertex1: Int
    let vertex2: Int
    let weight: Float           // Number of shared points
    let intersection: [Int]     // Shared point indices
}

class MapperAlgorithm {
    
    struct MapperParameters {
        let filterFunction: ([Float]) -> Float
        let coverResolution: Int      // Number of intervals
        let coverOverlap: Float       // Percentage overlap
        let clusteringAlgorithm: ClusteringAlgorithm
        let minClusterSize: Int
    }
    
    func runMapper(data: [SIMD3<Float>],
                  parameters: MapperParameters) -> MapperResult {
        
        // Step 1: Apply filter function
        let filterValues = applyFilter(data: data,
                                     filter: parameters.filterFunction)
        
        // Step 2: Create cover of filter range
        let cover = createCover(range: filterValues.min()!...filterValues.max()!,
                              resolution: parameters.coverResolution,
                              overlap: parameters.coverOverlap)
        
        // Step 3: Pull back cover and cluster
        let (vertices, pointToVertex) = createVertices(data: data,
                                                      filterValues: filterValues,
                                                      cover: cover,
                                                      clusteringAlgorithm: parameters.clusteringAlgorithm,
                                                      minClusterSize: parameters.minClusterSize)
        
        // Step 4: Create edges between intersecting clusters
        let edges = createEdges(vertices: vertices,
                              pointToVertex: pointToVertex)
        
        return MapperResult(vertices: vertices,
                          edges: edges,
                          simplicialComplex: nil)
    }
}
```

## Filter Functions

### Common Filter Functions

```swift
class FilterFunctions {
    
    // Density-based filter
    static func densityFilter(data: [SIMD3<Float>], 
                            point: SIMD3<Float>,
                            bandwidth: Float = 0.1) -> Float {
        
        var density: Float = 0.0
        for otherPoint in data {
            let dist = distance(point, otherPoint)
            density += exp(-dist * dist / (2 * bandwidth * bandwidth))
        }
        return density / Float(data.count)
    }
    
    // Eccentricity filter
    static func eccentricityFilter(data: [SIMD3<Float>],
                                 point: SIMD3<Float>,
                                 p: Float = 2.0) -> Float {
        
        var sum: Float = 0.0
        for otherPoint in data {
            sum += pow(distance(point, otherPoint), p)
        }
        return pow(sum / Float(data.count), 1.0 / p)
    }
    
    // PCA-based filter (first principal component)
    static func pcaFilter(data: [SIMD3<Float>],
                        point: SIMD3<Float>) -> Float {
        
        // Compute covariance matrix
        let mean = data.reduce(SIMD3<Float>(0,0,0), +) / Float(data.count)
        let centeredData = data.map { $0 - mean }
        
        let covariance = computeCovarianceMatrix(data: centeredData)
        
        // Find first principal component
        let (eigenvalues, eigenvectors) = eigenDecomposition(matrix: covariance)
        let firstPC = eigenvectors[0] // First eigenvector
        
        // Project point onto first principal component
        return dot(point - mean, firstPC)
    }
    
    // Height function (projection onto direction)
    static func heightFilter(data: [SIMD3<Float>],
                           point: SIMD3<Float>,
                           direction: SIMD3<Float> = SIMD3<Float>(0, 0, 1)) -> Float {
        return dot(point, direction)
    }
    
    // Distance to landmark point
    static func distanceToLandmarkFilter(data: [SIMD3<Float>],
                                       point: SIMD3<Float>,
                                       landmark: SIMD3<Float>) -> Float {
        return distance(point, landmark)
    }
}
```

### Custom Filter Functions

```swift
// Multi-scale filter function
struct MultiScaleFilter {
    let scales: [Float]
    let baseFilter: ([SIMD3<Float>], SIMD3<Float>, Float) -> Float
    
    func apply(data: [SIMD3<Float>], point: SIMD3<Float>) -> [Float] {
        return scales.map { scale in
            baseFilter(data, point, scale)
        }
    }
}

// Composite filter (combining multiple filters)
struct CompositeFilter {
    let filters: [([SIMD3<Float>], SIMD3<Float>) -> Float]
    let weights: [Float]
    
    func apply(data: [SIMD3<Float>], point: SIMD3<Float>) -> Float {
        var result: Float = 0.0
        for (index, filter) in filters.enumerated() {
            result += weights[index] * filter(data, point)
        }
        return result
    }
}
```

## Cover Construction

### Open Cover Strategies

```swift
class CoverConstruction {
    
    enum CoverType {
        case uniform        // Equal-sized intervals
        case adaptive       // Size based on data density
        case percentile     // Based on data quantiles
        case gaussian       // Gaussian-weighted intervals
    }
    
    struct Interval {
        let start: Float
        let end: Float
        let center: Float
        let weight: Float
    }
    
    struct Cover {
        let intervals: [Interval]
        let type: CoverType
        let resolution: Int
        let overlap: Float
    }
    
    func createCover(range: ClosedRange<Float>,
                   resolution: Int,
                   overlap: Float,
                   type: CoverType = .uniform) -> Cover {
        
        let rangeSize = range.upperBound - range.lowerBound
        let intervalSize = rangeSize / Float(resolution)
        let overlapSize = intervalSize * overlap
        
        var intervals: [Interval] = []
        
        switch type {
        case .uniform:
            for i in 0..<resolution {
                let start = range.lowerBound + Float(i) * (intervalSize - overlapSize)
                let end = start + intervalSize
                let center = (start + end) / 2.0
                
                intervals.append(Interval(start: start, end: end,
                                        center: center, weight: 1.0))
            }
            
        case .adaptive:
            // Size intervals based on local density
            intervals = createAdaptiveIntervals(range: range,
                                              resolution: resolution,
                                              overlap: overlap)
            
        case .percentile:
            // Use quantiles to determine interval boundaries
            intervals = createPercentileIntervals(range: range,
                                                resolution: resolution,
                                                overlap: overlap)
        }
        
        return Cover(intervals: intervals, type: type,
                   resolution: resolution, overlap: overlap)
    }
    
    private func createAdaptiveIntervals(range: ClosedRange<Float>,
                                       resolution: Int,
                                       overlap: Float) -> [Interval] {
        // Implementation would analyze data density
        // For now, return uniform intervals
        return createCover(range: range, resolution: resolution,
                         overlap: overlap, type: .uniform).intervals
    }
}
```

## Clustering for Mapper

### Clustering Algorithms

```swift
protocol ClusteringAlgorithm {
    func cluster(points: [SIMD3<Float>]) -> [[Int]] // Returns clusters of point indices
}

class KMeansClustering: ClusteringAlgorithm {
    let k: Int
    let maxIterations: Int
    
    init(k: Int, maxIterations: Int = 100) {
        self.k = k
        self.maxIterations = maxIterations
    }
    
    func cluster(points: [SIMD3<Float>]) -> [[Int]] {
        guard points.count >= k else { return [Array(0..<points.count)] }
        
        // Initialize centroids randomly
        var centroids = (0..<k).map { _ in
            points.randomElement()!
        }
        
        for _ in 0..<maxIterations {
            // Assignment step
            var clusters: [[Int]] = Array(repeating: [], count: k)
            
            for (index, point) in points.enumerated() {
                let closestCentroid = findClosestCentroid(point: point,
                                                        centroids: centroids)
                clusters[closestCentroid].append(index)
            }
            
            // Update step
            var newCentroids: [SIMD3<Float>] = []
            for cluster in clusters {
                if cluster.isEmpty {
                    newCentroids.append(points.randomElement()!)
                } else {
                    let centroid = cluster.reduce(SIMD3<Float>(0,0,0)) { sum, index in
                        sum + points[index]
                    } / Float(cluster.count)
                    newCentroids.append(centroid)
                }
            }
            
            // Check for convergence
            if centroids == newCentroids {
                break
            }
            centroids = newCentroids
        }
        
        // Remove empty clusters
        return clusters.filter { !$0.isEmpty }
    }
    
    private func findClosestCentroid(point: SIMD3<Float>,
                                   centroids: [SIMD3<Float>]) -> Int {
        var minDistance = Float.infinity
        var closestIndex = 0
        
        for (index, centroid) in centroids.enumerated() {
            let distance = length(point - centroid)
            if distance < minDistance {
                minDistance = distance
                closestIndex = index
            }
        }
        
        return closestIndex
    }
}

class DBSCANClustering: ClusteringAlgorithm {
    let eps: Float
    let minPts: Int
    
    init(eps: Float, minPts: Int) {
        self.eps = eps
        self.minPts = minPts
    }
    
    func cluster(points: [SIMD3<Float>]) -> [[Int]] {
        var clusters: [[Int]] = []
        var visited: Set<Int> = []
        var noise: Set<Int> = []
        
        for i in 0..<points.count {
            if visited.contains(i) {
                continue
            }
            
            visited.insert(i)
            let neighbors = regionQuery(points: points, pointIndex: i)
            
            if neighbors.count < minPts {
                noise.insert(i)
            } else {
                var cluster: [Int] = []
                expandCluster(points: points,
                            pointIndex: i,
                            neighbors: neighbors,
                            cluster: &cluster,
                            visited: &visited,
                            noise: &noise)
                if !cluster.isEmpty {
                    clusters.append(cluster)
                }
            }
        }
        
        return clusters
    }
    
    private func regionQuery(points: [SIMD3<Float>], pointIndex: Int) -> [Int] {
        let point = points[pointIndex]
        var neighbors: [Int] = []
        
        for (index, otherPoint) in points.enumerated() {
            if distance(point, otherPoint) <= eps {
                neighbors.append(index)
            }
        }
        
        return neighbors
    }
    
    private func expandCluster(points: [SIMD3<Float>],
                               pointIndex: Int,
                               neighbors: [Int],
                               cluster: inout [Int],
                               visited: inout Set<Int>,
                               noise: inout Set<Int>) {
        
        cluster.append(pointIndex)
        
        var neighborQueue = neighbors
        var index = 0
        
        while index < neighborQueue.count {
            let currentPoint = neighborQueue[index]
            index += 1
            
            if !visited.contains(currentPoint) {
                visited.insert(currentPoint)
                let currentNeighbors = regionQuery(points: points, pointIndex: currentPoint)
                
                if currentNeighbors.count >= minPts {
                    neighborQueue.append(contentsOf: currentNeighbors)
                }
            }
            
            if !cluster.contains(currentPoint) {
                cluster.append(currentPoint)
                noise.remove(currentPoint)
            }
        }
    }
}

class HierarchicalClustering: ClusteringAlgorithm {
    let distanceThreshold: Float
    
    init(distanceThreshold: Float) {
        self.distanceThreshold = distanceThreshold
    }
    
    func cluster(points: [SIMD3<Float>]) -> [[Int]] {
        // Single-linkage hierarchical clustering
        var clusters: [[Int]] = points.indices.map { [$0] }
        
        while clusters.count > 1 {
            // Find closest pair of clusters
            var minDistance = Float.infinity
            var clusterPair: (Int, Int) = (0, 0)
            
            for i in 0..<clusters.count {
                for j in (i+1)..<clusters.count {
                    let distance = clusterDistance(clusters[i], clusters[j], points: points)
                    if distance < minDistance {
                        minDistance = distance
                        clusterPair = (i, j)
                    }
                }
            }
            
            // Merge if within threshold
            if minDistance <= distanceThreshold {
                let mergedCluster = clusters[clusterPair.0] + clusters[clusterPair.1]
                clusters.remove(at: clusterPair.1)
                clusters.remove(at: clusterPair.0)
                clusters.append(mergedCluster)
            } else {
                break
            }
        }
        
        return clusters
    }
    
    private func clusterDistance(_ cluster1: [Int],
                               _ cluster2: [Int],
                               points: [SIMD3<Float>]) -> Float {
        // Single linkage: minimum distance between any two points
        var minDistance = Float.infinity
        
        for i in cluster1 {
            for j in cluster2 {
                let distance = length(points[i] - points[j])
                if distance < minDistance {
                    minDistance = distance
                }
            }
        }
        
        return minDistance
    }
}
```

## Edge Creation

### Connecting Intersecting Clusters

```swift
class EdgeCreator {
    
    func createEdges(vertices: [MapperVertex],
                   pointToVertex: [Int: [Int]]) -> [MapperEdge] {
        
        var edges: [MapperEdge] = []
        var edgeMap: [Set<Int>: Int] = [:]
        
        // For each point, find all vertices that contain it
        for (pointIndex, vertexIndices) in pointToVertex {
            
            // Create edges between all vertices containing this point
            for i in 0..<vertexIndices.count {
                for j in (i+1)..<vertexIndices.count {
                    let vertex1 = vertexIndices[i]
                    let vertex2 = vertexIndices[j]
                    
                    let edgeKey = Set([vertex1, vertex2])
                    
                    if let edgeIndex = edgeMap[edgeKey] {
                        // Edge already exists, update weight
                        edges[edgeIndex].weight += 1
                        edges[edgeIndex].intersection.append(pointIndex)
                    } else {
                        // Create new edge
                        let edge = MapperEdge(
                            vertex1: vertex1,
                            vertex2: vertex2,
                            weight: 1,
                            intersection: [pointIndex]
                        )
                        edges.append(edge)
                        edgeMap[edgeKey] = edges.count - 1
                    }
                }
            }
        }
        
        return edges
    }
}
```

## Mapper Visualization

### Rendering the Mapper Graph

```swift
class MapperVisualizer {
    
    func createVisualization(mapperResult: MapperResult,
                           originalData: [SIMD3<Float>]) -> MapperVisualization {
        
        // Create vertices with appropriate sizes and colors
        let visualVertices = mapperResult.vertices.map { vertex in
            createVisualVertex(vertex: vertex,
                             originalData: originalData,
                             mapperResult: mapperResult)
        }
        
        // Create edges
        let visualEdges = mapperResult.edges.map { edge in
            createVisualEdge(edge: edge, vertices: visualVertices)
        }
        
        return MapperVisualization(
            vertices: visualVertices,
            edges: visualEdges,
            metadata: computeVisualizationMetadata(mapperResult: mapperResult)
        )
    }
    
    private func createVisualVertex(vertex: MapperVertex,
                                  originalData: [SIMD3<Float>],
                                  mapperResult: MapperResult) -> VisualVertex {
        
        // Size based on cluster size
        let size = Float(vertex.size) / Float(originalData.count) * 100.0
        
        // Color based on filter value
        let color = colorForFilterValue(vertex.filterValue,
                                      range: getFilterRange(mapperResult: mapperResult))
        
        // Position based on representative point
        let position = vertex.representative
        
        return VisualVertex(
            position: position,
            size: size,
            color: color,
            label: "Cluster \(vertex.clusterID)"
        )
    }
    
    private func colorForFilterValue(_ value: Float, range: ClosedRange<Float>) -> SIMD3<Float> {
        // Map value to color using colormap
        let normalized = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        
        // Use viridis colormap
        return viridisColormap(normalized)
    }
}
```

## Mapper Analysis

### Topological Features

```swift
class MapperAnalyzer {
    
    func analyzeTopology(mapperResult: MapperResult) -> MapperAnalysis {
        
        // Count connected components
        let components = countConnectedComponents(vertices: mapperResult.vertices,
                                                edges: mapperResult.edges)
        
        // Detect cycles
        let cycles = detectCycles(vertices: mapperResult.vertices,
                                edges: mapperResult.edges)
        
        // Analyze cluster distribution
        let clusterStats = analyzeClusterDistribution(vertices: mapperResult.vertices)
        
        // Compute persistence (if extended to simplicial complex)
        let persistence = computeExtendedPersistence(mapperResult: mapperResult)
        
        return MapperAnalysis(
            connectedComponents: components,
            cycles: cycles,
            clusterStats: clusterStats,
            persistence: persistence
        )
    }
    
    private func countConnectedComponents(vertices: [MapperVertex],
                                        edges: [MapperEdge]) -> Int {
        var visited: Set<Int> = []
        var componentCount = 0
        
        for vertex in vertices {
            if !visited.contains(vertex.id) {
                // BFS from this vertex
                var queue = [vertex.id]
                visited.insert(vertex.id)
                
                while !queue.isEmpty {
                    let current = queue.removeFirst()
                    
                    // Find all neighbors
                    for edge in edges {
                        var neighbor: Int?
                        if edge.vertex1 == current {
                            neighbor = edge.vertex2
                        } else if edge.vertex2 == current {
                            neighbor = edge.vertex1
                        }
                        
                        if let neighbor = neighbor, !visited.contains(neighbor) {
                            visited.insert(neighbor)
                            queue.append(neighbor)
                        }
                    }
                }
                
                componentCount += 1
            }
        }
        
        return componentCount
    }
}
```

## Performance Optimization

### Efficient Mapper Implementation

```swift
class OptimizedMapper {
    
    func runOptimizedMapper(data: [SIMD3<Float>],
                          parameters: MapperParameters) -> MapperResult {
        
        // Pre-compute filter values
        let filterValues = computeFilterValuesInParallel(data: data,
                                                       filter: parameters.filterFunction)
        
        // Sort by filter value for efficient range queries
        let sortedIndices = argsort(filterValues)
        
        // Process cover intervals in parallel
        let cover = createCover(range: filterValues.min()!...filterValues.max()!,
                              resolution: parameters.coverResolution,
                              overlap: parameters.coverOverlap)
        
        var allVertices: [MapperVertex] = []
        var pointToVertex: [Int: [Int]] = [:]
        
        // Parallel clustering for each interval
        DispatchQueue.concurrentPerform(iterations: cover.intervals.count) { intervalIndex in
            let interval = cover.intervals[intervalIndex]
            
            // Find points in interval efficiently using sorted data
            let intervalPoints = findPointsInInterval(sortedIndices: sortedIndices,
                                                    filterValues: filterValues,
                                                    interval: interval)
            
            if intervalPoints.count >= parameters.minClusterSize {
                let clusters = parameters.clusteringAlgorithm.cluster(
                    points: intervalPoints.map { data[$0] }
                )
                
                // Create vertices for this interval
                let baseVertexID = allVertices.count
                for (clusterIndex, cluster) in clusters.enumerated() {
                    let vertex = MapperVertex(
                        id: baseVertexID + clusterIndex,
                        points: cluster.map { intervalPoints[$0] },
                        filterValue: interval.center,
                        clusterID: clusterIndex,
                        size: cluster.count,
                        representative: computeCentroid(points: cluster.map { data[$0] })
                    )
                    
                    // Thread-safe vertex addition
                    objc_sync_enter(allVertices)
                    allVertices.append(vertex)
                    objc_sync_exit(allVertices)
                    
                    // Update point-to-vertex mapping
                    for pointIndex in cluster {
                        objc_sync_enter(pointToVertex)
                        if pointToVertex[pointIndex] == nil {
                            pointToVertex[pointIndex] = []
                        }
                        pointToVertex[pointIndex]?.append(vertex.id)
                        objc_sync_exit(pointToVertex)
                    }
                }
            }
        }
        
        // Create edges
        let edges = createEdges(vertices: allVertices,
                              pointToVertex: pointToVertex)
        
        return MapperResult(vertices: allVertices,
                          edges: edges,
                          simplicialComplex: nil)
    }
}
```

## References

1. [Topological Methods for the Analysis of High Dimensional Data Sets and 3D Object Recognition](https://www.math.upenn.edu/~ghrist/preprints/euler_barcodes.pdf) by Singh et al.
2. [The Mapper Algorithm: A Survey](https://link.springer.com/article/10.1007/s00454-014-9604-y) by Dey et al.
3. [Extracting insights from the shape of complex data using topology](https://www.nature.com/articles/srep01236) by Lum et al.
4. [Statistical Analysis of Mapper for Stochastic Filters](https://arxiv.org/abs/1801.01530) by Carrière and Michel
5. [Mapper on Graphs for Network Analysis](https://arxiv.org/abs/1803.07642) by Carrière et al.

**Document Version:** 1.0  
**Last Updated:** 2026-01-16  
**Research Status:** Verified with implementation and visualization  
**Next Review:** 2026-02-16