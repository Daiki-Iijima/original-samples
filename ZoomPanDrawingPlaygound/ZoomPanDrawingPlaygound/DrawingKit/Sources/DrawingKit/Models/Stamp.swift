import CoreGraphics
import UIKit

/// スタンプ種別
public enum StampKind: String, Equatable, Codable {
    case check
    case cross
    case circle
}

/// スタンプが持つ情報描画情報
public struct StampStyle: Equatable {
    public var color: UIColor
    public var size: CGFloat
    public var opacity: CGFloat

    public init(color: UIColor, size: CGFloat, opacity: CGFloat) {
        self.color = color
        self.size = size
        self.opacity = opacity
    }

    @MainActor public static let initial = StampStyle(color: .red, size: 36, opacity: 1)
}

/// スタンプが持つ要素
public struct Stamp: Equatable {
    public var id: UUID
    public var kind: StampKind
    public var center: CGPoint
    public var style: StampStyle

    public init(id: UUID = UUID(), kind: StampKind, center: CGPoint, style: StampStyle) {
        self.id = id
        self.kind = kind
        self.center = center
        self.style = style
    }
}
