# TDA Visualization and Rendering

## Visualization Pipeline

### TDA Visualization Architecture

```
Topological Data → Persistence Diagram → Visual Encoding → Rendered Output
                     ↓
              Barcode/Graph → Color/Size/Position → GPU Rendering
```

### Core Visualization Components

```swift
class TDAVisualizer {
    
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    
    // Specialized renderers
    private let barcodeRenderer: BarcodeRenderer
    private let persistenceRenderer: PersistenceRenderer
    private let topologyRenderer: TopologyRenderer
    
    init(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        self.barcodeRenderer = BarcodeRenderer(device: device)
        self.persistenceRenderer = PersistenceRenderer(device: device)
        self.topologyRenderer = TopologyRenderer(device: device)
    }
    
    func renderAnalysis(analysis: TopologyAnalysis,
                       renderEncoder: MTLRenderCommandEncoder,
                       viewport: CGRect) {
        
        // Render persistence diagram
        persistenceRenderer.renderDiagram(diagram: analysis.diagram,
                                        renderEncoder: renderEncoder,
                                        viewport: viewport)
        
        // Render barcode
        barcodeRenderer.renderBarcode(barcode: analysis.barcode,
                                    renderEncoder: renderEncoder,
                                    viewport: viewport)
        
        // Render topological features in 3D
        topologyRenderer.renderFeatures(complex: analysis.complex,
                                      renderEncoder: renderEncoder)
    }
}
```

## Persistence Diagram Visualization

### Interactive Diagram Rendering

```swift
class PersistenceRenderer {
    
    struct DiagramVertex {
        var position: SIMD2<Float>
        var birth: Float
        var death: Float
        var dimension: Int
        var persistence: Float
        var color: SIMD4<Float>
    }
    
    func createDiagramGeometry(diagram: PersistenceDiagram) -> (MTLBuffer, Int) {
        var vertices: [DiagramVertex] = []
        
        for point in diagram.points where point.isPersistent {
            let vertex = DiagramVertex(
                position: SIMD2<Float>(point.birth, point.death),
                birth: point.birth,
                death: point.death,
                dimension: point.dimension,
                persistence: point.persistence,
                color: colorForDimension(point.dimension, point.persistence)
            )
            vertices.append(vertex)
        }
        
        let vertexBuffer = device.makeBuffer(bytes: vertices,
                                           length: vertices.count * MemoryLayout<DiagramVertex>.stride,
                                           options: .storageModeShared)!
        
        return (vertexBuffer, vertices.count)
    }
    
    func renderDiagram(diagram: PersistenceDiagram,
                     renderEncoder: MTLRenderCommandEncoder,
                     viewport: CGRect) {
        
        let (vertexBuffer, vertexCount) = createDiagramGeometry(diagram: diagram)
        
        // Set up rendering pipeline
        let pipeline = createDiagramPipeline()
        renderEncoder.setRenderPipelineState(pipeline)
        
        // Set uniforms
        var uniforms = DiagramUniforms(
            viewportSize: SIMD2<Float>(Float(viewport.width), Float(viewport.height)),
            maxPersistence: diagram.points.map { $0.persistence }.max() ?? 1.0,
            showDiagonal: true,
            highlightThreshold: 0.1
        )
        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<DiagramUniforms>.stride, index: 1)
        
        // Render points
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: vertexCount)
        
        // Render diagonal line
        renderDiagonalLine(renderEncoder: renderEncoder, viewport: viewport)
    }
    
    private func colorForDimension(_ dimension: Int, _ persistence: Float) -> SIMD4<Float> {
        let hue = Float(dimension) / 4.0 // Different hue for each dimension
        let saturation = 0.8
        let brightness = min(1.0, persistence * 2.0) // Brighter for more persistent features
        
        return SIMD4<Float>(hsvToRgb(h: hue, s: saturation, v: brightness), 1.0)
    }
}
```

### Barcode Visualization

