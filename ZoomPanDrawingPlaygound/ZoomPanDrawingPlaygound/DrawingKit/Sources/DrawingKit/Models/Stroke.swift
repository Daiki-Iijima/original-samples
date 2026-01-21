import CoreGraphics
import Foundation

/// 1本の線（ストローク）
public struct Stroke: Equatable {
    public var id: UUID
    public var points: [CGPoint]
    public var style: PenStyle

    public init(id: UUID = UUID(), points: [CGPoint], style: PenStyle) {
        self.id = id
        self.points = points
        self.style = style
    }
}
