import CoreGraphics
import UIKit

/// 矩形の塗りつぶし
public enum RectFill: Equatable {
    case none
    case solid(UIColor)
}

/// 画像座標（= canvas座標）で扱う矩形のスタイル
public struct CanvasRectStyle: Equatable, @unchecked Sendable {
    public var strokeColor: UIColor
    public var strokeWidth: CGFloat
    public var fill: RectFill

    public init(
        strokeColor: UIColor,
        strokeWidth: CGFloat = 2,
        fill: RectFill = .none
    ) {
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.fill = fill
    }

    public static let initial = CanvasRectStyle(
        strokeColor: .systemYellow,
        strokeWidth: 2,
        fill: .none
    )
}

/// 画像座標（左上原点）で指定する矩形
public struct CanvasRect: Equatable, Identifiable {
    public var id: UUID
    public var rect: CGRect  // canvas座標：左上原点、width/height
    public var style: CanvasRectStyle

    public init(
        id: UUID = UUID(),
        rect: CGRect,
        style: CanvasRectStyle = .initial
    ) {
        self.id = id
        self.rect = rect
        self.style = style
    }
}