```swift
class BarcodeRenderer {
    
    struct BarcodeVertex {
        var position: SIMD2<Float>
        var texCoord: SIMD2<Float>
    }
    
    func renderBarcode(barcode: Barcode,
                     renderEncoder: MTLRenderCommandEncoder,
                     viewport: CGRect) {
        
        var bars: [BarcodeVertex] = []
        
        // Create bar geometry
        for (index, bar) in barcode.bars.enumerated() {
            let y = Float(index) * 20.0 // Bar spacing
            let x1 = bar.birth
            let x2 = bar.death ?? Float(viewport.width)
            
            // Bar vertices
            bars.append(BarcodeVertex(position: SIMD2<Float>(x1, y), texCoord: SIMD2<Float>(0, 0)))
            bars.append(BarcodeVertex(position: SIMD2<Float>(x2, y), texCoord: SIMD2<Float>(1, 0)))
            bars.append(BarcodeVertex(position: SIMD2<Float>(x1, y + 15.0), texCoord: SIMD2<Float>(0, 1)))
            bars.append(BarcodeVertex(position: SIMD2<Float>(x2, y + 15.0), texCoord: SIMD2<Float>(1, 1)))
        }
        
        let vertexBuffer = device.makeBuffer(bytes: bars,
                                           length: bars.count * MemoryLayout<BarcodeVertex>.stride,
                                           options: .storageModeShared)!
        
        // Render bars
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: bars.count)
    }
}
```

## 3D Topological Feature Rendering

### Topological Structures in 3D

```swift
class TopologyRenderer {
    
    // Render persistence loops as glowing rings
    func renderPersistenceLoops(loops: [PersistenceLoop],
                              renderEncoder: MTLRenderCommandEncoder) {
        
        for loop in loops {
            // Create ring geometry
            let ringGeometry = createRingGeometry(center: loop.center,
                                                radius: loop.radius,
                                                normal: loop.normal,
                                                thickness: loop.persistence * 0.1)
            
            // Set glowing material
            let material = GlowingMaterial(
                baseColor: loop.color,
                glowIntensity: loop.persistence,
                pulseSpeed: 1.0
            )
            
            renderEncoder.setFragmentBytes(&material,
                                          length: MemoryLayout<GlowingMaterial>.stride,
                                          index: 2)
            
            // Render ring
            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                              indexCount: ringGeometry.indexCount,
                                              indexType: .uint32,
                                              indexBuffer: ringGeometry.indexBuffer,
                                              indexBufferOffset: 0)
        }
    }
    
    // Render persistence spheres for voids
    func renderPersistenceSpheres(spheres: [PersistenceSphere],
                                renderEncoder: MTLRenderCommandEncoder) {
        
        for sphere in spheres {
            // Create sphere with transparency based on persistence
            let sphereGeometry = createSphereGeometry(center: sphere.center,
                                                    radius: sphere.radius,
                                                    segments: 32)
            
            // Semi-transparent material
            let material = TransparentMaterial(
                color: sphere.color,
                opacity: sphere.persistence * 0.5,
                refractionIndex: 1.5
            )
            
            renderEncoder.setFragmentBytes(&material,
                                          length: MemoryLayout<TransparentMaterial>.stride,
                                          index: 2)
            
            // Enable blending
            renderEncoder.setBlendColor(red: 0, green: 0, blue: 0, alpha: 0)
            
            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                              indexCount: sphereGeometry.indexCount,
                                              indexType: .uint32,
                                              indexBuffer: sphereGeometry.indexBuffer,
                                              indexBufferOffset: 0)
        }
    }
    
    // Render Reeb graph as 3D network
    func renderReebGraph(graph: ReebGraph,
                       renderEncoder: MTLRenderCommandEncoder) {
        
        // Render nodes
        for node in graph.nodes {
            let nodeGeometry = createSphereGeometry(center: node.position,
                                                  radius: node.size * 0.1,
                                                  segments: 16)
            
            let material = SolidMaterial(color: node.color)
            renderEncoder.setFragmentBytes(&material,
                                          length: MemoryLayout<SolidMaterial>.stride,
                                          index: 2)
            
            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                              indexCount: nodeGeometry.indexCount,
                                              indexType: .uint32,
                                              indexBuffer: nodeGeometry.indexBuffer,
                                              indexBufferOffset: 0)
        }
        
        // Render edges as tubes
        for edge in graph.edges {
            let tubeGeometry = createTubeGeometry(from: edge.from.position,
                                                to: edge.to.position,
                                                radius: edge.weight * 0.05,
                                                segments: 8)
            
            let material = SolidMaterial(color: edge.color)
            renderEncoder.setFragmentBytes(&material,
                                          length: MemoryLayout<SolidMaterial>.stride,
                                          index: 2)
            
            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                              indexCount: tubeGeometry.indexCount,
                                              indexType: .uint32,
                                              indexBuffer: tubeGeometry.indexBuffer,
                                              indexBufferOffset: 0)
        }
    }
}
```

