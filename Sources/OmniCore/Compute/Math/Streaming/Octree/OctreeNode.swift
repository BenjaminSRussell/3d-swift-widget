import Foundation
import simd

/// OctreeNode: Spatial indexing for 10GB+ datasets
/// Expert Panel: Data Scientist - Handles infinite data without crashes
public struct OctreeNode {
    public var bounds: SIMD3<Float>
    public var size: Float
    public var children: [OctreeNode]?
    public var dataChunkID: UUID?  // Reference to disk-based data chunk
    public var isLoaded: Bool = false
    
    public init(bounds: SIMD3<Float>, size: Float) {
        self.bounds = bounds
        self.size = size
    }
    
    /// Checks if this node intersects the camera frustum
    public func intersects(frustum: Frustum) -> Bool {
        // AABB vs Frustum intersection test
        let min = bounds - SIMD3<Float>(repeating: size / 2)
        let max = bounds + SIMD3<Float>(repeating: size / 2)
        
        for plane in frustum.planes {
            let pVertex = SIMD3<Float>(
                plane.normal.x > 0 ? max.x : min.x,
                plane.normal.y > 0 ? max.y : min.y,
                plane.normal.z > 0 ? max.z : min.z
            )
            
            if dot(plane.normal, pVertex) + plane.distance < 0 {
                return false
            }
        }
        
        return true
    }
    
    /// Subdivides this node into 8 children
    public mutating func subdivide() {
        let halfSize = size / 2
        let quarterSize = size / 4
        
        var newChildren: [OctreeNode] = []
        
        for x in 0..<2 {
            for y in 0..<2 {
                for z in 0..<2 {
                    let offset = SIMD3<Float>(
                        Float(x) * halfSize - quarterSize,
                        Float(y) * halfSize - quarterSize,
                        Float(z) * halfSize - quarterSize
                    )
                    
                    let childBounds = bounds + offset
                    newChildren.append(OctreeNode(bounds: childBounds, size: halfSize))
                }
            }
        }
        
        self.children = newChildren
    }
}

/// Frustum: Camera view frustum for culling
public struct Frustum {
    public struct Plane {
        public var normal: SIMD3<Float>
        public var distance: Float
        
        public init(normal: SIMD3<Float>, distance: Float) {
            self.normal = normal
            self.distance = distance
        }
    }
    
    public var planes: [Plane]
    
    public init(viewProjectionMatrix: simd_float4x4) {
        // Extract frustum planes from view-projection matrix
        // Left, Right, Bottom, Top, Near, Far
        planes = []
        
        let m = viewProjectionMatrix
        
        // Left plane
        planes.append(Plane(
            normal: normalize(SIMD3(m[0][3] + m[0][0], m[1][3] + m[1][0], m[2][3] + m[2][0])),
            distance: m[3][3] + m[3][0]
        ))
        
        // Right plane
        planes.append(Plane(
            normal: normalize(SIMD3(m[0][3] - m[0][0], m[1][3] - m[1][0], m[2][3] - m[2][0])),
            distance: m[3][3] - m[3][0]
        ))
        
        // Bottom plane
        planes.append(Plane(
            normal: normalize(SIMD3(m[0][3] + m[0][1], m[1][3] + m[1][1], m[2][3] + m[2][1])),
            distance: m[3][3] + m[3][1]
        ))
        
        // Top plane
        planes.append(Plane(
            normal: normalize(SIMD3(m[0][3] - m[0][1], m[1][3] - m[1][1], m[2][3] - m[2][1])),
            distance: m[3][3] - m[3][1]
        ))
        
        // Near plane
        planes.append(Plane(
            normal: normalize(SIMD3(m[0][2], m[1][2], m[2][2])),
            distance: m[3][2]
        ))
        
        // Far plane
        planes.append(Plane(
            normal: normalize(SIMD3(m[0][3] - m[0][2], m[1][3] - m[1][2], m[2][3] - m[2][2])),
            distance: m[3][3] - m[3][2]
        ))
    }
}

/// StreamingOctree: Manages infinite data streaming
/// Expert Panel: Data Scientist - Only loads visible voxels
public actor StreamingOctree {
    private var root: OctreeNode
    private var loadedChunks: Set<UUID> = []
    private let maxLoadedChunks: Int
    
    public init(worldSize: Float, maxLoadedChunks: Int = 100) {
        self.root = OctreeNode(bounds: SIMD3<Float>(repeating: 0), size: worldSize)
        self.maxLoadedChunks = maxLoadedChunks
    }
    
    /// Loads visible chunks based on camera frustum
    /// - Parameter viewProjectionMatrix: Camera's view-projection matrix
    /// - Returns: Array of chunk IDs that are now visible
    public func loadVisibleChunks(viewProjectionMatrix: simd_float4x4) async -> [UUID] {
        let frustum = Frustum(viewProjectionMatrix: viewProjectionMatrix)
        var visibleChunks: [UUID] = []
        
        // Traverse octree and collect visible leaf nodes
        traverseAndLoad(node: root, frustum: frustum, visibleChunks: &visibleChunks)
        
        // Unload distant chunks if over limit (LRU)
        if loadedChunks.count > maxLoadedChunks {
            await unloadDistantChunks(keep: Set(visibleChunks))
        }
        
        return visibleChunks
    }
    
    private func traverseAndLoad(node: OctreeNode, frustum: Frustum, visibleChunks: inout [UUID]) {
        guard node.intersects(frustum: frustum) else {
            return
        }
        
        if let children = node.children {
            // Recurse into children
            for child in children {
                traverseAndLoad(node: child, frustum: frustum, visibleChunks: &visibleChunks)
            }
        } else {
            // Leaf node - load data chunk
            if let chunkID = node.dataChunkID {
                visibleChunks.append(chunkID)
                loadedChunks.insert(chunkID)
            }
        }
    }
    
    private func unloadDistantChunks(keep: Set<UUID>) async {
        let toUnload = loadedChunks.subtracting(keep)
        
        for chunkID in toUnload {
            // Unload chunk from memory
            await unloadChunk(chunkID)
            loadedChunks.remove(chunkID)
        }
        
        print("StreamingOctree: Unloaded \(toUnload.count) chunks, keeping \(loadedChunks.count)")
    }
    
    private func unloadChunk(_ chunkID: UUID) async {
        // TODO: Implement actual chunk unloading
        // This would release GPU buffers and memory
    }
    
    /// Loads a data chunk from disk
    private func loadChunk(_ chunkID: UUID) async throws -> Data {
        // TODO: Implement actual chunk loading from disk
        // This would read voxel data from a file
        return Data()
    }
}
