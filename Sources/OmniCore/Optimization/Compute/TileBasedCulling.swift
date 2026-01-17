import Foundation
import CoreGraphics

/// **The Compute Sub-System (The Logic Sub-System)**
///
/// A module that divides the screen into 16x16 tiles. If a tile contains no data,
/// the GPU is instructed to "sleep" for those pixels. This saves battery and heat.
public protocol TileBasedCulling {
    /// The size of the tile (e.g., 16x16).
    var tileSize: CGSize { get }

    /// Analyses the scene and returns a list of visible tiles.
    /// - Parameter viewport: The current viewport rect.
    /// - Returns: An array of rects representing the visible tiles.
    func calculateVisibleTiles(in viewport: CGRect) -> [CGRect]

    /// Generates a mask texture indicating active and inactive tiles.
    /// - Returns: A texture or buffer handle representing the culling mask.
    func generateCullingMask() -> Any
}