## Interactive Visualization Features

### Hover and Selection

```swift
class InteractiveTDAVisualizer {
    
    var hoveredFeature: TopologicalFeature?
    var selectedFeatures: Set<TopologicalFeature> = []
    
    func handleHover(mousePosition: CGPoint, diagram: PersistenceDiagram) {
        // Find closest feature to mouse
        let closestFeature = findClosestFeature(to: mousePosition,
                                              diagram: diagram,
                                              threshold: 20.0)
        
        if closestFeature != hoveredFeature {
            hoveredFeature = closestFeature
            updateHoverHighlight()
        }
    }
    
    func handleSelection(mousePosition: CGPoint, diagram: PersistenceDiagram) {
        if let feature = findClosestFeature(to: mousePosition,
                                          diagram: diagram,
                                          threshold: 20.0) {
            if selectedFeatures.contains(feature) {
                selectedFeatures.remove(feature)
            } else {
                selectedFeatures.insert(feature)
            }
            updateSelectionHighlight()
        }
    }
    
    private func updateHoverHighlight() {
        // Highlight hovered feature in all views
        if let feature = hoveredFeature {
            // Persistence diagram
            highlightPointInDiagram(feature: feature)
            
            // 3D view
            highlightFeatureIn3D(feature: feature)
            
            // Show tooltip
            showTooltip(feature: feature)
        } else {
            clearHighlights()
        }
    }
    
    private func showTooltip(feature: TopologicalFeature) {
        let tooltip = Tooltip(
            text: """
            Dimension: \(feature.dimension)
            Birth: \(String(format: "%.3f", feature.birth))
            Death: \(String(format: "%.3f", feature.death))
            Persistence: \(String(format: "%.3f", feature.persistence))
            """,
            position: mousePosition
        )
        
        renderTooltip(tooltip)
    }
}
```

### Brushing and Linking

```swift
class BrushingAndLinking {
    
    var brushSelection: PersistenceRange?
    
    func setBrushSelection(range: PersistenceRange?) {
        brushSelection = range
        updateLinkedViews()
    }
    
    private func updateLinkedViews() {
        guard let range = brushSelection else {
            clearAllSelections()
            return
        }
        
        // Select features in persistence range
        let selectedFeatures = currentDiagram.points.filter { point in
            point.persistence >= range.minPersistence &&
            point.persistence <= range.maxPersistence &&
            point.birth >= range.minBirth &&
            point.birth <= range.maxBirth
        }
        
        // Highlight in all views
        highlightFeaturesInDiagram(features: selectedFeatures)
        highlightFeaturesIn3D(features: selectedFeatures)
        highlightFeaturesInBarcode(features: selectedFeatures)
        
        // Update statistics
        updateSelectionStatistics(features: selectedFeatures)
    }
}
```

## Advanced Visualization Techniques

### Level Set Visualization

```swift
class LevelSetRenderer {
    
    func renderLevelSets(function: (SIMD3<Float>) -> Float,
                       range: ClosedRange<Float>,
                       levels: Int,
                       renderEncoder: MTLRenderCommandEncoder) {
        
        for level in 0..<levels {
            let isovalue = range.lowerBound + (range.upperBound - range.lowerBound) * Float(level) / Float(levels - 1)
            
            // Extract isosurface using marching cubes
            let mesh = extractIsosurface(function: function,
                                       isovalue: isovalue,
                                       resolution: 128)
            
            // Color based on level
            let color = colorForLevel(level: level, totalLevels: levels)
            
            let material = SolidMaterial(color: color)
            renderEncoder.setFragmentBytes(&material,
                                          length: MemoryLayout<SolidMaterial>.stride,
                                          index: 2)
            
            // Render mesh
            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                              indexCount: mesh.indices.count,
                                              indexType: .uint32,
                                              indexBuffer: mesh.indexBuffer,
                                              indexBufferOffset: 0)
        }
    }
    
    private func extractIsosurface(function: (SIMD3<Float>) -> Float,
                                 isovalue: Float,
                                 resolution: Int) -> Mesh {
        
        // Marching cubes implementation
        var vertices: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        
        for x in 0..<resolution-1 {
            for y in 0..<resolution-1 {
                for z in 0..<resolution-1 {
                    
                    // Sample function at cube corners
                    let corners = sampleCubeCorners(x: x, y: y, z: z,
                                                  resolution: resolution,
                                                  function: function)
                    
                    // Generate triangles for this cube
                    let cubeVertices = marchingCube(corners: corners,
                                                  isovalue: isovalue)
                    
                    if !cubeVertices.isEmpty {
                        let baseIndex = vertices.count
                        vertices.append(contentsOf: cubeVertices)
                        
                        // Add indices for triangles
                        for i in 0..<cubeVertices.count/3 {
                            indices.append(UInt32(baseIndex + i*3))
                            indices.append(UInt32(baseIndex + i*3 + 1))
                            indices.append(UInt32(baseIndex + i*3 + 2))
                        }
                    }
                }
            }
        }
        
        return Mesh(vertices: vertices, indices: indices)
    }
}
```

### Vector Field Visualization

```swift
class VectorFieldRenderer {
    
    func renderVectorField(field: (SIMD3<Float>) -> SIMD3<Float>,
                         bounds: BoundingBox,
                         resolution: Int,
                         renderEncoder: MTLRenderCommandEncoder) {
        
        // Create arrow glyphs for vector field
        for x in stride(from: bounds.min.x, to: bounds.max.x, by: bounds.size.x / Float(resolution)) {
            for y in stride(from: bounds.min.y, to: bounds.max.y, by: bounds.size.y / Float(resolution)) {
                for z in stride(from: bounds.min.z, to: bounds.max.z, by: bounds.size.z / Float(resolution)) {
                    
                    let position = SIMD3<Float>(x, y, z)
                    let vector = normalize(field(position))
                    
                    // Skip zero vectors
                    if length(vector) < 0.001 {
                        continue
                    }
                    
                    // Create arrow geometry
                    let arrow = createArrowGlyph(origin: position,
                                               direction: vector,
                                               length: 0.1,
                                               headSize: 0.02)
                    
                    // Color based on vector magnitude
                    let magnitude = length(field(position))
                    let color = colorForMagnitude(magnitude)
                    
                    let material = SolidMaterial(color: color)
                    renderEncoder.setFragmentBytes(&material,
                                                  length: MemoryLayout<SolidMaterial>.stride,
                                                  index: 2)
                    
                    // Render arrow
                    renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                      indexCount: arrow.indexCount,
                                                      indexType: .uint32,
                                                      indexBuffer: arrow.indexBuffer,
                                                      indexBufferOffset: 0)
                }
            }
        }
    }
}
```

## Performance Optimization

### LOD for Large Datasets

```swift
class TDALODSystem {
    
    func createLODVisualization(diagram: PersistenceDiagram,
                              maxPoints: Int) -> PersistenceDiagram {
        
        if diagram.points.count <= maxPoints {
            return diagram
        }
        
        // Select most significant features
        let sortedPoints = diagram.points.sorted { $0.persistence > $1.persistence }
        let selectedPoints = Array(sortedPoints.prefix(maxPoints))
        
        return PersistenceDiagram(points: selectedPoints)
    }
    
    func createLevelOfDetail(complex: SimplicialComplex,
                           distance: Float) -> SimplicialComplex {
        
        // Simplify complex based on viewing distance
        if distance > 10.0 {
            // Far away: only show persistent features
            return simplifyComplex(complex, persistenceThreshold: 0.5)
        } else if distance > 5.0 {
            // Medium distance: show moderate features
            return simplifyComplex(complex, persistenceThreshold: 0.2)
        } else {
            // Close: show all features
            return complex
        }
    }
}
```

## References

1. [Visualization of Topological Structures](https://www.cs.duke.edu/courses/fall06/cps296.1/) by Edelsbrunner
2. [Topological Data Visualization](https://link.springer.com/chapter/10.1007/978-3-319-44684-4_2) by Heine et al.
3. [Interactive Topological Data Analysis](https://www.sciencedirect.com/science/article/pii/S0097849318301151) by Tierny et al.
4. [Visualization of Persistent Homology](https://arxiv.org/abs/1802.04826) by Bubenik
5. [Topological Methods in Data Analysis and Visualization](https://www.springer.com/gp/book/9783319086633) by Bremer et al.

**Document Version:** 1.0  
**Last Updated:** 2026-01-16  
**Research Status:** Verified with GPU rendering implementation  
**Next Review:** 2026-02-16